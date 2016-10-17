#!/bin/bash


usage() {

	echo "Usage: $0 [OPTIONS]"
	echo "  --enable-data-download      perform data file download (default)"
	echo "  --disable-data-download     do not perform data file download"
	echo "  --start-web-server          start web server"
	echo "  -k,--keep-alive             keep alive"
	echo "  --sleep=number              pause number seconds before exiting"
	echo "  --threads=number            set number of threads"
	echo "  -h, --help                  display this help and exit"
}

#--------------------------------------------------------------------------------
# Process parameters

opt_a=0
opt_d=1
opt_k=0
opt_s=0
opt_t=0

while true
do
	case $1 in

	-h|--help)
		usage
		exit
		;;
	--enable-data-download)
		opt_d=1
		;;
	--disable-data-download)
		opt_d=0
		;;
	--start-web-server)
		opt_a=1
		;;
	-k|--keep-alive)
		opt_k=1
		;;
	--sleep=?*)
		opt_s=1
		seconds=${1#*=}
		;;
	--sleep|sleep=)
		echo "$0: missing argument to '$1' option"
		usage
		exit 1
		;;
	--threads=?*)
		opt_t=1
		threads=${1#*=}
		;;
	--threads|threads=)
		echo "$0: missing argument to '$1' option"
		usage
		exit 1
		;;
	--)
		shift
		break
		;;
	-?*)
		echo "$0: invalid option: $1"
		usage
		exit 1
		;;
	*)
		break
	esac

	shift
done

if [ $# != 0 ]
then
	usage
	exit 1
fi

#--------------------------------------------------------------------------------
# Verify sleep seconds

if [ $opt_s -eq 1 ]
then
	if [[ ! $seconds =~ ^[0-9]+$ ]]
	then
		echo "$0: invalid sleep number: $seconds"
		exit 1
	fi
fi

#--------------------------------------------------------------------------------
# Verify threads

if [ $opt_t -eq 1 ]
then
	if [[ ! $threads =~ ^[0-9]+$ ]]
	then
		echo "$0: invalid thread number: $threads"
		exit 1
	fi
fi

#--------------------------------------------------------------------------------
# Verify input/output/database directories

if [ ! -d /opt/input ]
then
	echo "$0: directory not found: /opt/input"
	exit 1
fi

if [ ! -d /opt/output ]
then
	echo "$0: directory not found: /opt/output"
	exit 1
fi

if [ ! -d /opt/database ]
then
	echo "$0: directory not found: /opt/database"
	exit 1
fi

#--------------------------------------------------------------------------------
# Download data files

if [ $opt_d -eq 1 ]
then
	cd /opt/input
	
	DATA_FILES="\
		MGOL_DEC2014 \
		MGOL_DEC2014.60 \
		UNIREF50_2015_12 \
		UNIREF100_2015_12 \
		UniVec_Core \
		rRNA \
		mgol60__2__mgol100.lookup \
		uniref50__2__uniref100.lookup"
	
	for file in $DATA_FILES
	do
		echo "start: `date`: $file"
		zsync -q http://virome.dbi.udel.edu/repository/$file.zsync
		test -s $file.zs-old && /bin/rm $file.zs-old
		test -s $file && chmod 644 $file
	done
	echo "completed: `date`"
fi

#--------------------------------------------------------------------------------
# Start apache

if [ $opt_a -eq 1 ]
then
	/usr/sbin/apachectl start
fi

#--------------------------------------------------------------------------------
# Configure/run virome pipeline

export PERL5LIB=/opt/ergatis/lib/perl5

/opt/ergatis/autopipe_package/virome_little_run_pipeline.pl \
-t /opt/ergatis/project_saved_templates/little-pipeline/ \
-r /opt/projects/virome \
-e /var/www/html/ergatis/cgi/ergatis.ini \
-i /opt/projects/virome/workflow/project_id_repository/ \
-f /opt/ergatis/play_data/GS115.fasta

# This following status setting is temporary.  We will ultimately use workflow
# status or file to indicate actual success or failure of the pipeline.

status=$?
echo $status

if [ $status -ne 0 ]
then
	echo "$0: workflow error: $status"
        echo "$0: see pipeline.xml.log file in local output directory"

	cp /opt/projects/virome/workflow/runtime/pipeline/*/pipeline.xml.log /opt/output/.
fi

#--------------------------------------------------------------------------------
# Verify sleep and keep-alive options - mutually exclusive

if [ $opt_s -eq 1 -a $opt_k -eq 1 ]
then
	echo "$0: specifying both sleep and keep-alive options not allowed"
	exit 1
fi

#--------------------------------------------------------------------------------
# Sleep

if [ $opt_s -eq 1 ]
then
	echo "sleeping $seconds seconds before exiting..."
	sleep $seconds
fi

#--------------------------------------------------------------------------------
# Keepalive

if [ $opt_k -eq 1 ]
then
	echo "keep alive..."
	while true
	do
		sleep 60
	done
fi
