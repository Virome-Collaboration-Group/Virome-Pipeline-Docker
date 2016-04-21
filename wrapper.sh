#! /bin/sh


export PERL5LIB=/opt/ergatis/lib/perl5

#--------------------------------------------------------------------------------
# Verify input/output/project directories

if [ ! -d /tmp/input ]
then
	echo "$0: directory not found: /tmp/input"
	exit 1
fi

if [ ! -d /tmp/output ]
then
	echo "$0: directory not found: /tmp/output"
	exit 1
fi

if [ ! -d /usr/local/projects ]
then
	echo "$0: directory not found: /usr/local/projects"
	exit 1
fi

#--------------------------------------------------------------------------------
# Download data files

cd /tmp/input

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
	echo "`date`: $file"
	zsync -q http://virome.dbi.udel.edu/repository/$file.zsync
	test -s $file.zs-old && /bin/rm $file.zs-old
	chmod 644 $file
done
echo `date`
	
#--------------------------------------------------------------------------------
# Configure/run pipeline (sadkins)

#mkdir -p /tmp/output/pipe_cfg
#chmod 777 /tmp/output/pipe_cfg

### /opt/scripts/create_prok_pipeline_config.pl \
### 	-p 1 \
### 	-m 1 \
### 	-l 1 \
### 	-t /opt/templates/pipelines/  \
### 	-o /tmp/output/pipe_cfg &> /tmp/output/create_prokpipe.log
### 
### /opt/scripts/run_prok_pipeline.pl \
### 	-l /tmp/output/pipe_cfg/pipeline.layout \
### 	-c /tmp/output/pipe_cfg/pipeline.config \
### 	-r /usr/local/projects/virome \
### 	-e /var/www/html/ergatis/cgi/ergatis.ini &> /tmp/output/run_prokpipe.log
	
#--------------------------------------------------------------------------------
# Create virome project

mkdir -p /usr/local/projects/virome/workflow/lock_files
mkdir -p /usr/local/projects/virome/workflow/pipeline
mkdir -p /usr/local/projects/virome/workflow/project_id_repository
mkdir -p /usr/local/projects/virome/workflow/project_saved_templates
mkdir -p /usr/local/projects/virome/workflow/runtime/pipeline
mkdir -p /usr/local/projects/virome/output_repository

cp /tmp/project.config /usr/local/projects/virome/workflow/.
touch /usr/local/projects/virome/workflow/project_id_repository/valid_id_repository

#--------------------------------------------------------------------------------
# Configure/run pipeline (virome)

/opt/scripts/virome_454_fasta_unassembled_run_pipeline.pl \
	--template_directory=/opt/virome/project_saved_templates/454-fasta-unassembled \
	--repository_root=/usr/local/projects/virome \
	--id_repository=/opt/ergatis/global_id_repository \
	--ergatis_ini=/var/www/html/ergatis/cgi/ergatis.ini \
	--fasta=/tmp/file.fasta \
	--prefix=test \
	--library_id=2 \
	--sequences=1 \
	--database=diag1

echo $?
