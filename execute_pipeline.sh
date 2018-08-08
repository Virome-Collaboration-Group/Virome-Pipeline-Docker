#!/bin/bash

usage() {

	echo "Usage: $0 [OPTIONS] file"
	echo "  --enable-data-download             perform data file download (default)"
	echo "  --disable-data-download            do not perform data file download"
	echo "  -k, --keep-alive                   keep alive"
	echo "  --sleep=N                          pause number seconds before exiting"
	echo "  -t N, --threads N, --threads=N     set number of threads"
	echo "  -h, --help                         display this help and exit"
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
	--threads=)
		echo "$0: missing argument to '$1' option"
		usage
		exit 1
		;;
	--threads|-t)
		if [ "$2" ]
		then
			opt_t=1
			threads=$2
			shift
		else
			echo "$0: missing argument to '$1' option"
			usage
			exit 1
		fi
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
	if [ $seconds -lt 1 ]
	then
		echo "$0: invalid sleep number: $seconds"
		exit 1
	fi
fi

#--------------------------------------------------------------------------------
# Verify threads

if [ $opt_t -eq 1 ]
then
	if [ $threads -lt 1 ]
	then
		echo "$0: invalid thread number: $threads"
		exit 1
	fi

	max_threads=${threads}
fi

#--------------------------------------------------------------------------------
# Detect host environment

if [ -f /sys/hypervisor/uuid ] && [ `head -c 3 /sys/hypervisor/uuid` == ec2 ]
then
	host_type=ec2

elif [ ! -z $IPLANT_EXECUTION_ID ]
then
	host_type=cyverse

else
	host_type=local
fi

#--------------------------------------------------------------------------------
# Verify input/output/database directories

if [ $host_type = "ec2" -o $host_type = "local" ]
then
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
fi

#--------------------------------------------------------------------------------
# Amazon EC2 host instance

if [ $host_type = "ec2" ]
then
	# Download data files

	cd /opt/database

	aws --no-sign-request s3 cp --recursive --quiet s3://virome . 
	retcode=$?

	if [ $retcode -ne 0 ]
	then
		echo "$0: aws s3 cp failed: aws return code: $retcode"
		exit 1
	fi
fi

#--------------------------------------------------------------------------------
# CyVerse host instance

if [ $host_type = "cyverse" ]
then
	cwd=`pwd`

	# Output handling

	output=$cwd/output
	mkdir -p $output

	#### temp map output repo here
	mkdir -p $output/run_time_files
	rm -rf /opt/projects/virome/output_repository
	ln -s $output/run_time_files /opt/projects/virome/output_repository

	if [ ! -d $output ]
	then
		echo "$0: directory not found: $output"
		exit 1
	else
		if [ ! -L /opt/output ]
		then
			ln -s $output /opt/output
		fi
	fi

	# Database handling

	database=$cwd/database

	if [ ! -d $database ]
	then
		echo "$0: directory not found: $database"
		exit 1
	else
		if [ ! -L /opt/database ]
		then
			ln -s $database /opt/database
		fi
	fi

	# Debugging

	echo "input_file: $input_file"
	echo "max_threads: $max_threads"

	echo
	input_file=$cwd/$input_file
	echo "input_file: $input_file"

	echo
	ls -l /opt

	echo
	ls -l $cwd

	echo
	ls -l $database/MGOL_DEC2014.00.phr
fi

#--------------------------------------------------------------------------------
# Local host instance

if [ $host_type = "local" ]
then
	# Download data files if /opt/database is empty or if there has been a
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
					test -s $file && chmod 644 $file
	
					for f in `cat /opt/database/db.lst`
					do
						echo "start: `date`: $f"
						#### get just the file name from url
						filename=$(basename "$f" ".zsync")
	
						#### if file exists pass filename to zsync
						z_args=""
						if [ -s "/opt/database/${filename}" ]
						then
							z_args="-i /opt/database/${filename}"
						fi
	
						zsync -q $z_args $f
						test -s "/opt/database/${filename}.zs-old" && rm -rf "/opt/database/${filename}.zs-old"
					done
	
					#### remove db.lst file within the loop so next db/db.lst does not interfere
					test -s "/opt/database/db.lst" && rm -rf "/opt/database/db.lst"
				done
	
			echo "completed: `date`"
		fi
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
