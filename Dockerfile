############################################################
# Dockerfile to build container virome pipeline image
############################################################

FROM ubuntu:trusty

MAINTAINER Tom Emmel <temmel@som.umaryland.edu>

# Set default timezone

ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Handle warnings from apt/dpkg

ARG TERM=linux
ARG DEBIAN_FRONTEND=noninteractive

#--------------------------------------------------------------------------------
# SOFTWARE

ARG WORKFLOW_VERSION=3.2.0
ARG WORKFLOW_DOWNLOAD_URL=http://sourceforge.net/projects/tigr-workflow/files/tigr-workflow/wf-${WORKFLOW_VERSION}.tar.gz

ARG ERGATIS_VERSION=2r19b5
ARG ERGATIS_DOWNLOAD_URL=https://github.com/Virome-Collaboration-Group/ergatis/archive/v${ERGATIS_VERSION}.zip
#ARG ERGATIS_DOWNLOAD_URL=https://github.com/Virome-Collaboration-Group/ergatis/archive/master.zip

ARG VIROME_VERSION=master
ARG VIROME_DOWNLOAD_URL=https://github.com/Virome-Collaboration-Group/virome_pipeline/archive/${VIROME_VERSION}.zip
#ARG VIROME_VERSION=1.6
#ARG VIROME_DOWNLOAD_URL=https://github.com/Virome-Collaboration-Group/virome_pipeline/archive/v${VIROME_VERSION}.zip

ARG TRNASCAN_VERSION=2.0.2
ARG TRNASCAN_DOWNLOAD_URL=http://trna.ucsc.edu/software/trnascan-se-${TRNASCAN_VERSION}.tar.gz

ARG INFERNAL_VERSION=1.1.2
ARG INFERNAL_DOWNLOAD_URL=http://eddylab.org/infernal/infernal-${INFERNAL_VERSION}.tar.gz

#--------------------------------------------------------------------------------
# BASICS

