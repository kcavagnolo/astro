#! /usr/bin/perl -w
#
# NAME:
#     extract_spectra.pl
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

$extract_sou_annuli = "no";          # Extract spectrum for source using annuli
$extract_bgd_annuli = "no";          # Extract background spectrum
$set_keys = "yes";
$evtext   = "exclude";                # Extension name of events file
$runname  = "annuli";                 # The name of the annuli to use
$multiex  = "no";
$onlynew  = "no";                    # make only new files
$fext     = "wrmf";                   # extension of spec file
$binning  = 20;                       # Binning specification for spectra
$rootdir  = "reprocessed/";           # where to find the cluster specific data
$wmaplo   = 300;                      # Lower bound for WMAP energy
$wmaphi   = 2000;                     # Upper bound for WMAP energy
$wmapbin  = "det=8";                  # Binning specification for WMAP
$bgdwmapbin = "det=8";                # Binning specification for WMAP
$verb = 0;
$extract_localbgd   = "no";           # Extract a local background for the last annulus and set the needed keywords
$locext   = "localbgd";               # Extension name of local bgd region

#######################
#######################

# Check the number of arguments given
use Cwd;
use FindBin qw($Bin);
die "## ERROR: CIAO is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "## ERROR: Wrong number of command line arguments\n" if (@ARGV != 1);

# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# define chips
%chip_id = ("" =>"0", "i0" =>"0", "i1" =>"1", "i2" =>"2", "i3" =>"3", "s0"
            =>"4", "s1" =>"5", "s2" =>"6", "s3" =>"7", "s4" =>"8",
            "s5" =>"9");

