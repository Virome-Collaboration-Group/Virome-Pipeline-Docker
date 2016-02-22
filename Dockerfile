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

ENV CD_HIT_VERSION 4.6.4
ENV CD_HIT_DOWNLOAD_URL https://github.com/weizhongli/cdhit/archive/V${CD_HIT_VERSION}.tar.gz

ENV MGA_VERSION noversion
ENV MGA_DOWNLOAD_URL http://metagene.nig.ac.jp/metagene/mga_x86_64.tar.gz

ENV NCBI_BLAST_VERSION 2.3.0
ENV NCBI_BLAST_DOWNLOAD_URL ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-${NCBI_BLAST_VERSION}+-x64-linux.tar.gz

ENV TRNASCAN_SE_VERSION 1.3.1
ENV TRNASCAN_SE_DOWNLOAD_URL http://lowelab.ucsc.edu/software/tRNAscan-SE-${TRNASCAN_SE_VERSION}.tar.gz

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

#--------------------------------------------------------------------------------
# BMSL perl module (not in CPAN)

RUN mkdir -p /usr/src/bmsl
WORKDIR /usr/src/bmsl

RUN curl -SL $BMSL_DOWNLOAD_URL -o bmsl.tar.gz \
	&& tar --strip-components=1 -xvf bmsl.tar.gz -C /usr/src/bmsl \
	&& rm bmsl.tar.gz \
	&& mkdir -p /opt/ergatis/docs \
	&& perl Makefile.PL INSTALL_BASE=/opt/ergatis SCHEMA_DOCS_DIR=/opt/ergatis/docs \
	&& make \
	&& make install

#--------------------------------------------------------------------------------
# ERGATIS

RUN mkdir -p /usr/src/ergatis
WORKDIR /usr/src/ergatis

COPY ergatis.software.config /tmp/.

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
	&& cp /opt/ergatis/software.config /opt/ergatis/software.config.orig \
	&& cp /tmp/ergatis.software.config /opt/ergatis/software.config \
	&& groupadd ergatis \
	&& useradd -g ergatis --shell /bin/bash ergatis

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
	&& ./deploy.sh < /tmp/workflow.deploy.answers

#--------------------------------------------------------------------------------
# VIROME

RUN mkdir /opt/virome
WORKDIR /opt/virome

COPY virome.software.config /tmp/.

RUN curl -SL $VIROME_DOWNLOAD_URL -o virome.tar.gz \
	&& tar --strip-components=1 -xvf virome.tar.gz -C /opt/virome \
	&& /bin/rm -rf /opt/virome/software/* /opt/virome/autopipe_package/ergatis \
	&& rm virome.tar.gz \
	&& cp /opt/virome/software.config /opt/virome/software.config.orig \
	&& cp /tmp/virome.software.config /opt/virome/software.config

#--------------------------------------------------------------------------------
# CD-HIT

RUN mkdir -p /usr/src/cd-hit
WORKDIR /usr/src/cd-hit

RUN curl -SL $CD_HIT_DOWNLOAD_URL -o cd-hit.tar.gz \
	&& tar --strip-components=1 -xvf cd-hit.tar.gz -C /usr/src/cd-hit \
	&& rm cd-hit.tar.gz \
	&& mkdir -p /opt/cd-hit/bin \
	&& make \
	&& mv cd-hit-est-2d cd-hit-div cd-hit-2d cd-hit-est cd-hit *.pl /opt/cd-hit/bin/.

#--------------------------------------------------------------------------------
# MGA

RUN mkdir -p /usr/src/mga
WORKDIR /usr/src/mga

RUN curl -SL $MGA_DOWNLOAD_URL -o mga.tar.gz \
	&& tar -xvf mga.tar.gz -C /usr/src/mga \
	&& rm mga.tar.gz \
	&& mkdir -p /opt/mga/bin \
	&& mv README /opt/mga/. \
	&& mv mga_linux_ia64 /opt/mga/bin/mga

#--------------------------------------------------------------------------------
# NCBI-BLAST+

RUN mkdir -p /usr/src/ncbi-blast+
WORKDIR /usr/src/ncbi-blast+

RUN curl -SL $NCBI_BLAST_DOWNLOAD_URL -o ncbi-blast+.tar.gz \
	&& tar --strip-components=1 -xvf ncbi-blast+.tar.gz -C /usr/src/ncbi-blast+ \
	&& rm ncbi-blast+.tar.gz \
	&& mkdir -p /opt/ncbi-blast+ \
	&& mv * /opt/ncbi-blast+/.

#--------------------------------------------------------------------------------
# TRNASCAN-SE

RUN mkdir -p /usr/src/trnascan-se
WORKDIR /usr/src/trnascan-se

RUN curl -SL $TRNASCAN_SE_DOWNLOAD_URL -o trnascan-se.tar.gz \
	&& tar --strip-components=1 -xvf trnascan-se.tar.gz -C /usr/src/trnascan-se \
	&& rm trnascan-se.tar.gz \
	&& sed -i -e 's/..HOME./\/opt\/trnascan-se/' Makefile \
	&& make \
	&& make install

#--------------------------------------------------------------------------------
# Cleanup

WORKDIR /usr/src
RUN /bin/rm -rf /usr/src/* \
	&& rm /tmp/ergatis.software.config \
	&& rm /tmp/virome.software.config \
	&& rm /tmp/workflow.deploy.answers

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
