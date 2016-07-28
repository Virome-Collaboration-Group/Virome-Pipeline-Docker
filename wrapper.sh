#!/bin/bash


usage() {

	echo "Usage: $0 [OPTIONS]"
	echo "  --enable-data-download      perform data file download (default)"
	echo "  --disable-data-download     do not perform data file download"
	echo "  --start-web-server          start web server"
	echo "  --threads=N                 thread count, where N is positive integer"
	echo "  -h, --help                  display this help and exit"
}

#--------------------------------------------------------------------------------
# Process parameters

opt_a=0
opt_d=1
opt_t=0

while true
do
	case $1 in

	-h|--help)
		usage
		exit
		;;
	--start-web-server)
		opt_a=1
		;;
	--enable-data-download)
		opt_d=1
		;;
	--disable-data-download)
		opt_d=0
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
# Verify threads

if [ $opt_t = 1 ]
then
	if [[ $threads =~ ^-?[0-9]+$ ]]
	then
		if [ $threads -le 0 ]
		then
			echo "$0: invalid thread count: $threads"
			exit 1
		fi
	else
		echo "$0: invalid thread count: $threads"
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
# Configure/run pipeline (virome)

export PERL5LIB=/opt/ergatis/lib/perl5

# TODO: This next step is probably asynchronous, so it probably immediately exits
# after the pipeline is executed. So, we need to invoke another script to
# block and wait for the pipeline to be complete before this script is allowed
# to exit

/opt/package_virome/autopipe_package/virome_little_run_pipeline.pl \
-t /opt/package_virome/project_saved_templates/little-pipeline/ \
-r /opt/projects/virome \
-e /var/www/html/ergatis/cgi/ergatis.ini \
-i /opt/projects/virome/workflow/project_id_repository/ \
-f /opt/package_virome/play_data/GS115.fasta

echo $?

# TODO: Invoke the blocking/pipeline monitoring script. Exit with an exit
# value that indicates overall pipeline success or failure.

# TODO: Implement
# /opt/scripts/monitor.pl
