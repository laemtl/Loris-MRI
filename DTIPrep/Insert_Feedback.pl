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

my $noRegQCedDTIname = "assembly/108583/NAPEN00/mri/processed/DTIPrepPipeline/PreventAD_108583_NAPEN00_noRegQCedDTI_001.mnc";
my $registeredFinalnoRegQCedDTI = "assembly/108583/NAPEN00/mri/processed/DTIvisualQC/PreventAD_108583_NAPEN00_FinalnoRegQCedDTI_001.mnc";
my $qcnotes = "/data/preventAD/data/pipelines/DTIvisualQC_ilana/108583/NAPEN00/mri/processed/DTIPrepPipeline/qc-notes";

{ package Settings; do "$ENV{LORIS_CONFIG}/.loris_mri/prod" }
my  $dbh    =   &DB::DBI::connect_to_db(@Settings::db);
my $data_dir=   $Settings::data_dir;

my ($success) = &insertFeedbacks($noRegQCedDTIname,
                                 $registeredFinalnoRegQCedDTI,
                                 $qcnotes,
                                 $dbh
                                );
print $success;

exit 0;


sub insertFeedbacks {
    my ($noRegQCedDTI, $FinalnoRegQCedDTI, $qcnotes, $dbh) = @_;

    # Get FileIDs
    my ($noRegQCedDTIFileID)      = &DTIvisu::getFileID($noRegQCedDTI,      $dbh);
    my ($FinalnoRegQCedDTIFileID) = &DTIvisu::getFileID($FinalnoRegQCedDTI, $dbh);
    print LOG "\nERROR: could not find fileID of $noRegQCedDTIFileID or $FinalnoRegQCedDTIFileID\n" unless ($noRegQCedDTIFileID && $FinalnoRegQCedDTIFileID);

    # Read qc-notes file
    my ($noRegQCRefs, $finalNoRegQCRefs) = &DTIvisu::createFeedbackRefs($qcnotes, $dbh);
    print LOG "\nERROR: could not create Feedback hash using qcnotes for one of the file\n" unless ($noRegQCRefs, $finalNoRegQCRefs);

    # Append FileID into $noRegQCRefs and $finalNoRegQCRefs for QC status and caveat fields
    $noRegQCRefs->{29}->{'FileID'} = $noRegQCedDTIFileID;
    $noRegQCRefs->{30}->{'FileID'} = $FinalnoRegQCedDTIFileID;

    # Feedback checking
    &CheckFeedbackRefOptions($noRegQCRefs);
}


sub CheckFeedbackRefOptions {
    my ($feedbackRef) = @_;

    # if slice wise artifact = none, checkbox = No
    # else checkbox for slice wise artifact = Yes and Movement artifact comments is appended 
    # slight, fair or unacceptable slice wise artifact, depending on its intensity
    if ($feedbackRef->{7}->{'Value'} eq 'None') {
        $feedbackRef->{7}->{'Value'} = 'No';    
    } else {
        $feedbackRef->{9}->{'Value'}.= $feedbackRef->{7}->{'Value'} . ' slice wise artifact'; 
        $feedbackRef->{7}->{'Value'} = 'Yes';
    }
    
    # Repeat same as above for gradient wise artifact
    if ($feedbackRef->{8}->{'Value'} eq 'None') {
        $feedbackRef->{8}->{'Value'} = 'No';
    } else {
        $feedbackRef->{9}->{'Value'}.= $feedbackRef->{7}->{'Value'} . ' slice wise artifact';
        $feedbackRef->{8}->{'Value'} = 'Yes';
    }

    # Checks parameter types field options
    # 1. Entropy 
    my @entropy_opt = ['Acceptable', 'Suspicious', 'Unacceptable', 'Not_available'];
    unless ($feedbackRef->{5}->{'Value'} ~~ @entropy_opt) {
        print LOG "\nERROR: entropy rating is $feedbackRef->{5}->{'Value'}, while it should be either 'Acceptable', 'Suspicious', 'Unacceptable' or 'Not_available'\n";
        exit;
    }
    # 2. Movement within scan 
    my @mvt_within_scan_opt = ['None', 'Slight', 'Poor', 'Unacceptable'];
    unless ($feedbackRef->{6}->{'Value'} ~~ @mvt_within_scan_opt) {
        print LOG "\nERROR: Movement within scan is $feedbackRef->{6}->{'Value'}, while it should be either 'None', 'Slight', 'Poor' or 'Unacceptable'\n";
        exit;
    }
    # 3. Other parameter types fields (aka color_artifact 1 and intensity artifact 10) 
    my @param_type_opt = ['Fair', 'Good', 'Poor', 'Unacceptable'];
    unless (($feedbackRef->{1}->{'Value'} ~~ @param_type_opt) && ($feedbackRef->{10}->{'Value'} ~~ @param_type_opt)) {
        print LOG "\nERROR: Color artifact is $feedbackRef->{1}->{'Value'} and Intensity artifact is $feedbackRef->{10}->{'Value'} while it should be either 'Fair', 'Good', 'Poor', 'Unacceptable'.\n";
        exit;
    }

    
}
