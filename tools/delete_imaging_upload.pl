#!/usr/bin/perl

=pod

=head1 NAME

delete_mri_upload.pl -- Delete everything that was produced (or part of what was produced) by the imaging pipeline for a given set of imaging uploads

=head1 SYNOPSIS

perl delete_mri_upload.pl [-profile file] [-ignore] [-nobackup] [-protocol] [-form] [-uploadID list_of_uploadIDs]
            [-type list_of_scan_types] [-defaced]

Available options are:

-profile     : name of the config file in C<../dicom-archive/.loris_mri> (defaults to C<prod>).

-ignore      : ignore files whose paths exist in the database but do not exist on the file system.
               Default is to abort if such a file is found, irrespective of whether a backup has been
               requested or not (see C<-nobackup>). If this option is used, a warning is issued
               and program execution continues.
               
-nobackup    : do not backup the files produced by the imaging pipeline for the upload(s) passed on
               the command line (default is to perform a backup).
               
-uploadID    : comma-separated list of upload IDs (found in table C<mri_upload>) to delete. The program will 
               abort if the list contains an upload ID that does not exist. Also, all upload IDs must
               have the same C<tarchive> ID (which can be C<NULL>).
               
-protocol    : delete the imaging protocol(s) in table C<mri_processing_protocol> associated to either the
               upload(s) specified via the C<-uploadID> option or any file that was produced using this (these)
               upload(s). Let F be the set of files directly or indirectly associated to the upload(s) to delete.
               This option must be used if there is at least one record in C<mri_processing_protocol> that is tied
               only to files in F. Protocols that are tied to files not in F are never deleted. If the files in F
               do not have a protocol associated to them, the switch is ignored if used.
               
-form        : delete the entries in C<mri_parameter_form> associated to the upload(s) passed on
               the command line, if any (default is NOT to delete them).
               
-type        : comma-separated list of scan type names to delete. All the names must exist in table C<mri_scan_type> or
               the script will issue an error. This option cannot be used in conjunction with C<-defaced>.
               
-defaced     : fetch the scan types listed in config setting C<modalities_to_delete> and perform a deletion of these scan
               types as if their names were used with option C<-type>. Once all deletions are done, set the C<SourceFileID>
               and C<TarchiveSource> of all the defaced files in table <files> to C<NULL> and to the tarchive ID of the 
               upload(s) whose arguments were passed to C<-uploadID>, respectively.

=head1 DESCRIPTION

This program deletes an imaging upload or specific parts of it from the database and the file system. There are three
possible ways in which this script can be used:

1. Delete everything that is associated to an archive. Basically, for uploads on which the MRI pipeline was
successfully run, this removes all records tied to the upload in the following tables:
   a) C<notification_spool>
   b) C<files>
   c) C<tarchive_series> and C<tarchive_files>
   d) C<mri_protocol_violated_scans>, C<MRICandidateErrors> and C<mri_violations_log>
   e) C<files_intermediary>. 
   f) C<parameter_file>
   g) C<tarchive>
   h) C<mri_upload>
   i) C<mri_processing_protocol> if option C<-protocol> is used (see below)
   j) C<mri_parameter_form> if option C<-form> is used (see below)
   
All the deletions and modifications performed in the database are done as part of a single transaction, so they either
all succeed or a rollback is performed and the database is not modified in any way. The ID of the upload to delete
is specified via option C<-uploadID>. More than one upload can be deleted if they all have the same C<TarchiveID> 
in table C<mri_upload>: option C<-uploadID> can take as argument a comma-separated list of upload IDs for this case.
If an upload that is deleted is the only one that was associated to a given session, the script will set the C<Scan_done>
value for that session to 'N'. If option C<-form> is used, the C<mri_parameter_form> and its associated C<flag> record 
are also deleted, for each deleted upload. If option C<-protocol> is used and if there is a record in table 
C<mri_processing_protocol> that is tied only to the deleted upload(s), then that record is also deleted.

C<delete_imaging_upload.pl> cannot be used to delete an upload that has an associated MINC file that has been QCed.
In other words, if there is a MINC file tied to the upload that is targeted for deletion and if that MINC file has 
an associated record in table C<files_qcstatus> or C<feedback_mri_comments>, the script will issue an error message
and exit.

Before deleting any records in the database, the script will verify that all the records in tables a) through j) that 
represent file names (e.g. a record in C<files>, a protocol file in C<mri_processing_protocol>, etc...) refer to files
that actually exist on the file system. If it finds a record that does not meet that criterium, the script issues an 
error message and exits, leaving the database untouched. To avoid this check, use option C<-ignore>. Each time a file
record is deleted, the file it refers to on the file system is also deleted. A backup will be created by 
C<delete_imaging_upload.pl> of all the files that were deleted during execution. Option C<-nobackup> can be used to 
prevent a backup from being created. If created, the backup file will be named C<< imaging_upload.<TARCHIVE_ID>.tar.gz >>
or C<< imaging_upload.<TARCHIVE_ID>.tar.gz >> if the upload(s) did not have an associated C<tarchive>. Note that the file
paths inside this backup archive are absolute. To restore the files in the archive, one must use C<tar> with option 
C<--absolute-names>.

The script will also create a file that contains a backup of all the information that was deleted or modified from the 
database tables. This backup is created using C<mysqldump> and contains an C<INSERT> statement for every record erased. 
If sourced back into the database with C<mysql>, it should allow the database to be exactly like it was before 
C<delete_imaging_upload.pl> was invoked, provided the database was not modified in the meantime. The SQL backup file will
be named C<< imaging_upload.<TARCHIVE_ID>.sql.gz >> or simply C<< imaging_upload.sql.gz >> if the upload(s) did not have
an associated C<tarchive>.

2. Delete specific scan types from an archive. The behaviour of the script is identical to the one described above, except 
   that:
    a) the deletions are limited to MINC files of a specific scan type: use option C<-type> with a comma-separated list
       of scan type names to specify which ones.
    b) everything associated to the MINC files deleted in a) is also deleted: this includes the processed files in 
       C<files_intermediary>, the records in C<mri_violations_log>, C<tarchive_series> and C<tarchive_files>.
    c) if C<-protocol> is used and there is an entry in table C<mri_processing_protocol> that is tied only to the files
       deleted in a), then that record is also deleted.
    d) tables C<tarchive>, C<mri_upload>, C<notification_spool>, C<MRICandidateErrors> and C<mri_parameter_form> are never
       modified.
   Note that option C<-type> cannpot be used in conjunction with either option C<-form> or option C<-defaced>.
       
3. Replace MINC files with their defaced counterparts. This is the behaviour obtained when option C<-defaced> is used. As far as 
   deletions go, the behaviour of the script in this case is identical to the one described in 2), except that the list of 
   scan types to delete is fetched from the config setting C<modalities_to_deface>. Use of option C<-defaced> is not permitted
   in conjunction with option C<-type> or option C<-form>. Once all deletions are made, the script will change the C<SourceFileID> 
   of all defaced files to C<NULL> and set the C<TarchiveSource> of all defaced files to the C<TarchiveiD> of the upload(s). 
   This effectively "replaces" the original MINC files with their corresponding defaced versions. Note that that script will issue 
   an error message and abort, leaving the database and file system untouched, if:
       a) A MINC file should have a corresponding defaced file but does not.
       b) A MINC file that has been defaced has an associated file that is not a defaced file.
    

=head2 Methods

=cut

use strict;
use warnings;

use NeuroDB::DBI;
use NeuroDB::ExitCodes;
use NeuroDB::MRI;

use Getopt::Tabular;       

use File::Temp qw/tempfile/;

use constant DEFAULT_PROFILE                   => 'prod';
use constant DEFAULT_DIE_ON_FILE_ERROR         => 1;
use constant DEFAULT_NO_BACKUP                 => 0;
use constant DEFAULT_NO_SQL                    => 0;
use constant DEFAULT_DELETE_PROTOCOLS          => 0;
use constant DEFAULT_DELETE_MRI_PARAMETER_FORM => 0;
use constant DEFAULT_KEEP_DEFACED              => 0;

use constant PIC_SUBDIR                => 'pic';

# These are the tables that contain references to files related to the uploads.
# Note that the script also deletes entries in mri_parameter_form even though
# this table is not listed here.
my @PROCESSED_TABLES = (
    'files',
    'files_intermediary',
    'parameter_file',
    'mri_protocol_violated_scans',
    'mri_violations_log',
    'MRICandidateErrors',
    'tarchive',
    'mri_processing_protocol',
    'mri_upload'
);

# Stolen from get_dicom_files.pl: should be a constant global to both
# scripts 
my $FLOAT_EQUALS_THRESHOLD = 0.00001;

my $profile                = DEFAULT_PROFILE;
my $dieOnFileError         = DEFAULT_DIE_ON_FILE_ERROR;
my $noBackup               = DEFAULT_NO_BACKUP;
my $noSQL                  = DEFAULT_NO_SQL;
my $deleteProtocols        = DEFAULT_DELETE_PROTOCOLS;
my $deleteMriParameterForm = DEFAULT_DELETE_MRI_PARAMETER_FORM;
my $keepDefaced            = DEFAULT_KEEP_DEFACED;

