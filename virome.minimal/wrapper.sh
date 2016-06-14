#!/bin/bash

export PERL5LIB=/opt/package_virome/autopipe_package/ergatis/lib

#--------------------------------------------------------------------------------
# Verify input/output/project directories

### if [ ! -d /tmp/input ]
### then
### 	echo "$0: directory not found: /tmp/input"
### 	exit 1
### fi
### 
### if [ ! -d /tmp/output ]
### then
### 	echo "$0: directory not found: /tmp/output"
### 	exit 1
### fi
### 
### if [ ! -d /usr/local/projects ]
### then
### 	echo "$0: directory not found: /usr/local/projects"
### 	exit 1
### fi

#--------------------------------------------------------------------------------
# Download data files

### cd /tmp/input
### 
### DATA_FILES="\
### 	MGOL_DEC2014 \
### 	MGOL_DEC2014.60 \
### 	UNIREF50_2015_12 \
### 	UNIREF100_2015_12 \
### 	UniVec_Core \
### 	rRNA \
### 	mgol60__2__mgol100.lookup \
### 	uniref50__2__uniref100.lookup"
### 
### for file in $DATA_FILES
### do
### 	echo "`date`: $file"
### 	zsync -q http://virome.dbi.udel.edu/repository/$file.zsync
### 	test -s $file.zs-old && /bin/rm $file.zs-old
### 	chmod 644 $file
### done
### echo `date`

#--------------------------------------------------------------------------------
# Configure/run pipeline (virome)

# TODO: This next step is probably asynchronousk, so it probably immediately exits
# after the pipeline is executed. So, we need to invoke another script to 
# block and wait for the pipeline to be complete before this script is allowed
# to exit
/opt/package_virome/autopipe_package/ergatis/util/virome_little_run_pipeline.pl \
-t /opt/package_virome/project_saved_templates/little-pipeline/ \
-r /opt/projects/virome/ \
-e /opt/package_virome/autopipe_package/ergatis.ini \
-i /opt/projects/virome/workflow/project_id_repository/ \
-f /opt/package_virome/play_data/GS115.fasta

# TODO: Invoke the blocking/pipeline monitoring script. Exit with an exit
# value that indicates overall pipeline success or failure.

# TODO: Implement
# /opt/scripts/monitor.pl
exit $?