# status
print "## Started extraction at ",scalar(localtime),"##\n";
%refdata = sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
{
  foreach $key (sort keys %refdata) {

      # split up the data line
      @data = split(/\s+/,$refdata{$key});
      $name    = $data[0];
      $obsid   = $data[1];
      $datadir = $data[15];
      if ($data[11] =~ /^s/) {
	  $id = $chip_id{$data[11]};
      } else {
	  $id = "0,1,2,3";
      }

      # change directory
      chdir("$datadir/$obsid/$rootdir/");

      # define and check for file names
      $evtfile  = "${obsid}_${evtext}.fits";
      $bgfile   = "${obsid}_bgevt.fits";
      $bpix     = "${obsid}_bpix.fits";
      @regions  = glob("*_${runname}*.reg");
      $localbgd = "${obsid}_${locext}.reg";
      $fail     = "no";

      # get number of annuli
      $size = $#regions+1;
      print "## STATUS: Starting work on...\n";
      print "## STATUS: Name: $name\n";
      print "## STATUS: Obsid: $obsid\n";
      print "## STATUS: Annuli to extract: $size\n";

      # catch error and move-on
      unless (-e $evtfile && -e $bgfile && -e $bpix && @regions) {
	  $offender = "no $evtfile" unless (-e $evtfile);
	  $offender = "no $bgfile" unless (-e $bgfile);
	  $offender = "no $bpix" unless (-e $bpix);
	  $offender = "no region files" unless (-e @regions);
	  sub_logerror($offender);
	  next;
      }

      # set badpix file
      system(`punlearn ardlib.par; punlearn acis_set_ardlib`);
      system(`acis_set_ardlib $bpix verb=0`);

      # get the asol file or files
      $asol = sub_get_afile('pcad*asol*.fits*');
      if ($fail eq "yes") {
	  $offender = "no asol";
	  sub_logerror($offender);
	  next;
      }
      $pbk  = sub_get_afile('*pbk*.fits*');
      if ($fail eq "yes") {
	  $offender = "no pbk";
	  sub_logerror($offender);
	  next;
      }
      $msk  = sub_get_afile('*msk1*.fits*');
      if ($fail eq "yes") {
	  $offender = "no msk";
	  sub_logerror($offender);
	  next;
      }

      # need to make a single apshist
      $aspfile = "spec.asphist";
      unless (-e $aspfile) {
	  $command = "punlearn asphist; asphist infile=$asol outfile=$aspfile"
	      ." evtfile=\"$evtfile\[ccd_id=${id}\]\" clob+ verbose=0";
	  system($command);
	  unless (-e $aspfile) {
	      $offender = "create asphist";
	      sub_logerror($offender);
	      next;
	  }
      }

      # extract spectra for annuli
      foreach $reg (@regions) {

	  # set some names
	  $fail = "no";
	  $sourcereg = $reg;
	  $anum = $reg;
	  $anum =~ s/.*${runname}(\d+)\.reg/$1/;
	  $root = "${name}_${obsid}_${runname}${anum}_src1";

	  # make only new files
	  if ($multiex eq "yes" && -e "${root}.busy") {
	      print "## STATUS: Already working on $root\n";
	      next;
	  } else {
	      system("touch ${root}.busy");
	  }

	  # make only new files
	  if ($onlynew eq "yes" && -e "${root}.${fext}") {
	      print "## STATUS: Already have $root spec\n";
	      next;
	  }

	  # run acisspec script to extract and make cal files
	  print "## STATUS: Working on $root\n";
	  sub_ext_src($evtfile,$sourcereg,$root) if ($extract_sou_annuli eq "yes");
	  if ($fail eq "yes") {
	      $offender = "sub_ext_src: $reg";
	      sub_logerror($offender);
	      next;
	  }

	  # extract background spectrum
	  sub_ext_bgd($bgfile,$sourcereg,$root) if ($extract_bgd_annuli eq "yes");
	  if ($fail eq "yes") {
	      $offender = "sub_ext_bgd: $reg";
	      sub_logerror($offender);
	      next;
	  }

	  # set the XFLT keywords need by XSPEC deprojection model
	  sub_set_xflt_keywords($root) if ($set_keys eq "yes");
	  print "## STATUS: Done with $root\n";
      }

      # extract local background spectrum
      sub_ext_localbgd($evtfile,$localbgd) if ($extract_localbgd eq "yes");
      $fail = "no";
      if ($fail eq "yes") {
	  $offender = "sub_ext_localbgd";
	  sub_logerror($offender);
	  next;
      }

      # change back to original directory
      unlink("*${runname}*.busy");
      unlink($aspfile);
      print "## Finished with $obsid ($name)\n";
      chdir("$Bin");
  }
}

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
print "## Finished extraction at ",scalar(localtime),"##\n";
delete $ENV{'DYLD_BIND_AT_LAUNCH'};
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_file {

    my($infile) = @_;
    my(@data,$name,%info);
    open(INFILE,$infile) || die "## ERROR: Cannot open $infile\n";
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

sub sub_ext_src {

    my($command);
    my($evtfile,$sourcereg,$root) = @_;
    $command = "punlearn specextract; specextract infile=\"$evtfile\[sky=region($sourcereg)]\" "
	."outroot=$root bkgfile=\"\" grouptype=\"NUM_CTS\" binspec=$binning ptype=PI "
	."energy_wmap=${wmaplo}:${wmaphi} binwmap=$wmapbin asp=$aspfile pbkfile=$pbk mskfile=$msk "
	."weight=yes correct=no combine=no clobber=yes verbose=$verb";
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

sub sub_ext_bgd {

    my($command,$wbin);
    my($bgfile,$sourcereg,$root) = @_;
    $command = "punlearn dmextract; dmextract infile=\"${bgfile}\[sky=region($sourcereg)\]\[bin pi\]\" "
	."outfile=${root}_bgd.pi wmap=\"[energy=${wmaplo}:${wmaphi}][bin $bgdwmapbin]\" clobber=yes verbose=$verb";
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

sub sub_ext_localbgd {

    my($command,@annlist,@numbers,$base,$ext,$f,$n,$last,$lastann);
    my($evtfile,$localbgd) = @_;

    # extract the local background spectrum
    $command = "punlearn dmextract; dmextract infile=\"$evtfile\[sky=region($localbgd)\]\[bin pi\]\" "
	."outfile=${name}_${obsid}_localbgd.pi clobber=yes verbose=$verb";
    system($command);

    # find the last annulus
    @annlist = `ls ${name}_${obsid}_${runname}*_src1.pi`;
    @numbers = ();
    $base    = "${name}_${obsid}_${runname}";
    $ext     = "_src1.pi";
    foreach $f (@annlist) {
	$n = $f;
	$n =~ s/^.*annuli//;
	$n =~ s/$ext\n//;
	push (@numbers,$n);
    }
    @sorted = sort{$a<=>$b}@numbers;
    $last = $sorted[$#sorted];
    $lastann = "$base$last$ext";
    
    # delete the bgd keyword in the source.pi file for the last annulus
    $command = "punlearn dmhedit; dmhedit infile=$lastann operation=del key=BACKFILE filelist=\"\"";
    system($command);

    # re-write the local bgd as the bgd file for the last source annulus' pi file
    $command = "punlearn dmhedit; dmhedit infile=$lastann operation=add key=BACKFILE value=${name}_${obsid}_localbgd.pi filelist=\"\"";
    system($command);

    # check that it worked or return an error
    unless (-e "${name}_${obsid}__localbgd.pi") {
	$fail = "yes";
    } else {
	$fail = "no";
    }
}

#######################
#######################

sub sub_set_xflt_keywords {

    my($root) = @_;

    # get r_out and check value
    $rout = sub_get_radii($sourcereg);
    if ($rout > 0) {
	$fail = "no";
    } else {
	$fail = "yes";
	return;
    }
    $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=add key=XFLT0001 value=$rout filelist=\"\""
	." ; punlearn dmhedit; dmhedit infile=${root}.pi operation=add key=XFLT0002 value=$rout filelist=\"\""
    	." ; punlearn dmhedit; dmhedit infile=${root}.pi operation=add key=XFLT0003 value=0 filelist=\"\""
    	." ; punlearn dmhedit; dmhedit infile=${root}.pi operation=add key=BACKFILE value=${root}_bgd.pi filelist=\"\""
    	." ; punlearn dmhedit; dmhedit infile=${root}.pi operation=del key=GROUPING file=\"\""
    	." ; punlearn dmhedit; dmhedit infile=${root}.pi operation=del key=QUALITY file=\"\"";
    system($command);
    $command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=add key=XFLT0001 value=$rout filelist=\"\""
    	." ; punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=add key=XFLT0002 value=$rout filelist=\"\""
    	." ; punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=add key=XFLT0003 value=0 filelist=\"\""
    	." ; punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=add key=BACKFILE value=${root}_bgd.pi filelist=\"\"";
    system($command);
}

#######################
#######################

sub sub_get_radii {

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
    if ($rout =~ /\'/) {
	$rmax = $rout;
	$rmax =~ s/\'//;
	$rmax = sprintf("%.4f",$rmax);
    } else {
	$rmax = sprintf("%.4f",$rout*0.492/60);
    }
    return $rmax;
}

#######################
#######################

sub sub_logerror {
    my($offender) = @_;
    chdir("$Bin");
    open  ERRFILE,">>err_extract_spectra.log";
    print "## ERROR: extract_spectra.pl failure in $offender (ObsID $obsid) ",scalar(localtime),"\n";
    print ERRFILE "${obsid} # FAILURE: extract_spectra.pl; $offender; ",scalar(localtime),"\n";
    close ERRFILE;
}

#######################
#######################

sub sub_get_afile {

    # get the asol file or files
    my $akey = $_[0];
    my $curdir = cwd();

    # change to appropriate dir (they sometimes change the locations)
    my @dir = qw(primary secondary);
    my @globlist = ();
    my @infile = ();
    foreach $dir (@dir) {
	chdir "../$dir";
	@globlist =  glob("$akey");
	if (@globlist) {
	    @globlist = map { "../$dir/" . $_} @globlist;
	    push @infile, @globlist;
	}
	chdir $curdir;
    }

    # check that it worked or return an error
    chdir($curdir);
    unless (@infile) {
	$fail = "yes";
    } else {
	$fail = "no";
	my $out = join(",",@infile);
	return $out;
    }
}

#######################
#######################
