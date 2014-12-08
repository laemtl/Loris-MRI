=pod

=head1 NAME

DTIvisu --- A set of utility functions for performing common tasks relating to DTI visual QC data.

=head1 SYNOPSIS

use DTIvisu;

=head1 DESCRIPTION

Really a mismatch of utility functions, primarily used by DTIvisualQC_insertion.pl

=head1 METHODS

=cut

package DTIvisu;

use Exporter();
use File::Basename;
use Getopt::Tabular;
use File::Path          'make_path';
use Date::Parse;
use MNI::Startup        qw(nocputimes);
use MNI::Spawn;
use MNI::FileUtilities  qw(check_output_dirs);

@ISA        = qw(Exporter);

@EXPORT     = qw();
@EXPORT_OK  = qw(getQCdate getFileID getScanType);




=pod
Grep file's ID from the database.
Input:  - $fileName: name of the file to look for fileID
Output: - $fileID: fileID of the file found in the database
=cut
sub getFileID {
    my ($fileName, $dbhr) = @_;

    my $query = <<END_QUERY;
      SELECT
        FileID
      FROM
        files
      WHERE
        File like ?
END_QUERY
    my $sth     = $dbhr->prepare($query);
    my $where   = "%$fileName%";
    $sth->execute($where);

    my $fileID;
    if ($sth->rows > 0) {
        my $row     = $sth->fetchrow_hashref();
        $fileID = $row->{'FileID'};
    }

    return ($fileID);
}





=pod
Determine ScanType for the file to be registered.
Input:  - $QCedFile = name of the file to be registered into the DB
Output: - $scanType = scan type to use to register $QCedFile into the DB
=cut
sub getScanType {
    my ($QCedFile) = @_;

    my ($scanType, $coordinateSpace);
    if ($QCedFile =~ m/-eddy-reg-to-t1_rgb/i) {
        $scanType = "FinalnoRegQCedDTIrgb";
        $coordinateSpace = "nativeT1";
    } elsif ($QCedFile =~ m/FinalnoRegQCedDTI/i) {
        $scanType = "FinalnoRegQCedDTI";
        $coordinateSpace = "native";
    } elsif ($QCedFile =~ m/FinalQCedDTI/i) {
        $scanType = "FinalQCedDTI";
        $coordinateSpace = "native";
    }

    return ($scanType, $coordinateSpace);
}



=pod
Determine QC_date based on the file's timestamp in the filesystem.
Input:  - $QCedFile
Output: - $QCdate
=cut
sub getQCdate {
    my ($QCedFile) = @_;

    # Get a 13-element list giving the status info for a file, including $mtime (last modify time) which will correspond to the QCdate.
    ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($QCedFile);

    my $date  = localtime($mtime);
    my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($date);
    my $QCdate = sprintf("%4d%02d%02d",$year+1900,$month+1,$day);

    return ($QCdate);
}





=pod

=cut
sub createFeedbackRefs {
    my ($qcnotes, $dbh) = @_;

    my $qc_labels = &DTIvisu::createLabelsHash($dbh);
    
    my ($noRegQCarr, $FinalnoRegQCarr) = &DTIvisu::readQCnotes($qcnotes);
    exit unless ($noRegQCarr && $FinalnoRegQCarr);

    my ($qc_info_noRegQChash)      = &DTIvisu::updateLabelsHash($noRegQCarr);
    my ($qc_info_FinalnoRegQChash) = &DTIvisu::updateLabelsHash($FinalnoRegQCarr);

    return ($qc_info_noRegQChash && $qc_info_FinalnoRegQChash);
}


