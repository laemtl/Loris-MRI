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
Function that will determine output names based on each DTI file dataset and return a hash of DTIref:
       QCed_file_1 -> Input DTIPrep filename
                   -> Raw DWI source filename
                   -> ScanType to be attributed for file to be registered
                   -> QC_date (equivalent of pipeline date) of the file to be registered
       QCed_file_2 -> Input DTIPrep filename
Inputs:  - $DTIs_list: list of visualy QCed files to be registered
         - $QCoutdir: directory storing the QCed files to be registered
Outputs: - $DTIrefs: hash containing parameters to use to register QCed files
=cut
#sub createDWIQChasref {
#    my ($QCedfiles, $DTIvisu_subdir) = @_;
#
#    my %DTIrefs;
#    foreach my $QCedFile (@$QCedfiles) {
#        
#        # Input DTIPrep filename & FileID
#        my $inputName     = substr(basename($QCedFile), 0, -4);
#        if ($QCedFile =~ m/-eddy-reg-to-t1_rgb/) {
#            $inputName    =~ s/-eddy-reg-to-t1_rgb//g;     
#        } else {
#            $inputName    =~ s/Final//g;
#        }
#        my ($inputFileID) = &DTIvisu::getFileID($inputName);
#
#        #  Raw DWI source filename & FileID
#        my ($sourceName)  = &DTI::fetch_header_info('processing:sourceFile', 
#                                                   $QCedFile,
#                                                   '$3'
#                                                  );
#        my ($sourceFileID)= &DTIvisu::getFileID($sourceName); 
#
#        # QC_date (equivalent to pipeline date) of the file to be registered
#        # read this information direclty from the filesystem creation date
#        my ($QCdate)    = &DTIvisu::getQCdate($QCedFile);  
#
#        # ScanType to be attributed for file to be registered
#        my ($scanType, $coordinateSpace)  = &DTIvisu::getOtherInfo($QCedFile);
#
#        # organize info into $DTIrefs
#        $DTIrefs->{$QCedFile}->{'inputName'}       = $inputName;
#        $DTIrefs->{$QCedFile}->{'inputFileID'}     = $inputFileID;
#        $DTIrefs->{$QCedFile}->{'sourceName'}      = $sourceName;
#        $DTIrefs->{$QCedFile}->{'sourceFileID'}    = $sourceFileID;
#        $DTIrefs->{$QCedFile}->{'QCdate'}          = $QCdate;
#        $DTIrefs->{$QCedFile}->{'ScanType'}        = $scanType;
#        $DTIrefs->{$QCedFile}->{'coordinateSpace'} = $coordinateSpace;
#    }
#
#    return ($DTIrefs);
#}




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
    my ($qcnotes) = @_;

    my @qc_labels = ["FileType",
                     "Color_FA",
                     "Red",      
                     "Green",
                     "Blue",      
                     "Entropy_rating",      
                     "Motion",         
                     "Motion_Slice_Wise",   
                     "Motion_Gradient_Wise",
                     "Motion_comment",      
                     "Intensity", 
                     "Checkerboard", 
                     "Horizontal_striping", 
                     "Diagonal_striping", 
                     "High_intensity_in_acquisition_direction",
                     "Signal_loss",         
                     "Intensity_comment",
                     "Too_few_remaining_gradients",   
                     "No_b0_left",    
                     "No_gradient_info",
                     "Incorrect_diffusion_directions",    
                     "Duplicate_series",  
                     "Coverage_comment",  
                     "large_AP_wrap",
                     "medium_AP_wrap",
                     "small_AP_wrapi", 
                     "tight_LR_brain",    
                     "base_cerebellum_cut",   
                     "top_brain_cut", 
                     "QC_status", 
                     "Caveat"];
    
    # Read qc-notes file into an array @fileTypes with one line per file type
    open my $file, '<', $qcnotes or die $!;
    my @fileTypes = <$file>;
    close $file;


}
