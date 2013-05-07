#!/usr/bin/perl -w
#
# NAME:
#     find_rmax.pl
#
# PURPOSE:
#     Locate the radius from the cluster centroid at which
#     the source surface brightness is equal to or within
#     10% of the background surface brightness. Once this point
#     us found, the R_max value in the input reference file is
#     rewritten with the new value.
#
# EXPLANATION:
#     This script opens the surface brightness profile, usually
#     named <obsid>_sb.dat, created by make_cumprof.pl and reads
#     the sur_bri, sur_bri_err, bg_sur_bri, and bg_sur_bri_err
#     values.
#
#     This script assumes the following directory structure:
#     all pertinent Chandra data files are in a dir labeled with
#     the obsid, which is then in a dir labeled acis/. The location
#     of acis/ relative to the dir from which this script is run is
#     set with the variable $datadir.
#
#     e.g.: for Abell 644 obsid 2211, this script will look to
#     $datadir/acis/2211/$rootdir for all the files needed to complete
#     the data reduction
#
# CALLING SEQUENCE:
#     find_rmax.pl <reference list>
#
# INPUTS:
#     the assumed format for the list is as follows:
#     in the case of X and Y being the centroid position in pixels and Rmax in pixels
#     Name             ObsID        X        Y   Rmax     MinCts         z  Nh20     Tx     Fe  Lbol Eobs Diff
#     ABELL_0644        2211   3908.5   4332.5  243.9       5000    0.0704  6.41   8.64   0.35 45.00 1.11    y
#     ABELL_1651        4185   4222.5   4034.5  132.3       5000    0.0844  1.88   5.97   0.30 45.00 1.11    n
#
# OUTPUTS:
#    new reference file with new R-max value
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$bintype = "10pix";
$newref = "new_rmax_ref.list";
$datadir = "../";
$rootdir = "reprocessed";

#######################
#######################
##   Main Program    ##
#######################
#######################

# Check the number of arguments given
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# Load useful libraries
# Store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# open file to new reference
sub_print_info();

# Open a a log file
open(LOGFILE,">>find_rmax.log") || die "\n## $obsid: Can't find_rmax.log\n";
print LOGFILE "###### Started finding r_max at ",scalar(localtime)," ######\n";

# Read in the reference file
%refdata  = sub_read_file($ARGV[0]);

# Go through each cluster
{
  foreach $key (sort keys %refdata) {

      # split up the data line
      @data = split(/\s+/,$refdata{$key});

      # get values specific to each cluster
      $name  = $data[0];
      $obsid = $data[1];
      $x     = $data[2];
      $y     = $data[3];
      $rmax  = $data[4];

      # write to log file
      print "\n###### Started $name (ObsId $obsid) ",scalar(localtime),"\n\n";
      print LOGFILE "###### Started $name (ObsId $obsid) ",scalar(localtime),"\n";

      # define file names
      $sbfile = "${obsid}_sbprof_${bintype}.dat";
      $regfile = "${obsid}_robs.reg";
      print "## Using sb file $sbfile\n";

      # change directory
      chdir("$datadir/$obsid/$rootdir");

      # make sure we have events files to work with
      unless (-e $sbfile) {
	print "## No sb file for $obsid\n";
	print LOGFILE "${obsid}: No sb file\n";
	chdir("$Bin");
	next;
      }

      # get data from sb prof into a hash
      %sbprof = sub_get_profile($sbfile);

      # find rmax
      $robs = sub_rmax(%sbprof);
      $robs = $rmax if ($robs > $rmax);
      print LOGFILE "${obsid}: Found R_max of $robs\n";
      print "## Found R_max of $robs\n";

      # write R_max to the reference file
      sub_write_ref($newref,@data);
      print LOGFILE "${obsid}: Wrote R_max column in $newref\n";
      print "## Wrote R_max column in $newref\n";

      # write to log file
      print LOGFILE "###### Finished $name (ObsId $obsid) ",scalar(localtime),"\n";
      print "\n###### Finished $name (ObsId $obsid) ",scalar(localtime),"\n\n";

      # write a region file for the centroid for easy viewing
      open(REGFILE,">$regfile");
      print REGFILE "circle(${x},${y},${robs})\n";
      close REGFILE;

      # change back to original directory
      chdir("$Bin");
    }
}

print LOGFILE "###### Finished finding r_max ",scalar(localtime)," ######\n\n";
print "\n###### Finished finding r_max ",scalar(localtime)," ######\n\n";
close LOGFILE;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_print_info {

  open(NEWREF,">$Bin/${newref}");
  printf NEWREF "%-25s %6s %6s %6s %6s %7s %8s %6s %6s %6s %6s %5s %8s %5s %6s\n",
    "#Name","ObsID","X","Y","Rmax","MinCts","z","Nh20","Tx","Fe","Lbol","Chip","E_obs","Diff","Robs";
  close NEWREF;
}

#######################
#######################

sub sub_read_file {

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

sub sub_get_profile {

  my($infile) = @_;
  my(%info,@data);

  open(INFILE,$infile);
  while (<INFILE>) {
    chomp;
    s/^\s+//;  # trim leading whitespace
    s/\s+$//;  # trim trailing whitespace
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    next unless (/^\d/); # skip ahead until line is numbers
    @data = split;
    $info{$data[2]} = $_;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub sub_rmax {

  my(%prof) = @_;

  $i=0;
  foreach $pixel (sort {$a <=> $b} keys %prof) {

    # skip first three entries
    $i++;
    next if ($i < 3);

    # split up the data line
    my @data = split(/\s+/,$prof{$pixel});

    # get values specific to each cluster
    my $rin     = $data[2];
    my $rout    = $data[3];
    my $rmid    = $data[4];
    my $sb      = $data[5];
    my $sberr   = $data[6];
    my $bgsb    = $data[7];
    my $bgsberr = $data[8];

    # calculate the needed values
    my $sbhi = $sb + $sberr;
    my $sblo = $sb - $sberr;
    my $bghi = $bgsb + $bgsberr;
    my $bglo = $bgsb - $bgsberr;

    # I'll overestimate r_obs to ensure
    # inclusion of all diffuse emission
    my $tot  = $sb - $bgsb;
    $robs = $rmid;
    if ($tot <= 0) {
      $robs = $rmid+(0.3*$rmid);
      last;
    }
  }
  return $robs;
}

#######################
#######################

sub sub_write_ref {

  my($ref,@oldref) = @_;
  open NEWREF, ">>/$Bin/$ref";
  my @newref = @oldref;
  $newref[14] = $robs;
  printf NEWREF "%-25s %6s %6.0f %6.0f %6.0f %7.0f %8.4f %6.2f %6.2f %6.2f %6.2f %5s %8.4f %5s %6.0f\n",
    $newref[0],$newref[1],$newref[2],$newref[3],$newref[4],$newref[5],$newref[6],$newref[7],$newref[8],$newref[9],$newref[10],$newref[11],$newref[12],$newref[13],$newref[14];
  close NEWREF;
}

#######################
#######################

sub sub_logerror {

    my($offender) = @_;

    chdir("$Bin");
    open  ERRFILE,">>cent_errors.log";
    print "${obsid} # failure in cent_emi.pl, $offender ",scalar(localtime),"\n";
    print ERRFILE "${obsid} # failure in cent_emi.pl, $offender ",scalar(localtime),"\n";
    close ERRFILE;
}

#######################
#######################
