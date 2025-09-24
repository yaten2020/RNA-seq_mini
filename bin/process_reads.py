#!/usr/bin/env python
# process_reads.py
import gzip
import sys
reads = 0
bases = 0


with gzip.open(sys.argv[1], 'rb') as read:
    for id in read:
      seq = next(read)
      reads += 1
      bases += len(seq.strip())
      next(read)
      next(read)

print("reads", reads)
print("bases", bases)
