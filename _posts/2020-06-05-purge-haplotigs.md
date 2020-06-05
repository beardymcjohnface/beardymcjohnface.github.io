---
layout: post
category: project
title: "Publishing a bioinf package"
---

There's not much to say about Purge Haplotigs that isn't already covered in the paper and documentation.
Instead I'll talk about my impressions and experience with creating a bioinformatics software package.

[_Read the paper_](https://doi.org/10.1186/s12859-018-2485-7)

### but y tho?

My motivation for creating the tool began with BioInfoSummer 2016.
I figured our work on curating the Chardonnay assembly would be a neat little story for a poster ([available here](docs/Roach-Bioinfosummer-2016.pdf)).
Two things happened: people liked my solution to what turned out to be a common assembly problem,
and there was a talk on publishing bioinformatics software by Torsten Seemann ([based on his paper](https://doi.org/10.1186/2047-217X-2-15)).
So I'd decided to turn our collection of scripts into a package that other people could use for their work.
To do this properly was way more work than I'd anticipated.

### Things I've learned 1: Early adopters make all the difference

I was following Torsten's advice in his talk and paper for writing bioinf packages,
and was trying to think of all the annoyances I'd encountered using other people's bioinf software to avoid the same mistakes.
More importantly however, I'd got in contact with Jason Chin who was at PacBio at the time.
We'd already been in discussions on the Chardonnay assembly and for access to FALCON-Unzip.
He put me in touch with Sarah Kingan and Gregory Concepcion who were also working on the same problem.
They provided feedback in the early days, and later begun using and promoting the package to other research groups.

### Things I've learned 2: It's a lot of work

Most of the time I've spent on the software happened _after_ the first submission of the paper.
The code-base has had substantial overhauls and refactoring following feedback from the reviewers and users,
as well as following ideas that I'd had for performance improvements etc.
Probably the most time has been spent on bug-fixes, usually trying to get the software to run on other peoples' systems.
While I always knew that maintaining a package was necessary for its success I don't think I appreciated just how time consuming it was going to be.

### Thing I've learned 3: It's incredibly rewarding

Purge Haplotigs is far from being one of the most successful packages out there.
It currently has 70 citations on google scholar 
and I'm expecting it to be obsolete in a few years as both long-read sequencing and assemblers continue to improve.
Nevertheless, it's already exceeded our original expectations.
Hearing directly from scientists that have found your package useful gives you warm fuzzy feelings,
and it's a bit surreal walking around at a large conference and seeing your package popping up on a bunch of posters.

All things considered, would I do it again? absolutely!
Would I maintain more than one package at a time? absolutely not! :p

## References

_Purge Haplotigs: allelic contig reassignment for third-gen diploid genome assemblies_,
(2018),
MJ Roach, SA Schmidt, AR Borneman,
BMC bioinformatics 19 (1), 460 |
[DOI](https://doi.org/10.1186/s12859-018-2485-7)

_Ten recommendations for creating usable bioinformatics command line software_,
(2013),
Torsten Seemann,
GigaScience, Volume 2, Issue 1, December 2013, 2047–217X–2–15 | [DOI](https://doi.org/10.1186/2047-217X-2-15)


