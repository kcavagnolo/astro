#! /usr/bin/perl -w
#
# NAME:
#     extract_source.pl
#
# PURPOSE:
#     Create the PI, ARF, and RMF files from a flare cleaned
#     and point source cleaned level 2 events file. The output
#     of this script can then be read into a spectral fitting
#     program to calculate temperatures, metallicities, and
#     other physical parameters.
#
# EXPLANATION:
#     Script assumes FITS files and region files are located in:
#     /$datadir/acis/$obsid/reprocessed
#
# CALLING SEQUENCE:
#     extract_spectra.pl <reference list>
#
# INPUTS:
#     Clean level 2 events file:             <obsid>_exclude.fits
#     Reprojected background events file:    <obsid>_bgevt.fits
#     Annular region files for extraction:   <cluster name>_<obsid>_<chipid>_<run name><annuli number>.reg
#     Local background regions:              <cluster name>_<obsid>_localbgd.reg
#     Reference list of clusters to be used: <reference list>.list
#     the assumed format for the list is as follows:
#     #Name                          ObsID        X        Y   Rmax     MinCts         z  Nh20     Tx     Fe  Lbol ChipID
#     ABELL_0644                      2211   3908.5   4332.5  243.9       5000    0.0704  6.41   8.64   0.35 45.00     s3
#     ABELL_1651                      4185   4222.5   4034.5  132.3       5000    0.0844  1.88   5.97   0.30 45.00     s3
#
# OUTPUTS:
#     Background spectrum:                                    <cluster name>_<obsid>_<run name><annulus number>_bgd.pi
#     Source spectrum for a particular annulus (PI):          <cluster name>_<obsid>_<run name><annulus number>_sou.pi
#     Auxiliary Response Function (ARF):                      <cluster name>_<obsid>_<run name><annulus number>_sou.warf
#     or in the case of non-weighted emission:                <cluster name>_<obsid>_<run name><annulus number>_sou.arf
#        http://cxc.harvard.edu/ciao/dictionary/arf.html
#     FITS Embedded Function (FEF):                           <cluster name>_<obsid>_<run name><annulus number>_sou.wfef
#        http://cxc.harvard.edu/ciao/dictionary/fef.html
#     Weight Map (only if using script in "extended" mode):   <cluster name>_<obsid>_<run name><annulus number>_sou.wmap
#     Redistribution Matrix File (RMF):                       <cluster name>_<obsid>_<run name><annulus number>_sou.wrmf
#     or in the case of non-weighted emission:                <cluster name>_<obsid>_<run name><annulus number>_sou.rmf
#        http://cxc.harvard.edu/ciao/dictionary/rmf.html
#
# MODIFICATION HISTORY:
#     May 3, 2005 --- Ken Cavagnolo
#        added extensive header in IDL format
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$extract_source    = "yes";           # Extract spectrum for one region around source
$extract_deepbgd   = "yes";           # Extract spectrum for one region around source
$extract_localbgd  = "no";           # Extract local bgd spec instead of deep bgd
$set_xflt_keywords = "yes";           # Set the pointer keywords, leave at "yes" unless you know for sure what you're doing
#@regex             = qw(r200 r500 r1000 r2500 r5000 r7500 r200-core r500-core r1000-core r2500-core r5000-core r7500-core);
@regex             = qw(rcoolz354);
$evtext            = "exclude";         # extension of file to use
%localext          = ("nc" => "ncbgd",
		      "wc" => "wcbgd",
		      "ec" => "ecbgd");   # Extension of local bgd spec
$binspec           = "25";            # counts per bin
$onlynew           = "no";           # make only new files
$wmaplo            = 300;             # Lower bound for WMAP energy
$wmaphi            = 2000;            # Upper bound for WMAP energy
$wmapbin           = "det=8";         # Binning specification for WMAP
$rootdir           = "reprocessed";
$verb              = 3;

#######################
#######################

