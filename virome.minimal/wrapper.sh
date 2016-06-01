#! /bin/sh


export PERL5LIB=/opt/package_virome/autopipe_package/ergatis/lib

#--------------------------------------------------------------------------------
# Verify input/output/project directories

### if [ ! -d /tmp/input ]
### then
### 	echo "$0: directory not found: /tmp/input"
### 	exit 1
### fi
### 
### if [ ! -d /tmp/output ]
### then
### 	echo "$0: directory not found: /tmp/output"
### 	exit 1
### fi
### 
### if [ ! -d /usr/local/projects ]
### then
### 	echo "$0: directory not found: /usr/local/projects"
### 	exit 1
### fi

#--------------------------------------------------------------------------------
# Download data files

### cd /tmp/input
### 
### DATA_FILES="\
### 	MGOL_DEC2014 \
### 	MGOL_DEC2014.60 \
### 	UNIREF50_2015_12 \
### 	UNIREF100_2015_12 \
### 	UniVec_Core \
### 	rRNA \
### 	mgol60__2__mgol100.lookup \
### 	uniref50__2__uniref100.lookup"
### 
### for file in $DATA_FILES
### do
### 	echo "`date`: $file"
### 	zsync -q http://virome.dbi.udel.edu/repository/$file.zsync
### 	test -s $file.zs-old && /bin/rm $file.zs-old
### 	chmod 644 $file
### done
### echo `date`

#--------------------------------------------------------------------------------
# Configure/run pipeline (virome)

/opt/scripts/virome_454_fasta_unassembled_run_pipeline.pl \
	--template_directory=/opt/package_virome/project_saved_templates/454-fasta-unassembled \
	--repository_root=/opt/projects/virome \
	--id_repository=/opt/projects/virome/workflow/project_id_repository \
	--ergatis_ini=/opt/package_virome/autopipe_package/ergatis.ini \
	--fasta=/tmp/file.fasta \
	--prefix=test \
	--library_id=2 \
	--sequences=1 \
	--database=diag1

echo $?
