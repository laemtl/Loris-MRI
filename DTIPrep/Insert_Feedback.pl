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

&insertFeedbacks($noRegQCedDTIname,
                 $registeredFinalnoRegQCedDTI,
                 $qcnotes,
                 $dbh
                );

exit 0;


sub insertFeedbacks {
    my ($noRegQCedDTI, $FinalnoRegQCedDTI, $qcnotes, $dbh) = @_;

    # Get FileIDs
    my ($noRegQCedDTIFileID)      = &DTIvisu::getFileID($noRegQCedDTI,      $dbh);
    my ($FinalnoRegQCedDTIFileID) = &DTIvisu::getFileID($FinalnoRegQCedDTI, $dbh);
    print LOG "\nERROR: could not find fileID of $noRegQCedDTIFileID or $FinalnoRegQCedDTIFileID\n" unless ($noRegQCedDTIFileID && $FinalnoRegQCedDTIFileID);

    # Read qc-notes file
    my ($noRegQCRefs, $finalNoRegQCRefs) = &DTIvisu::createFeedbackRefs($qcnotes, $dbh);
    unless ($noRegQCRefs && $finalNoRegQCRefs) {
        print LOG "\nERROR: could not create Feedback hash using qcnotes for one of the file\n";
        exit;
    }

    # Append FileID into $noRegQCRefs and $finalNoRegQCRefs for QC status and caveat fields
    $noRegQCRefs->{29}->{'FileID'}      = $noRegQCedDTIFileID;
    $noRegQCRefs->{30}->{'FileID'}      = $noRegQCedDTIFileID;
    $finalNoRegQCRefs->{29}->{'FileID'} = $FinalnoRegQCedDTIFileID;
    $finalNoRegQCRefs->{30}->{'FileID'} = $FinalnoRegQCedDTIFileID;

    # Feedback checking
    &CheckFeedbackRefOptions($noRegQCRefs);
    &CheckFeedbackRefOptions($finalNoRegQCRefs);

    # Insert Comments 
    my ($success) = &InsertComments($noRegQCedDTIFileID, $noRegQCRefs, $dbh);
    my $yeah_mess = "\nAll feedbacks were correctly inserted into DB!!\n";
    my $fail_mess = "\nERROR: some feedbacks could not be inserted. Check log above to see what failed.\n";
    if ($success) {
        print LOG $yeah_mess;
    } else {
        print LOG $fail_mess;
        exit;
    }
    
}



sub InsertComments {
    my ($fileID, $hashRefs, $dbh) = @_;
    
    # Insert Parameter Type Comments (drop downs)
    my @typeIDs = [1, 5, 6, 10];
    foreach my $typeID (@typeIDs) {
#        my $typeName   = $hashRefs->{$typeID}->{'ParameterType'};
        my $typeValue  = $hashRefs->{$typeID}->{'Value'};
        my $DBtypeID   = $hashRefs->{$typeID}->{'ParameterTypeID'};
#        my ($DBtypeID) = &DTIvisu::getParameterTypeID($typeName, $dbh);    
        my ($success)  = &DTIvisu::insertParameterType($fileID, $DBtypeID, $typeValue, $dbh); 
        my $message    = "\nERROR: could not insert FileID $fileID, ParameterTypeID $typeID and Value $typeValue into parameter_File\n";
        unless ($success) {
            print LOG $message;
            exit;
        }
    }    

    # Insert feedback MRI predefined comments (checkboxes)
    my @predefIDs = [2,   3,  4,  7,  8, 11, 12, 
                     13, 14, 15, 17, 18, 19, 20, 
                     21, 23, 24, 25, 26, 27, 28
                    ];
    foreach my $predefID (@predefIDs) {
#        my $predefName = $hashRefs->{$predefID}->{'PredefinedComment'};
        my $predefValue= $hashRefs->{$predefID}->{'Value'};
        my $DBpredefID = $hashRefs->{$predefID}->{'PredefinedCommentID'};
        my $comTypeID  = $hashRefs->{$predefID}->{'CommentTypeID'};
#        my ($DBpredefID, $comTypeID) = &DTIvisu::getPredefinedCommentID($predefName, $dbh);
        my ($success)  = &DTIvisu::insertPredefinedComment($fileID, $DBpredefID, $comTypeID, $predefValue, $dbh);
        my $message    = "\nERROR: could not insert FileID $fileID, PredefinedCommentID $predefID and Value $predefValue into feedback_mri_comments\n";
        unless ($success) {
            print LOG $message;
            exit;
        }
    }                

    # Insert text comments
    my @textIDs = [9, 16, 22];
    foreach my $textID (@textIDs) {
#        my $textName    = $hashRefs->{$textID}->{'CommentType'};
        my $textValue   = $hashRefs->{$textID}->{'Value'};
        my $comTypeID   = $hashRefs->{$textID}->{'CommentTypeID'}; 
#        my ($comTypeID) = &DTIvisu::getCommentTypeID($textName, $dbh);
        my ($success)   = &DTIvisu::insertCommentType($fileID, $comTypeID, $textValue, $dbh); 
        my $message    = "\nERROR: could not insert FileID $fileID, CommentTypeID $comTypeID and Value $textValue into feedback_mri_comments\n";
        unless ($success) {
            print LOG $message;
            exit;
        }
    }

    # Insert QC status
    my $qcstatus    = $hashRefs->{29}->{'Value'};
    my ($qcsuccess) = &DTIvisu::insertQCStatus($fileID, $qcstatus, $dbh);
    my $qcmessage   = "\nERROR: could not insert FileID $fileID, QCstatus $qcstatus into files_qc_status\n";
    unless ($qcsuccess) {
        print LOG $qcmessage;
        exit;
    }

    # Insert caveat
    my $caveat       = $hashRefs->{30}->{'Value'};
    my ($cavsuccess) = &DTIvisu::updateCaveat($fileID, $caveat, $dbh);
    my $cavmessage   = "\nERROR: could not insert FileID $fileID, QCstatus $caveat into files\n";
    unless ($cavsuccess) {
        print LOG $cavmessage;
        exit;
    }

    return 1;
}



