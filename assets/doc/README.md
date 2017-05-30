# ![VIROME DIY Analysis Pipeline](https://github.com/Virome-Collaboration-Group/Virome-Pipeline-Docker/blob/master/assets/img/virome-diy.png)

### Introduction
VIROME DIY is a bioinformatics analysis pipeline used for viral metagenome sequencing data at University of Delaware, DBi.

The pipeline uses Docker... . Its a self-contained image with all tools, software and libraries pre configured.

This pipeline is primarily used on a x86_64 computer server with 24 cpus, 128GB memory. however, the pipeline should be able to run on any system including a modern laptop with 16GB of memory and ample of disk space. We have done some limited testing using AWS, and working towards a stable release.

### Requirements

#### Software
- [Docker](https://docs.docker.com/installation/) for Linux / Windows / OSX

#### Recommended hardware specifications
1. processor/core requirement

   text here

2. min space requirement

   250 GB

3. min memory

   128 GB

### Configuration
#### define various terms/mount points
1. Input directory and Input file

   /path/to/inputdir

2. Output dir and output

   /path/to/output

3. Subject database file location

   /path/to/databasedir


### Running the pipeline
#### VIROME OPTIONS
```
--enable-data-download
--disable-data-download
--start-web-server
-k, --keep-alive
--sleep=number
--threads=number
-h, --help
```

#### Get latest docker image of VIROME DIY
```
docker pull virome/virome-pipeline
```

#### Run default test case using web browser to monitor pipeline progress
```
docker run -i -t --rm -p 9000:80 -v /path/to/inputdir:/opt/input -v /path/to/output:/opt/output -v /path/to/databasedir:/opt/database —-entrypoint execute_pipeline_test.sh —-start-web-server virome —-test-case1
```

#### Run pipeline with use defined input
```
docker run -i -t —-rm -p 9000:80 -v /path/to/inputdir:/opt/input -v /path/to/output:/opt/output -v /path/to/databasedir:/opt/database virome —-input-file=/opt/input/filename.fasta
```

### Output
desc output and upload location


### Credits
