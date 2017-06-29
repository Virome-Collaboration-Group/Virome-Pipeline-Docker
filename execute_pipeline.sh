#!/bin/bash

usage() {

	echo "Usage: $0 [OPTIONS] file"
	echo "  --enable-data-download      perform data file download (default)"
	echo "  --disable-data-download     do not perform data file download"
	echo "  -k, --keep-alive            keep alive"
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

max_threads=1

while true
do
	case $1 in

	--help|-h)
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
	--keep-alive|-k)
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

if [ $# != 1 ]
then
	usage
	exit 1
fi

input_file=$1

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
# Verify input file

if [ ! -f $input_file ]
then
	echo "$0: cannot open input file: $input_file"
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

	max_threads=${threads}
fi

#--------------------------------------------------------------------------------
# Download data files - if database directory is empty or if there has been a
# version update

if [ $opt_d -eq 1 ]
then
	cd /opt/database

	download=0

	find . -mindepth 1 -print -quit | grep -q .
	retcode=$?

	if [ $retcode -eq 1 ]
	then
		download=1

		curl -s -SL http://virome.dbi.udel.edu/db/version.json -o version.json
		mv version.json version.json.current
	else
		if [ -s version.json.current ]
		then
			curl -s -SL http://virome.dbi.udel.edu/db/version.json -o version.json

			diff version.json version.json.current >/dev/null
			retcode=$?

			if [ $retcode -eq 1 ]
			then
				download=1
			fi

			mv version.json version.json.current
		else
			#### /opt/database could have files unrelated to database
			#### assume there are files other than version.json.current
			#### then download database
			download=1

			curl -s -SL http://virome.dbi.udel.edu/db/version.json -o version.json
			mv version.json version.json.current
		fi
	fi

	if [ $download -eq 1 ]
	then

		DATA_FILES="\
			univec/db.lst \
			rRNA/db.lst \
			mgol/db.lst \
			uniref/latest/db.lst \
			fxn_lookup/db.lst"

		for file in $DATA_FILES
		do
			echo "start: `date`: $file"
			zsync -q http://virome.dbi.udel.edu/db/$file.zsync
			test -s $file.zs-old && /bin/rm $file.zs-old
			test -s $file && chmod 644 $file

			for f in `cat /opt/database/db.lst`
			do
				echo "start: `date`: $f"
				zsync -q $f
			done

		done

		echo "completed: `date`"
	fi
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
-f $input_file \
-d $max_threads

status=$?

if [ $status -ne 0 ]
then
	echo "$0: pipeline error: $status"
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

#--------------------------------------------------------------------------------
# Exit

exit $status
