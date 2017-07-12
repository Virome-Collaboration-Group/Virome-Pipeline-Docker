#!/bin/bash

usage() {

	echo "Usage: $0 [OPTIONS] file"
	echo "  -h, --help                  display this help and exit"
}

#--------------------------------------------------------------------------------
# Process parameters

opt_a=0

while true
do
	case $1 in

	--help|-h)
		usage
		exit
		;;
	--start-web-server)
		opt_a=1
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
# Start apache

if [ $opt_a -eq 1 ]
then
	/usr/sbin/apachectl start
fi