sub CheckFeedbackRefOptions {
    my ($feedbackRef) = @_;

    my ($mapping_success) = &mapSliceWiseArtifact($feedbackRef);
    exit unless ($mapping_success);

    my ($validRef) = &checkFeedbackRef($feedbackRef);
    exit unless ($validRef);

    return 1;
}




sub mapSliceWiseArtifact {
    my ($feedbackRef) = @_;

    # if slice wise artifact = none, checkbox = No
    # else checkbox for slice wise artifact = Yes and Movement artifact comments is appended 
    # slight, fair or unacceptable slice wise artifact, depending on its intensity
    my @other_opt = ['Slight', 'Poor', 'Unacceptable'];
    if ($feedbackRef->{7}->{'Value'} eq 'None') {
        $feedbackRef->{7}->{'Value'} = 'No';    
    } elsif ($feedbackRef->{7}->{'Value'} ~~ @other_opt) {
        $feedbackRef->{9}->{'Value'}.= $feedbackRef->{7}->{'Value'} . ' slice wise artifact'; 
        $feedbackRef->{9}->{'Value'} =~ s/Null//ig;
        $feedbackRef->{7}->{'Value'} = 'Yes';
    } else {
        print LOG "\nERROR: $feedbackRef->{7}->{'ParameterType'} is $feedbackRef->{7}->{'Value'} while it should be either 'Slight', 'Poor', 'Unacceptable' or 'None'\n";
        return undef;
    }
    
    # Repeat same as above for gradient wise artifact
    if ($feedbackRef->{8}->{'Value'} eq 'None') {
        $feedbackRef->{8}->{'Value'} = 'No';
    } elsif ($feedbackRef->{8}->{'Value'} ~~ @other_opt) {
        $feedbackRef->{9}->{'Value'}.= $feedbackRef->{8}->{'Value'} . ' gradient wise artifact';
        $feedbackRef->{9}->{'Value'} =~ s/Null//ig;
        $feedbackRef->{8}->{'Value'} = 'Yes';
    } else {
        print LOG "\nERROR: $feedbackRef->{8}->{'ParameterType'} is $feedbackRef->{8}->{'Value'} while it should be either 'Slight', 'Poor', 'Unacceptable' or 'None'\n";
        return undef;
    }

    return 1;
}

sub checkFeedbackRef {
    my ($feedbackRef) = @_;


    # Checks parameter types field options
    # 1. Entropy 
    my @entropy_opt          = ['Acceptable', 'Suspicious', 'Unacceptable', 'Not_available'];
    my ($entropy_success)    = &checkComments($feedbackRef, 5, @entropy_opt);
    # 2. Movement within scan 
    my @mvt_within_opt       = ['None', 'Slight', 'Poor', 'Unacceptable'];
    my ($mvt_within_success) = &checkComments($feedbackRef, 6, @mvt_within_opt);
    # 3. Other parameter types fields (aka color_artifact 1 and intensity artifact 10) 
    my @param_type_opt       = ['Fair', 'Good', 'Poor', 'Unacceptable'];
    my ($param_type_success) = &checkComments($feedbackRef, 1, @param_type_opt);

    # Checks predefined comments options
    my @predefined_opt = ['Yes', 'No'];
    my $predefined_success;
    foreach my $id (keys $feedbackRef) {
        next unless (exists($feedbackRef->{$id}->{'PredefinedComment'}));
        ($predefined_success) = &checkComments($feedbackRef, $id, @predefined_opt);
    }

    # Checks QC status
    my @qcstatus_opt       = ['Pass', 'Fail'];
    my ($qcstatus_success) = &checkComments($feedbackRef, 29, @qcstatus_opt);

    # Checks Caveat
    my @caveat_opt   = ['True','False'];
    my ($caveat_opt) = &checkComments($feedbackRef, 30, @caveat_opt);

    return 1 if ($entropy_success    && 
                 $mvt_within_success && 
                 $param_type_success && 
                 $predefined_success && 
                 $qcstatus_success   && 
                 $caveat_opt
                );

   return undef;
}


sub checkComments {
    my ($feedbackRefs, $id, $options) = @_;

    my $opt_string = "'" . join("','", @$options) . "'";
    unless ($feedbackRefs->{$id}->{'Value'} ~~ @$options) {
        print LOG "\nERROR: $feedbackRefs->{$id}->{'PredefinedComment'} is $feedbackRefs->{$id}->{'Value'} while it should be either $opt_string\n";
        return undef;
    }

    return 1;
}

