// ---------------
// parameters
// ---------------
params.reads = "data/yeast/reads/ref1_{1,2}.fq.gz"
params.transcriptome = "data/yeast/transcriptome/Saccharomyces_cerevisiae.R64-1-1.cdna.all.fa.gz"
params.outdir = "results"
params.input_csv = null  // supply a csv with sampleID, read1, read2 records, one per line.

// ----------------
// Input channels
// ----------------

// Capture the fasta file with all the transcripts for salmon.
transcriptome_ch = Channel.fromPath( params.transcriptome, checkIfExists:true )

// Add an option to read sample metadata from a csv file.
if (params.input_csv) {
    log.info "Reading inputs from CSV: ${params.input_csv}"

    read_pairs_ch = Channel
        .fromPath(params.input_csv)
        .splitCsv(header:true)
        .map { row ->
            def f1 = file(row.fastq_1)
            def f2 = file(row.fastq_2)

            if (!f1.exists()) exit 1, "ERROR: FASTQ file not found -> ${f1}"
            if (!f2.exists()) exit 1, "ERROR: FASTQ file not found -> ${f2}"

            tuple(row.sample_id, [f1, f2])   // <-- matches fromFilePairs
        }

} else {
    log.info "Using default reads pattern: ${params.reads}"

    read_pairs_ch = Channel.fromFilePairs(params.reads, checkIfExists: true).view()
}

log.info """\
         R N A S E Q - N F   P I P E L I N E
         ===================================
         transcriptome: ${params.transcriptome}
         reads        : ${params.reads}
         outdir       : ${params.outdir}
         """
         .stripIndent()


// Define the `INDEX` process that create a binary index given the transcriptome file in multi-fasta format.

process INDEX {
    container = "https://depot.galaxyproject.org/singularity/salmon:1.10.3--haf24da9_3"
    input:
    path transcriptome

    output:
    path 'index'

    script:
    """
    salmon index --threads $task.cpus -t $transcriptome -i index
    """
}

// Run Salmon to perform the quantification of expression using the index and the matched read files

process QUANT {
    container = "https://depot.galaxyproject.org/singularity/salmon:1.10.3--haf24da9_3"
    tag "quantification on ${sample_id}"
    publishDir "${params.outdir}/quant", mode:'copy'

    input:
    each index
    tuple val(sample_id), path(reads)

    output:
    path(sample_id)

    script:
    """
    salmon quant --threads $task.cpus --libType=U -i $index -1 ${reads[0]} -2 ${reads[1]} -o ${sample_id}
    """
}

// Run fastQC to check quality of reads files

process FASTQC {
    tag "FASTQC on $sample_id"
    container = "quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0"

    input:
    tuple val(sample_id), path(reads)

    output:
    path("fastqc_${sample_id}_logs")  // here, path() is used as a function to convert the string into a path.

    script:
    """
    mkdir fastqc_${sample_id}_logs
    fastqc -o fastqc_${sample_id}_logs -f fastq -q ${reads} --threads $task.cpus
    """
}

// Create a report using multiQC for the quantification and fastqc processes
//
process MULTIQC {
    publishDir "${params.outdir}/multiqc", mode:'copy'
    container = "quay.io/biocontainers/multiqc:1.23--pyhdfd78af_0"

    input:
    path('*')

    output:
    path('multiqc_report.html')

    script:
    """
    multiqc .
    """
}

workflow {
    index_ch = INDEX( transcriptome_ch )
    quant_ch = QUANT( index_ch, read_pairs_ch )
    fastqc_ch = FASTQC(read_pairs_ch)
    MULTIQC( quant_ch.mix( fastqc_ch ).collect() )
 }

workflow.onComplete {
        log.info ( workflow.success ? "\nDone! Open the following report in your browser --> $params.outdir/multiqc/multiqc_report.html\n" : "Oops .. something went wrong" )
}