my $uploadIDList           = undef;
my $scanTypeList           = undef;

my @opt_table = (
    ['-profile' , 'string'  , 1, \$profile, 
     'Name of config file in ../dicom-archive/.loris_mri (defaults to "prod")'],
    ['-ignore'  , 'const'   , 0, \$dieOnFileError, 
     'Ignore files that exist in the database but not on the file system.'
     . ' Default is to abort if such a file is found.'],
    ['-nobackup', 'const'   , 1, \$noBackup,
     'Do not backup anything. Default is to backup all files to be deleted '
     . 'into an archive named "imaging_upload.<TarchiveID>.tar.gz", in the '
     . 'current directory'],
    ['-uploadID', 'string', 1, \$uploadIDList,
     'Comma-separated list of upload IDs to delete. All the uploads must be associated to the same archive.'],
    ['-protocol', 'const', 1, \$deleteProtocols,
     'Delete the entries in mri_processing_protocols tied to the upload(s) specified via -uploadID.'],
    ['-form', 'const', 1, \$deleteMriParameterForm,
     'Delete the entries in mri_parameter_form tied to the upload(s) specified via -uploadID.'],
    ['-type', 'string', 1, \$scanTypeList, 'Comma-separated list of scan types to delete.'],
    ['-nosql', 'const', 1, \$noSQL,
     'Do not backup the information deleted from the database with mysqldump. '
      . 'Default is to backup all records deleted in a file named imaging_upload_<TarchiveID>.sql in the '
      . 'current directory.'],
    ['-defaced', 'const', 1, \$keepDefaced,
     'Replace each MINC files whose scan types are in the list of types to deface with its'
      . ' corresponding defaced file.']
);

my $Help = <<HELP;
HELP

my $usage = <<USAGE;
Usage: $0 [-profile profile] [-ignore] [-nobackup] [-protocol] [-form] [-uploadID uploadIDList]
USAGE

&Getopt::Tabular::SetHelp($Help, $usage);
&Getopt::Tabular::GetOptions(\@opt_table, \@ARGV) || exit $NeuroDB::ExitCodes::GETOPT_FAILURE;

if(@ARGV != 0) {
    print STDERR "$usage\n";
    exit $NeuroDB::ExitCodes::INVALID_ARG;
}

if(defined $scanTypeList && $deleteMriParameterForm) {
    print STDERR "Option -type cannot be used in conjunction with option -form. Aborting.\n";
       exit $NeuroDB::ExitCodes::INVALID_ARG;
} 

if(defined $scanTypeList && $keepDefaced) {
    print STDERR "Option -type cannot be used in conjunction with option -defaced. Aborting.\n";
       exit $NeuroDB::ExitCodes::INVALID_ARG;
} 

if($keepDefaced && $deleteMriParameterForm) {
    print STDERR "Option -defaced cannot be used in conjunction with option -form. Aborting.\n";
       exit $NeuroDB::ExitCodes::INVALID_ARG;
} 

if(!defined $uploadIDList) {
    print STDERR "Missing -uploadID option\n";
    exit $NeuroDB::ExitCodes::MISSING_ARG;
}

# Split the comma-separated string into a list of numbers
my @uploadID = split(',', $uploadIDList);

# Eliminate duplicate IDs
my %uploadID = map { $_ => 1 } @uploadID;
@uploadID = keys %uploadID;


#======================================#
# Validate all command line arguments  #
#======================================#
if(grep(!/\d+/, @uploadID)) {
    print STDERR "Argument to -uploadID option has to be a comma-separated list of numbers\n";
    exit $NeuroDB::ExitCodes::MISSING_ARG;
}

if (!$ENV{LORIS_CONFIG}) {
    print STDERR "\n\tERROR: Environment variable 'LORIS_CONFIG' not set\n\n";
    exit $NeuroDB::ExitCodes::INVALID_ENVIRONMENT_VAR; 
}

if (!-e "$ENV{LORIS_CONFIG}/.loris_mri/$profile") {
    print $Help; 
    print STDERR "Cannot read profile file '$ENV{LORIS_CONFIG}/.loris_mri/$profile'\n";  
    exit $NeuroDB::ExitCodes::PROFILE_FAILURE;
}

# Incorporate contents of profile file
{ package Settings; do "$ENV{LORIS_CONFIG}/.loris_mri/$profile" }

if ( !@Settings::db ) {
    print STDERR "ERROR: You don't have a \@db setting in file "
                 . "$ENV{LORIS_CONFIG}/.loris_mri/$profile";
    exit $NeuroDB::ExitCodes::DB_SETTINGS_FAILURE;
}

#====================================#
# Establish database connection.     #
#====================================#
my $dbh = &NeuroDB::DBI::connect_to_db(@Settings::db);

# Die as soon as a DB operation fails. As a side-effect, any transaction that has not
# been commited at that point will automatically be rolled back
$dbh->{'RaiseError'} = 1;

# Do not print an error message when a DB error occurs since the error message 
# will be printed when the program dies anyway 
$dbh->{'PrintError'} = 0;

my $dataDirBasepath    = NeuroDB::DBI::getConfigSetting(\$dbh,'dataDirBasepath');
$dataDirBasepath =~ s!/$!!;
my $tarchiveLibraryDir = NeuroDB::DBI::getConfigSetting(\$dbh,'tarchiveLibraryDir');
$tarchiveLibraryDir =~ s!/$!!;

my $query = "SELECT m.UploadID, m.TarchiveID, m.UploadLocation as FullPath, m.Inserting, m.InsertionComplete, m.SessionID, t.ArchiveLocation "
    .       "FROM mri_upload m "
    .       "LEFT JOIN tarchive t USING (TarchiveID) "
    .       "WHERE m.UploadID IN ("
    .       join(',', ('?') x @uploadID)
    .       ")";
my $uploadsRef = $dbh->selectall_hashref($query, 'UploadID', { 'Slice' => 1 }, @uploadID);

#======================================================#
# Check that all upload IDs passed on the command line #
# were found in the database                           #
#======================================================#
if(keys %$uploadsRef != @uploadID) {
    foreach(@uploadID) {
        if(!defined $uploadsRef->{$_}) {
            printf STDERR "No upload found in table mri_upload with upload ID $_\n";
            exit $NeuroDB::ExitCodes::INVALID_ARG;
        }
    }
}

#======================================================#
# Check that the pipeline is not processing any of the #
# uploads                                              #
#======================================================#
foreach(@uploadID) {
    if($uploadsRef->{$_}->{'Inserting'}) {
        printf STDERR "Cannot delete upload $_: the MRI pipeline is currently processing it.\n";
        exit $NeuroDB::ExitCodes::INVALID_ARG;
    }
}

