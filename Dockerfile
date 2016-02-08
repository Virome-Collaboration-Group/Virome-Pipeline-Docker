############################################################
# Dockerfile to build container virome pipeline image
# Based on Ubuntu
############################################################ 

# Docker 1.9.1 currently hangs when attempting to build openjdk-6-jre.
# Upgrade Docker by installing DockerToolbox-1.10.0-rc3.

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
	liblog-log4perl-perl \
	libmath-combinatorics-perl \
	libperlio-gzip-perl \
	libxml-parser-perl \
	libxml-rss-perl \
	libxml-twig-perl \
	libxml-writer-perl \
  && rm -rf /var/lib/apt/lists/*

COPY lib/lib*.deb /tmp/

RUN dpkg -i \
	/tmp/libfile-mirror-perl_0.10-1_all.deb \
	/tmp/liblog-cabin-perl_0.06-1_all.deb \
  && rm /tmp/libfile-mirror-perl_0.10-1_all.deb \
	/tmp/liblog-cabin-perl_0.06-1_all.deb

# BMSL perl module (not in CPAN)

RUN mkdir -p /usr/src/bmsl
WORKDIR /usr/src/bmsl

RUN curl -SL $BMSL_DOWNLOAD_URL -o bmsl.tar.gz \
	&& tar --strip-components=1 -xvf bmsl.tar.gz -C /usr/src/bmsl \
	&& rm bmsl.tar.gz \
	&& mkdir -p /opt/ergatis/docs \
	&& perl Makefile.PL INSTALL_BASE=/opt/ergatis SCHEMA_DOCS_DIR=/opt/ergatis/docs \
	&& make \
	&& make install \
	&& /bin/rm -rf /usr/src/bmsl

#--------------------------------------------------------------------------------
# ERGATIS

RUN mkdir -p /usr/src/ergatis
WORKDIR /usr/src/ergatis

RUN curl -SL $ERGATIS_DOWNLOAD_URL -o ergatis.tar.gz \
	&& tar --strip-components=1 -xvf ergatis.tar.gz -C /usr/src/ergatis \
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
	&& useradd -g ergatis --shell /bin/bash ergatis \
	&& /bin/rm -rf /usr/src/ergatis

COPY ergatis.ini /var/www/html/ergatis/cgi/.

#--------------------------------------------------------------------------------
# WORKFLOW

RUN mkdir /usr/src/workflow
WORKDIR /usr/src/workflow

COPY workflow.deploy.answers /tmp/.

RUN curl -SL $WORKFLOW_DOWNLOAD_URL -o workflow.tar.gz \
	&& tar -xvf workflow.tar.gz -C /usr/src/workflow \
	&& rm workflow.tar.gz \
	&& mkdir -p /opt/workflow/server-conf \
	&& chmod 777 /opt/workflow/server-conf \
	&& ./deploy.sh < /tmp/workflow.deploy.answers \
	&& /bin/rm -rf /usr/src/workflow /tmp/workflow.deploy.answers

#--------------------------------------------------------------------------------
# VIROME

RUN mkdir /opt/virome
WORKDIR /opt/virome

RUN curl -SL $VIROME_DOWNLOAD_URL -o virome.tar.gz \
	&& tar --strip-components=1 -xvf virome.tar.gz -C /opt/virome \
	&& rm virome.tar.gz

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

CMD [ "/usr/sbin/apache2ctl", "-DFOREGROUND" ]
