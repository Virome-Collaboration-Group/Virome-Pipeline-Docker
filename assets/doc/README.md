# ![VIROME DIY Analysis Pipeline](https://github.com/Virome-Collaboration-Group/Virome-Pipeline-Docker/blob/master/assets/img/virome-diy.png)

### Introduction


### Requirements

#### Software
- [Docker](https://docs.docker.com/installation/) for Linux / Windows / OSX

#### Hardware
—- processor/core requirement
—- min space requirement
—- min memory

### Configuration
#### define various terms/mount points
-- /path/to/inputdir
-- /path/to/output
-- /path/to/databasedir


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
—- desc output and upload location


### Credits