=pod
=cut
sub createLabelsHash {
    my ($dbh) = @_;

    my %qc_labels;
    $qc_labels->{0}{'FileType'}           = undef;
    $qc_labels->{1}{'ParameterType'}      = 'Color_Artifact';
    $qc_labels->{2}{'PredefinedComment'}  = 'red artifact';
    $qc_labels->{3}{'PredefinedComment'}  = 'green artifact';
    $qc_labels->{4}{'PredefinedComment'}  = 'blue artifact';
    $qc_labels->{5}{'ParameterType'}      = 'Entropy';
    $qc_labels->{6}{'ParameterType'}      = 'Movement_artifacts_within_scan';
    $qc_labels->{7}{'PredefinedComment'}  = 'slice wise artifact (DWI ONLY)';
    $qc_labels->{8}{'PredefinedComment'}  = 'gradient wise artifact (DWI ONLY)';
    $qc_labels->{9}{'CommentType'}        = 'Movement artifact';
    $qc_labels->{10}{'ParameterType'}     = 'Intensity_artifact';
    $qc_labels->{11}{'PredefinedComment'} = 'checkerboard artifact';
    $qc_labels->{12}{'PredefinedComment'} = 'horizontal intensity striping (Venetian blind effect, DWI ONLY)';
    $qc_labels->{13}{'PredefinedComment'} = 'diagonal striping (NRRD artifact, DWI ONLY)';
    $qc_labels->{14}{'PredefinedComment'} = 'high intensity in direction of acquisition';
    $qc_labels->{15}{'PredefinedComment'} = 'signal loss (dark patches)';
    $qc_labels->{16}{'CommentType'}       = 'Intensity';
    $qc_labels->{17}{'PredefinedComment'} = 'Too few remaining gradients (DWI ONLY)';
    $qc_labels->{18}{'PredefinedComment'} = 'No b0 remaining after DWIPrep (DWI ONLY)';
    $qc_labels->{19}{'PredefinedComment'} = 'No gradient information available from scanner (DWI ONLY)';
    $qc_labels->{20}{'PredefinedComment'} = 'Incorrect diffusion direction (DWI ONLY)';
    $qc_labels->{21}{'PredefinedComment'} = 'Duplicate series';
    $qc_labels->{22}{'CommentType'}       = 'Coverage';
    $qc_labels->{23}{'PredefinedComment'} = 'Large AP wrap around, affecting brain';
    $qc_labels->{24}{'PredefinedComment'} = 'Medium AP wrap around, no affect on brain';
    $qc_labels->{25}{'PredefinedComment'} = 'Small AP wrap around, no affect on brain';
    $qc_labels->{26}{'PredefinedComment'} = 'Too tight LR, affecting brain';
    $qc_labels->{27}{'PredefinedComment'} = 'Base of cerebellum cut off';
    $qc_labels->{28}{'PredefinedComment'} = 'Top of brain cut off';
    $qc_labels->{29}{'Files'}             = 'QC_status';
    $qc_labels->{30}{'Files'}             = 'Caveat';

    foreach my $hashID (keys %$qc_labels) {

        if (exists ($qc_labels->{$hashID}{'PredefinedComment'})) {

            &DTIvisu::getPredefinedCommentID($qc_labels->{$hashID}{'PredefinedComment'}, $hashID, $dbh);
            exit unless (exists ($qc_labels->{$hashID}{'PredefinedCommentID'}));

        } elsif (exists ($qc_labels->{$hashID}{'CommentType'})) {

            &DTIvisu::getCommentTypeID($qc_labels->{$hashID}{'CommentType'}, $hashID, $dbh);
            exit unless (exists ($qc_labels->{$hashID}{'CommentTypeID'}));

        } elsif (exists ($qc_labels->{$hashID}{'ParameterType'})) {

            &DTIvisu::getParameterTypeID($qc_labels->{$hashID}{'ParameterType'}, $hashID, $dbh);
            exit unless (exists ($qc_labels->{$hashID}{'ParameterTypeID'}));

        }

    }

    return (\%$qc_labels);
}


=pod
=cut
sub getPredefinedCommentID {
    my ($predefinedComment, $hashID, $dbh) = @_;

    my $query = <<END_QUERY;
        SELECT
            PredefinedCommentID
        FROM
            feedback_mri_predefined_comments
        WHERE 
            Comment=?
END_QUERY

    my $sth = $dbh->prepare($query);
    $sth->execute($predefinedComment);

    if ($sth->rows > 0) {
        my $row     = $sth->fetchrow_hashref();
        $qc_labels->{$hashID}->{'PredefinedCommentID'} = $row->{'PredefinedCommentID'};
    }
}



=pod
=cut
sub getCommentTypeID {
    my ($CommentType, $hashID, $dbh) = @_;

    my $query = <<END_QUERY;
        SELECT
            CommentTypeID
        FROM
            feedback_mri_comment_types
        WHERE 
            CommentName=?
END_QUERY

    my $sth = $dbh->prepare($query);
    $sth->execute($CommentType);
    
    if ($sth->rows > 0) {
        my $row     = $sth->fetchrow_hashref();
        $qc_labels->{$hashID}->{'CommentTypeID'} = $row->{'CommentTypeID'};
    }
}


=pod
=cut
sub getParameterTypeID {
    my ($ParameterType, $hashID, $dbh) = @_;

    my $query = <<END_QUERY;
        SELECT
            ParameterTypeID
        FROM
            parameter_type
        WHERE 
            Name=?
END_QUERY

    my $sth = $dbh->prepare($query);
    $sth->execute($ParameterType);

    if ($sth->rows > 0) {
        my $row     = $sth->fetchrow_hashref();
        $qc_labels->{$hashID}->{'ParameterTypeID'} = $row->{'ParameterTypeID'};
    }
}

=pod
=cut
sub readQCnotes {
    my ($qcnotes) = @_;

    # Read qc-notes file into an array @filesQC with one line per file type
    open my $file, '<', $qcnotes or die $!;
    my @filesQC = <$file>;
    close $file;

    my (@noRegQCarr, @FinalnoRegQCarr);
    foreach my $line (@filesQC) {
        $line =~ s/\r|\n//g;
        next if ($line eq '');
        my @tmp_arr = split(',',$line);
        if ($tmp_arr[0] eq "FinalnoRegQCedDTI") {
            @FinalnoRegQCarr = @tmp_arr;
        } elsif ($tmp_arr[0] eq "noRegQCedDTI") {
            @noRegQCarr      = @tmp_arr;
        }
    }

    return (\@noRegQCarr, \@FinalnoRegQCarr);
}



sub updateLabelsHash {
    my ($valueArr) = @_;

    my $qc_info_hash = $qc_labels;
    my $valArrSize   = @$valueArr;
    
    # checks if array size and hash size are identical
    return undef unless ($valArrSize == (scalar keys %$qc_info_hash));
        
    foreach my $arrID (0 .. ($valArrSize - 1)) {
        $qc_info_hash->{$arrID}->{'Value'} = @$valueArr[$arrID];
    }
    
    return ($qc_info_hash);
}
