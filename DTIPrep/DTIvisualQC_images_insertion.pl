#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Tabular;
use File::Basename;
use FindBin;
use Date::Parse;
use XML::Simple;
use lib "$FindBin::Bin";

# These are to load the DTI & DBI modules to be used
use DB::DBI;
use DTI::DTI;
use DTI::DTIvisu;

# Set default option values
my $profile         = undef;
my $DTIvisu_subdir  = undef;
my @args;

# Set the help section
my  $Usage  =   <<USAGE;

Register DTI_visualQC_ilana DWI files via register_processed_data.pl.

The following output files will be considered:
    - Final_noRegQCed minc file (QCed DWI without motion correction)
    - Final_QCed minc file (QCed DWI wit motion correction)
    - Final_noRegQCed RGB map produced for visual QC of color (or vibration) artefact

Usage: $0 [options]

-help for options

USAGE

# Define the table describing the command-line options
my  @args_table = (
    ["-profile",              "string", 1,  \$profile,          "name of the config file in ../dicom-archive/.loris_mri."],
    ["-DTIvisu_subdir",       "string", 1,  \$DTIvisu_subdir,   "DTI visual QC subdirectory storing the QCed files to be registered (typically /data/preventAD/data/pipelines/DTIvisualQC_ilana/108583/NAPEN00/processed/DTIPrepPipeline)"]
);

Getopt::Tabular::SetHelp ($Usage, '');
GetOptions(\@args_table, \@ARGV, \@args) || exit 1;

# input option error checking
{ package Settings; do "$ENV{LORIS_CONFIG}/.loris_mri/$profile" }
if  ($profile && !defined @Settings::db) {
    print "\n\tERROR: You don't have a configuration file named '$profile' in:  $ENV{LORIS_CONFIG}/.loris_mri/ \n\n";
    exit 33;
}
if (!$profile) {
    print "$Usage\n\tERROR: You must specify a profile.\n\n";
    exit 33;
}
if (!$DTIvisu_subdir) {
    print "$Usage\n\tERROR: You must specify a DTI visual QC subdirectory with processed files to be registered in the database.\n\n";
    exit 33;
}

