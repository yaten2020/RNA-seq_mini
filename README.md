# A minimalist RNA-seq pipeline
This repository contains a [Nextflow](https://www.nextflow.io/) pipeline that can be executed either **locally** or on the **SGE cluster** of your choice.
The pipeline uses a global Conda environment defined in `conda_env.yml`.

---

## Setup
for singularity:
```
NXF_SINGULARITY_CACHEDIR # singularity packages fetched by nextflow
SINGULARITY_CACHEDIR #  singularity packages managed by singularity itself. default is ~/.singularity
```


1. Ensure you have [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html) installed:
   ```bash
   curl -s https://get.nextflow.io | bash
   mv nextflow ~/bin/   # or another location in your PATH

   # install java runtime
   curl -s "https://get.sdkman.io" | bash
   source "$HOME/.sdkman/bin/sdkman-init.sh"
   sdk install java 21.0.2-tem
   ```
2. Clone this repository and `cd` into it:
   ```bash
   git clone <https://github.com/yaten2020/RNA-seq_mini.git>
   cd RNA-seq_mini
   ```

##  Repository structure

```
README.md     # as it says.
├── bin
│   ├── conda_env.yml                 # conda packages for the analysis
│   ├── nextflow_conda.config         # config file to use when using it with conda
│   ├── nextflow_singularity.config   # config file to use when using singularity
│   ├── rna_seq_conda.nf              # conda version of the pipeline
│   ├── rna_seq_singularity.nf        # singularity version of the pipeline
│   ├── sge_conda.config              # config file to use when on SGE cluster
│   └── sge_singularity.config        # config file to use when on SGE cluster
└── data                          # small size fastq and bam files to use.
```


## Configuration

Pipeline can be used with conda or singularity:

**Configure the pipeline to run with conda:**
```bash
# Make sure Conda (or Mamba) is available on your system
module load anaconda
cp bin/rna_seq_conda.nf ./main.nf
cp bin/nextflow_conda.config nextflow.config
nextflow run main.nf -profile standard  # this will run the pipeline for the sample data included in the repo.
   ```
**Running the pipeline with singularity containers:**
```bash
# make sure you have singularity in your execatable PATH.
module load singularity
cp bin/rna_seq_singularity.nf ./main.nf
cp bin/nextflow_singularity.config ./nextflow.config
nextflow run main.nf -profile standard  # this will run the pipeline for the sample data included in the repo.
```
___

## Running the pipeline

The pipeline behavior is controlled via **profiles** in `nextflow.config`.

### Local execution
- Use the `standard` profile for local machine. This is setup to use one thread and 4 GB memory so that it does not crash your system.
- Concurrency is limited to **2 processes** at a time (to avoid overloading your machine).
- Any resource requests in `main.nf` are **ignored** when using this profile.
```bash
nextflow run RNAseq.nf -profile standard
```
### SGE cluster execution
Use the `sge_cluster` profile to run on the SGE cluster of your choice:
```bash
nextflow run main.nf -profile sge_cluster
```
Make sure you have the **SGE config** file provided by your system admin.

**Option-1**: You can plug it into line-32 of nextflow.config file, using the option `includeConfig` call in the  file.
```
includeConfig "$projectDir/bin/sge_conda.config"
```
**Option-2** Specify the SGE config at the command line:
```bash
nextflow run main.nf -profile sge_cluster -c YOUR_SGE_CONFIG_file
```
Default resources (if not specified in process blocks inside `main.nf`): 10 CPUs each with 16 GB memory for 12 hours.

Resources when specified in `main.nf` inside process blocks are always honoured.

## Overriding defaults

- You can always override defaults with extra config files:

```bash
nextflow run main.nf -profile sge_cluster -c --reads 'data/yeast/reads/*_{1,2}.fq.gz' --outdir 'path/of/your/choice'
```
**Reading in your own data:**
- you can speciy a csv file (sampleID,path/to/fastq_1,path/to/fastq_2), first line should be a header line.
```bash
nextflow run main.nf -profile sge_cluster --input_csv metadata.csv
```
## Parameters

| Parameter   | Description                                | Default   |
|-------------|--------------------------------------------|-----------|
| `--reads`   | Path to the input file(s) (e.g. FASTQ)     | `data/yeast/reads/ref1_{1,2}.fq.gz` |
| `--input_csv` | CSV file with your sample IDs and path to FASTQ files | `null` |
| `--outdir`  | Directory where results will be saved      | `results/` |
| `--threads` | Number of threads to use (per process)     | Inherited from profile defaults |
> ℹ️ If `--threads` is provided, it should match or override `cpus` in `main.nf` (when using the `sge_cluster` profile). In the `standard` profile, `cpus` is always fixed to 1 regardless of this parameter.

---
## Notes
- For local testing, start with small inputs and the `standard` profile.
- For production runs on your SGE cluster, always use `-profile sge_cluster`.
