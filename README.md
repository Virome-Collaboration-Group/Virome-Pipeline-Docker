# Virome-Pipeline-Docker
Docker container for the Virome pipeline

##DOCKER BUILD


Build the container:

```
docker build -t virome .
```


##DOCKER RUN

Run the container:

```
docker run -ti --rm [DOCKER OPTIONS] virome [VIROME OPTIONS]
```

To gain a shell inside the container, override the default entrypoint using the "--entrypoint"
docker option:

```
docker run -ti --rm --entrypoint /bin/bash virome
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


##VIROME OPTIONS

These options are available to help configure and monitor the pipeline:

```
  --enable-data-download      download data files (default)
  --disable-data-download     do not download data files
  --start-web-server          start web server (for monitoring progress)
  -k, --keep-alive            keep alive (do not exit the container when complete)
  --sleep=number              pause number seconds before exiting the container
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

