#!/bin/bash

usage() {

	echo "Usage: $0 [OPTIONS]"
	echo "  --enable-data-download      perform data file download (default)"
	echo "  --disable-data-download     do not perform data file download"
	echo "  --input-file=file           input file to process"
	echo "  -k, --keep-alive            keep alive"
	echo "  --sleep=number              pause number seconds before exiting"
	echo "  --threads=number            set number of threads"
	echo " --blast-only"
	echo " --post-blast-only"
	echo "  --test-case[1-4]            run one of four possible test cases"
	echo "  -h, --help                  display this help and exit"
}

#--------------------------------------------------------------------------------
# Process parameters

opt_a=0
opt_d=1
opt_e=0
opt_f=0
opt_k=0
opt_s=0
opt_t=0
opt_v=0
opt_b=0
opt_p=0

input_file=""
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
	--blast-only)
		opt_b=1
		;;
	--post-blast-only)
		opt_p=1
		;;
	--debug=?*)
		opt_v=${1#*=}
		;;
	--debug=)
		echo "$0: missing argument to --debug option"
		usage
		exit 1
		;;
	--debug)
		if [ "$2" ]
		then
			opt_v=$2
			shift
		else
			echo "$0: missing argument to --debug option"
			usage
			exit 1
		fi
		;;
	--test-case1)
		opt_e=1
		input_file="/opt/play_data/play_data.fasta"
		;;
	--test-case2)
		opt_e=1
		input_file="/opt/play_data/bad_guy_1.fasta"
		;;
	--test-case3)
		opt_e=1
		input_file="/opt/play_data/bad_guy_2.fasta"
		;;
	--test-case4)
		opt_e=1
		input_file="/opt/play_data/bad_guy_3.fasta"
		;;
	--input-file=?*)
		opt_f=1
		input_file=${1#*=}
		;;
	--input-file|input-file=)
		echo "$0: missing argument to '$1' option"
		usage
		exit 1
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

if [ $# != 0 ]
then
	usage
	exit 1
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
# Verify input file

if [ $opt_f -eq 0 -a $opt_e -eq 0 ]
then
	echo "Input file not defined, if running a test case use --test-case[1-4] option"
	usage
	exit 1
fi

if [ $opt_p -eq 1 ]
then
	if [ ! -d "/opt/input/${input_file}" ]
	then
		echo "$0: Not a directory, input to post-blast must be a input dir unpacked from blastonly output: $input_file"
		exit 1
	fi
else
	if [ ! -f $input_file ]
	then
		echo "$0: cannot open input file: $input_file"
		exit 1
	fi
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
# Verify whether host is an Amazon EC2 instance

if [ -f /sys/hypervisor/uuid ] && [ `head -c 3 /sys/hypervisor/uuid` == ec2 ]
then
	host_type=ec2
else
	host_type=local
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

#--------------------------------------------------------------------------------
# Start apache

if [ $opt_a -eq 1 ]
then
	/usr/sbin/apachectl start
fi

#--------------------------------------------------------------------------------
# Configure/run virome pipeline
if [ $opt_v -ne 0 ]
then
	hn=`hostname`
	#### temp map output repo here
	mkdir -p /opt/output/output_repository_${hn}
	rm -rf /opt/projects/virome/output_repository
	ln -s /opt/output/output_repository_${hn} /opt/projects/virome/output_repository
fi

export PERL5LIB=/opt/ergatis/lib/perl5

if [ $opt_b -eq 1 ]
then
	/opt/ergatis/autopipe_package/virome_blastonly_pipeline.pl \
	-t /opt/ergatis/project_saved_templates/virome-pipeline/ \
	-r /opt/projects/virome \
	-e /var/www/html/ergatis/cgi/ergatis.ini \
	-i /opt/projects/virome/workflow/project_id_repository/ \
	-f $input_file \
	-d $max_threads \
	-v $opt_v

	status=$?
else
	if [ $opt_p -eq 1 ]
	then
		/opt/ergatis/autopipe_package/virome_postblast_pipeline.pl \
		-t /opt/ergatis/project_saved_templates/virome-pipeline/ \
		-r /opt/projects/virome \
		-e /var/www/html/ergatis/cgi/ergatis.ini \
		-i /opt/projects/virome/workflow/project_id_repository/ \
		-f /opt/input/${input_file} \
		-d $max_threads \
		-v $opt_v

		status=$?
	else
		/opt/ergatis/autopipe_package/virome_complete_pipeline.pl \
		-t /opt/ergatis/project_saved_templates/virome-pipeline/ \
		-r /opt/projects/virome \
		-e /var/www/html/ergatis/cgi/ergatis.ini \
		-i /opt/projects/virome/workflow/project_id_repository/ \
		-f $input_file \
		-d $max_threads \
		-v $opt_v

		status=$?
	fi
fi

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
