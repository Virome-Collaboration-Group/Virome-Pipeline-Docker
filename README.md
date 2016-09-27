# Virome-Pipeline-Docker
Docker container for the Virome pipeline

##DOCKER BUILD


Build container:
```
docker build -t virome .
```


##DOCKER RUN



Default application:

```
/opt/scripts/wrapper.sh
```

Run the container using the default application:

```
docker run -ti --rm [DOCKER_OPTIONS] virome [APPLICATION_OPTIONS]
```

Run the container overriding the default application using the "--entrypoint"
option:

```
docker run -ti --rm --entrypoint /bin/bash [DOCKER_OPTIONS] virome [APPLICATION_OPTIONS]
```


##DOCKER OPTIONS


Volumes:

Use the "-v" option to share local host directories to the container.  The
required volumes are /opt/input, /opt/output, /opt/database.

```
docker run -ti --rm \
	-v /path/to/inputdir:/opt/input \
	-v /path/to/outputdir:/opt/output \
	-v /path/to/databasedir:/opt/database \
	virome
```

Port:

Use the "-p" option to publish the web server port.

```
docker run -ti --rm \
	-v /path/to/inputdir:/opt/input \
	-v /path/to/outputdir:/opt/output \
	-v /path/to/databasedir:/opt/database \
	-p 80:80 \
	virome
```

Timezone:

Use the "-e" option to set the TZ environment variable to the desired timezone.
The default is TZ=America/New_York.

```
docker run -ti --rm \
	-v /path/to/inputdir:/opt/input \
	-v /path/to/outputdir:/opt/output \
	-v /path/to/databasedir:/opt/database \
	-e TZ=America/Chicago \
	virome
```

Entrypoint:

Use the "--entrypoint" option to override the default application.  To obtain a
shell, run:

```
docker run -ti --rm \
	-v /path/to/inputdir:/opt/input \
	-v /path/to/outputdir:/opt/output \
	-v /path/to/databasedir:/opt/database \
	--entrypoint /bin/bash \
	virome
```


##APPLICATION OPTIONS

These options are available for the default application:

```
  --enable-data-download      download data files (default)
  --disable-data-download     do not download data files
  --start-web-server          start web server
  --keepalive                 keep alive
  --sleep=number              pause number seconds before exiting
  --threads=number            set number of threads
  -h, --help                  display this help and exit
```

```
docker run -ti --rm \
	-v /path/to/inputdir:/opt/input \
	-v /path/to/outputdir:/opt/output \
	-v /path/to/databasedir:/opt/database \
	virome [APPLICATION_OPTIONS]
```
