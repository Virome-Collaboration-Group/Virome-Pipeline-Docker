#!/usr/bin/env perl

=head1 NAME

create_virome_pipeline_config.pl - Will create a pipeline.layout and pipeline.config for selected sub-pipelines of
    the automated virome annotation pipeline

=head1 SYNOPSIS

 USAGE: create_prok_pipeline_config.pl
     [ --templates_directory|-t=/path/to/ergatis/global_pipeline_templates
       --output_directory=/path/to/directory
       --log|-L=/path/to/file.log
       --debug|-D=3
       --help
     ]

=head1 OPTIONS

B<--templates_directory,-t>
    The directory get the templates from

B<--output_directory,-o>
    The directory of where to write the output pipeline.layout and pipeline.config file.
    Defaults to current directory.

B<--input_file, -i>
    The name of the input file to pass to the QC portion of the pipeline.

    If it ends in .list, that will be passed as an iterable list of files.

B<--library_id, -l>
    The id number of the library you are running.

B<--env, -e>
    The environment that this pipeline is running at.

B<--abbr, -a>
    The three letter prefix for the library.

B<--pre_assembled>
    If set to 1, pipeline input is assumed to have been already assembled.

    If set to 0 (default) assembly of reads will take place

    NOTE:: --input_type and --454 will be ignored if this is set to 1

B<--pyro_454>
    If set to 1, will use CD-HIT to align 454 pyrosequencing reads into OTU clusters

    If set to 0 (default), will not do OTU clustering

B<--input_type>
    Determines what type of file the input is in.  Choose from [none(default), fasta, fastq, or sff]

    NOTE:: SFF is only possible when --pyro_454 is enabled...otherwise it is ignored.

B<--log,-L>
    Logfile.

B<--debug,-D>
    1,2 or 3. Higher values more verbose.

B<--help,-h>
    Print this message

=head1  DESCRIPTION

    This script will combine a series of sub-pipelines related to the virome
    annotation engine pipeline and create a pipeline.layout and pipeline.config file.
    The config file can then be configured with the correct options and a pipeline
    can be run.

    This script will include sub-pipelines from the provided templates_directory and create
    a new pipeline. The following pipelines will be looked for by this script and a directory for
    each is expected in the templates_directory:

    virome_pipeline_initialization
    virome_pipeline_qc
    virome_pipeline_core

    The 'virome_pipeline_qc' template will contain multiple template.config and
    template.layout files and the options provided will determine which of these
    will be used.  The differences will be in which of the 5 components will be
    added to the pipeline.

=head1  INPUT
    No input files are required. Just the options and an output directory if
    necessary.

=head1 OUTPUT
    A .config and .layout file are created that will be relevant to the current pipeline being created

=head1  CONTACT

    Shaun Adkins
    sadkins@som.umaryland.edu

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use XML::Writer;
use Pod::Usage;
use Data::Dumper;

############# GLOBALS AND CONSTANTS ################
my $debug = 1;
my ($ERROR, $WARN, $DEBUG) = (1,2,3);
my $logfh;
my $outdir = ".";
my $input_type = 'none';    # Default value
my $valid_input_types = { 'sff' => 1, 'fasta' => 1, 'fastq' => 1 };
# Default template directory path if one isn't provided
my $template_directory = "/opt/ergatis/global_pipeline_templates";
####################################################

## Maps sub-pipeline names
my $pipelines = {
    'core' => 'virome_pipeline_core',
    'init' => 'virome_pipeline_init',
    'qc'   => 'virome_pipeline_qc'
				};

my %options;
my $results = GetOptions (\%options,
						  "template_directory|t=s",
						  "output_directory|o=s",
                          "input_file|i=s",
                          "library_id|l=s",
                          "env|e=s",
                          "abbr|a=s",
                          "pre_assembled=i",
                          "pyro_454=i",
                          "input_type=s",
						  "log|L=s",
						  "debug|d=s",
						  "help|h"
						 );

&check_options(\%options);