# check for ciao env loaded
use Cwd;
use FindBin qw($Bin);
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# read in the reference file
foreach $regex (@regex) {
%refdata  = sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
{
  foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get obsid
    $name    = $data[0];
    $obsid   = $data[1];
    $rmax    = $data[4];
    $datadir = $data[15];
    $fail    = "no";

    # change directory
    chdir("$datadir/$obsid/$rootdir/");
    print "\n## Starting work on $obsid ($name)\n";

    # define and check for file names
    $evtfile   = "${obsid}_${evtext}.fits";
    $bgfile    = "${obsid}_bgevt.fits";
    $sourcereg = "${obsid}_${regex}.reg";
    $root      = "${name}_${obsid}_${regex}_src1";
    if ($extract_localbgd eq "yes") {
	$lext = $localext{$regex};
	$localbgd  = "${obsid}_${lext}.reg";
    }

    # catch error and move-on
    unless (-e $evtfile && -e $bgfile && -e $sourcereg) {
      $offender = "no $evtfile" unless (-e $evtfile);
      $offender = "no $bgfile" unless (-e $bgfile);
      $offender = "no $sourcereg" unless (-e $sourcereg);
      print "## $offender for $obsid ($name)\n";
      chdir($Bin);
      sub_logerror($offender);
      next;
    };

    # make only new files
    if ($onlynew eq "yes") {
        $fizzile = "${root}.pi";
        if (-e $fizzile) {
	    print "## Already have $root spec\n";
	    chdir("$Bin");
	    next;
        }
    }

    # set badpix file
    sub_set_ardlib($evtfile);

    # get the asol file or files
    $asol = get_asolfile();
    print "## Using aspect solution: $asol\n";
    $pbk  = get_pbkfile();
    print "## Using parameter block file: $pbk\n";

    # extract spectrum for entire cluster
    print "## Extracting source spectrum for region $regex\n";
    sub_extract_src($evtfile,$sourcereg,$root) if ($extract_source eq "yes") ;
    if ($fail eq "yes") {
      $offender = "sub_extract_src";
      sub_logerror($offender);
      next;
    }
    print "## Source spectrum extraction complete\n";
    print "## Extracting background spectrum\n";
    print "## Background spectrum extraction complete\n";

    # extract local background spectrum
    if ($extract_deepbgd eq "yes") {
      sub_extract_bgd($bgfile,$sourcereg,$root);
      if ($fail eq "yes") {
	$offender = "sub_extract_bgd";
	sub_logerror($offender);
	next;
      }
    } elsif ($extract_localbgd eq "yes") {
      sub_extract_local($evtfile,$localbgd);
      if ($fail eq "yes") {
	$offender = "sub_ext_localbgd";
	sub_logerror($offender);
	next;
      }
    }

    # set header keywords
    print "## Setting XFLT keywords\n";
    sub_set_xflt_keywords($root) if ($set_xflt_keywords eq "yes");
    if ($fail eq "yes") {
      $offender = "sub_set_xflt_keywords";
      sub_logerror($offender);
      next;
    }

    print "## Finished with $obsid ($name)\n";

    # change back to original directory
    chdir("$Bin");
  }
}

}

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};
exit 0;

######################
######################
##   Sub-Routines   ##
######################
######################

sub sub_read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile);
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

sub get_values {
    open(IN,$sourcereg) || die "## ERROR: Cannot open $sourcereg\n";
    while(<IN>) {
      chomp;
      next if (/^\#/);
      next if (/^$/);
      s/^\s+//;
      s/\s+$//;
      @info = split(/,/);
      $rout = pop @info;
      $rout =~ s/\)//;
    }
    if ($rout =~ m/\'$/) {
	$rout =~ s/\'//;
	$rmax = sprintf("%f",$rout/60.0);
    } else {
	$rmax = sprintf("%f",$rout*0.492/60.0);
    }
    return $rmax;
}

#######################
#######################

sub sub_extract_src {
  my($command);
  my($evtfile,$sourcereg,$root) = @_;

  # set asol file
  $command = "punlearn mkwarf; pset mkwarf asolfile=$asol";
  system($command);

  # now run the specextract command
  if ($obsid eq "1226" ||
      $obsid eq "1190" ||
      $obsid eq "1196" ||
      $obsid eq "1228") {
      $command = "punlearn specextract; specextract infile=\"$evtfile\[sky=region($sourcereg)]\" "
          ."outroot=$root bkgfile=\"\" energy=\"0.3:9.5:0.01\" energy_wmap=${wmaplo}:${wmaphi} binwmap=$wmapbin "
          ."pbkfile=$pbk, grouptype=\"NUM_CTS\" binspec=$binspec ptype=PI clobber=yes verbose=$verb";
      system($command);
  } else {
      $command = "punlearn specextract; specextract infile=\"$evtfile\[sky=region($sourcereg)]\" "
          ."outroot=$root bkgfile=\"\" grouptype=\"NUM_CTS\" energy_wmap=${wmaplo}:${wmaphi} binwmap=$wmapbin "
	  ."pbkfile=$pbk binspec=$binspec ptype=PI clobber=yes verbose=$verb";
      system($command);
  }

  # delete grouping keyword which confuses XSPEC
  $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=del key=GROUPING file=\"\"";
  system($command);

  # delete quality keyword which confuses XSPEC
  $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=del key=QUALITY file=\"\"";
  system($command);

  # check that it worked or return an error
  unless (-e "${root}_grp.pi") {
    $fail = "yes";
  } else {
    $fail = "no";
  }
}

