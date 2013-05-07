#! /usr/bin/perl -w
#
# NAME:
#     addbg_rm_pt_src.pl (Additional background remove point sources)
#
# PURPOSE:
#     This script creates spectra which are used to fit for the
#     Galactic soft X-ray background which can be vital component to
#     model for regions of high emission (see the RASS maps). The
#     script removes pt srcs and extended srcs from the off-axis ACIS
#     chips and excises the same regions from the deep bgds. The
#     script then extracts a spectrum from the observation and deep
#     bgd and writes the appropriate header keywords. These specta can
#     then be read into Xspec for fitting (IT IS HIGHLY RECOMMENDED
#     THAT THE USER ADJUST THE BACKGROUND SPECTRUM FOR THE 9-12 KEV
#     COUNT RATE PRIOR TO FITTING IN XSPEC! THIS IS ACCOMPLISHED WITH
#     THE SCRIPT 'adj_backscal.pl' BY SETTING THE '@src' VARIABLE TO
#     'addex').
#
# EXPLANATION:
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
#     ** New files will be placed in the directory defined by the
#     variable $rootdir **
#
# CALLING SEQUENCE:
#     unix%> perl addbg_rm_pt_src.pl <reference list>
#
# FILES ASSUMED TO EXIST:
#     <obsid>_exclude.reg -- Region file containing pt srcs; this file
#                            is generated automatically by find_pt_src.pl
#
# INPUTS:
#     <reference list> -- File containing information about each cluster
#
#     Example:
#     #Name                      ObsID      X      Y   Rmax  MinCts        z   Nh20     Tx     Fe   Lbol  Chip    E_obs  Diff   Robs   Location
#     1E0657_56                   3184   3776   4026    590    5000   0.2960   6.53  11.64   0.23  46.20    i3   1.5432     y    200   /mnt/DROBO
#
# KEY OUTPUTS:
#  <obsid>_addex_src.pi     -- spectrum for the good regions of the off-axis source field
#  <obsid>_addex_src_grp.pi -- grouped spectrum
#  <obsid>_addex_bgd.pi     -- spectrum for the good regions of the deep bgd field
#  <obsid>_addex_bgd_grp.pi -- grouped spectrum
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$runwav   = "yes";                             # run pt src detection?
$extspec  = "yes";                             # should spectra be extracted?
$onlynew  = "yes";                             # only extract new spectra?
$grpcts   = 40;                                # grouping factor for extracted spectra
$ellsigma = 3;                                 # size of sigma ellipse enclosing pt src
$binning  = 8;                                 # binning factor, bigger=faster, smaller=precision
$scales   = "\"1.0 2.0 4.0 8.0 16.0 32.0\"";   # pixel scales to check, steps of 2^n (overkill is okay since you want source-free regions)
$wmaplo   = 300;                               # Lower bound for WMAP energy
$wmaphi   = 2000;                              # Upper bound for WMAP energy
$wmapbin  = "det=16";                          # Binning specification for WMAP
$rootdir  = "reprocessed/";                    # where to put reprocessed files
$verb     = 1;                                 # how wordy the script should be

#######################
#######################
##   Main Program    ##
#######################
#######################

# check the number of arguments given
die "Wrong number of command line arguments\n" if (@ARGV != 1);

# load useful libraries
# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# open err log
open(ERR,">>bgd_err.log");

