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
#     <reference list> = file containing information about each cluster
#     in the case of X and Y being the centroid position in pixels and Rmax in pixels
#     #Name                      ObsID      X      Y   Rmax  MinCts        z   Nh20     Tx     Fe   Lbol  Chip    E_obs  Diff   Robs   Location
#     1E0657_56                   3184   3778   4026    590    5000   0.2960   6.53  11.64   0.23  46.20    i3   1.5432     y    200   MBRANE
#     1E0657_56                   5356   4205   4267    670    5000   0.2960   6.53  11.64   0.23  46.20    i2   1.5432     y    200   MBRANE
#     1E0657_56                   5361   3788   3916    662    5000   0.2960   6.53  11.64   0.23  46.20    i3   1.5432     y    200   MBRANE
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

# General options
$datadir1 = "../../me_temp_proj/acis/"; # Location of /acis/ in relation to this script
$datadir2 = "/Volumes/MBRANE";          # Location of /acis/ in relation to this script
$datadir3 = "/Volumes/GALACTUS";          # Location of /acis/ in relation to this script
$rootdir  = "reprocessed/";             # where to find the cluster specific data
$verb     = 2;                          # how wordy the script should be whilst running

# energy bands
$rmin = 0000;         # soft band min in eV
$rmax = 1500;         # soft band max in eV
$gmin = 1500;         # mid band min in eV
$gmax = 2000;         # mid band max in eV
$bmin = 2000;         # hard band min in eV
$bmax = 9000;         # hard band max in eV
$bin = 2;             # binning factor

#######################
#######################
##   Main Program    ##
#######################
#######################

# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# read in the reference file
%refdata = sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # get obsid
  $name    = $data[0];
  $obsid   = $data[1];
  $x       = $data[2];
  $y       = $data[3];
  $rmax    = $data[4];
  $loc     = $data[15];
  $datadir = $datadir1 if ($loc eq "NAZGUL");
  $datadir = $datadir2 if ($loc eq "MBRANE");
  $datadir = $datadir3 if ($loc eq "GALACTUS");

  # change directory
  chdir("$datadir/$obsid/$rootdir/");

  # set general names
  $evtfile = "${obsid}_exclude.fits";
  $image = "${obsid}_colorimg.jpg";
  $psfile = "${obsid}_colorimg.ps";

  # catch error and move-on
  unless (-e $evtfile) {
    $offender = "no $evtfile";
    chdir($Bin);
    sub_logerror($offender);
    next;
  };

  # status
  print "## Creating image for $name $obsid\n";

  # create image
  sub_crimg($evtfile,$image,$psfile);

  # take care of postscript file
#  mkdir("$Bin/$profdir",0777) unless (-d "$Bin/$profdir");
#  system("cp -f ${sbps} $Bin/$profdir");

  # change back to original directory
  chdir("$Bin");
}

# email user that the task is complete
print "###### Finished making images at ",scalar(localtime),"######\n";

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};

# exit cleanly
exit 0;

#######################
#######################
##   Sub-Routines    ##
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

sub sub_logerror {

  my($offender) = @_;

  chdir("$Bin");
  open  ERRFILE,">>errors_image.log";
  print "${obsid} # failure in make_profile.pl, $offender ",scalar(localtime),"\n";
  print ERRFILE "${obsid} # failure in make_profile.pl, $offender ",scalar(localtime),"\n";
  close ERRFILE;
}

#######################
#######################

sub sub_crimg {

  my($evt,$img,$ps)=@_;

  my $reg  = "circle(${x},${y},${rmax})";
  $command = "punlearn dmcopy; dmcopy \"${evt}[sky=$reg]\" temp.fits verbose=$verb clobber=yes";
  system($command);

  $command = "punlearn dmimg2jpg; dmimg2jpg "
    ."\"temp.fits[energy=$rmin:$rmax][bin sky=$bin]\" "
      ."\"temp.fits[energy=$gmin:$gmax][bin sky=$bin]\" "
	."\"temp.fits[energy=$bmin:$bmax][bin sky=$bin]\" "
	  ."regionfile=\"\" "
	    ."outfile=\"$img\" "
	      ."showaimpoint=yes "
		."scalefunction=pow "
		  ."scaleparam=0.5 "
		    ."psfile=$ps "
		      ."verbose=$verb "
			."clobber=yes";
  system($command);
  unlink("temp.fits");

  # check that it worked or return an error
  if (-e $ps && -e $img) {
    print "\n## Created image and postscript\n";
    $fail = "no";
  } else {
    $fail = "yes";
  }
}

#######################
#######################

