#!/bin/bash


usage() {

	echo "Usage: $0 [OPTIONS]"
	echo "  --enable-data-download      perform data file download (default)"
	echo "  --disable-data-download     do not perform data file download"
	echo "  --input-file=file           input file to process"
	echo "  --start-web-server          start web server"
	echo "  -k,--keep-alive             keep alive"
	echo "  --sleep=number              pause number seconds before exiting"
	echo "  --threads=number            set number of threads"
	echo "  --test-case[1-4]			Run default test case. Four different test cases available 1-4"
	echo "  -h, --help                  display this help and exit"
}

#--------------------------------------------------------------------------------
# Process parameters

opt_a=0
opt_d=1
opt_f=0
opt_k=0
opt_s=0
opt_t=0
opt_f=0
opt_e=0

# Temporary settings
input_file=""
max_threads=1

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
# Download data files

if [ $opt_d -eq 1 ]
then
    cd /opt/database

	curl -s -SL http://virome.dbi.udel.edu/db/version.json -o version.json

	#### TO-DO: check version and start download if version is different.
	#### start download if
	#### 	- no files in /opt/database
	####	- version is different
	####	- Throw error if --disable-datadownload and no files in /opt/database

    DATA_FILES="\
        univec/db.lst \
        rRNA/db.lst \
        mgol/db.lst \
        uniref/db.lst"

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

#--------------------------------------------------------------------------------
# Start apache

if [ $opt_a -eq 1 ]
then
	source /tmp/apache2.envvars
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

#--------------------------------------------------------------------------------
# Exit

exit $status
