---
layout: post
category: misc
title: "Introduction to Snakemake"
excerpt: "Yet another Snakemake tutorial..."
---

Snakemake gets its inspiration from the program _Make_.
_Make_ is an old program that was originally designed to compile and install software.
It was appropriated by bioinformaticians because the program is ideal for writing pipelines.

The key concept with Makefiles is that they describe __recipes__ not __steps__.
A recipe tells the computer how to create one type of file from another.
The magic happens by having one recipe to describe one step that can be used for hundreds of different files.

```text
file_to_make: file_to_read
    shell_command
```

An example Makefile to compile some FORTRAN code:

```text
# These recipes can only be used for newExe.f90 and newExe.o
newExe.o: newExe.f90
    gfortran -c newExe.f90

newExe: newExe.o
    gfortran -o newExe newExe.o

# This will run on any .f90 file
%.o: %.f90
    gfortran -o $@ -c $<

# This will run on any .o file
%: %.o
    gfortran -o $@ $<
```

# Setup

Follow the instructions [HERE](https://gist.github.com/beardymcjohnface/afebbebcdc1d64423870d6a3ee93d432) 
to set up your environment and files for the Snakemake tutorial.

# Test dataset

We will use the official tutorial files for this.
Clone with git, I'll be moving 'A/B/C.fastq' and 'genome.fa' into an empty directory.

```shell
git clone https://github.com/snakemake/snakemake-tutorial-data.git
```

# Minimum requirements for Snakefile

Using the same concept as before, you start with your destination, _then_ you describe the journey.
__By default, Snakemake runs the first rule it encounters in the Snakefile.__
This is important because we use the first rule--`rule all`-- to declare the pipeline targets.
There are no outputs or shell command for rule all,
so the rule just tells Snakemake that we need the file "A.sam".

Create a file called `Snakefile` and add the following:

```python
# Targets - what is the final thing the pipeline will make?
rule all:
    input:
        "A.sam"

# rules - how will the pipeline make the target files?
rule map_reads:
    input:
        "genome.fa",
        "A.fastq"
    output:
        "A.sam"
    shell:
        "minimap2 -a -x sr genome.fa A.fastq > A.sam"
```

This is your pipeline and Snakemake will recognise it when you run Snakemake.
The only thing you need to tell Snakemake at this stage is how many concurrent jobs to run.
For only 1 job at a time, you would run this:

`snakemake -j 1`

If you name your snakefile something else you need to tell Snakemake that it is your Snakefile. 
e.g. 

`snakemake -s mySnakeFile.smk -j 1`

# Chaining rules

SAM files are stupid, lets convert it to a BAM file.
Update the targets (your destination) and add a new rule for file conversion.

```python
# Targets
rule all:
    input:
        #"A.sam"
        "A.bam"

# rules
rule map_reads:
    input:
        "genome.fa",
        "A.fastq"
    output:
        "A.sam"
    shell:
        "minimap2 -a -x sr genome.fa A.fastq > A.sam"

rule convert_sam:
    input:
        "A.sam"
    output:
        "A.bam"
    shell:
        "samtools view -bh A.sam > A.bam"
```

Why is this better than a bash script?
Currently, it's not. 
Here's what the bash script would look like:

```shell
minimap2 -a -x sr genome.fa A.fastq > A.sam
samtools view -bh A.sam > A.bam
```

Snakemake is better in the long run though.

# Wildcards

You hardly ever have one sample, so we need recipes that will work for files with different names.
We also saw this concept at the top with the Makefile.
Snakemake uses jinja variables (curly braces) for wildcards and accessing elements in the shell commands.
Inputs and outputs can be accessed from the shell commands as these jinja variables.
If you're familiar with Python, these are __not__ the same as f-strings.

```python
# jinja variable - variable is interpreted by Snakemake
"{file}.bam"

# f-string - variable is resolved by Python BEFORE being passed to Snakemake
f"{file}.bam"
```

Wildcards must be consistent and present in both inputs and outputs.
They can be accessed in the shell command by prepending _wildcards._ like below.

```python
rule convert_sam:
    input:
        "{file}.sam"
    output:
        "{file}.bam"
    shell:
        "samtools view -bh {input} > {output}"
        # this would also work:
        # "samtools view -bh {wildcards.file}.sam > {wildcards.file}.bam
```

Now, the rule _convert_sam_ will match any file ending in _.sam_ and can make a _.bam_ file from it.


# Named inputs and outputs

For rule _map_reads_ we have two different inputs: the genome fasta file, and the reads to map.
This is a list and you can access list elements like normal with python, 
where `input[0]` is `genome.fa` and `input[1]` is `A.fastq`. 
This can get confusing quickly so named inputs are better.

convert the rule to use wildcards, and convert the inputs to named inputs.

```python
rule map_reads:
    input:
        genome = "genome.fa",
        reads = "{sample}.fastq"
    output:
        "{sample}.sam"
    shell:
        "minimap2 -a -x sr {input.genome} {input.reads} > {output}"
```


# Expand

Now that our rules will work with any sample names, lets declare the other samples as targets.
We can do this one-by-one like so:

```python
rule all:
    input:
        "A.bam",
        "B.bam",
        "C.bam"
```

Which is fine if you only have a couple of samples, but it's a pain if you have lots.
The expand function lets you declare multiple samples with similar prefixes and/or suffixes.
You can use this function to declare targets, or in regular rules for inputs or outputs etc.
You can also use it outside of rules in regular Python code.

```python
rule all:
    input:
        expand("{sample}.bam", sample=['A','B','C'])
```

# Temp files

After we convert the SAM to a BAM file, we don't need the SAM file.
We can tell Snakemake to delete any intermediate files as soon as it doesn't need them anymore.
We do this by marking them as temporary with `temp()` or `temporary()`.
Only outputs can be marked as temporary.

```python
rule map_reads:
    input:
        genome = "genome.fa",
        reads = "{sample}.fastq"
    output:
        temp("{sample}.sam")
    shell:
        "minimap2 -a -x sr {input.genome} {input.reads} > {output}"
```

# Protected files

If a certain job is very computationally expensive, 
you can make the output write-protected to prevent accidental deletion.
Just mark it with `protected()`

```python
rule convert_sam:
    input:
        "{file}.sam"
    output:
        protected("{file}.bam")
    shell:
        "samtools view -bh {input} > {output}"
```

# Configuration

At the moment, we have the reference genome and the sample names hard-coded in the pipeline.
This is bad practice.
If we want to run the pipeline on a different genome or with different samples, 
we would have to manually rename the file names throughout the Snakefile.
It is better to have the file names declared in a separate configuration file.

Create a new file called config.yaml and add the following:

```yaml
genome: genome.fa
samples:
 - A
 - B
 - C
# or 
# samples: ['A','B','C']
```

YAML is a very popular format for config files as it is very simple and human-readable.
Above, `genome` is a string variable with the value `genome.fa` 
and `samples` is a list with the variables `['A','B','C']`.

To use this config file in our pipeline, we can pass it when we run it like so:

`Snakemake -j 1 --configfile config.yaml`

or specify the config file name in the pipeline:

```python
configfile: "config.yaml"
```

You can also do both;
the command line option `--configfile` will override the file specified in the Snakefile.

We can now access the config variables in the pipeline via a dictionary variable called 'config'.
Let's update our pipeline to remove the hard-coded file names and use the config dictionary.

```python
configfile: "config.yaml"

rule all:
    input:
        expand("{sample}.bam", sample=config['samples'])

rule map_reads:
    input:
        genome = config['genome'],
        reads = "{sample}.fastq"
    output:
        temp("{sample}.sam")
    shell:
        "minimap2 -a -x sr {input.genome} {input.reads} > {output}"

rule convert_sam:
    input:
        "{file}.sam"
    output:
        "{file}.bam"
    shell:
        "samtools view -bh {input} > {output}"
```

# Directories

It's generally good practice to keep each rule's files in their own directories.
Let's move the reads to their own directory. 
Create a folder called `reads/` and move the sample `.fastq` files there.
Make sure the new file paths are specified in either the config file, or the Snakefile.
Let's save the SAM files to `temp/` and the BAM files to `output/`.

```python
configfile: "config.yaml"

rule all:
    input:
        expand("output/{sample}.bam", sample=config['samples'])

rule map_reads:
    input:
        genome = config['genome'],
        reads = "reads/{sample}.fastq"
    output:
        temp("temp/{sample}.sam")
    shell:
        "minimap2 -a -x sr {input.genome} {input.reads} > {output}"

rule convert_sam:
    input:
        "temp/{file}.sam"
    output:
        "output/{file}.bam"
    shell:
        "samtools view -bh {input} > {output}"
```

Snakemake will automatically create the directories if they don't exist,
and it will remove any empty directories after their temp files are removed.

It can be helpful to use variables for directory names in case you wish to change the 
directory structure of you pipeline, or have it a configurable option.

In the config.yaml file:

```yaml
genome: genome.fa
samples: ['A','B','C']
outputDirectory: output
readDirectory: reads
```

In the Snakefile, use Python's plus symbol for string concatenation to combine string variables with bare strings.
e.g. `out_dir + "/{sample}.bam"` will result in `"output/{sample}.bam"`.

```python
configfile: "config.yaml"

temp_dir = 'temp'
out_dir = config['outputDirectory']
read_dir = config['readDirectory']

rule all:
    input:
        expand(out_dir + "/{sample}.bam", sample=config['samples'])

rule map_reads:
    input:
        genome = config['genome'],
        reads = read_dir + "/{sample}.fastq"
    output:
        temp(temp_dir + "/{sample}.sam")
    shell:
        "minimap2 -a -x sr {input.genome} {input.reads} > {output}"

rule convert_sam:
    input:
        temp_dir + "/{file}.sam"
    output:
        out_dir + "/{file}.bam"
    shell:
        "samtools view -bh {input} > {output}"
```

# Threads

Snakemake supports some sophistocated resource management.
The most obvious is multithreading.
Minimap2 can utilise say 8 threads by passing the `-t 8` on the command line.
We can tell Snakemake how many threads a job will use, and it will adjust jobs accordingly.

Let's tell Snakemake to use 8 threads for the mapping step with `Threads:` and tell Minimap to use that many threads.

```python
rule map_reads:
    input:
        genome = config['genome'],
        reads = read_dir + "/{sample}.fastq"
    output:
        temp(temp_dir + "/{sample}.sam")
    threads:
        8
    shell:
        "minimap2 -t {threads} -a -x sr {input.genome} {input.reads} > {output}"
```

Now when we run the pipeline, if we increase `-j` to 8, minimap will use 8 threads. e.g.

`Snakemake -j 8`

If we leave it at 1, Snakemake will automatically scale the minimap step down to 1 thread.

# Params

It can be helpful to make run parameters for some steps customisable, rather than hard-coded in the rules.
At the moment, minimap is using short-read mapping parameters `-x sr`.
To map nanopore reads we would instead use `-x map-ont`.
Parameters can added as configuration options, included in rules under `params:`, 
and accessed in the command as jinja variables.
Like inputs and outputs, you can have multiple parameters and they can be named.

in config.yaml:

```yaml
genome: genome.fa
samples: ['A','B','C']
outputDirectory: output
readDirectory: reads
minimapParameters: -x sr
```

in the Snakefile:

```python
rule map_reads:
    input:
        genome = config['genome'],
        reads = read_dir + "/{sample}.fastq"
    output:
        temp(temp_dir + "/{sample}.sam")
    threads:
        8
    params:
        config['minimapParameters']
    shell:
        "minimap2 -t {threads} -a {params} {input.genome} {input.reads} > {output}"
```

# conda environments

Installing things with conda is easy.
Making Snakemake do it is even easier.
You can declare a conda environment for a rule to ensure that the correct version of the program is being used,
and that it is in an isolated environment that will not mess with other programs.

Create a directory to host your environment files called `envs/` and create a file in it called `minimap.yaml`.
This file will tell Snakemake what programs it needs to install from conda to run a particular rule.

```yaml
name: minimap2
channels:
    - bioconda
    - conda-forge
    - defaults
dependencies:
    - minimap2>=2.20
```

Use this environment in a rule with `conda:` like so:

```python
rule map_reads:
    input:
        genome = config['genome'],
        reads = read_dir + "/{sample}.fastq"
    output:
        temp(temp_dir + "/{sample}.sam")
    threads:
        8
    params:
        config['minimapParameters']
    conda:
        'envs/minimap2.yaml'
    shell:
        "minimap2 -t {threads} -a {params} {input.genome} {input.reads} > {output}"
```

__The path to the environment is always relative to the location of the Snakefile.__
This is a useful feature, because you can run your pipeline from a different directory and not have to worry about
copying the env files to your current location.

To make use of these conda environments you need to run Snakemake with the `--use-conda` flag, e.g.

`Snakemake -j 8 --use-conda`

Snakemake will now create an isolated environment for running this job.


# Run directives

A Snakemake rule does not have to be a shell job, you can run some python code instead.
Lets add a rule to count the reads in the .fastq files, and update the targets.
Run directives are useful because they can directly access the input and output variables as well as global variables.

```python
rule all:
    input:
        expand("output/{sample}.{file}", sample=config['samples'], file=['bam','reads.tsv'])

rule count_reads:
    input:
        read_dir + "/{sample}.fastq"
    output:
        out_dir + "/{sample}.reads.tsv"
    run:
        with open(output[0],'w') as out:
            count = file_len(input[0]) / 4
            out.write(wildcards.sample + '\t' + count + '\n')
```

# Script directives

If you have a lot of code, or an R script to run, it's neater to use the script directive than the run directive.
Lets convert the above to a python script.
With the script directive, you can access the snakemake inputs, outputs etc via a class called `snakemake`.

Create a folder called `scripts/`, and add a file in it called `count_reads.py`:

```python
with open(snakemake.output[0],'w') as out:
    with open(snakemake.input[0],'r') as f:
        for i, l in enumerate(f):
            pass
        count = str((i + 1) / 4)
        out.write(snakemake.wildcards.sample + '\t' + count + '\n')
```

update the rule to use the script directive:

```python
rule all:
    input:
        expand("output/{sample}.{file}", sample=config['samples'], file=['bam','reads.tsv'])

rule count_reads:
    input:
        read_dir + "/{sample}.fastq"
    output:
        out_dir + "/{sample}.reads.tsv"
    script:
        "scripts/count_reads.py"
```

__Like with envs, the script paths are always relative to the Snakefile.__
So much cleaner, isn't it?

__Continued in part 2...__
