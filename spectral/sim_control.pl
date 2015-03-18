
#!/usr/bin/perl -w
#
# NAME:
#     sim_spec.pl
#
# PURPOSE:
#
# EXPLANATION:
#     This script takes in the properties of an object (ie: tx, fe, lbol,
#     nh20, etc), observation specific ARF and RMF, and simulates
#     a spectrum using XSpec's 'fakeit' command.
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
#
# CALLING SEQUENCE:
#     sim_spec.pl <reference list> <data file>
#     IE:
#     perl sim_spec.pl reference.list ../fits/dat/adj_r2500-50_nhfro_fefree_7-7.dat
#     perl sim_spec.pl reference.list ../fits/dat/c2fits_final_fefree_7-7.dat
#
# INPUTS:
#     <reference list> = file containing information about each cluster
#     the assumed format for the list is as follows:
#     in the case of X and Y being the centroid position in pixels and Rmax in pixels
#     Name            ObsID      X      Y   Rmax  MinCts        z   Nh20     Tx     Fe   Lbol  Chip    E_obs  Diff
#     ABELL_0611       3194   4131   3943    360    5000   0.2880   4.99   1.23   0.30  45.67    s3   1.5528     n
#     ABELL_2537       4962   3949   4157    360    5000   0.2950   4.26   1.23   0.30  45.67    s3   1.5444     n
#
# OUTPUTS:
#     faked spectrum:     <obsid>_<energy band>_spec.fak
#     xcm file for xspec: <obsid>_<energy band>_fak.xcm
#     log of creation:    <obsid>_<energy band>_fak.xcm.log
#     model parameters:   <obsid>_<energy band>_fak.xcm.model
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

# set system parameters
$datadir1 = "/Volumes/HD1/";
$datadir2 = "/Volumes/MBRANE/";
$datadir2 = "/Volumes/GALACTUS/";
$rootdir  = "reprocessed/";
$quiet    = "yes";
$cleanup  = "yes";            # remove existing files with the same name
$datfile  = "/Users/cavagnolo/research/me_temp_proj/me_fits/dat/c2fits_final_r2500-50_fefree_7-7.dat";

# set sim parameters
$xspecver = "xspec11";       # version of Xspec to invoke
$runname = "r2500-50";       # name of the source region to simulate
$output  = "control";        # root name of output spec: <obsid>_<output>
$model   = "mekal";          # model to use in faking spectra
$nhmod   = "wabs";           # e.g., wabs, tbabs, ph
$grpcts  = "25";             # number of counte per channel to group
$src     = "src1";           # extension of the RMF and ARF spectral files to use
$bg      = "bgd_adj";        # extension of the BGD spectral files to use
$h0      = "70";             # cosmology: value of H_0
$q0      = 0.0;                              # norm. acceleration (ignored by Xspec)
$omegal  = "0.7";            # cosmology: value of Omega_lambda
$syserr  = "0.00";           # % systematic error to add
$simnum  = 35;               # number of sim'd spec for each obsid

#######################
#######################
##   Main Program    ##
#######################
#######################

# check input params
$nargs = @ARGV;
die "Incorrect number of parameters\n" if ($nargs != 1);

# read in the reference file
%refdata = sub_get_data($ARGV[0]);
%fitdata = sub_get_data($datfile);

# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# open a log file
open(ERR,">>err_sim_control.log");

# go through each cluster in reference list
foreach $key (sort keys %refdata) {

  # split up the data line
  @ref = split(/\s+/,$refdata{$key});
  @fit  = split(/\s+/,$fitdata{$key});

  # get values from ref file
  $name  = $ref[0];
  $obsid = $ref[1];
  $z     = $ref[6];
  $loc   = $ref[15];
  $datadir = $datadir1 if ($loc eq "NAZGUL");
  $datadir = $datadir2 if ($loc eq "MBRANE");
  $datadir = $datadir2 if ($loc eq "GALACTUS");

  # check for fit data
  unless (@fit) {
    chdir("$Bin");
    print "## Missing fit info for ${obsid} ${name}, check logfile for report.\n";
    print ERR "${obsid} : no fit data in ${datfile}\n";
    next;
  }

  # get values from dat file
  $nh       = $fit[4]*1e-2;
  $tx       = $fit[7];
  $fe       = $fit[10];
  $normbf   = $fit[13];
  $realrate = $fit[23];
  $realrate = 0.001 if ($realrate <= 0.00);

  # change directory
  chdir("$datadir/$obsid/$rootdir");

  # define some names
  $bgd  = "${name}_${obsid}_${runname}_${bg}.pi";
  $rmf  = "${name}_${obsid}_${runname}_${src}.wrmf";
  $arf  = "${name}_${obsid}_${runname}_${src}.warf";
  $root = "${obsid}_${output}";

  # exit via next if there are no arf or rmf files
  unless (-e $rmf && -e $arf) {
    chdir("$Bin");
    print "## Missing response(s) for ${obsid} ${name}, check logfile for report.\n";
    print ERR "${obsid} : no $rmf or $arf\n";
    next;
  }

  # remove existing files with same root
  if ($cleanup eq "yes") {
      @remy = glob("${root}*.fak");
      foreach $reme (@remy) {
	  print "## Removing: $reme, it's in the way...\n";
	  system("rm -f $reme");
      }
  }

  # determine the exposure time for this observation
  $exposure = sub_get_expotime();
  if ($fail eq "yes") {
    chdir("$Bin");
    print ERR "${obsid} : no exposure time\n";
    next;
  }

  print "## Working on ${obsid}\n";

  $jj = 1;
  # start simming the control sample
  while ($jj <= $simnum) {

    # initialize the FAIL control
    $fail    = "no";

    # build some other variables
    $norm1   = $normbf if ($normbf > 0);
    $fak     = "${root}_${jj}spec.fak";
    $fakgrp  = "${root}_${jj}spec_grp.fak";
    $xcmfile = "${root}_${jj}fak.xcm";

    # print model to XCMFILE, get parameters for con limit determination
    sub_make_xcmfile($nhmod,$model,$xcmfile);

    # run xspec (see subroutine sub_run_xspec) with a timeout
    $frac = sub_run_xspec($xcmfile,$bgd,$rmf,$arf,$fak,$exposure,$realrate,$root);

    # echo the progress of the fitter in quiet mode
    if ($quiet eq "yes") {
	$out1 = sprintf("%3.2f",(abs($frac-1))*100);
	$out2 = sprintf("%.6f",$norm1);
	print "## sim ${jj}: real/fake-- $out1\% ; ",
	"norm1-- $out2\n";
    }

    # group the spectra to the proper number of counts
    $command = "grppha infile=\"$fak\" outfile=\"\!$fakgrp\" chatter=0 comm=\"group min $grpcts & exit\"";
    system($command);

    # increment the eta counter
    $jj++;
  }

  # clean-up the resulting mess of files
  unlink <*fak*.xcm>;
  unlink <xautosav*>;
#  unlink <*spec.fak>;

  # change back to original directory
  chdir("$Bin");
}

