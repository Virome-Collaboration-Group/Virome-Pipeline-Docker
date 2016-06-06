############################################################
# Dockerfile to build container virome pipeline image
# Based on Ubuntu
############################################################ 

# Docker 1.9.1 currently hangs when attempting to build openjdk-6-jre.
# Upgrade Docker by installing DockerToolbox-1.10.0-rc3.

FROM ubuntu:trusty

MAINTAINER Tom Emmel <temmel@som.umaryland.edu>

#--------------------------------------------------------------------------------
# SOFTWARE

ENV BMSL_VERSION v2r18b1
ENV BMSL_DOWNLOAD_URL http://sourceforge.net/projects/bsml/files/bsml/bsml-$BMSL_VERSION/bsml-$BMSL_VERSION.tar.gz

ENV ERGATIS_VERSION v2r19b4
ENV ERGATIS_DOWNLOAD_URL https://github.com/jorvis/ergatis/archive/$ERGATIS_VERSION.tar.gz

ENV WORKFLOW_VERSION 3.1.5
ENV WORKFLOW_DOWNLOAD_URL http://sourceforge.net/projects/tigr-workflow/files/tigr-workflow/wf-$WORKFLOW_VERSION.tar.gz

ENV VIROME_VERSION 1.0
ENV VIROME_DOWNLOAD_URL https://github.com/Virome-Collaboration-Group/virome_pipeline/archive/master.zip

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
	ncbi-blast+ \
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
# WORKFLOW -- install in /opt/workflow

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
# VIROME -- install in /opt/package_virome

RUN mkdir -p /opt/src/virome
WORKDIR /opt/src/virome

COPY ergatis.install.fix /tmp/.
COPY virome.ergatis.ini /tmp/.
COPY virome.software.config /tmp/.

RUN curl -SL $VIROME_DOWNLOAD_URL -o virome.zip \
	&& unzip -o virome.zip \
	&& rm virome.zip \
	&& mv /opt/src/virome/virome_pipeline-master /opt/package_virome \
	&& cd /opt/package_virome/autopipe_package/ergatis \
	&& cp /tmp/ergatis.install.fix . \
	&& ./ergatis.install.fix \
	&& perl Makefile.PL INSTALL_BASE=/opt/package_virome \
	&& make \
	&& make install \
	&& cp /tmp/virome.ergatis.ini /opt/package_virome/autopipe_package/ergatis/htdocs/cgi/ergatis.ini \
	&& cp /tmp/virome.ergatis.ini /opt/package_virome/autopipe_package/ergatis.ini \
	&& cp /tmp/virome.software.config /opt/package_virome/software.config

RUN echo "virome = /opt/projects/virome" >> /opt/package_virome/autopipe_package/ergatis.ini

#--------------------------------------------------------------------------------
# TRNASCAN-SE -- install in /opt/trnascan-se

RUN mkdir -p /usr/src/trnascan-se
WORKDIR /usr/src/trnascan-se

RUN curl -SL $TRNASCAN_SE_DOWNLOAD_URL -o trnascan-se.tar.gz \
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
# Scripts

ENV PERL5LIB=/opt/package_virome/autopipe_package/ergatis/lib

RUN mkdir -p /opt/scripts
WORKDIR /opt/scripts

COPY virome_454_fasta_unassembled_run_pipeline.pl /opt/scripts/.
RUN chmod 755 /opt/scripts/virome_454_fasta_unassembled_run_pipeline.pl

COPY wrapper.sh /opt/scripts/wrapper.sh
RUN chmod 755 /opt/scripts/wrapper.sh

COPY file.fasta /tmp/.

#--------------------------------------------------------------------------------
# Default Command

CMD [ "/opt/scripts/wrapper.sh" ]