# read in the reference file
%refdata = sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # get obsid
  $name    = $data[0];
  $obsid   = $data[1];
  $id      = $data[11];
  $datadir = $data[15];

  # define the ccd to use and file names
  $evtfile = "${obsid}_exclude.fits";

  # handle the bgfile name
  if ($id =~ /^i/) {
    $bgccd = "6";
    $bgfile = "${obsid}_s2_bgevt.fits";
  } else {
    $bgccd = "2";
    $bgfile = "${obsid}_i2_bgevt.fits";
  }
  $imgroot  = "${name}_${obsid}";
  $regfile  = "${obsid}_addex.reg";
  $src      = "${obsid}_addex_src.fits";
  $srcroot  = "${obsid}_addex";
  $deep     = "${obsid}_addex_bgd.fits";;
  $deepspec = "${obsid}_addex_bgd.pi";
  $deepgrp  = "${obsid}_addex_bgd_grp.pi";

  # change directory
  chdir("$datadir/$obsid/$rootdir/");

  # change the name if an alternate chip was used
  unless (-e $bgfile) {
    if ($id =~ /^i/) {
      $bgccd = "7";
      $bgfile = "${obsid}_s3_bgevt.fits";
    } elsif ($id =~ /^s/) {
      $bgccd = "3";
      $bgfile = "${obsid}_i3_bgevt.fits";
    } else {
      print "## You've given me a bad chip_id... sinner >:)\n";
    }
  }

  # make sure we have bgd files to work with
  unless (-e $bgfile) {
    print "## No bgd file for $obsid ($name)\n";
    print ERR "${obsid}: No bgd file\n";
    chdir($Bin);
    next;
  }

  # make sure we have events files to work with
  unless (-e $evtfile) {
    print "## No evt file for $obsid ($name)\n";
    print ERR "${obsid}: No evt file\n";
    chdir($Bin);
    next;
  }

  # make only new files
  if ($onlynew eq "yes") {
#      $fizzile = "${obsid}_addex_src1.wrmf";
      $fizzile = "${obsid}_addex_src1.pi";
      if (-e $fizzile) {
          print "## Already have $srcroot spec\n";
          next;
      }
  }

  # set badpix file
  sub_set_ardlib($evtfile);

  # get the asol file or files
  $asol = sub_get_asolfile();
  print "## Using aspect solution: $asol\n";

  # run wavdetect to get sources
  sub_run_wavdetect($evtfile,$imgroot) if ($runwav eq "yes");

  # check for radius=0 and NAN values
  sub_check_reg($regfile);

  # extract spectra
  sub_extr_spec($evtfile,$bgfile,$regfile,$srcroot,$asol) if ($extspec eq "yes");

  # clean-up temp files
  unlink "*_stk";
  unlink "temp.fits";

  # change back to original directory
  chdir($Bin);
}

close ERR;

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

sub sub_set_ardlib {

    my($chips,@chips,$evtfile,$d,$curdir,$indir);
    $indir = cwd();
    $evtfile = shift;
    system("punlearn ardlib.par");

    # change to appropriate dir (they sometimes change the locations)
    # glob for matching file names
    chdir "../";
    $curdir = cwd();
    @dir = qw(reprocessed primary secondary);
    @infile = ();
    foreach $dir (@dir) {
        chdir $dir;
        @globlist = glob("*bpix1*");
        @globlist = map { "$dir/" . $_} @globlist if (@globlist);
        push @infile, @globlist;
        chdir "../";
    }

    die "$obsid: No evt1 file\n" unless (@infile);
    $bpix   = shift @infile;

    # unzip if necesary
    if ($bpix =~ /gz$/) {
        system("gunzip -f $bpix");
        $bpix =~ s/\.gz$//;
    }

    # return the name
    chdir($curdir);

    # get the chips to use
    chdir("$rootdir");
    $chips = `dmkeypar $evtfile DETNAM ; pget dmkeypar value`;
    chdir("../");

    chomp($chips);
    $chips =~ s/ACIS\-//;
    @chips = split('', $chips);
    foreach $d (@chips) {
        $command = "pset ardlib AXAF_ACIS${d}_BADPIX_FILE=${curdir}/$bpix\[BADPIX${d}]";
        system($command);
    }

    chdir $indir;
}

#######################
#######################

sub sub_run_wavdetect {

  my($evtfile,$imgroot) = @_;
  my($imgfile,$outfile,$scellfile,$imagefile,$nbdgfile);

  # define local file names
  $outfile   = "${imgroot}_src.fits";
  $scellfile = "${imgroot}_scell.fits";
  $imagefile = "${imgroot}_imgfile.fits";
  $nbdgfile  = "${imgroot}_nbgd.fits";

  # isolate the bgd ccd
  $command = "punlearn dmcopy; dmcopy \"$evtfile\[ccd_id=${bgccd}\][bin sky=$binning]\" temp_src.fits clobber=yes verbose=$verb";
  system($command);

  # run wavdetect
  $command = "punlearn wavdetect; wavdetect infile=temp_src.fits outfile=$outfile scellfile=$scellfile "
    ."imagefile=$imagefile defnbkgfile=$nbdgfile regfile=$regfile ellsigma=${ellsigma} scales=$scales clobber=yes verbose=$verb";
  print "## Running wavdetect on $evtfile\n";
  system $command;

  unlink "temp_src.fits";
}