# return with everything okay
close ERR;
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_get_data {

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

sub myprint {
  my $line;
  foreach $line (@_) {
    print $line unless ($quiet eq "yes");
    print XSPEC_INPUT $line;
  }
}

#######################
#######################

sub sub_make_xcmfile {

  # input vaules
  my($nhmod,$model,$xcmfile) = @_;

  # other local variables
  my($modstring,$line);

  # clean up any files left over from previous runs
  unlink "$xcmfile";

  # print to XCM file
  open(XCMFILE,">$xcmfile");
  print XCMFILE "query yes\n";
  print XCMFILE "cosmo ${h0} ${q0} ${omegal}\n";

  # MEKAL+MEKAL model###################################################
  if ($model eq "mekal") {
    $modstring = "${nhmod}(mekal)";
    $moline = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & $norm1 /*";
    # Unknown model or error##############################################
  } else {
    die "Unknown model: $model\n";
  }

  # print the fakeit commands
  $fakline = "fakeit $bgd & $rmf & $arf & y & \\n & $fak & $exposure /*";

  # print out model
  print XCMFILE "model $modstring $moline\n",
  "$fakline\n";

  # add in systematic error
  print XCMFILE "systematic $syserr\n" unless ($syserr == 0);
  print XCMFILE "tclout rate\n";
  print XCMFILE "puts \"Hey rate \$xspec_tclout\"\n";

  # done with the xcm file, close
  close XCMFILE;
}

#######################
#######################

sub sub_run_xspec {

  my ($xcmfile,$bgd,$rmf,$arf,$fak,$exp,$realrate,$root) = @_;

  # get rid of old files
  unlink("$fak");
  unlink("${xcmfile}.model");
  unlink("${xcmfile}.log");

  # starts xspec (perl and read and write from/to it)
  # $pid is a global variable that can be used to kill xspec
  use IPC::Open3;
  $pid = open3(*XSPEC_INPUT,*XSPEC_OUTPUT,*XSPEC_ERR,"$xspecver") || die "Can't run xspec\n";

  # open the xcmfile written earlier and feed to xspec
  myprint "\@${xcmfile}\n";
  myprint "query no\n";

  while (<XSPEC_OUTPUT>) {
    chomp($line = $_);
    print "xspec: $line\n" unless ($quiet eq "yes");
    if ($line =~ m/^Hey rate/) {
      @fakerate = split(/\s+/,$line);
      $fakerate = $fakerate[2];
      $fakerate =~ s/\+\/\-//; # remove +/- on some values
      $frac = $fakerate/$realrate;

      # all done quit XSPEC
      myprint "exit\n\n";

    }
  }

  close XSPEC_INPUT;
  close XSPEC_OUTPUT;
  close XSPEC_ERR;
  waitpid($pid,0);
  return $frac;

}

#######################
#######################

sub sub_get_expotime {

  # get and format keyword value from file
  my($evt2) = "${obsid}_exclude.fits";
  my $value = `punlearn dmkeypar; dmkeypar ${evt2} EXPOSURE; pget dmkeypar value`;
  chomp($value);      # remove any newline
  $value =~ s/\s+//g; # remove white space
  $value =~ s/\'//g;  # remove quotes

  # check that it worked or return an error
  if ($value > 0) {
    $fail = "no";
    return $value;
  } else {
    $fail = "yes";
  }
}

#######################
#######################
