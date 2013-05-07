#!/usr/bin/perl -w
#
# NAME:
#     e_shift.pl
#
# PURPOSE:
#     Calculate the shifted energy band for the 2.0keV
#     rest frame
#
# EXPLANATION:
#     This script uses the cluster redshift to calculate
#     the observed value for the rest frame 2.0keV bandpass.
#
# CALLING SEQUENCE:
#     e_shift.pl reference.list
#
# INPUTS:
#     the assumed format for the list is as follows:
#     in the case of X and Y being the centroid position in pixels and Rmax in pixels
#     Name                 ObsID        X        Y   Rmax     MinCts         z  Nh20     Tx     Fe  Lbol Chip E_obs Diff
#     ABELL_0644            2211   3908.5   4332.5  243.9       5000    0.0704  6.41   8.64   0.35 45.00   i3 -9.99    y
#     ABELL_1651            4185   4222.5   4034.5  132.3       5000    0.0844  1.88   5.97   0.30 45.00   s3 -9.99    n
#
# OUTPUTS:
#     New, formatted reference list:  set by var $newref below
#
# MODIFICATION HISTORY:
#     None
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$newref = "new_e_shift.list";

#######################
#######################
##   Main Program    ##
#######################
#######################

# write the file header
sub_print_info();

# Read in the reference file
%refdata  = read_file($ARGV[0]);

# Go through each cluster
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # get values specific to each cluster
  $z = $data[6];
  $eobs = 2.0/(1+${z});

  # write X and Y to the reference file
  sub_write_ref($newref,@data);

}

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_print_info {

  open(NEWREF,">${newref}");
  printf NEWREF "%-25s %6s %6s %6s %6s %7s %8s %6s %6s %6s %6s %5s %8s %5s %6s %10s\n",
    "#Name","ObsID","X","Y","Rmax","MinCts","z","Nh20","Tx","Fe","Lbol","Chip","E_obs","Diff","Robs","Location";
  close NEWREF;
}

#######################
#######################

sub read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## Can't open $infile\n";
  while (<INFILE>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    s/^\s+//;        # trim leading whitespace
    s/\s+$//;        # trim trailing whitespace
    @data = split;
    $name = join "_", $data[0],$data[1];
    $info{$name} = $_;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub sub_write_ref {

  my($ref,@oldref) = @_;
  open NEWREF, ">>$ref";
  my @newref = @oldref;
  $newref[12] = $eobs;
  printf NEWREF "%-25s %6s %6.0f %6.0f %6.0f %7.0f %8.4f %6.2f %6.2f %6.2f %6.2f %5s %8.4f %5s %6i %10s\n",
  $newref[0],$newref[1],$newref[2],$newref[3],$newref[4],$newref[5],$newref[6],$newref[7],$newref[8],
  $newref[9],$newref[10],$newref[11],$newref[12],$newref[13],$newref[14],$newref[15];
  close NEWREF;
}

#######################
#######################