# Get the tarchive IDs of all the uploads. Note that if an upload does not
# have a tarchiveID, its value will be undef: we remap it to the string 'NULL'
my %tarchiveID = map { ($uploadsRef->{$_}->{'TarchiveID'} // 'NULL') => 1 } keys %$uploadsRef;

if(keys %tarchiveID != 1) {
    print STDERR "The upload IDs passed on the command line have different TarchiveIDs: ";
    print STDERR join(',', keys %tarchiveID);
    print STDERR ". Aborting\n";
    exit $NeuroDB::ExitCodes::INVALID_ARG;
}
my $tarchiveID = (keys %tarchiveID)[0];

my $archiveLocation = $tarchiveID ne 'NULL' 
    ? (values %$uploadsRef)[0]->{'ArchiveLocation'} : 'NULL';
    
if(!defined $tarchiveLibraryDir && $archiveLocation ne 'NULL' && $archiveLocation !~ /^\//) {
    print STDERR "Cannot determine absolute path for archive '$archiveLocation' "
        . "since config setting 'tarchiveLibraryDir' is not set. Aborting.\n";
    exit $NeuroDB::ExitCodes::MISSING_CONFIG_SETTING;
}

#===================================================#
# Make sure there are no entries in files_qc_status #
# and feedback_mri_comments for the files in the    #
# archive                                           #
#===================================================#

if($tarchiveID ne 'NULL' && &hasQcOrComment($dbh, $tarchiveID)) {
    print STDERR "Cannot delete upload(s) passed on command line: there is QC information"
        . " defined on the MINC files for the associated tarchive (ID=$tarchiveID)\n";
    exit $NeuroDB::ExitCodes::INVALID_ARG;
}

#========================================================#
# Validate argument to -type (if this option is used)    #
#========================================================#
my %scanTypesToDelete = &getScanTypesToDelete($dbh, $scanTypeList, $keepDefaced);
die "Option -defaced was used but config setting 'modalities_to_deface' is empty. Aborting\n" if $keepDefaced && !%scanTypesToDelete;
my @invalidTypes = grep($scanTypesToDelete{$_} == 0, keys %scanTypesToDelete);
die "Invalid scan types argument: " . join(',', @invalidTypes) . "\n" if @invalidTypes;
my @scanTypesToDelete = keys %scanTypesToDelete;
die "Option -form cannot be used in conjunction with -type. Aborting\n" if $deleteMriParameterForm && @scanTypesToDelete;
    
#=================================================================#
# Find the absolute paths of all files associated to the          #
# upload(s) passed on the command lines in all the tables listed  #
# in @PROCESSED_TABLES                                            #
#=================================================================#
my %files;
$files{'files'}                       = &getFilesRef($dbh, $tarchiveID, $dataDirBasepath, \@scanTypesToDelete);
$files{'files_intermediary'}          = &getIntermediaryFilesRef($dbh, $tarchiveID, $dataDirBasepath, \@scanTypesToDelete);
$files{'parameter_file'}              = &getParameterFilesRef($dbh, $tarchiveID, $dataDirBasepath, \@scanTypesToDelete);
$files{'mri_protocol_violated_scans'} = &getMriProtocolViolatedScansFilesRef($dbh, $tarchiveID, $dataDirBasepath, \@scanTypesToDelete);
$files{'mri_violations_log'}          = &getMriViolationsLogFilesRef($dbh, $tarchiveID, $dataDirBasepath, \@scanTypesToDelete);
$files{'MRICandidateErrors'}          = &getMRICandidateErrorsFilesRef($dbh, $tarchiveID, $dataDirBasepath, \@scanTypesToDelete);
if($tarchiveID eq 'NULL') {
    $files{'tarchive'} = [];
} else {
    $files{'tarchive'}                    = [ 
        {
            'FullPath'        => $archiveLocation eq 'NULL' || $archiveLocation =~ /^\// 
                ? $archiveLocation : "$tarchiveLibraryDir/$archiveLocation",
            'ArchiveLocation' => $archiveLocation,
            'TarchiveID'      => $tarchiveID
        }
    ];
}
$files{'mri_upload'}                  = [ values %$uploadsRef ];
$files{'mri_processing_protocol'}     = &getMriProcessingProtocolFilesRef($dbh, \%files);

#=================================================================#
# If -defaced was used, validate that:                            #
#  a) All the MINCs that should have been defaced were defaced    #
#  b) All the MINCs that were defaced have one and only one       #
#     associated file: namely their defaced counterpart           #
#=================================================================#
if($keepDefaced) {
    my $invalidDefacedFilesRef = &getInvalidDefacedFiles($dbh, \%files) if $keepDefaced;
    if(%$invalidDefacedFilesRef) {
        while( my($fname, $invalidFilesRef) = each %$invalidDefacedFilesRef) {
            if(!@$invalidFilesRef) {
                printf STDERR "Error! No defaced file found for %s.\n", $fname;
            } else {
                my $f = @$invalidFilesRef == 1 ? 'file' : 'files';
                printf STDERR "Error! Invalid processed $f found for %s:\n", $fname;
                printf STDERR join("", map { "\t$_\n" } @$invalidFilesRef);
            }
        }
        print STDERR "\nAborting.\n"; 
        exit $NeuroDB::ExitCodes::INVALID_ARG;
    }
}

#========================================================================#
# Make sure that -protocol option is used if:                            #
# 1. There is at least one processing protocol associated to the files   #
#    to delete.                                                          #
# 2. This protocol is associated *only* to one or more of the files that #
#    are going to be deleted.                                            #
#========================================================================#
if(@{ $files{'mri_processing_protocol'} } && !$deleteProtocols) {
    my $msg = sprintf(
        "%s found for the %s to delete: you must use -protocol\n",
        (@{ $files{'mri_processing_protocol'} } > 1 ? 'Processing protocols' : 'Processing protocol'),
        (@uploadID > 1 ? 'uploads' : 'upload')
    );
    die "$msg\n";
}

#=============================================================================#
# Verify that all files found in the various tables exist on the file system  #
#=============================================================================#

my $missingFilesRef = &setFileExistenceStatus(\%files);
if(@$missingFilesRef) {
    my $msg;
    if(@$missingFilesRef == 1) {
        $msg = "File $missingFilesRef->[0] exists in the database but was not found on the file system.";
    } else {
        $msg= "The following files exist in the database but were not found on the file system:\n";
        foreach(@$missingFilesRef) {
            $msg .= "\t$_\n";
        }
    }
    
    die "Error! $msg\nAborting.\n" if $dieOnFileError;
    print STDERR "Warning! $msg\n";
}

&backupFiles(\%files, $tarchiveID, \@scanTypesToDelete, $keepDefaced) unless $noBackup;

#=======================================================#
# Delete everything associated to the upload(s) in the  #
# database                                              #
#=======================================================#
&deleteUploadsInDatabase($dbh, $uploadsRef, \%files, $deleteMriParameterForm, \@scanTypesToDelete, $noSQL, $keepDefaced);

#=======================================================#
# Delete everything associated to the upload(s) in the  #
# file system                                           #
#=======================================================#
&deleteUploadsOnFileSystem(\%files, \@scanTypesToDelete, $keepDefaced);

#==========================#
# Print success message    #
#==========================#
&printExitMessage(\@uploadID, \%files, \@scanTypesToDelete, $tarchiveID, $noSQL);

exit $NeuroDB::ExitCodes::SUCCESS;

#--------------------------------------------------------------------------------------------------------------------------#
#                                                                                                                          #
#                                                        SUBROUTINES                                                       #
#                                                                                                                          #
#--------------------------------------------------------------------------------------------------------------------------#

=pod

=head3 printExitMessage($uploadIDRef, $filesRef, $scanTypesToDeleteRef, $tarchiveID, $noSQL) 

Prints an appropriate message before exiting. 

INPUTS:
  - $dbh: database handle reference.
  - $filesRef: reference to the array that contains the file informations for all the files
    that are associated to the upload(s) passed on the command line.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.
  - $tarchiveID: ID of the tarchive associated to the upload(s) (will be 'NULL' if none).
  - $noSQL: whether an SQL backup file of the deleted records is needed or not.

=cut
sub printExitMessage {
    my($uploadIDRef, $filesRef, $scanTypesToDeleteRef, $tarchiveID, $noSQL) = @_;

    # If there are specific types of scan to delete, then we know that there
    # can be only one upload in @$uploadIDRef
    if(@$scanTypesToDeleteRef) {
        if(!@{ $filesRef->{'files'} }) {
            printf(
                "No scans of type %s found for upload %s.\n", 
                &prettyListPrint($scanTypesToDeleteRef, 'or'),
                $uploadIDRef->[0]
            );
        } else {
            printf(
                "Scans of type %s successfully deleted for upload %s.\n",
                &prettyListPrint($scanTypesToDeleteRef, 'and'),
                $uploadIDRef->[0]
            );
        }
    } else {
        printf(
            "Successfully deleted %s %s.\n",
            @$uploadIDRef == 1 ? 'upload' : 'uploads',
            &prettyListPrint($uploadIDRef, 'and')
        );
    }
    
    if(!$noSQL) {
        my $finalSQLFile = &getSQLBackupFileName($tarchiveID);
        if(-e $finalSQLFile) {
            print "Wrote $finalSQLFile.\n";
        } else {
            print "No deletions performed in the database: no SQL backup file created.\n";
        }
    }
}

=pod

=head3 prettyListPrint($listRef, $andOr) 

Pretty prints a list in string form (e.g "1, 2, 3 and 4" or "7, 8 or 9").

INPUTS:
  - $listRef: the list of elements to print, separated by commas.
  - $andOr: whether to join the last element with the rest of the elements using an 'and' or an 'or'.

=cut
sub prettyListPrint {
    my($listRef, $andOr) = @_;
    
    return $listRef->[0] if @$listRef == 1;
     
    return join(', ', @$listRef[0..$#{ $listRef }-1]) . " $andOr " . $listRef->[$#{ $listRef } ];
}

=pod

=head3 getMriProcessingProtocolFilesRef($dbh, $filesRef)

Finds the list of C<ProcessingProtocolID> to delete, namely those in table
C<mri_processing_protocol> associated to the files to delete, and *only* to 
those files that are going to be deleted.

INPUTS:
  - $dbh: database handle reference.
  - $filesRef: reference to the array that contains the file informations for all the files
    that are associated to the upload(s) passed on the command line.

RETURNS:
 - reference on an array that contains the C<ProcessProtocolID> in table C<mri_processing_protocol>
   associated to the files to delete. This array has two keys: C<ProcessProtocolID> => the protocol 
   process ID found table C<mri_processing_protocol> and C<FullPath> => the value of C<ProtocolFile>
   in the same table.

=cut

sub getMriProcessingProtocolFilesRef {
    my($dbh, $filesRef) = @_;
    
    my %fileID;
    foreach my $t (@PROCESSED_TABLES) {
        foreach my $f (@{ $filesRef->{$t} }) {
            $fileID{ $f->{'FileID'} } = 1 if defined $f->{'FileID'};
        }
    }
    
    return [] if !%fileID;
    
    my $query = 'SELECT DISTINCT(mpp.ProcessProtocolID), mpp.ProtocolFile AS FullPath '
              . 'FROM files f '
              . 'JOIN mri_processing_protocol mpp USING (ProcessProtocolID) '
              . 'WHERE f.FileID IN ('
              . join(',', ('?') x keys %fileID)
              . ') AND f.ProcessProtocolID IS NOT NULL';
    
    # This variable will contain all the protocols associated to the files that will be
    # deleted. Note that these protocols might also be associated to files that are *not* 
    # going to be deleted
    my $protocolsRef = $dbh->selectall_arrayref($query, { 'Slice' => {} }, keys %fileID);
    
    return [] unless @$protocolsRef;
    
    # Now get the list of protocols in @$protocolsRef that are also associated to files
    # that are not going to de deleted
    $query = 'SELECT ProcessProtocolID '
           . 'FROM files '
           . 'WHERE ProcessProtocolID IN ('
           . join(',', ('?') x @$protocolsRef)
           . ') '
           . 'AND FileID NOT IN ('
           . join(',', ('?') x keys %fileID)
           . ')';
    
    my $protocolsNotDeletedRef = $dbh->selectcol_arrayref(
        $query, 
        { 'Columns' => [1] },
        (map { $_->{'ProcessProtocolID'} } @$protocolsRef), 
        keys %fileID
    );
    
    # Eliminate from @$protocolsRef the entries of that are also in @$protocolsNotDeletedRef
    for(my $i=$#{ $protocolsRef }; $i >= 0; $i--) { 
        if(grep($_ == $protocolsRef->[$i]->{'ProcessProtocolID'}, @$protocolsNotDeletedRef)) {
            splice(@$protocolsRef, $i, 1);
        }
    }
    
    return $protocolsRef;
}

=pod

=head3 hasQcOrComment($dbh, $tarchiveID)

Determines if any of the MINC files associated to the C<tarchive> have QC 
information associated to them by looking at the contents of tables 
C<files_qcstatus> and C<feedback_mri_comments>.

INPUTS:
  - $dbh: database handle reference.
  - $tarchiveID: ID of the DICOM archive (can be 'NULL').

RETURNS:
  - 1 if there is QC information associated to the DICOM archive, 0 otherwise.

=cut
sub hasQcOrComment {
    my($dbh, $tarchiveID) = @_;
    
    return 0 if $tarchiveID eq 'NULL'; 
    
    #=========================================#
    # Fetch contents of tables files_qcstatus #
    # and feedback_mri_comments               #
    #=========================================#
    (my $query =<<QUERY) =~ s/\s+/ /g;
         SELECT fqs.FileID
         FROM files_qcstatus fqs 
         JOIN files f USING (FileID)
         WHERE f.TarchiveSource = ?
         
         UNION
          
         SELECT fmc.FileID
         FROM feedback_mri_comments fmc 
         JOIN files f USING (FileID)
         WHERE f.TarchiveSource = ?
         LIMIT 1
QUERY

    my $rowsRef = $dbh->selectall_arrayref($query, undef, $tarchiveID, $tarchiveID);

    return @$rowsRef > 0;
}

=pod

=head3 getFilesRef($dbh, $tarchiveID, $dataDirBasePath)

Get the absolute paths of all the files associated to a DICOM archive and are listed in 
table C<files>.

INPUTS:
  - $dbhr  : database handle reference.
  - $tarchiveID: ID of the DICOM archive.
  - $dataDirBasePath: config value of setting C<dataDirBasePath>.
  - $scanTypesToDeleteRef: reference to the array that contains the list of names of scan types to delete.

RETURNS: 
 - an array of hash references. Each hash has three keys: C<FileID> => ID of a file in table C<files>
   C<File> => value of column C<File> for the file with the given ID and C<FullPath> => absolute path
   for the file with the given ID.

=cut
sub getFilesRef {
    my($dbh, $tarchiveID, $dataDirBasePath, $scanTypesToDeleteRef) = @_;
    
    return [] if $tarchiveID eq 'NULL';
    
    # Get FileID and File path of each files in files directly tied
    # to $tarchiveId
    my $mriScanTypeJoin = @$scanTypesToDeleteRef 
        ? 'JOIN mri_scan_type mst ON (f.AcquisitionProtocolID = mst.ID) ' 
        : '';
    my $mriScanTypeAnd = @$scanTypesToDeleteRef 
        ? sprintf(' AND mst.Scan_type IN (%s) ', join(',', ('?') x  @$scanTypesToDeleteRef)) 
        : '';
    my $query = 'SELECT f.FileID, f.File FROM files f '   
              . $mriScanTypeJoin
              . 'WHERE f.TarchiveSource = ? '
              . $mriScanTypeAnd;
    
    my $filesRef = $dbh->selectall_arrayref($query, { Slice => {} }, $tarchiveID, @$scanTypesToDeleteRef);
    
    # Set full path of every file
    foreach(@$filesRef) {
        $_->{'FullPath'} = $_->{'File'} =~ /^\// 
            ? $_->{'File'} : "$dataDirBasePath/$_->{'File'}";
    } 
    
    return $filesRef;   
}

=pod

=head3 getIntermediaryFilesRef($dbh, $tarchiveID, $dataDirBasePath, $scanTypesToDeleteRef)

Get the absolute paths of all the intermediary files associated to an archive 
that are listed in table C<files_intermediary>.

INPUTS:
  - $dbhr  : database handle reference.
  - $tarchiveID: ID of the DICOM archive.
  - $dataDirBasePath: config value of setting C<dataDirBasePath>.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.

RETURNS: 
  - an array of hash references. Each hash has seven keys: C<IntermedID> => ID of a file in 
    table C<files_intermediary>, C<Input_FileID> => ID of the file that was used as input to create 
    the intermediary file, C<Output_FileID> ID of the output file, C<FileID> => ID of this file in 
    table C<files>, C<File> => value of column C<File> in table C<files> for the file with the given 
    ID, C<SourceFileID> value of column C<SourceFileID> for the intermediary file and 
    C<FullPath> => absolute path of the file with the given ID.

=cut
sub getIntermediaryFilesRef {
    my($dbh, $tarchiveID, $dataDirBasePath, $scanTypesToDeleteRef) = @_;
    
    return [] if $tarchiveID eq 'NULL';

    # This should get all files in table files_intermediary that are tied
    # indirectly to the tarchive with ID $tarchiveId
    # Note that there can be multiple entries in files_intermediary that have
    # the same Output_FileID: consequently, this select statement can return 
    # entries with identical FileID and File values (but different IntermedID)
    my $mriScanTypeJoin = @$scanTypesToDeleteRef
        ? 'JOIN mri_scan_type mst ON (f2.AcquisitionProtocolID=mst.ID) '
        : '';
    my $mriScanTypeAnd = @$scanTypesToDeleteRef
        ? sprintf(' AND mst.Scan_type IN (%s) ', join(',', ('?') x @$scanTypesToDeleteRef))
        : '';
    my $query = 'SELECT fi.IntermedID, fi.Input_FileID, fi.Output_FileID, f.FileID, f.File, f.SourceFileID '
              . 'FROM files_intermediary fi '
              . 'JOIN files f ON (fi.Output_FileID=f.FileID) '
              . 'WHERE f.SourceFileID IN ('
              . '    SELECT f2.FileID '
              . '    FROM files f2 '
              .      $mriScanTypeJoin
              . '    WHERE f2.TarchiveSource = ? '
              .      $mriScanTypeAnd
              . ')';

    my $filesRef = $dbh->selectall_arrayref(
        $query, { Slice => {} }, $tarchiveID, @$scanTypesToDeleteRef
    );

    # Set full path of every file
    foreach(@$filesRef) {
        $_->{'FullPath'} = $_->{'File'} =~ /^\// 
            ? $_->{'File'} : "$dataDirBasePath/$_->{'File'}";
    } 
    
    return $filesRef;   
}

=pod

=head3 getParameterFilesRef($dbh, $tarchiveID, $dataDirBasePath, $scanTypesToDeleteRef)

Gets the absolute paths of all the files associated to an archive that are listed in table
C<parameter_file> and have a parameter type set to C<check_pic_filename>, C<check_nii_filename>
C<check_bval_filename> or C<check_bvec_filename>.

INPUTS:
  - $dbhr  : database handle reference.
  - $tarchiveID: ID of the DICOM archive.
  - $dataDirBasePath: config value of setting C<dataDirBasePath>.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.

RETURNS: 
  - an array of hash references. Each hash has four keys: C<FileID> => FileID of a file 
    in table C<parameter_file>, C<Value> => value of column C<Value> in table C<parameter_file>
    for the file with the given ID, C<Name> => name of the parameter and C<FullPath> => absolute
    path of the file with the given ID.

=cut
sub getParameterFilesRef {
    my($dbh, $tarchiveID, $dataDirBasePath, $scanTypesToDeleteRef) = @_;
    
    return [] if $tarchiveID eq 'NULL';

    my $mriScanTypeJoin = @$scanTypesToDeleteRef
        ? 'JOIN mri_scan_type mst ON (mst.ID=f.AcquisitionProtocolID) ' : '';
    my $mriScanTypeAnd = @$scanTypesToDeleteRef
        ? sprintf('AND mst.Scan_type IN (%s) ', join(',', ('?') x @$scanTypesToDeleteRef)) : '';
    $query = 'SELECT FileID, Value, pt.Name FROM parameter_file pf '
           . 'JOIN files f USING (FileID) '
           . 'JOIN parameter_type AS pt USING (ParameterTypeID) '
           . $mriScanTypeJoin
           . "WHERE pt.Name IN ('check_pic_filename', 'check_nii_filename', 'check_bval_filename', 'check_bvec_filename') "
           . 'AND ( '
           . '         f.TarchiveSource = ? '
           . '      OR f.SourceFileID IN (SELECT FileID FROM files WHERE TarchiveSource = ?) '
           . ') '
           . $mriScanTypeAnd;

    my $filesRef = $dbh->selectall_arrayref(
        $query, { Slice => {} }, $tarchiveID, $tarchiveID, @$scanTypesToDeleteRef
    );
    
    # Set full path of every file
    foreach(@$filesRef) {
        my $fileBasePath = $_->{'Name'} eq 'check_pic_filename'
            ? "$dataDirBasePath/" . PIC_SUBDIR : $dataDirBasePath;
        $_->{'FullPath'} = $_->{'Value'} =~ /^\//
            ? $_->{'Value'} : sprintf("%s/%s", $fileBasePath, $_->{'Value'});
    }
    
    return $filesRef;
}

=pod

=head3 getMriProtocolViolatedScansFilesRef($dbh, $tarchiveID, $dataDirBasePath, $scanTypesToDeleteRef)

Get the absolute paths of all the files associated to a DICOM archive that are listed in 
table C<mri_protocol_violated_scans>.

INPUTS:
  - $dbhr  : database handle reference.
  - $tarchiveID: ID of the DICOM archive.
  - $dataDirBasePath: config value of setting C<dataDirBasePath>.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.

RETURNS: 
 - an array of hash references. Each hash has three keys: C<ID> => ID of the record in table
   C<mri_protocol_violated_scans>, C<minc_location> => value of column C<minc_location> in table 
   C<mri_protocol_violated_scans> for the MINC file found and C<FullPath> => absolute path of the MINC
   file found.

=cut
sub getMriProtocolViolatedScansFilesRef {
    my($dbh, $tarchiveID, $dataDirBasePath, $scanTypesToDeleteRef) = @_;
    
    # Return a reference to the enmpty array if:
    # 1. The upload(s) do not have a tarchiveID, which means that no MINC file
    #    were produced and consequently there cannot be any protocol violations
    # OR
    # 2. The -type option was used: only specific MINC files related to an archive
    #    should be deleted and so we do not want to erase any protocol
    #    violations since they are associated to an archive (not to specific files)
    return [] if $tarchiveID eq 'NULL' || @$scanTypesToDeleteRef;

    # Get FileID and File path of each files in files directly tied
    # to $tarchiveId
    $query = 'SELECT ID, minc_location FROM mri_protocol_violated_scans WHERE TarchiveID = ?';
    my $filesRef = $dbh->selectall_arrayref($query, { Slice => {} }, $tarchiveID);

    # Set full path of every file
    foreach(@$filesRef) {
        $_->{'FullPath'} = $_->{'minc_location'} =~ /^\// 
            ? $_->{'minc_location'} : "$dataDirBasePath/$_->{'minc_location'}";
    } 
    
    return $filesRef;   
}

=pod

=head3 getMriViolationsLogFilesRef($dbh, $tarchiveID, $dataDirBasePath, $scanTypesToDeleteRef)

Get the absolute paths of all the files associated to an archive that are listed in 
table C<mri_violations_log>.

INPUTS:
  - $dbhr  : database handle reference.
  - $tarchiveID: ID of the DICOM archive.
  - $dataDirBasePath: config value of setting C<dataDirBasePath>.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.

RETURNS: 
 an array of hash references. Each hash has three keys: C<LogID> => ID of the record in table 
 C<mri_violations_log>, C<MincFile> => value of column C<MincFile> for the MINC file found in table
 C<mri_violations_log> and C<FullPath> => absolute path of the MINC file.

=cut
sub getMriViolationsLogFilesRef {
    my($dbh, $tarchiveID, $dataDirBasePath, $scanTypesToDeleteRef) = @_;
    
    return [] if $tarchiveID eq 'NULL';

    my $query;
    if(@$scanTypesToDeleteRef) {
        $query = 'SELECT LogID, mvl.MincFile '
               . 'FROM mri_violations_log mvl '
               . 'JOIN files f ON (f.File COLLATE utf8_bin = mvl.MincFile) '
               . 'JOIN mri_scan_type mst ON (f.AcquisitionProtocolID = mst.ID) '
               . 'WHERE TarchiveID = ? '
               . 'AND mst.Scan_type IN('
               . join(',', ('?') x @$scanTypesToDeleteRef)
               . ')';
    } else {
        $query = 'SELECT LogID, MincFile FROM mri_violations_log WHERE TarchiveID = ?';
    }
    my $filesRef = $dbh->selectall_arrayref($query, { Slice => {} }, $tarchiveID, @$scanTypesToDeleteRef);

    # Set full path of every file
    foreach(@$filesRef) {
        $_->{'FullPath'} = $_->{'MincFile'} =~ /^\// 
            ? $_->{'MincFile'} : "$dataDirBasePath/$_->{'MincFile'}";
    } 

    return $filesRef;   
}

=pod

=head3 getMRICandidateErrorsFilesRef($dbh, $tarchiveID, $dataDirBasePath, $scanTypeToDeleteRef)

Get the absolute paths of all the files associated to a DICOM archive that are listed in 
table C<MRICandidateErrors>.

INPUTS:
  - $dbh   : database handle reference.
  - $tarchiveID: ID of the DICOM archive.
  - $dataDirBasePath: config value of setting C<dataDirBasePath>.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.

RETURNS: 
 - an array of hash references. Each hash has three keys: C<ID> => ID of the record in the 
   table, C<MincFile> => value of column C<MincFile> for the MINC file found in table 
   C<MRICandidateErrors> and C<FullPath> => absolute path of the MINC file.

=cut
sub getMRICandidateErrorsFilesRef {
    my($dbh, $tarchiveID, $dataDirBasePath, $scanTypeToDeleteRef) = @_;
    
    return [] if $tarchiveID eq 'NULL' || @$scanTypeToDeleteRef;

    # Get file path of each files in files directly tied
    # to $tarchiveId
    $query = 'SELECT ID, MincFile FROM MRICandidateErrors WHERE TarchiveID = ?';
    my $filesRef = $dbh->selectall_arrayref($query, { Slice => {} }, $tarchiveID);

    # Set full path of every file
    foreach(@$filesRef) {
        $_->{'FullPath'} = $_->{'MincFile'} =~ /^\// 
            ? $_->{'MincFile'} : "$dataDirBasePath/$_->{'MincFile'}";
    } 
    
    return $filesRef;   
}

=pod

=head3 getBackupFileName($tarchiveID)

Gets the name of the backup compressed file that will contain a copy of all the files
that the script will delete.

INPUTS:
  - $tarchiveID: ID of the DICOM archive (in table C<tarchive>) associated to the upload(s) passed on the command line.

getbackup
RETURNS: 
  - backup file name.

=cut
sub getBackupFileName {
    my($tarchiveID) = @_;
    
    return $tarchiveID eq 'NULL' ? "imaging_upload.tar.gz" : "imaging_upload.$tarchiveID.tar.gz";
}

=pod

=head3 getSQLBackupFileName($tarchiveID)

Gets the name of the backup compressed file that will contain the SQL statements that can be used
to restore the database to the state it had before the script was invoked.

INPUTS:
  - $tarchiveID: ID of the DICOM archive (in table C<tarchive>) associated to the upload(s) passed on the command line.

getbackup
RETURNS: 
  - backup file name.

=cut
sub getSQLBackupFileName {
    my($tarchiveID) = @_;
    
    return $tarchiveID eq 'NULL' ? "imaging_upload.sql.gz" : "imaging_upload.$tarchiveID.sql.gz";
}

=pod

=head3 setFileExistenceStatus($filesRef)

Checks the list of all the files related to the upload(s) that were found in the database and 
builds the list of those that do not exist on the file system. 

INPUTS:
  - $filesRef: reference to the array that contains the file informations for all the files
  that are associated to the upload(s) passed on the command line.
  
  
RETURNS:
  - Reference on the list of files that do not exist on the file system.
                 
=cut
sub setFileExistenceStatus {
    my($filesRef) = @_;
    
    my %missingFiles;
    foreach my $t (@PROCESSED_TABLES) {
        foreach my $f (@{ $filesRef->{$t} }) {
            $f->{'Exists'} = -e $f->{'FullPath'};
            
            # A file is only considered "missing" if it is expected to be on the file
            # system but is not. There are some file paths refered to in the database that
            # are expected to refer to files that have been moved or deleted and consequently
            # they are not expected to be on the file system at the specified location (e.g. 
            # ArchiveLocation for an upload on which the MRI pipeline was successfully run).
            $missingFiles{ $f->{'FullPath'} } = 1 if !$f->{'Exists'} && &shouldExist($t, $f);
        }
    }
    
    return [ keys %missingFiles ];
}

=pod

=head3 shouldExist($table, $fileRef)

Checks whether a file path in the database refers to a file that should exist on the file system.

INPUTS:
  - $table: name of the table in which the file path was found.
  - $fileRef: reference to the array that contains the file information for a given file.
  
RETURNS:
  - 0 or 1 depending on whether the file should exist or not.
                 
=cut
sub shouldExist {
    my($table, $fileRef) = @_;
    
    return 0 if $table eq 'mri_upload' && defined $fileRef->{'InsertionComplete'} && $fileRef->{'InsertionComplete'} == 1;
    
    
    return 1;
}

=head3 backupFiles($filesRef, $tarchiveID, $scanTypesToDeleteRef, $keepProcessed)

Backs up all the files associated to the archive before deleting them. The backed up files will
be stored in a C<.tar.gz> archive in which all paths are absolute.

INPUTS:
  - $filesRef: reference to the array that contains the file informations for all the files
    that are associated to the upload(s) passed on the command line.
  - $tarchiveID: ID of the archive associated to the upload(s) passed on the command line.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.
  - $keepDefaced: whether the defaced files should be kept or not.

=cut
    
sub backupFiles {
    my($filesRef, $tarchiveID, $scanTypesToDeleteRef, $keepDefaced) = @_;
    
    my $hasSomethingToBackup = 0;
    foreach my $t (@PROCESSED_TABLES) {
        foreach my $f (@{ $filesRef->{$t} }) {
            last if $hasSomethingToBackup;
            
            # If the file is not going to be deleted, do not back it up
            next unless &shouldDeleteFile($t, $f, $scanTypesToDeleteRef, $keepDefaced);
            $hasSomethingToBackup = 1 if $f->{'Exists'}
        }
    }
    
    if(!$hasSomethingToBackup) {
        print "No files to backup.\n";
        return;
    }
    
    # Create a temporary file that will list the absolute paths of all
    # files to backup (archive). 
    my($fh, $tmpFileName) = tempfile("$0.filelistXXXX", UNLINK => 1);
    foreach my $t (@PROCESSED_TABLES) {
        foreach my $f (@{ $filesRef->{$t} }) {
            next unless &shouldDeleteFile($t, $f, $scanTypesToDeleteRef, $keepDefaced);
            print $fh "$f->{'FullPath'}\n" unless !$f->{'Exists'};
        }
    }
    close($fh);
    
    # Put all files in a big compressed tar ball
    my $filesBackupPath = &getBackupFileName($tarchiveID);
    print "\nBacking up files related to the upload(s) to delete...\n";
    if(system('tar', 'zcvf', $filesBackupPath, '--absolute-names', '--files-from', $tmpFileName)) {
        print STDERR "backup command failed: $!\n";
        exit $NeuroDB::ExitCodes::PROGRAM_EXECUTION_FAILURE;
    } 

    print "File $filesBackupPath successfully created.\n";
}

=pod

=head3 shouldDeleteFile($table, $fileRef, $scanTypesToDeleteRef, $keepDefaced)

Checks whether a given file should be deleted or not.

INPUTS:
  - $table: name of the table in which the file path was found.
  - $fileRef: reference to the array that contains the file information for a given file.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.
  - $keepDefaced: whether the defaced files should be kept or not.
  
RETURNS:
  - 0 or 1 depending on whether the file should be deleted or not.
                 
=cut

sub shouldDeleteFile {
    my($table, $fileRef, $scanTypesToDeleteRef, $keepDefaced) = @_;
    
    # If specific scan types are deleted or if the defaced files are kept 
    # (i.e @$scanTypesToDeleteRef is filled with the modalities_to_deface Config
    # values), then we don't delete and don't backup the tarchive file.
    return 0 if $table eq 'tarchive' && @$scanTypesToDeleteRef;
    
    # If the defaced files are kept, the entries in files_intermediary are deleted
    # and backed up but the corresponding entries in table files are not.  
    return 0 if $table eq 'files_intermediary' && $keepDefaced;
    
    # If the MRI pipeline was successfully run on the upload, the file has moved
    # so do not attempt to delete it
    return 0 if $table eq 'mri_upload' && $fileRef->{'InsertionComplete'} == 1;
    
    return 1;
}

=pod

=head3 deleteUploadsInDatabase$dbh, $uploadsRef, $filesRef, $deleteMriParameterForm, $scanTypesToDeleteRef, $noSQL, $keepDefaced)

This method deletes all information in the database associated to the given upload(s)/scan type combination. 
More specifically, it deletes records from tables C<notification_spool>, C<tarchive_files>, C<tarchive_series>
C<files_intermediary>, C<parameter_file>, C<files>, C<mri_protocol_violated_scans>, C<mri_violations_log>
C<MRICandidateErrors>, C<mri_upload>, C<tarchive>, C<mri_processing_protocol> and C<mri_parameter_form> 
(the later is done only if requested). It will also set the C<Scan_done> value of the scan's session to 'N' for
each upload that is the last upload tied to that session. All the delete/update operations are done inside a single 
transaction so either they all succeed or they all fail (and a rollback is performed).

INPUTS:
  - $dbh       : database handle.
  - $uploadsRef: reference on a hash of hashes containing the uploads to delete. Accessed like this:
                 C<< $uploadsRef->{'1002'}->{'TarchiveID'} >>(this would return the C<TarchiveID> of the C<mri_upload>
                 with ID 1002). The properties stored for each hash are: C<UploadID>, C<TarchiveID>, C<ArchiveLocation>
                 and C<SessionID>.
  - $filesRef: reference to the array that contains the file informations for all the files
    that are associated to the upload(s) passed on the command line.
  - $deleteMriParameterForm: whether to delete the C<mri_parameter_form> entries associated to the upload(s) passed on the command line.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.
  - $noSQL: whether to generate a file that contains SQL statements that can regenerate the deleted records or not.
  - $keepDefaced: whether the defaced files should be kept or not.

                 
=cut
sub deleteUploadsInDatabase {
    my($dbh, $uploadsRef, $filesRef, $deleteMriParameterForm, $scanTypesToDeleteRef, $noSQL, $keepDefaced)= @_;
    
    # This starts a DB transaction. All operations are delayed until
    # commit is called
    $dbh->begin_work;
    
    my(undef, $tmpSQLFile) = $noSQL
        ? (undef, undef) : tempfile('sql_backup_XXXX', UNLINK => 1);
        
    &deleteTableData($dbh, 'notification_spool', 'ProcessID', [ keys %$uploadsRef ], $tmpSQLFile) if !@$scanTypesToDeleteRef;
    
    my $IDsRef = &getTarchiveSeriesIDs($dbh, $filesRef);  
    &deleteTableData($dbh, 'tarchive_files', 'TarchiveSeriesID', $IDsRef, $tmpSQLFile);
    
    &deleteTableData($dbh, 'tarchive_series', 'TarchiveSeriesID', $IDsRef, $tmpSQLFile); 
    
    my @IDs  = map { $_->{'FileID'} } @{ $filesRef->{'parameter_file'} };
    push(@IDs, map { $_->{'FileID'} } @{ $filesRef->{'files_intermediary'} }) if !$keepDefaced;
    push(@IDs, map { $_->{'FileID'} } @{ $filesRef->{'files'} });
    &deleteTableData($dbh, 'parameter_file', 'FileID', \@IDs, $tmpSQLFile);
    
    @IDs = map { $_->{'IntermedID'} } @{ $filesRef->{'files_intermediary'} };
    &deleteTableData($dbh, 'files_intermediary', 'IntermedID', \@IDs, $tmpSQLFile); 
    
    # Since all files in files_intermediary are linked to other files in table files, we
    # have to delete these files first from table files.
    if(!$keepDefaced) {
        @IDs = map { $_->{'FileID'} } @{ $filesRef->{'files_intermediary'} };
        &deleteTableData($dbh, 'files', 'FileID', \@IDs, $tmpSQLFile);
    } else { 
        &updateFilesIntermediaryTable($dbh, $tarchiveID, $filesRef, $tmpSQLFile);
    }
   
    @IDs = map { $_->{'FileID'} } @{ $filesRef->{'files'} };
    &deleteTableData($dbh, 'files', 'FileID', \@IDs, $tmpSQLFile);
    
    @IDs = map { $_->{'ProcessProtocolID'} } @{ $filesRef->{'mri_processing_protocol'} };
    &deleteTableData($dbh, 'mri_processing_protocol', 'ProcessProtocolID', \@IDs, $tmpSQLFile);
    
    @IDs = map { $_->{'ID'} } @{ $filesRef->{'mri_protocol_violated_scans'} };
    &deleteTableData($dbh, 'mri_protocol_violated_scans', 'ID', \@IDs, $tmpSQLFile);
    
    @IDs = map { $_->{'LogID'} } @{ $filesRef->{'mri_violations_log'} };
    &deleteTableData($dbh, 'mri_violations_log', 'LogID', \@IDs, $tmpSQLFile);
    
    @IDs = map { $_->{'ID'} } @{ $filesRef->{'MRICandidateErrors'} };
    &deleteTableData($dbh, 'MRICandidateErrors', 'ID', \@IDs, $tmpSQLFile);
    
    &deleteMriParameterForm($dbh, $uploadsRef, $tmpSQLFile) if $deleteMriParameterForm;

    # Should check instead if the tarchive is not tied to anything
    # (i.e no associated entries in files, mri_violations_log, etc...)
    # and delete it if so. This way, if you specify a list of scan types to
    # delete and if after the deletion nothing remains in the archive, the archive
    # will be deleted
    my $tarchiveID = @{ $filesRef->{'tarchive'} } 
        ? $filesRef->{'tarchive'}->[0]->{'TarchiveID'} : 'NULL';
    if(!@$scanTypesToDeleteRef) {
        &deleteTableData($dbh, 'mri_upload', 'UploadID', [keys %$uploadsRef], $tmpSQLFile);
   
        &deleteTableData($dbh, 'tarchive', 'TarchiveID', [$tarchiveID], $tmpSQLFile) if $tarchiveID ne 'NULL';
    }
    
    &updateSessionTable($dbh, $uploadsRef, $tmpSQLFile) unless @$scanTypesToDeleteRef;
        
    
    $dbh->commit;
    
    # Compress the SQL
    &gzipTmpSQLFile($tarchiveID, $tmpSQLFile) if defined $tmpSQLFile && -s $tmpSQLFile;
}

=pod

=head3 gzipTmpSQLFile($tarchiveID, $tmpSQLFile)

Compresses the file that contains the SQL statements used to restore the deleted records using C<gzip>.

INPUTS:
  - $tarchiveID: ID of the DICOM archive associated to the upload(s) passed on the command line.
  - $tmpSQLFile: path of the SQL file that contains the SQL statements used to restore the deleted records.
  
RETURNS:
  - 0 or 1 depending on whether the file should be deleted or not.
                 
=cut
sub gzipTmpSQLFile {
    my($tarchiveID, $tmpSQLFile) = @_;
    
    # Gzip the SQL file
    my $cmd = sprintf(
        "gzip -c %s > %s", 
        quotemeta($tmpSQLFile), 
        quotemeta(&getSQLBackupFileName($tarchiveID))
    );
    system($cmd) == 0
        or die "Failed running command $cmd. Aborting\n";
}    

=pod

=head3 updateSessionTable($dbh, $uploadsRef, $tmpSQLFile)

Sets to C<N> the C<Scan_done> column of all C<sessions> in the database that do not have an associated upload
after the script has deleted those whose IDs are passed on the command line. The script also adds an SQL statement
in the SQL file whose path is passed as argument to restore the state that the C<session> table had before the deletions.

INPUTS:
   - $dbh       : database handle.
   - $uploadsRef: reference on a hash of hashes containing the uploads to delete. Accessed like this:
                 C<< $uploadsRef->{'1002'}->{'TarchiveID'} >>(this would return the C<TarchiveID> of the C<mri_upload>
                 with ID 1002). The properties stored for each hash are: C<UploadID>, C<TarchiveID>, C<ArchiveLocation>
                 and C<SessionID>.
   - $tmpSQLFile: path of the SQL file that contains the SQL statements used to restore the deleted records.
  
=cut
sub updateSessionTable {
    my($dbh, $uploadsRef, $tmpSQLFile) = @_;
    
    # If any of the uploads to delete is the last upload that was part of the 
    # session associated to it, then set the session's 'Scan_done' flag
    # to 'N'.
    my @sessionIDs = map { $uploadsRef->{$_}->{'SessionID'} } keys %$uploadsRef;
    @sessionIDs = grep(defined $_, @sessionIDs);
    
    return if !@sessionIDs;
    
    my $query = "UPDATE session s SET Scan_done = 'N'"
              . " WHERE s.ID IN ("
              . join(',', ('?') x @sessionIDs)
              . ") AND (SELECT COUNT(*) FROM mri_upload m WHERE m.SessionID=s.ID) = 0";
    $dbh->do($query, undef, @sessionIDs );

    if($tmpSQLFile) {
        # Write an SQL statement to restore the 'Scan_done' column of the deleted uploads
        # to their appropriate values. This statement needs to be after the statement that
        # restores table mri_upload (at the end of the file is good enough). 
        open(SQL, ">>$tmpSQLFile") or die "Cannot append text to file $tmpSQLFile: $!. Aborting.\n";
        print SQL "\n\n";
        print SQL "UPDATE session s SET Scan_done = 'Y'"
                . " WHERE s.ID IN ("
                . join(',', @sessionIDs)
                . ") AND (SELECT COUNT(*) FROM mri_upload m WHERE m.SessionID=s.ID) > 0;\n";
        close(SQL);
    }
}

=pod

=head3 updateFilesIntermediaryTable($dbh, $tarchiveID, $filesRef, $tmpSQLFile)

Sets the C<TarchiveSource> and C<SourceFileID> columns of all the defaced files to C<$tarchiveID> and C<NULL>
respectively. The script also adds an SQL statement in the SQL file whose path is passed as argument to 
restore the state that the defaced files in the C<files> table had before the deletions.

INPUTS:
   - $dbh       : database handle.
   - $tarchiveID: ID of the DICOM archive associated to the upload(s) passed on the command line.
   - $filesRef: reference to the array that contains the file informations for all the files
     that are associated to the upload(s) passed on the command line.
   - $tmpSQLFile: path of the SQL file that contains the SQL statements used to restore the deleted records.
  
=cut
sub updateFilesIntermediaryTable {
    my($dbh, $tarchiveID, $filesRef, $tmpSQLFile) = @_;
    
    my %defacedFiles = map { $_->{'FileID'} => $_->{'SourceFileID'} } @{ $filesRef->{'files_intermediary'} };
    if(%defacedFiles) {
        my $query = "UPDATE files SET TarchiveSource = ?, SourceFileID = NULL "
                  . " WHERE FileID IN ("
                  . join(',', ('?') x keys %defacedFiles)
                  . ")";
        $dbh->do($query, undef, $tarchiveID, keys %defacedFiles);

        open(SQL, ">>$tmpSQLFile") or die "Cannot append text to file $tmpSQLFile: $!. Aborting.\n";
        print SQL "\n\n";
        while(my($fileID, $sourceFileID) = each %defacedFiles) {
            print SQL "UPDATE files SET TarchiveSource = NULL, SourceFileID = $sourceFileID WHERE FileID = $fileID;\n";
        }
        close(SQL);
    }
}

=pod

=head3 deleteMriParameterForm($dbh, $uploadsRef, $tmpSQLFile)

Delete the entries in C<mri_parameter_form> (and associated C<flag> entry) for the upload(s) passed on the
command line. The script also adds an SQL statement in the SQL file whose path is passed as argument to 
restore the state that the C<mri_parameter_file> and <flag> tables had before the deletions.

INPUTS:
   - $dbh       : database handle.
   - $uploadsRef: reference on a hash of hashes containing the uploads to delete. Accessed like this:
                 C<< $uploadsRef->{'1002'}->{'TarchiveID'} >>(this would return the C<TarchiveID> of the C<mri_upload>
                 with ID 1002). The properties stored for each hash are: C<UploadID>, C<TarchiveID>, C<ArchiveLocation>
                 and C<SessionID>.
   - $tmpSQLFile: path of the SQL file that contains the SQL statements used to restore the deleted records.
  
=cut
sub deleteMriParameterForm {
    my($dbh, $uploadsRef, $tmpSQLFile) = @_;
    
    my $query = "SELECT f.CommentID FROM flag f "
              . "JOIN session s ON (s.ID=f.SessionID) "
              . "JOIN mri_upload mu ON (s.ID=mu.SessionID) "
              . "WHERE f.Test_name='mri_parameter_form' "
              . "AND mu.UploadID IN ( " 
              . join(',', ('?') x keys %$uploadsRef)
              . ") ";
    my $rowsRef = $dbh->selectall_arrayref($query, { Slice => {} }, keys %$uploadsRef);
    my @commentIDs = map { $_->{'CommentID'} } @$rowsRef;
    
    return if !@commentIDs;

    &deleteTableData($dbh, 'mri_parameter_form', 'CommentID', \@commentIDs, $tmpSQLFile);
    &deleteTableData($dbh, 'flag'              , 'CommentID', \@commentIDs, $tmpSQLFile);
}

=pod

=head3 deleteUploadsOnFileSystem($filesRef, $scanTypesToDeleteRef, $keepDefaced)

This method deletes from the file system all the files associated to the upload(s) passed on the
command line that were found on the file system. A warning will be issued for any file that
could not be deleted.

INPUTS:
  - $filesRef: reference to the array that contains the file informations for all the files
    that are associated to the upload(s) passed on the command line.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.
  - $keepDefaced: whether the defaced files should be kept or not.
               
=cut
sub deleteUploadsOnFileSystem {
    my($filesRef, $scanTypesToDeleteRef, $keepDefaced) = @_;
    
    my %deletedFile;
    foreach my $t (@PROCESSED_TABLES) {
        foreach my $f (@{ $filesRef->{$t} }) {
            next if !shouldDeleteFile($t, $f, $scanTypesToDeleteRef, $keepDefaced);
            
            next if !$f->{'Exists'};
            
            next if $deletedFile{ $f->{'FullPath'} };
            
            NeuroDB::MRI::deleteFiles($f->{'FullPath'});
            $deletedFile{ $f->{'FullPath'} } = 1;
        }
    }
}

=pod

=head3 getTypesToDelete($dbh, $scanTypeList, $keepDefaced)

Gets the list of names of the scan types to delete. If C<-type> was used, then this list is built
using the argument to this option. If C<-defaced> was used, then the list is fetched using the config
setting C<modalities_to_deface>.

INPUTS:
  - $dbh: database handle.
  - $scanTypeList: comma separated string of scan type names.
  - $keepDefaced: whether the defaced files should be kept or not.
                  
RETURNS:
  - A reference on a hash of the names of the scan types to delete: key => scan type name
    value => 1 or 0 depending on whether the name is valid or not.
=cut
sub getScanTypesToDelete {
    my($dbh, $scanTypeList, $keepDefaced) = @_;
    
    return () if !defined $scanTypeList && !$keepDefaced;
    
    if($keepDefaced) {
        my $scanTypesRef = &NeuroDB::DBI::getConfigSetting(\$dbh, 'modalities_to_deface');
        return defined $scanTypesRef ? (map { $_ => 1 } @$scanTypesRef) : ();
    }
    
    my %types = map { $_=> 1 } split(/,/, $scanTypeList);
    
    $query = 'SELECT Scan_type, ID FROM mri_scan_type '
           . 'WHERE Scan_type IN ('
           . join(',', ('?') x keys %types)
           . ')';
    my $validTypesRef = $dbh->selectall_hashref($query, 'Scan_type', undef, keys %types);
    
    return map { $_ => defined $validTypesRef->{$_} } keys %types;
}

=pod

=head3 getTarchiveSeriesIDs($dbh, $filesRef)

Gets the list of C<TarchiveSeriesID> to delete in table C<tarchive_files>.

INPUTS:
  - $dbh: database handle.
  - $filesRef: reference to the array that contains the file informations for all the files
    that are associated to the upload(s) passed on the command line.
                  
RETURNS:
  - A reference on an array containing the C<TarchiveSeriesID> to delete.
  
=cut
sub getTarchiveSeriesIDs {
    my($dbh, $filesRef) = @_;
    
    return [] unless @{ $filesRef->{'files'} };
    
    my @fileID = map { $_->{'FileID'} } @{ $filesRef->{'files'} };
    my $query = 'SELECT tf.TarchiveSeriesID '
              . 'FROM tarchive_files tf '
              . 'JOIN tarchive_series ts ON (tf.TarchiveSeriesID=ts.TarchiveSeriesID) '
              . "JOIN files f ON (ts.SeriesUID=f.SeriesUID AND ABS(f.EchoTime*1000 - ts.EchoTime) < $FLOAT_EQUALS_THRESHOLD) "
              . 'WHERE f.FileID IN (' 
              . join(',', ('?') x @fileID)
              . ')';
    my $tarchiveFilesRef = $dbh->selectall_arrayref($query, { 'Slice' => {} }, @fileID);

    return [ map { $_->{'TarchiveSeriesID'} } @$tarchiveFilesRef ];
}

=head3 deleteTableData($dbh, $table, $key, $keyValuesRef, $tmpSQLBackupFile)

Deletes records from a database table and adds in a file the SQL statements that allow rewriting the
records in the table. 


INPUTS:
  - $dbh: database handle.
  - $table: name of the database table.
  - $key: name of the key used to delete the records.
  - $keyValuesRef: reference on the list of values that field C<$key> has for the records to delete.
  - $tmpSQLBackupFile: path of the SQL file that contains the SQL statements used to restore the deleted records.
               
=cut
sub deleteTableData {
    my($dbh, $table, $key, $keyValuesRef, $tmpSQLBackupFile) = @_;
    
    return unless @$keyValuesRef;
    
    my $query = "DELETE FROM $table WHERE $key IN("
              . join(',', ('?') x @$keyValuesRef)
              . ')';

    &updateSQLBackupFile($tmpSQLBackupFile, $table, $key, $keyValuesRef) if $tmpSQLBackupFile;

    $dbh->do($query, undef, @$keyValuesRef);    
}

=head3 updateSQLBackupFile($tmpSQLBackupFile, $table, $key, $keyValuesRef)

Updates the SQL file with the statements to restore the records whose properties are passed as argument.
The block of statements is written at the beginning of the file.

INPUTS:
  - $tmpSQLBackupFile: path of the SQL file that contains the SQL statements used to restore the deleted records.
  - $table: name of the database table.
  - $key: name of the key used to delete the records.
  - $keyValuesRef: reference on the list of values that field C<$key> has for the records to delete.
               
=cut
sub updateSQLBackupFile {
    my($tmpSQLBackupFile, $table, $key, $keyValuesRef) = @_;
            
    # Make sure all keys are quoted before using them in the Unix command
    my %quotedKeys;
    foreach my $k (@$keyValuesRef) {
        (my $quotedKey = $k) =~ s/\'/\\'/g;
        $quotedKeys{$quotedKey} = 1;
    }
        
    # Read the current contents of the backup file
    open(SQL, "<$tmpSQLBackupFile") or die "Cannot read $tmpSQLBackupFile: $!\n";
    my @lines = <SQL>;
    close(SQL);
        
    # Run the mysqldump command for the current table and store the
    # result in $tmpSqlBackupFile (overwrite contents)
    my $mysqldumpOptions = '--no-create-info --compact --single-transaction --skip-extended-insert';
    
    my $warningToIgnore = 'mysqldump: [Warning] Using a password on the command line interface can be insecure.';
    my $cmd = sprintf(
        "mysqldump $mysqldumpOptions --where='%s IN (%s)' --result-file=%s  -h %s -p%s -u %s %s %s 2>&1 | fgrep -v '$warningToIgnore'",
        $key,
        join(',', keys %quotedKeys),
        quotemeta($tmpSQLBackupFile),
        quotemeta($Settings::db[3]),
        quotemeta($Settings::db[2]),
        quotemeta($Settings::db[1]),
        quotemeta($Settings::db[0]),
        $table
    );
        
    system($cmd) != 0
        or die "Cannot run command $cmd. Aborting\n";
        
    # Write back the original lines contained in $tmpSQlBackupFile at the end of the file.
    # This is so that the mysqldump results are written in the file in the reverse order in
    # which the mySQL delete statements are made.
    open(SQL, ">>$tmpSQLBackupFile") or die "Cannot append to file $tmpSQLBackupFile: $!\n";
    print SQL "\n\n";
    print SQL @lines;
    close(SQL);
}

=head3 getInvalidDefacedFiles($dbh, $filesRef, $scanTypesToDeleteRef)

Checks all the MINC files that should have been defaced and makes sure that only the defaced file
is associated to it.

INPUTS:
  - $dbh       : database handle.
  - $filesRef: reference to the array that contains the file informations for all the files
    that are associated to the upload(s) passed on the command line.
  - $scanTypesToDeleteRef: reference to the array that contains the list of scan type names to delete.
            
RETURNS:
  - The hash of MINC files that were either not defaced (and should have been) or that have more than one
    processed file associated to them. Key => file path (relative), Value => reference on an array that contains the
    list of processed files associated to the MINC file (0, 2, 3, ... entries).
     
=cut
sub getInvalidDefacedFiles {
    my($dbh, $filesRef, $scanTypesToDeleteRef) = @_;
    
    my %invalidDefacedFile;
    foreach my $f (@{ $filesRef->{'files'} }) {
        my @processedFiles = grep($_->{'Input_FileID'} == $f->{'FileID'}, @{ $filesRef->{'files_intermediary'} });
        $invalidDefacedFile{ $f->{'File'} } = [] if !@processedFiles;
            
        my @filesNotDefaced = grep( $_->{'File'} !~ /-defaced_\d+.mnc$/, @processedFiles);
        $invalidDefacedFile{ $f->{'File'} } = [ map { $_->{'File'} } @filesNotDefaced ] if @filesNotDefaced;
        
        # otherwise it means that @processedFiles contains one and only one file
        # that ends with '-defaced', which is what is expected
    }
    
    return \%invalidDefacedFile;
}