# The file that will be written to
my $pipeline_layout = $outdir."/virome.layout";
my $pipeline_config = $outdir."/virome.config";

# File handles for files to be written
open( my $plfh, "> $pipeline_layout") or &_log($ERROR, "Could not open $pipeline_layout for writing: $!");

# Since the pipeline.layout is XML, create an XML::Writer
my $layout_writer = new XML::Writer( 'OUTPUT' => $plfh, 'DATA_MODE' => 1, 'DATA_INDENT' => 3 );

# Write the pipeline.layout file
write_pipeline_layout( $layout_writer, sub {
    my ($writer) = @_;
    write_include($writer, $pipelines->{'init'});
    ### QC block ###
    if ($options{'pre_assembled'}) {
       write_include($writer, $pipelines->{'qc'}, "pipeline.preassembled.layout");
   } elsif ($options{'pyro_454'}) {
       # If the input is not pre_assembled we check to see if it needs OTU clustering
       if ($input_type eq 'sff') {
           write_include($writer, $pipelines->{'qc'}, "pipeline.sff.layout");
       } elsif ($input_type eq 'fasta') {
           write_include($writer, $pipelines->{'qc'}, "pipeline.454_fasta.layout");
       } elsif ($input_type eq 'fastq') {
           write_include($writer, $pipelines->{'qc'}, "pipeline.454_fastq.layout");
       } else {
           &_log($ERROR, "Value for --input_type option must be one of [".join("|", (keys %{$valid_input_types}))."] if the input has not already been pre-assembled.");
       }
   } else {
       # Neither --pre_assembled, nor --pyro_454 were passed
       if ($input_type eq 'fasta') {
           # this scenario uses the same QC components as the --pre_assembled option
           write_include($writer, $pipelines->{'qc'}, "pipeline.preassembled.layout");
       } elsif ($input_type eq 'fastq') {
           write_include($writer, $pipelines->{'qc'}, "pipeline.no_454_fastq.layout");
       } else {
           &_log($ERROR, "Value for --input_type option must be either FASTA or FASTQ if --pre_assembled, and --pyro_454 have not been provided or set to 0.");
       }
   }
   ### end QC block ###
   write_include($writer, $pipelines->{'core'});
});

# end the writer
$layout_writer->end();

my %config;

# Write the pipeline config file
add_config( \%config, $pipelines->{'init'});
add_config( \%config, $pipelines->{'qc'});  # fortunately we can use one config for all the variations
add_config(\%config, $pipelines->{'core'});

$config{"global"}->{'$;ENVIRONMENT$;'} = $options{env};
$config{"global"}->{'$;ABBR;'} = $options{abbr};
$config{"global"}->{'$;LIBARY_ID;'} = $options{library_id};


if ($options{input_file} =~ /list$/) {
    $config{"global"}->{'$;INPUT_LIST;'} = $options{input_file};
} else {
    $config{"global"}->{'$;I_FILE;'} = $options{input_file};
}

if ($options{pre_assembled}) {
    $config{"nt_fasta_check default"}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/fasta_size_filter/$;PIPELINEID$;_default/fasta_size_filter.fsa.list';
} elsif ($options{pyro_454}) {
    $config{"nt_fasta_check default"}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/cd-hit-454/$;PIPELINEID$;_default/cd-hit-454.fsa.list';
} else {
    if ($input_type eq 'fasta') {
        # this scenario uses the same QC components as the --pre_assembled option
        $config{"nt_fasta_check default"}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/fasta_size_filter/$;PIPELINEID$;_default/fasta_size_filter.fsa.list';
    } elsif ($input_type eq 'fastq') {
        $config{"nt_fasta_check default"}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/QC_filter/$;PIPELINEID$;_default/QC_filter.fsa.list';
    } else {
        &_log($ERROR, "We should have never gotten to his condition so something is wonky.");
    }
}


# open config file for writing
open( my $pcfh, "> $pipeline_config") or &_log($ERROR, "Could not open $pipeline_config for writing: $!");

# Write the config
write_config( \%config, $pcfh );

