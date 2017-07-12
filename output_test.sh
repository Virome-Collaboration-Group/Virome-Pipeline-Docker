#!/bin/bash

if [ -d /opt/output ]
then
	cd /opt/output

	mkdir hello
	touch hello/goodbye

	find hello -exec ls -l {} \;

	/bin/rm -rf hello

else
	echo "$0: directory does not exist: /opt/output"
fi