# Needed for log file
my  $data_dir    =  $Settings::data_dir;
my  $log_dir     =  "$data_dir/logs/DTI_visualQC_register";
system("mkdir -p -m 755 $log_dir") unless (-e $log_dir);
my  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my  $date        =  sprintf("%4d-%02d-%02d_%02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
my  $log         =  "$log_dir/DTI_visualQC_register_$date.log";
open(LOG,">>$log");
print LOG "Log file, $date\n\n";

# Establish database connection
my  $dbh    =   &DB::DBI::connect_to_db(@Settings::db);
print LOG "\n==> Successfully connected to database \n";

print LOG "\n==> DTI output directory is: $DTIvisu_subdir\n";



    #######################
    ####### Step 1: #######  Get the list of output files to register
    #######################
# Remove last / from DTIvisu_subdir
$DTIvisu_subdir =~ s/\/$//;

# Read content of DTI visual QC directory
my $QCedfiles   = &DTI::getFilesList($DTIvisu_subdir, 'Final');
# grep FinalQCedDTI file
my ($FinalQCedDTI)         = grep { $_ =~ /FinalQCedDTI/}                  @$QCedfiles;
my ($FinalnoRegQCedDTI)    = grep { $_ =~ /FinalnoRegQCedDTI_\d\d\d\.mnc/} @$QCedfiles;
my ($FinalnoRegQCedDTIrgb) = grep { $_ =~ /-eddy-reg-to-t1_rgb/}           @$QCedfiles;


unless ($FinalQCedDTI && $FinalnoRegQCedDTI && $FinalnoRegQCedDTIrgb) {
    print LOG "\nERROR:\n\tCould not find all outputs to register in $DTIvisu_subdir.\n";
    exit 33;
}

    
    #######################
    ####### Step 2: #######  Register FinalQCedDTI
    #######################
my ($registeredFinalQCedDTI) = &register_file($FinalQCedDTI, $DTIvisu_subdir, $dbh);
unless ($registeredFinalQCedDTI) {
    print LOG "\nERROR:\n\t$FinalQCedDTI was not inserted into the database";
    exit;
}

    #######################
    ####### Step 3: #######  Register FinalnoRegQCedDTI
    #######################
my ($registeredFinalnoRegQCedDTI, $sourceName) = &register_file($FinalnoRegQCedDTI, $DTIvisu_subdir, $dbh);
unless ($registeredFinalnoRegQCedDTI) {
    print LOG "\nERROR:\n\t$FinalnoRegQCedDTI was not inserted into the database";
    exit;
}

    #######################
    ####### Step 4: #######  Register FinalnoRegQCedDTIrgb
    #######################
my ($registeredFinalnoRegQCedDTIrgb, $sourceName) = &register_file($FinalnoRegQCedDTIrgb, $DTIvisu_subdir, $dbh, $sourceName);
unless ($registeredFinalnoRegQCedDTIrgb) {
    print LOG "\nERROR:\n\t$FinalnoRegQCedDTIrgb was not inserted into the database";
    exit;
}

    
exit 0;

# create a hashref of files to register with their options
#my ($DTIrefs) = &DTIvisu::createDWIQChasref($QCedfiles,
#                                            $DTIvisu_subdir
#                                           );
#if  (!$DTIrefs) {
#    print LOG "\nERROR:\n\tCould not determine a list of outputs to register $DTIvisu_subdir.\n";
#    exit 33;
#}

#################
### Functions ###
#################
=pod
Input:  - $QCedFile: QCed file to be registered into the DB
=cut
sub register_file {
    my ($QCedFile, $DTIvisu_subdir, $dbh, $sourceName) = @_;

    # Input DTIPrep filename & FileID
    my $inputName     = substr(basename($QCedFile), 0, -4);
    if ($QCedFile =~ m/-eddy-reg-to-t1_rgb/) {
        $inputName    =~ s/-eddy-reg-to-t1_rgb//g;
    } else {
        $inputName    =~ s/Final//g;
    }
    my ($inputFileID) = &DTIvisu::getFileID($inputName, $dbh);

    #  Raw DWI source filename & FileID
    unless ($sourceName) {
        ($sourceName) = &DTI::fetch_header_info('processing:sourceFile',
                                                $QCedFile,
                                                '$3'
                                               );
    }
    $sourceName       =~ s/\/assembly/assembly/;
    $sourceName       =~ s/"//g; 
    $sourceName       =~ s/\/\//\//g;
    my ($sourceFileID)= &DTIvisu::getFileID($sourceName, $dbh);

    # QC_date (equivalent to pipeline date) of the file to be registered
    # read this information direclty from the filesystem creation date
    my ($QCdate)      = &DTIvisu::getQCdate($QCedFile);

    # ScanType to be attributed for file to be registered
    my ($scanType, $coordinateSpace)  = &DTIvisu::getScanType($QCedFile);

    # SourcePipeline
    my $sourcePipeline= "DTIvisualQC";

    # OutputType
    my $outputType    = "qc";

    # Tool
    my $tool          = "VisualQC"; 

    # message to print if missing information    
    my $message = <<END_MESSAGE;
WARNING!! Missing information to be able to register $QCedFile.
    sourceFileID:    $sourceFileID
    sourcePipeline:  $sourcePipeline
    QCdate:          $QCdate
    coordinateSpace: $coordinateSpace
    scanType:        $scanType
    outputType:      $outputType
    inputFileID:     $inputFileID
END_MESSAGE

    ## if all variables set, register file into DB
    if (($QCedFile)         &&  ($sourceFileID) &&
         ($sourcePipeline)  &&  ($QCdate)       &&
         ($coordinateSpace) &&  ($scanType)     &&
         ($outputType)      &&  ($inputFileID)) {        
        my ($registeredMincFile)   = &registerFile($QCedFile,
                                                   $sourceFileID,
                                                   $sourcePipeline,
                                                   $tool,
                                                   $QCdate,
                                                   $coordinateSpace,
                                                   $scanType,
                                                   $outputType,
                                                   $inputFileID
                                                  );
        return ($registeredMincFile, $sourceName) if ($QCedFile =~ m/FinalnoRegQCedDTI/);
        return ($registeredMincFile);
    } else {
        print LOG $message;
        return undef;
    }
}





=pod
Register file into the database via register_processed_data.pl with all options.
Inputs:  - $file            = file to be registered in the database
         - $src_fileID      = FileID of the source file used to obtain the file to be registered
         - $src_pipeline    = Pipeline used to obtain the file (DTIPrepPipeline)
         - $src_tool        = Name and version of the tool used to obtain the file (DTIPrep or mincdiffusion)
         - $pipelineDate    = file's creation date (= pipeline date)
         - $coordinateSpace = file's coordinate space (= native, T1 ...)
         - $scanType        = file's scan type (= QCedDTI, FAqc, MDqc, RGBqc...)
         - $outputType      = file's output type (.xml, .txt, .mnc...)
         - $inputs          = files that were used to create the file to be registered (intermediary files)
Outputs: - $registeredFile  = file that has been registered in the database
=cut
sub registerFile  {
    my  ($file, $src_fileID, $src_pipeline, $src_tool, $pipelineDate, $coordinateSpace, $scanType, $outputType, $inputs)    =   @_;

    # Check if File has already been registered into the database. Return File registered if that is the case.
    my ($alreadyRegistered) = &fetchRegisteredFile($src_fileID, $src_pipeline, $pipelineDate, $coordinateSpace, $scanType, $outputType);
    if ($alreadyRegistered) {
        print LOG "> File $file already registered into the database.\n";
        return ($alreadyRegistered);
    }

    # Print LOG information about the file to be registered
    print LOG "\n\t- sourceFileID is: $src_fileID\n";
    print LOG "\t- src_pipeline is: $src_pipeline\n";
    print LOG "\t- tool is: $src_tool\n";
    print LOG "\t- pipelineDate is: $pipelineDate\n";
    print LOG "\t- coordinateSpace is: $coordinateSpace\n";
    print LOG "\t- scanType is: $scanType\n";
    print LOG "\t- outputType is: $outputType\n";
    print LOG "\t- inputFileIDs is: $inputs\n";

    # Register the file into the database using command $cmd
    my $cmd =   "register_processed_data.pl " .
                    "-profile $profile " .
                    "-file $file " .
                    "-sourceFileID $src_fileID " .
                    "-sourcePipeline $src_pipeline " .
                    "-tool $src_tool " .
                    "-pipelineDate $pipelineDate " .
                    "-coordinateSpace $coordinateSpace " .
                    "-scanType $scanType " .
                    "-outputType $outputType  " .
                    "-inputFileIDs \"$inputs\" ";
    system($cmd);
    print LOG "\n==> Command sent:\n$cmd\n";

    my  ($registeredFile) = &fetchRegisteredFile($src_fileID, $src_pipeline, $pipelineDate, $coordinateSpace, $scanType, $outputType);

    if (!$registeredFile) {
        print LOG "> WARNING: No fileID found for SourceFileID=$src_fileID, SourcePipeline=$src_pipeline, PipelineDate=$pipelineDate, CoordinateSpace=$coordinateSpace, ScanType=$scanType and OutputType=$outputType.\n\n\n";
    }

    return ($registeredFile);
}



=pod
Fetch the registered file from the database to link it to the minc files.
Inputs:  - $src_fileID      = FileID of the native file used to register the processed file
         - $src_pipeline    = Pipeline name used to register the processed file
         - $pipelineDate    = Pipeline data used to register the processed file
         - $coordinateSpace = coordinate space used to register the processed file
         - $scanType        = scan type used to register the processed file
         - $outputType      = output type used to register the processed file
Outputs: - $registeredFile  = path to the registered processed file
=cut
sub fetchRegisteredFile {
    my ($src_fileID, $src_pipeline, $pipelineDate, $coordinateSpace, $scanType, $outputType) = @_;

    my $registeredFile;

    # fetch the FileID of the raw dataset
    my $query   =   "SELECT f.File "          .
                    "FROM files f "             .
                    "JOIN mri_scan_type mst "   .
                        "ON mst.ID=f.AcquisitionProtocolID ".
                    "WHERE f.SourceFileID=? "   .
                        "AND f.SourcePipeline=? "   .
                        "AND f.PipelineDate=? "     .
                        "AND f.CoordinateSpace=? "  .
                        "AND mst.Scan_type=? "      .
                        "AND OutputType=?";

    my $sth     =   $dbh->prepare($query);
    $sth->execute($src_fileID, $src_pipeline, $pipelineDate, $coordinateSpace, $scanType, $outputType);

    if  ($sth->rows > 0)    {
        my $row =   $sth->fetchrow_hashref();
        $registeredFile =   $row->{'File'};
    }

    return  ($registeredFile);

}