# close the file handles
close($plfh);
close($pcfh);


print "Wrote $pipeline_layout and $pipeline_config\n";

sub write_config {
    my ($config, $fh) = @_;

    # Make sure this section is first
    &write_section( 'global', $config->{'global'}, $fh );
    delete( $config->{'global'} );

    foreach my $section ( keys %{$config} ) {
        &write_section( $section, $config->{$section}, $fh );
    }
}

sub write_section {
    my ($section, $config, $fh) = @_;
    print $fh "[$section]\n";

	foreach my $k ( sort keys %{$config} ) {
	  print $fh "$k=$config->{$k}\n";
	}
    print $fh "\n";
}

sub add_config {
    my ($config, $subpipeline, $config_name) = @_;
print $template_directory, "\t", $subpipeline, "\n";
    my $pc = "$template_directory/$subpipeline/pipeline.config";
    $pc = "$template_directory/$subpipeline/$config_name" if( $config_name );
    open(IN, "< $pc") or &_log($ERROR, "Could not open $pc for reading: $!");

    my $section;
    while(my $line = <IN> ) {
        chomp( $line );
        next if( $line =~ /^\s*$/ || $line =~ /^\;/ );

        if( $line =~ /^\[(.*)\]/ ) {
            $section = $1;
        } elsif( $line =~ /(\$\;.*\$\;)\s*=\s*(.*)/ ) {
            &_log($ERROR, "Did not find section before line $line") unless( $section );
            $config->{$section} = {} unless( exists( $config->{$section} ) );
            $config->{$section}->{$1} = $2;
        }

    }

    close(IN);
}

sub write_parallel_commandSet {
    my ($writer, $block) = @_;
    $writer->startTag("commandSet", 'type' => 'parallel');
    $writer->dataElement("state","incomplete");
    $block->($writer);
    $writer->endTag("commandSet");
}

sub write_pipeline_layout {
    my ($writer, $body) = @_;
    $writer->startTag("commandSetRoot",
                      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
                      "xsi:schemaLocation" => "commandSet.xsd",
                      "type" => "instance" );

    $writer->startTag("commandSet",
                      "type" => "serial" );

    $writer->dataElement("state", "incomplete");
    $writer->dataElement("name", "start pipeline:");

    $body->($writer);

    $writer->endTag("commandSet");
    $writer->endTag("commandSetRoot");
}

sub write_include {
    my ($writer, $sub_pipeline, $pipeline_layout) = @_;
    $pipeline_layout = "pipeline.layout" unless( $pipeline_layout );
    my $sublayout = $template_directory."/$sub_pipeline/$pipeline_layout";
    &_log($ERROR, "Could not find sub pipeline layout $sublayout\n") unless( -e $sublayout );
    $writer->emptyTag("INCLUDE", 'file' => "$sublayout");
}

sub check_options {
   my $opts = shift;

   &_pod if( $opts->{'help'} );
   open( $logfh, "> $opts->{'log'}") or die("Can't open log file ($!)") if( $opts->{'log'} );

   foreach my $req ( qw(input_file library_id env abbr) ) {
       &_log($ERROR, "Option $req is required") unless( $opts->{$req} );
   }

   $outdir = $opts->{'output_directory'} if( $opts->{'output_directory'} );
   $template_directory = $opts->{'template_directory'} if( $opts->{'template_directory'} );

   # Make sure input type provided is a valid one
   if ($opts->{'input_type'} ) {
       &_log($ERROR, "Value for --input_type option must be one of [none|".join("|", (keys %{$valid_input_types}))."]")
	   unless( exists( $valid_input_types->{lc( $opts->{'input_type'} )} ) || lc( $opts->{'input_type'} ) eq 'none' );
       $input_type = $opts->{'input_type'};
   }
}

sub _log {
   my ($level, $msg) = @_;
   if( $level <= $debug ) {
      print STDOUT "$msg\n";
   }
   print $logfh "$msg\n" if( defined( $logfh ) );
   exit(1) if( $level == $ERROR );
}

sub _pod {
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}