#######################
#######################

sub sub_check_reg {

    my($reg) = @_;
    my $temp = "temp.reg";
    open(TEMP,">$temp");

    # open the file
    open(REG,"$reg");
    while(<REG>){
	chomp;
	next if (/\,0\.00/ || /NAN/);
	print TEMP "$_\n";
    }
    close REG;
    # make sure the file has at least one entry
    print TEMP "circle(0,0,0)\n";
    close TEMP;
    system("mv -f $temp $reg");
}

#######################
#######################

sub sub_extr_spec {

  my($command);
  my($evt,$bg,$reg,$root,$asol) = @_;

  # now run the specextract command
  $command = "punlearn mkwarf; pset mkwarf asolfile=$asol";
  system($command);
  $command = "punlearn dmcopy; dmcopy \"$evt\[ccd_id=${bgccd}\]\" temp.fits clobber=yes verbose=$verb";
  system($command);
  $command = "punlearn dmcopy; dmcopy \"temp.fits[exclude sky=region(${reg})]\" ${src} clobber=yes verbose=$verb";
  system($command);
  $command = "punlearn specextract; specextract infile=\"$src\" "
    ."outroot=$srcroot bkgfile=\"\" grouptype=\"NUM_CTS\" energy_wmap=${wmaplo}:${wmaphi} binwmap=$wmapbin "
      ."binspec=$grpcts ptype=PI clobber=yes verbose=$verb";
  system($command);

  # extract the background spectrum
  $command = "punlearn dmcopy; dmcopy \"${bg}[exclude sky=region(${regfile})]\" ${deep} clobber=yes verbose=$verb";
  system($command);
  $command = "punlearn dmextract; dmextract infile=\"${deep}\[bin pi\]\" "
    ."outfile=${deepspec} wmap=\"[energy=${wmaplo}:${wmaphi}][bin $wmapbin]\" clobber=yes verbose=$verb";
  system($command);
  $command = "grppha infile=\"${deepspec}\" outfile=\"\!${deepgrp}\" chatter=0 comm=\"group min $grpcts & exit\"";
  system($command);

  # check that it worked or return an error
  unless (-e "${root}_src1_grp.pi" && -e "${root}_bgd_grp.pi") {
    $fail = "yes";
  } else {
    $fail = "no";
  }
}

#######################
#######################

sub sub_get_asolfile {

  # get the asol file or files
  my($curdir,@infile,$asol,@dir,@globlist);
  $curdir = cwd();

  # change to appropriate dir (they sometimes change the locations)
  @dir = qw(primary secondary);
  @infile = ();
  foreach $dir (@dir) {
    chdir "../$dir";
    @globlist =  <pcad*asol*.fits*>;
    @globlist = map { "../$dir/" . $_} @globlist if (@globlist);
    push @infile, @globlist;
    chdir $curdir;
  }

  die "No asol files found.  Exiting.\n" unless (@infile);
  $asol = join(",",@infile);

  # return the name(s)
  chdir($curdir);
  return $asol;
}

#######################
#######################

# deprecated, but kept around... for some reason
#  $srcgrp   = "${obsid}_addex_src_grp.pi";
#  $deepgrp  = "${obsid}_addex_bgd_grp.pi";
#      $command = "punlearn dmextract; dmextract \"${src}[bin pi]\" ${srcspec} wmap=\"[energy=500:2000][bin det=8]\" clobber=yes verbose=$verb";
#      system($command);
#      $command = "punlearn dmcopy; dmcopy \"${bgfile}[exclude sky=region(${regfile})]\" ${deep} clobber=yes verbose=$verb";
#      system($command);
#      $command = "punlearn dmextract; dmextract \"${deep}[bin pi]\" ${deepspec} wmap=\"[energy=500:2000][bin det=8]\" clobber=yes verbose=$verb";
#      system($command);
#  }
#  if ($grpspec eq "yes") {
#      $command = "grppha infile=\"${srcspec}\" outfile=\"\!${srcgrp}\" chatter=0 comm=\"group min $grpcts & exit\"";
#      system($command);
#  }
