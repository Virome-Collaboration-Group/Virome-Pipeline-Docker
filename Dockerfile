############################################################
# Dockerfile to build container images
# Based on Ubuntu
############################################################ 

FROM ubuntu:trusty

MAINTAINER Tom Emmel <temmel@som.umaryland.edu>

ENV BMSL_VERSION v2r18b1
ENV BMSL_DOWNLOAD_URL http://sourceforge.net/projects/bsml/files/bsml/bsml-$BMSL_VERSION/bsml-$BMSL_VERSION.tar.gz

ENV ERGATIS_VERSION v2r19b4
ENV ERGATIS_DOWNLOAD_URL https://github.com/jorvis/ergatis/archive/$ERGATIS_VERSION.tar.gz

ENV WORKFLOW_VERSION 3.1.5
ENV WORKFLOW_DOWNLOAD_URL http://sourceforge.net/projects/tigr-workflow/files/tigr-workflow/wf-$WORKFLOW_VERSION.tar.gz

ENV VIROME_VERSION 1.0
ENV VIROME_DOWNLOAD_URL https://github.com/bjaysheel/virome_pipeline/archive/$VIROME_VERSION.tar.gz

#--------------------------------------------------------------------------------
# BASICS

RUN apt-get update && apt-get install -y \
	build-essential \
	curl \
	cpanminus \
	dh-make-perl \
	apache2 \
	openjdk-6-jre \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

#--------------------------------------------------------------------------------
# JAVA

# Docker 1.9.1 currently hangs when attempting to build openjdk6-jre.

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
	liblog-log4perl-perl \
	libmath-combinatorics-perl \
	libperlio-gzip-perl \
	libxml-parser-perl \
	libxml-rss-perl \
	libxml-twig-perl \
	libxml-writer-perl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN cpanm \
	File::Mirror \
	Log::Cabin

### 	Class::Struct \
### 	Data::Dumper \
### #	DB_File \
### 	ExtUtils::MakeMaker \
### 	File::Basename \
### 	File::Copy \
### 	File::Find \
### 	File::Path \
### 	Getopt::Long \
### 	IO::File \
### 	IPC::Open3 \
### 	LWP::Simple \
### 	Mail::Mailer \
### 	Storable \
### 	URI::Escape

# BMSL perl module (not in CPAN)

RUN mkdir -p /usr/src/bmsl
WORKDIR /usr/src/bmsl

RUN curl -SL $BMSL_DOWNLOAD_URL -o bmsl.tar.gz \
	&& tar -xvf bmsl.tar.gz -C /usr/src/bmsl --strip-components=1 \
	&& rm bmsl.tar.gz \
	&& mkdir -p /opt/ergatis/docs \
	&& perl Makefile.PL INSTALL_BASE=/opt/ergatis SCHEMA_DOCS_DIR=/opt/ergatis/docs \
	&& make \
	&& make install

#--------------------------------------------------------------------------------
# ERGATIS

RUN mkdir -p /usr/src/ergatis
WORKDIR /usr/src/ergatis

RUN curl -SL $ERGATIS_DOWNLOAD_URL -o ergatis.tar.gz \
	&& tar -xvf ergatis.tar.gz -C /usr/src/ergatis --strip-components=1 \
	&& rm ergatis.tar.gz \
	&& cd /usr/src/ergatis/install \
	&& mkdir -p /opt/ergatis \
	&& perl Makefile.PL LIVE_BUILD INSTALL_BASE=/opt/ergatis \
	&& sed -i -e 's/..BUILD_DIR..R/..\/src\/R/' Makefile \
	&& make \
	&& make install \
	&& mv /usr/src/ergatis/htdocs /var/www/html/ergatis \
	&& cp -pr /usr/src/ergatis/lib/* /opt/ergatis/lib/perl5/. \
	&& groupadd ergatis \
	&& useradd -g ergatis --shell /bin/bash ergatis

#--------------------------------------------------------------------------------
# WORKFLOW

RUN mkdir /usr/src/workflow
WORKDIR /usr/src/workflow

COPY workflow.deploy.answers /tmp/.

RUN curl -SL $WORKFLOW_DOWNLOAD_URL -o workflow.tar.gz \
	&& tar -xvf workflow.tar.gz -C /usr/src/workflow \
	&& rm workflow.tar.gz \
	&& cd /usr/src/workflow \
	&& ./deploy.sh < /tmp/workflow.deploy.answers

#--------------------------------------------------------------------------------
# VIROME

RUN mkdir /usr/src/virome
WORKDIR /usr/src/virome

RUN curl -SL $VIROME_DOWNLOAD_URL -o virome.tar.gz \
	&& tar -xvf virome.tar.gz -C /usr/src/virome --strip-components=1 \
	&& rm virome.tar.gz \
	&& cd /usr/src/virome 

#--------------------------------------------------------------------------------
# APACHE

ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data

ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV APACHE_RUN_DIR /var/run/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2

#ENV PERL5LIB /opt/ergatis/lib/perl5

RUN a2enmod cgid

COPY 000-default.conf /etc/apache2/sites-available/000-default.conf

EXPOSE 80

CMD [ "/usr/sbin/apache2ctl", "-DFOREGROUND" ]
