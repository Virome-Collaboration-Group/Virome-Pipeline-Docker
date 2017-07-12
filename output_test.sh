#!/bin/bash

if [ -d /opt/output ]
then
	cd /opt/output

	mkdir -p hello
	touch hello/goodbye

	find hello -exec ls -l {} \;

else
	echo "$0: directory does not exist: /opt/output"
fi
