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

ARG WORKFLOW_VERSION=3.1.5
ARG WORKFLOW_DOWNLOAD_URL=http://sourceforge.net/projects/tigr-workflow/files/tigr-workflow/wf-${WORKFLOW_VERSION}.tar.gz

ARG ERGATIS_VERSION=x
ARG ERGATIS_DOWNLOAD_URL=https://github.com/jorvis/ergatis/archive/master.zip

ARG VIROME_VERSION=
ARG VIROME_DOWNLOAD_URL=https://github.com/Virome-Collaboration-Group/virome_pipeline/archive/master.zip

ARG TRNASCAN_SE_VERSION=1.3.1
ARG TRNASCAN_SE_DOWNLOAD_URL=http://lowelab.ucsc.edu/software/tRNAscan-SE-${TRNASCAN_SE_VERSION}.tar.gz

#--------------------------------------------------------------------------------
# BASICS

RUN ping -c 5 archive.ubuntu.com && apt-get update && apt-get install -y \
	build-essential \
	curl \
	cpanminus \
	dh-make-perl \
	apache2 \
	openjdk-6-jre \
	ncbi-blast+ \
	sqlite3 \
	zip \
	zsync \
  && rm -rf /var/lib/apt/lists/*

#--------------------------------------------------------------------------------
# PERL for ergatis

RUN apt-get update && apt-get install -y \
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
	libxml-parser-perl \
	libxml-twig-perl \
	libxml-rss-perl \
	libxml-writer-perl \
  && rm -rf /var/lib/apt/lists/*

COPY lib/lib*.deb /tmp/

RUN dpkg -i /tmp/*.deb && rm /tmp/*.deb

#--------------------------------------------------------------------------------
# WORKFLOW -- install in /opt/workflow

RUN mkdir /usr/src/workflow
WORKDIR /usr/src/workflow

COPY workflow.deploy.answers /tmp/.

RUN curl -s -SL $WORKFLOW_DOWNLOAD_URL -o workflow.tar.gz \
	&& tar -xvf workflow.tar.gz -C /usr/src/workflow \
	&& rm workflow.tar.gz \
	&& mkdir -p /opt/workflow/server-conf \
	&& chmod 777 /opt/workflow/server-conf \
	&& ./deploy.sh < /tmp/workflow.deploy.answers

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
	&& cd /usr/src/ergatis/ergatis-master \
	&& cp /tmp/ergatis.install.fix . \
	&& ./ergatis.install.fix \
	&& perl Makefile.PL INSTALL_BASE=/opt/ergatis \
	&& make \
	&& make install \
	&& mv /usr/src/ergatis/ergatis-master/htdocs /var/www/html/ergatis \
	&& cp /tmp/ergatis.ini /var/www/html/ergatis/cgi/.

#--------------------------------------------------------------------------------
# VIROME -- install in /opt/package_virome

RUN mkdir -p /opt/src/virome
WORKDIR /opt/src/virome

RUN curl -s -SL $VIROME_DOWNLOAD_URL -o virome.zip \
	&& unzip -o virome.zip \
	&& rm virome.zip \
	&& mv /opt/src/virome/virome_pipeline-master /opt/package_virome \
	&& echo "virome = /opt/projects/virome" >> /var/www/html/ergatis/cgi/ergatis.ini

#--------------------------------------------------------------------------------
# TRNASCAN-SE -- install in /opt/trnascan-se

RUN mkdir -p /usr/src/trnascan-se
WORKDIR /usr/src/trnascan-se

RUN curl -s -SL $TRNASCAN_SE_DOWNLOAD_URL -o trnascan-se.tar.gz \
	&& tar --strip-components=1 -xvf trnascan-se.tar.gz -C /usr/src/trnascan-se \
	&& rm trnascan-se.tar.gz \
	&& sed -i -e 's/..HOME./\/opt\/trnascan-se/' Makefile \
	&& make \
	&& make install

#--------------------------------------------------------------------------------
# SCRATCH

RUN mkdir -p /usr/local/scratch && chmod 777 /usr/local/scratch \
	&& mkdir /usr/local/scratch/ergatis && chmod 777 /usr/local/scratch/ergatis \
	&& mkdir /usr/local/scratch/ergatis/archival && chmod 777 /usr/local/scratch/ergatis/archival \
	&& mkdir /usr/local/scratch/workflow && chmod 777 /usr/local/scratch/workflow \
	&& mkdir /usr/local/scratch/workflow/id_repository && chmod 777 /usr/local/scratch/workflow/id_repository \
	&& mkdir /usr/local/scratch/workflow/runtime && chmod 777 /usr/local/scratch/workflow/runtime \
	&& mkdir /usr/local/scratch/workflow/runtime/pipeline && chmod 777 /usr/local/scratch/workflow/runtime/pipeline \
	&& mkdir /usr/local/scratch/workflow/scripts && chmod 777 /usr/local/scratch/workflow/scripts

RUN mkdir /tmp/pipelines_building && chmod 777 /tmp/pipelines_building

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

ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data

ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV APACHE_RUN_DIR /var/run/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2

ENV PERL5LIB /opt/ergatis/lib/perl5

RUN a2enmod cgid

COPY 000-default.conf /etc/apache2/sites-available/000-default.conf

EXPOSE 80

#--------------------------------------------------------------------------------
# Scripts

ENV PERL5LIB=/opt/ergatis/lib/perl5

RUN mkdir -p /opt/scripts
WORKDIR /opt/scripts

COPY wrapper.sh /opt/scripts/wrapper.sh
RUN chmod 755 /opt/scripts/wrapper.sh

VOLUME /opt/database /opt/input /opt/output

#--------------------------------------------------------------------------------
# Default Command

#CMD [ "/usr/bin/timeout", "30", "/opt/scripts/wrapper.sh" ]
#CMD [ "/usr/sbin/apache2ctl", "-DFOREGROUND" ]

CMD [ "/opt/scripts/wrapper.sh" ]