RUN apt-get update && apt-get install -y --no-install-recommends \
	build-essential \
	curl \
	cpanminus \
	dh-make-perl \
	apache2 \
	openjdk-6-jre \
	ncbi-blast+ \
	sqlite3 \
	zip \
	unzip \
	zsync \
	libdbi-perl \
	libdbd-sqlite3-perl \
	libmailtools-perl \
	libmldbm-perl \
	libxml-libxml-perl \
	bioperl \
	libcpan-meta-perl \
	libcdb-file-perl \
	libcgi-session-perl \
	libconfig-inifiles-perl \
	libdate-manip-perl \
	libfile-spec-perl \
	libhtml-template-perl \
	libio-tee-perl \
	libjson-perl \
	liblog-log4perl-perl \
	libmath-combinatorics-perl \
	libperlio-gzip-perl \
	libterm-progressbar-perl \
	libxml-parser-perl \
	libxml-twig-perl \
	libxml-rss-perl \
	libxml-writer-perl \
	python \
	python-pip \
  && rm -rf /var/lib/apt/lists/*

COPY lib/libfile-mirror-perl_0.10-1_all.deb /tmp/
COPY lib/liblog-cabin-perl_0.06-1_all.deb /tmp/
COPY lib/libtree-nary-perl_1.3-1_all.deb /tmp/
RUN dpkg -i /tmp/*.deb && rm /tmp/*.deb

RUN pip install awscli

#### tRNAScan bug hack
#RUN sed -i 's/$opts->fastafile()/$opts->fasta_file()/' /usr/bin/tRNAscan-SE

#--------------------------------------------------------------------------------
# tRNAscan-SE install

WORKDIR /tmp

RUN curl -s -SL $INFERNAL_DOWNLOAD_URL -o infernal.tar.gz \
	&& tar -xzf infernal.tar.gz \
	&& cd ./infernal-${INFERNAL_VERSION} && ./configure && make && make install \
	&& rm /tmp/infernal.tar.gz && rm -rf /tmp/infernal-${INFERNAL_VERSION}

RUN curl -s -SL $TRNASCAN_DOWNLOAD_URL -o trnascan.tar.gz \
	&& tar -xzf trnascan.tar.gz \
	&& cd ./tRNAscan-SE-2.0 && ./configure && make && make install \
	&& rm /tmp/trnascan.tar.gz && rm -rf /tmp/tRNAscan-SE-2.0

#--------------------------------------------------------------------------------
# WORKFLOW -- install in /opt/workflow

RUN mkdir /usr/src/workflow
WORKDIR /usr/src/workflow

COPY workflow.deploy.answers /tmp/.

RUN curl -s -SL $WORKFLOW_DOWNLOAD_URL -o workflow.tar.gz \
	&& tar -xzf workflow.tar.gz -C /usr/src/workflow \
	&& rm workflow.tar.gz \
	&& mkdir -p -m 777 /opt/workflow/server-conf \
	&& ./deploy.sh < /tmp/workflow.deploy.answers

COPY workflow.log4j.properties /opt/workflow/log4j.properties

#--------------------------------------------------------------------------------
# ERGATIS -- install in /opt/ergatis

RUN mkdir -p /usr/src/ergatis
WORKDIR /usr/src/ergatis

COPY ergatis.install.fix /tmp/.
COPY ergatis.ini /tmp/.

RUN curl -s -SL $ERGATIS_DOWNLOAD_URL -o ergatis.zip \
	&& unzip -o ergatis.zip \
	&& rm ergatis.zip \
	&& mkdir /opt/ergatis \
	&& cd /usr/src/ergatis/ergatis-${ERGATIS_VERSION} \
	&& cp /tmp/ergatis.install.fix . \
	&& ./ergatis.install.fix \
	&& perl Makefile.PL INSTALL_BASE=/opt/ergatis \
	&& make \
	&& make install \
	&& mv /usr/src/ergatis/ergatis-${ERGATIS_VERSION}/htdocs /var/www/html/ergatis \
	&& cp /tmp/ergatis.ini /var/www/html/ergatis/cgi/.

#--------------------------------------------------------------------------------
# VIROME only-- install in /opt/ergatis

RUN mkdir -p /usr/src/virome
WORKDIR /usr/src/virome

RUN curl -s -SL $VIROME_DOWNLOAD_URL -o virome.zip \
	&& unzip -o virome.zip \
	&& rm virome.zip \
	&& cd /usr/src/virome/virome_pipeline-${VIROME_VERSION} \
	&& ./pre.install.fix \
	&& perl Makefile.PL INSTALL_BASE=/opt/ergatis \
	&& make \
	&& make install \
	&& mv /opt/ergatis/play_data /opt/play_data \
	&& gunzip /opt/play_data/*.gz \
	&& echo "virome = /opt/projects/virome" >> /var/www/html/ergatis/cgi/ergatis.ini

#--------------------------------------------------------------------------------
# SCRATCH

RUN mkdir -p -m 777 /usr/local/scratch \
	&& mkdir -m 777 /usr/local/scratch/ergatis \
	&& mkdir -m 777 /usr/local/scratch/ergatis/archival \
	&& mkdir -m 777 /usr/local/scratch/workflow \
	&& mkdir -m 777 /usr/local/scratch/workflow/id_repository \
	&& mkdir -m 777 /usr/local/scratch/workflow/runtime \
	&& mkdir -m 777 /usr/local/scratch/workflow/runtime/pipeline \
	&& mkdir -m 777 /usr/local/scratch/workflow/scripts \
	&& mkdir -m 777 /tmp/pipelines_building

#--------------------------------------------------------------------------------
# VIROME PROJECT

COPY project.config /tmp/.

RUN mkdir -p /opt/projects/virome \
	&& mkdir /opt/projects/virome/output_repository \
	&& mkdir /opt/projects/virome/virome-cache-files \
	&& mkdir /opt/projects/virome/software \
	&& mkdir /opt/projects/virome/workflow \
	&& mkdir /opt/projects/virome/workflow/lock_files \
	&& mkdir /opt/projects/virome/workflow/project_id_repository \
	&& mkdir /opt/projects/virome/workflow/runtime \
	&& mkdir /opt/projects/virome/workflow/runtime/pipeline \
	&& touch /opt/projects/virome/workflow/project_id_repository/valid_id_repository \
	&& cp /tmp/project.config /opt/projects/virome/workflow/.

#--------------------------------------------------------------------------------
# APACHE


COPY apache2.envvars		/etc/apache2/envvars
COPY apache2.ports.conf		/etc/apache2/ports.conf
COPY apache2.000-default.conf	/etc/apache2/sites-enabled/000-default.conf
COPY ergatis.conf		/etc/apache2/conf-available/.

RUN mkdir -p -m 777 /tmp/lock/apache2 /tmp/log/apache2 /tmp/run/apache2

RUN a2enmod cgid && a2enconf ergatis

EXPOSE 8080

#--------------------------------------------------------------------------------
# Copy blastp version to /usr/bin/.

RUN cp /opt/ergatis/software/ncbi-blast-2.5.0+/bin/* /usr/bin/.

#--------------------------------------------------------------------------------
# Multithreading - Set number of parallel runs for changed files

RUN num_cores=$(grep -c ^processor /proc/cpuinfo) && \
	find /opt/ergatis/project_saved_templates -type f -exec \
        /usr/bin/perl -pi \
        -e 's/\$;NODISTRIB\$;\s?=\s?0/\$;NODISTRIB\$;='$num_cores'/g' {} \;

#--------------------------------------------------------------------------------
# Scripts

RUN mkdir -p /opt/scripts
WORKDIR /opt/scripts

COPY execute_pipeline.sh /opt/scripts/execute_pipeline.sh
RUN chmod 755 /opt/scripts/execute_pipeline.sh

COPY execute_pipeline_test.sh /opt/scripts/execute_pipeline_test.sh
RUN chmod 755 /opt/scripts/execute_pipeline_test.sh

#--------------------------------------------------------------------------------
# Where the input data is to be found, and where the output is to be saved.

#VOLUME /opt/database /opt/input /opt/output

#--------------------------------------------------------------------------------
# Permissions

RUN chmod 777 /opt

RUN find /opt/projects/virome -type d -exec chmod 777 {} \;
RUN find /opt/workflow -type d -exec chmod 777 {} \;

#--------------------------------------------------------------------------------
# Non-root user

RUN useradd --create-home --shell /bin/bash virome
USER virome

#--------------------------------------------------------------------------------
# Default Command

ENTRYPOINT [ "/opt/scripts/execute_pipeline.sh" ]
