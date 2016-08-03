# Virome-Pipeline-Docker
Docker container for the Virome pipeline

##DOCKER BUILD


Build container:
```
docker build -t name .
```


##DOCKER RUN


Default application:

```
/opt/scripts/wrapper.sh
```

Run the container using the default application:

```
docker run -ti --rm name
```

Run the container using bash, overriding the default application:

```
docker run -ti --rm name bash
```

Required volumes:

On the command line use the "-v" option to share local host directories to the
container.  The required volume are /opt/input, /opt/output, /opt/database.

```
docker run -ti --rm \
	-v /path/to/inputdir:/opt/input \
	-v /path/to/outputdir:/opt/output \
	-v /path/to/databasedir:/opt/database \
	name bash
```

Timezone:

Set the TZ environment variable to the desired timezone on the command line using the
"-e" option.  The default is TZ=America/New_York.

```
docker run -ti --rm \
	-v /path/to/inputdir:/opt/input \
	-v /path/to/outputdir:/opt/output \
	-v /path/to/databasedir:/opt/database \
	-e TZ=America/Chicago \
	name bash
```


##WRAPPER SCRIPT

/opt/scripts/wrapper.sh [OPTIONS]

--enable-data-download      download data files (default)
--disable-data-download     do not download data files
--start-web-server          start web server
--sleep=number              pause number seconds before exiting
--threads=number            set number of threads
-h, --help                  display this help and exit


Run wrapper.sh in the container using default parameters:

```
% ./wrapper.sh
```


Run wrapper.sh in the container overriding the default parameters:

```
% ./wrapper.sh [OPTION]
```


##DOCKERFILE - TIMEZONE


The timezone environment variable TZ is set to the default America/New_York timezone:

```
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
```


Current datetime:

```
$ date
Fri Jun 17 15:47:13 EDT 2016
```


Run the container using the default timezone:

```
$ docker run -ti --rm name date
Fri Jun 17 15:47:18 EDT 2016
```


Run the container overriding the default timezone using the "-e" option:

```
$ docker run -ti --rm -e TZ=America/Chicago name date
Fri Jun 17 14:47:22 CDT 2016
```