#######################
#######################

sub sub_extract_bgd {
  my($command);
  my($bgfile,$sourcereg,$root) = @_;

  # extract the background spectrum
  $command = "punlearn dmextract; dmextract infile=\"${bgfile}\[sky=region($sourcereg)\]\[bin pi\]\" "
    ."outfile=${root}_bgd.pi wmap=\"[energy=${wmaplo}:${wmaphi}][bin $wmapbin]\" clobber=yes";
  system($command);

  # add BACKFILE keyword to spectrum header
  $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=add key=BACKFILE value=${root}_bgd.pi filelist=\"\"";
  system($command);

  # check that it worked or return an error
  unless (-e "${root}_bgd.pi") {
    $fail = "yes";
  } else {
    $fail = "no";
  }
}

#######################
#######################

sub sub_set_xflt_keywords {
  my($root) = @_;
  $rout = get_values($sourcereg);

  # check that we have a value
  if ($rout > 0) {
    $fail = "no";
  } else {
    $fail = "yes";
    return;
  }

  # set the keywords
  $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=add key=XFLT0001 value=$rout filelist=\"\"";
  system($command);
  $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=add key=XFLT0002 value=$rout filelist=\"\"";
  system($command);
  $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=add key=XFLT0003 value=0 filelist=\"\"";
  system($command);
  $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=add key=BACKFILE value=${root}_bgd.pi filelist=\"\"";
  system($command);
  $command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=add key=XFLT0001 value=$rout filelist=\"\"";
  system($command);
  $command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=add key=XFLT0002 value=$rout filelist=\"\"";
  system($command);
  $command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=add key=XFLT0003 value=0 filelist=\"\"";
  system($command);
  $command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=add key=BACKFILE value=${root}_bgd.pi filelist=\"\"";
  system($command);

  # set localbgd keyword
  if ($extract_localbgd eq "yes") {
    $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=del key=BACKFILE filelist=\"\"";
    system($command);
    $command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=del key=BACKFILE filelist=\"\"";
    system($command);
    $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=add key=BACKFILE value=${root}_${lext}.pi filelist=\"\"";
    system($command);
    $command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=add key=BACKFILE value=${root}_${lext}.pi filelist=\"\"";
    system($command);
  }
}

#######################
#######################

sub sub_logerror {

  my($offender) = @_;

  chdir("$Bin");
  open  ERRFILE,">>err_extract_source.log";
  print "${obsid} # failure in extract_source.pl, $offender ",scalar(localtime),"\n";
  print ERRFILE "${obsid} # failure in extract_source.pl, $offender ",scalar(localtime),"\n";
  close ERRFILE;
}

#######################
#######################

sub get_asolfile {

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

sub sub_extract_local {

  my($command);
  my($evtfile,$localbgd) = @_;

  # extract the local background spectrum
  $command = "punlearn dmextract; dmextract infile=\"$evtfile\[sky=region($localbgd)\]\[bin pi\]\" "
      ."outfile=${root}_${lext}.pi clobber=yes verbose=$verb";
  system($command);

  # check that it worked or return an error
  unless (-e "${root}_${lext}.pi") {
    $fail = "yes";
  } else {
    $fail = "no";
  }
}

#######################
#######################

sub get_pbkfile {

  # get the pbk file or files
    my($curdir,@infile,$pbk,@dir,@globlist);
    $curdir = cwd();

  # change to appropriate dir (they sometimes change the locations)
    @dir = qw(primary secondary);
    @infile = ();
    foreach $dir (@dir) {
	chdir "../$dir";
	@globlist =  <*pbk*.fits*>;
	@globlist = map { "../$dir/" . $_} @globlist if (@globlist);
	push @infile, @globlist;
	chdir $curdir;
    }

    die "No pbk files found.  Exiting.\n" unless (@infile);
    $pbk = join(",",@infile);

  # return the name(s)
    chdir($curdir);
    return $pbk;
}

#######################
#######################
