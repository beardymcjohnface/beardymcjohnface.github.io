---
layout: post
category: misc
title: "Managing thousands of pipeline files with permutations"
---

I'm working on a pipeline that uses and generates tens of thousands of files, and there's a good chance this could be 
expanded to produce hundreds of thousands. I wanted to avoid creating a few folders with thousands upon thousands of 
files in them, so I needed a way to distribute the files across a nested directory structure. 
<!--more-->

The solution I ended up using was inspired by the [Library of Babel](https://libraryofbabel.info/), which uses a 
[linear congruential generator](https://en.wikipedia.org/wiki/Linear_congruential_generator) (LCG) to produce unique 
blocks of text for the (sequentially numbered) 'pages' in the library. The library doesn't actually exist anywhere; the 
pages are generated when looked up but importantly, the text for a page is generated exactly the same each time.

The concept can be used in a pipeline to manage file locations. The character string of the sample names are converted 
to binary, and the integer of that bit string is returned. The integer is used as a seed to produce a pseudo-random 
integer. I say pseudo-random because the same integer is returned every time. This integer can be used for denoting the 
file location for that sample's files (e.g. the integer 5279 could denote the file path 5/2/7/9, or 52/79 etc.). The LCG 
formula is simply:

(_a_ * _X_ + _c_) mod _m_ 

Where _a_ is the multiplier, _X_ is the seed, _c_ is the increment, and _m_ is the modulus. For the LCG to work properly, 
_m_ should be larger than the expected permutations (or in this case, large enough for creating file paths), _m_ and _a_ 
should be relatively prime, and _c_ and _a_ should be close to _m_. This should ensure that samples with near-identical 
names will still produce very different integers. I'm using Snakemake, so my implementation is in Python:

```python
def sample_loc(sampleName):
    sampleLCG = int(sampleName.encode('utf-8').hex(), 16)
    sampleLCG = str((689413469847613948 * sampleLCG + 198413268946541531) % 987132987354497857)[1:]
    return os.path.join(sampleLCG[0:1],sampleLCG[1:3])
```

In the above example, 10 folders should be produced, each containing 100 folders. In this case, the samples should be 
fairly evenly distributed across 1000 different folders. 

```text
.
├── 0
│   ├── 00
│   │   ├── <sample>.R1.fastq.gz
│   │   ├── <sample>.R2.fastq.gz
│   │   ├── <sample>.bam
│   │   └── ...
│   ├── 01
│   │   ├── <sample>.R1.fastq.gz
│   │   ├── <sample>.R2.fastq.gz
│   │   └── ...
│   ...
├── 1
│   ├── 00
│   │   ├── <sample>.R1.fastq.gz
│   │   ├── ...
```

The function produced a minimum 15 character integer from each of my sample names which could be used to create a 
folder structure that is 1000-wide (1000 folders per folder) and five levels deep, yielding 1e8 total folders--slightly 
overkill. Alternatively the unused trailing characters could be used to give each sample its own unique folder within a 
nested structure.

The advantage of this is that if you know the sample name you know the location for its files (it is calculated very 
quickly), and you don't need to commit a dictionary of file paths to the system's memory. The location for that sample's 
files won't ever change, unless you start messing with the sample names or LCG values. You can create other functions to 
generate file manifests, target lists for Snakemake etc. Here is a function to return the file paths for all samples for
a given file extension.

```python
def all_sample_files(ext):
    files = []
    for sample in samples:
        files.append(os.path.join(sample_loc(sample), sample + ext))
    return files
```

You can then use it in Snakemake rules, for instance in rule 'all' to tell the pipeline to generate bam files for all 
your samples.

```python
rule all:
    input:
        all_sample_files('.bam')

rule map:
    input:
        os.path.join('{path}', '{sample}.R1.fastq.gz'),
        os.path.join('{path}', '{sample}.R2.fastq.gz'),
        'ref.fasta'
    output:
        os.path.join('{path}', '{sample}.bam')
    shell:
        ...
```

The only other issue is populating the samples' folders with the pipeline's input files. I did this using symlinks for 
the pipeline inputs, which were all dumped in a directory called 'reads'. Linking the pipeline inputs into the sample 
folders makes writing rules very simple (like in the rule 'map' above). To do the symlinks in the Snakefile:

```python
SAMPLES, = glob_wildcards(os.path.join('reads', '{sample}_R1.fastq.gz'))
for sample in SAMPLES:
    loc = sample_loc(sample)
    if not os.path.exists(loc):
        os.makedirs(loc, exist_ok=True)
    for r in ['R1', 'R2']:
        if not os.path.islink(os.path.join(loc, f'{sample}_{r}.fastq.gz')):
            os.symlink(
                os.path.join(os.getcwd(), 'reads', f'{sample}_{r}.fastq.gz'),
                os.path.join(os.getcwd(), loc, f'{sample}_{r}.fastq.gz'))
```

This 'randomness' of the LCG is important for making sure the samples are relatively evenly distributed. I generated 
integers for 15000ish sample names and collected the composition of the leading characters to check for evenness.

```text
cat list.out | cut -c1 | sort | uniq -c | sort -g
   1558 9
   1736 1
   1756 5
   1761 2
   1778 4
   1785 3
   1788 7
   1806 8
   1811 6
cat list.out | cut -c2 | sort | uniq -c | sort -g
   1477 9
...
   1629 5
cat list.out | cut -c3 | sort | uniq -c | sort -g
   1521 2
...
   1642 0
cat list.out | cut -c9 | sort | uniq -c | sort -g
   1550 6
...
   1609 1
```

The distributions are fairly even. I trim the first character to allow the top level folders to have leading zeros. I 
was curious if I could do the same thing with md5sums, i.e. md5 checksum of the sample name -> binary -> integer like so:

```python
import hashlib
sampleMd5 = hashlib.md5(sampleName.encode('utf-8')).hexdigest()
sampleInt = int(sampleMd5.encode('utf-8').hex(), 16)
```

and again checked the character distributions:

```text
$ cat list.out | cut -c1 | sort | uniq -c | sort -g
   5999 4
   9780 2
$ cat list.out | cut -c2 | sort | uniq -c | sort -g
    956 1
...
   4971 4
$ cat list.out | cut -c3 | sort | uniq -c | sort -g
   1015 1
...
   2395 8
$ cat list.out | cut -c9 | sort | uniq -c | sort -g
   1503 1
...
   1635 4
```

There was a lot of bias in the leading characters, but fairly even distributions at the end. You could probably just 
trim the first ten or so characters. I may have over-engineered my LCG solution, but it was fun nonetheless.
