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

# tasks to be completed
$rm_ptsrc  = "no";
$make_prof = "yes";
$regkey    = "2pix";
$verb      = 1;                                # how much verbosity should CIAO use?
$rootdir   = "reprocessed/";                   # where to find the cluster specific data

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});

# check the number of arguments given
die "## ERROR: Wrong number of command line arguments\n" if (@ARGV != 1);

# load useful libraries
# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# read in the reference file
%refdata = sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
{
  foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get values specific to each cluster
    $obsid   = $data[1];
    $datadir = $data[15];

    # change directory
    chdir("$datadir/$obsid/$rootdir");

    # define file names	
    $excrfits = "${obsid}_expcorr_${regkey}.fits";
    $excrdat  = "${obsid}_expcorr_${regkey}.dat";
    $fail     = "no";

    # set badpix file
    sub_set_ardlib();

    # get and unzip the exp map
    $expmapfile = sub_get_exp();
    if ($fail eq "yes") {
      chdir("$Bin");
      open ERRFILE,">>errors.log";
      print "## ${obsid} # failure in get_exp ",scalar(localtime),"\n";
      print ERRFILE "${obsid} # failure in get_exp ",scalar(localtime),"\n";
      close ERRFILE;
      next;
    }

    # get region to work with
    $reg = sub_get_reg($regkey) if ($make_prof eq "yes");
    if ($fail eq "yes") {
      chdir("$Bin");
      open  ERRFILE,">>errors.log";
      print "## ${obsid} # failure in get_reg ",scalar(localtime),"\n";
      print ERRFILE "${obsid} # failure in get_reg ",scalar(localtime),"\n";
      close ERRFILE;
      next;
    }

    # remove point source regions as in evt file
    if ($rm_ptsrc eq "yes") {
      $exclude   = "${obsid}_exclude.reg";
      $expmapexcl = "${obsid}_expmap_exclude.fits";
      sub_rm_ptsrc($expmapfile,$exclude,$expmapexcl);
      if ($fail eq "yes") {
	$offender = "sub_rm_ptsrc";
	sub_logerror($offender);
	next;
      }
      $expmapfile = $expmapexcl;
    }

    # create radial profile
    sub_make_prof($expmapfile,$reg,$excrfits,$excrdat) if ($make_prof eq "yes");
    if ($fail eq "yes") {
      $offender = "sub_make_prof";
      sub_logerror($offender);
      next;
    }

    # change back to original directory
    chdir("$Bin");
  }
}

# exit cleanly
print "## Finished ",scalar(localtime)," ##\n\n";
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "## ERROR: Can't open $infile\n";
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

sub sub_get_exp {

  my(@exp,$exp);
  @exp = glob("${obsid}_expmap.fits*");
  unless (@exp) {
    $fail = "yes";
    return;
  }
  $exp = shift @exp;
  print "## Found $exp for expsoure map.\n";
  if ($exp =~ /gz$/) {
    print "## Unzipping $exp\n";
    system("gunzip -f $exp");
    $exp =~ s/\.gz$//;
  }
  return $exp;
}

#######################
#######################

sub sub_set_ardlib {

  my($chips,@chips,$d,$curdir);
  $curdir = cwd();

  # reset the ardlib parameter file
  system("punlearn ardlib.par");

  # change to appropriate dir (they sometimes change the locations)
  # glob for matching files
  @dir = qw(reprocessed primary secondary);
  foreach $dir (@dir) {
    chdir "../$dir";
    @globlist = <*bpix*.fits*>;
    @globlist = map { "../$dir/" . $_} @globlist if (@globlist);
    last if (@globlist);
    chdir $curdir;
  }

  die "## ERROR: $obsid, No bpix file\n" unless (@globlist);
  $bpix = $globlist[0];
  print "## Using bad pixel file: $bpix\n";

  # unzip if necesary
  if ($bpix =~ /gz$/) {
    system("gunzip -f $bpix");
    $bpix =~ s/\.gz$//;
  }

  # return the name
  chdir($curdir);
  $chips = `dmkeypar $bpix DETNAM ; pget dmkeypar value`;
  chomp($chips);
  $chips =~ s/ACIS\-//;
  @chips = split('', $chips);
  foreach $d (@chips) {
    $command = "pset ardlib AXAF_ACIS${d}_BADPIX_FILE=${curdir}/$bpix\[BADPIX${d}]";
    system($command);
  }
}

#######################
#######################

sub sub_get_reg {

  my($regkey) = @_;
  my(@reg,$reg);
  @reg = glob("*${regkey}*.reg");
  unless (@reg) {
    $fail = "yes";
    return;
  }
  $reg = shift @reg;
  print "## Found $reg for use in radial extraction.\n";
  return $reg;
}

#######################
#######################

sub sub_rm_ptsrc {

  my($in,$reg,$out) = @_;

  $command = "dmcopy \"$in\[exclude sky=region($reg)]\" $out clobber=yes verbose=$verb\n";
  system($command);

  # check that it worked or return an error
  if (-e $out) {
    print "\n## Removed point source regions from exp map\n";
    $fail = "no";
  } else {
    $fail = "yes";
  }
}


#######################
#######################

sub sub_make_prof {

  my($infile,$reg,$excrfits,$excrdat) = @_;

  # extract profile from events, using blank sky background
  print "## Extracting exposure correction profile\n";
  $command = "punlearn dmextract; dmextract infile=\"${infile}\[bin sky=\@${reg}]\" "
    ."outfile=rprofile.fits bkg=\"\" clobber=yes verbose=$verb";
  system($command);

  # add a column for rmid, rin, rout
  print "## Adding Rin, Rout, and Rmid columns to FITS file\n";
  $command = "punlearn dmtcalc; dmtcalc infile=rprofile.fits outfile=$excrfits "
    ."expression=\"rmid=(0.5*(R[0]+R[1]))\" clobber=yes verbose=$verb";
  system($command);
  $command = "punlearn dmtcalc; dmtcalc infile=$excrfits outfile=$excrfits "
    ."expression=\"rin=(R[0])\" clobber=yes verbose=$verb";
  system($command);
  $command = "punlearn dmtcalc; dmtcalc infile=$excrfits outfile=$excrfits "
    ."expression=\"rout=(R[1])\" clobber=yes verbose=$verb";
  system($command);

  # dump to a text file
  print "## Dumping results to $excrdat file\n";
  $command = "punlearn dmlist; dmlist \"$excrfits\[cols rin,rout,rmid,sur_bri,sur_bri_err,"
    ."area,exposure]\" opt=array > $excrdat";
  system($command);

  # check that it worked or return an error
  unlink("rprofile.fits");
  if (-e $excrdat && -e $excrfits) {
    print "\n## Created exposure correction profile resulting in $excrfits and $excrdat\n";
    $fail = "no";
  } else {
    $fail = "yes";
  }
}

#######################
#######################
