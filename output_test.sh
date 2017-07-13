#!/bin/bash

if [ -d /opt/output ]
then
	cd /opt/output

	mkdir -p hello
	touch hello/goodbye
	chmod -R 777 hello

	find hello -exec ls -l {} \;

else
	echo "$0: directory does not exist: /opt/output"
fi
