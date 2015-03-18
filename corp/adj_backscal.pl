#! /usr/bin/perl -w
#
# NAME:
#     adj_backscal.pl
#
# PURPOSE:
#     Adjust the BACKSCAL header keyword and FITS table value
#     of the spectrum(a) for an observation to reflect the
#     deviation of the blank-sky background count rate in the
#     9.5-12keV energy range from that in the same energy band
#     of the observation's off-source chip count rate.
#
# EXPLANATION:
#     This script takes in the PI and bgd_ratio.dat files from
#     extract_spectra.pl and bgd_ratio.pl, respectively, and
#     adjusts the header keyword BACKSCAL based on the relation:
#
#     new_BACKSCAL = eta * orig_BACKSCAL
#     eta = (obs_count_rate / deep_bgd_count rate)^-1
#
#     This script assumes the following directory structure:
#     $loc/$obsid/$rootdir
#
#     $loc is specified as the last column of the input file
#     $obsid is specified as the second column of the input file
#     $rootdir is specified in the 'options' section of this script
#
#     Example:
#     For $loc /mnt/DROBO and $obsid 2211 and $rootdir reprocessed,
#     this script will look in /mnt/DROBO/2211/reprocessed for all the
#     files needed to complete the data reduction
#
# CALLING SEQUENCE:
#     adj_backscal.pl <reference file>
#
# FILES ASSUMED TO EXIST:
#     <spectrum_root>_$bgd.pi -- The background spectrum to be adjusted, where $bgd is set below
#     bgd_ratio.dat           -- A data file containing the results from bgd_ratio.pl
#
# INPUTS:
#     <reference list> = file containing information about each cluster
#     the assumed format for the list is as follows:
#
#     Example:
#     #Name                      ObsID      X      Y   Rmax  MinCts        z   Nh20     Tx     Fe   Lbol  Chip    E_obs  Diff   Robs   Location
#     1E0657_56                   3184   3776   4026    590    5000   0.2960   6.53  11.64   0.23  46.20    i3   1.5432     y    200   /mnt/DROBO
#
# OUTPUTS:
#     <spectrum root>_adj.pi -- a new bgd file with 'adj' appended to indicate it has been adjusted
#
#     Example:
#     ABELL_1795_r2500_bgd.pi goes in, ABELL_1795_r2500_bgd_adj.pi comes out
#
#     **NB**:
#     The header keywords for the associated source spectrum are NOT
#     updated, that is handled in the spectrun fitting scripts
#
#######################
#######################
##    Set Options    ##
#######################
#######################

#@src      = qw(r200 r500 r1000 r2500 r5000 r7500 rmax r200-core r500-core r1000-core r2500-core r5000-core r7500-core rlx-core);
@src = qw(annuli);
$bgd     = "bgd";
$datfile = "$ENV{'HOME'}/research/redux/redux_info/all_bgd_9-12.dat";
$rootdir = "reprocessed/";

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});

# Check the number of arguments given
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# Load useful libraries
# Store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# read in the reference file
%refdata = sub_read_ref($ARGV[0]);

# determine how many items there are
open(COUNT,$ARGV[0]);
while(<COUNT>){
  next if (/^\#/);
  next if (/^$/);
  $counter++;
}
close COUNT;
$ocount = $counter;

# do all src
foreach $src (@src) {

    # go through each obsid and adjust backscal
    $counter = $ocount;
    {
    foreach $key (sort keys %refdata) {

      # announce how much longer
      print "## STATUS: $counter clusters(s) left...\n";

      # split up the data line
      @data = split(/\s+/,$refdata{$key});

      # get line info
      $name    = $data[0];
      $obsid   = $data[1];
      $datadir = $data[15];

      # get the ratio of obs bgd ctr to deep bgd ctr
      print "## Finding bgd count rate ratio\n";
      $bgdratio = sub_bgdratio($datfile);
      if ($bgdratio eq "" || $bgdratio <= 0) {
	$offender = "no bgd ratio";
	print "## ERROR: $offender for ${obsid}\n";
	sub_logerror($offender);
	next;
      }
      print "## obs ctr/deep ctr of $bgdratio\n";

      # change directory
      chdir("$datadir/$obsid/$rootdir/");

      # define and check for file names
      @bgfile = glob("*${obsid}*${src}*${bgd}.pi");

      # adjust all files
      foreach $bgfile (@bgfile) {

	  unless (-e $bgfile) {
	      $offender = "no $bgfile";
	      print "## ERROR: $offender\n";
	      sub_logerror($offender);
	      next;
	  }

	  $newbgfile = $bgfile;
	  $newbgfile =~ s/\_bgd.pi/\_bgd\_adj.pi/;
	  sub_adjust();
      }

      # write to log file
      $counter--;
      print "## STATUS: Finished $name (ObsId $obsid)\n\n";

      # change back to original directory
      chdir("$Bin");
    }
  }
}

print "\n## STATUS: I'm all done!\n";
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_ref {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## $obsid:  Can't open $infile\n";
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

sub sub_bgdratio {

  my($dat) = @_;

  # parse file for matching obsid
  open(DAT,$dat);
  while(<DAT>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @data = split;
    my $fobs = $data[1];
    my $rate = $data[7];
    if ($fobs eq ${obsid}) {
      chomp $rate;
      return $rate;
    }
  }
}

#######################
#######################

sub sub_adjust {

  # make a copy of the bgd file
  system(`cp -f $bgfile $newbgfile`);
  print "## Copied $bgfile to $newbgfile\n";

  # get the original BACKSCAL value
  print "## Finding BACKSCAL value\n";
  chomp($origbscl = sub_origbscl($bgfile));

  # calculate new BACKSCAL
  $eta = 1/$bgdratio;
  $newbscl = $origbscl*$eta;
  print "## New BACKSCAL value: $newbscl\n";

  # insert new BACKSCAL value into file
  print "## Inserting new BACKSCAL value into $newbgfile\n";
  sub_newbscl($newbgfile,$newbscl);
}

#######################
#######################

sub sub_origbscl {

  my($bg) = @_;

  # run dmkeypar on the file
  $command = "punlearn dmkeypar; dmkeypar $bg BACKSCAL";
  system($command);

  # retrieve dmkeypar value
  chomp(my $backscal = `pget dmkeypar value`);
  print "## BACKSCAL value for ${obsid}: $backscal\n";

  # return the value
  return $backscal;
}

#######################
#######################

sub sub_newbscl {

  my($bg,$bscl) = @_;

  # run dmhedit and insert value
  $command = "punlearn dmhedit; dmhedit infile=$bg operation=add key=BACKSCAL value=$bscl filelist=\"\"";
  system($command);

}

#######################
#######################
sub sub_logerror {

  my($offender) = @_;

  chdir("$Bin");
  open  ERRFILE,">>err_adj_backscal.log";
  print "## ERROR: ${obsid} # failure in adj_backscal.pl, $offender\n";
  print ERRFILE "${obsid} # failure in adj_backscal.pl, $offender\n";
  close ERRFILE;
}

#######################
#######################
