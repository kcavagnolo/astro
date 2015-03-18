#! /usr/bin/perl -w
#
# NAME:
#
# PURPOSE:
#
# EXPLANATION:
#
# CALLING SEQUENCE:
#
# INPUTS:
#
# OUTPUTS:
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$datadir1 = "../temp";
$datadir2 = "/Volumes/GALACTUS";
$datadir3 = "/Volumes/GALACTUS";
$rootdir  = "reprocessed";
$evtext   = "clean";
$smooth   = "-smooth yes";
$scale    = "-scale sqrt";
$bin      = "-bin factor 2";
$cmap     = "-cmap b";
$nlevs    = "8";
$csmooth  = "5";
$cscale   = "log";

#######################
#######################

# load useful libraries
# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# read in the reference file
%refdata = &read_file($ARGV[0]);

# load images in DS9 and overlay region
MAIN: foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # get values specific to each cluster
  $obsid  = $data[1];
  $loc    = $data[15];
  $datadir = $datadir1 if ($loc eq "NAZGUL");
  $datadir = $datadir2 if ($loc eq "MBRANE");
  $datadir = $datadir3 if ($loc eq "GALACTUS");

  # change directory
  chdir("$datadir/$obsid/$rootdir/");

  # set files to be opened
  if ($evtext eq "") {
    @evtfile = glob("*evt2*.fits*");
    if (@evtfile) {
      $evtfile = shift(@evtfile);
    } else {
      @evtfile = glob("../primary/*evt2*");
      $evtfile = pop(@evtfile);
    }
  } else {
    @evtfile = glob("*${evtext}*.fits*");
    $evtfile = shift(@evtfile);
  }

  # load images
  &ds9_image();

  # change back to original directory
  chdir("$Bin");
}

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};

#######################
#######################
##   Sub-routines    ##
#######################
#######################

sub ds9_image {

  # execute ds9
  $command = "ds9 $evtfile $scale $bin $cmap $smooth "
    ."-contour yes "
	."-contour smooth $csmooth "
	  ."-contour scale $cscale "
	    ."-contour nlevels $nlevs "
	      ."-contour save ${obsid}.con wcs fk5";
  system $command;
}

#######################
#######################

sub read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## Can't open $infile\n";
  while (<INFILE>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;
    s/\s+$//;
    @data = split;
    $name = join "_", $data[0],$data[1];
    $info{$name} = $_;
  }
  close INFILE;
  return %info;
}

#######################
#######################
