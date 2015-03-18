#! /usr/bin/perl -w

$datadir = "../acis";         # Location of /acis/ in relation to this script
$rootdir = "reprocessed/";    # name of directory storing evt files
$verb = 1;
$grpcts = 20;

#######################
#######################
##   Main Program    ##
#######################
#######################

# read in the reference file
%refdata = get_data($ARGV[0]);

# store the script directory in $Bin
use FindBin qw($Bin);
use Cwd;

# go through each cluster and extract events, images
{
  foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get obsid
    $name = $data[0];
    $obsid = $data[1];

    # define and check for file names
    $evtfile   = "${obsid}_exclude.fits";
    $bgfile    = "${obsid}_bgevt.fits";
    $lofile    = "${obsid}_local.pi";
    $logrp     = "${obsid}_local_grp.pi";
    $dpfile    = "${obsid}_deep.pi";
    $dpgrp     = "${obsid}_deep_grp.pi";
    $sourcereg = "${obsid}_localbgd.reg";
    $fail = "no";

    # change directory
    chdir("$datadir/$obsid/$rootdir/");

    # set badpix file
    set_ardlib();

    # make sure we have events files to work with
    unless (-e $evtfile && -e $bgfile && -e $sourcereg) {
      $offender = "no $evtfile" unless (-e $evtfile);
      $offender = "no $bgfile" unless (-e $bgfile);
      $offender = "no $sourcereg" unless (-e $sourcereg);
      print "## $offender for $obsid ($name)\n";
      chdir($Bin);
      sub_logerror($offender);
      next;
    }

    # extract spectrum for local background
    extract_localbgd($evtfile,$sourcereg,$lofile);
    if ($fail eq "yes") {
      $offender = "extract_localbgd";
      sub_logerror($offender);
      next;
    }

    # group the spectra to the proper number of counts
    $command = "grppha infile=\"$lofile\" outfile=\"\!$logrp\" chatter=0 comm=\"group min $grpcts & exit\"";
    system($command);

    # extract spectrum for deep background
    extract_deepbgd($bgfile,$sourcereg,$dpfile);
    if ($fail eq "yes") {
      $offender = "extract_deepbgd";
      sub_logerror($offender);
      next;
    }

    # group the spectra to the proper number of counts
    $command = "grppha infile=\"$dpfile\" outfile=\"\!$dpgrp\" chatter=0 comm=\"group min $grpcts & exit\"";
    system($command);

    # change back to original directory
    chdir("$Bin");
  }
}

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub get_data {

    my($infile) = @_;
    my(@data,$name,%info);
    open(INFILE,$infile) || die "## Can't open $infile\n";
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

sub set_ardlib {

    my($chips,@chips,$evtfile,$d,$curdir);
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
        last if (@globlist);;
        chdir $curdir;
    }

    die "$obsid: No bpix file\n" unless (@globlist);
    $bpix = $globlist[0];

    # unzip if necesary
    if ($bpix =~ /gz$/) {
        system("gunzip -f $bpix");
        $bpix =~ s/\.gz$//;
    }

    # return the name
    chdir($curdir);

    # get the chips to use
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

sub extract_localbgd {

  my($command);
  my($evtfile,$sourcereg,$lofile) = @_;

  # extract the background spectrum
  $command = "punlearn dmextract; dmextract infile=\"$evtfile\[sky=region($sourcereg)\]\[bin pi\]\" "
    ."outfile=${lofile} clobber=yes verbose=$verb";
  system($command);

  # check that it worked or return an error
  if (-e $lofile) {
    $fail = "no";
  } else {
    $fail = "yes";
  }
}

#######################
#######################

sub extract_deepbgd {

  my($command);
  my($bgfile,$sourcereg,$dpfile) = @_;

  # extract the background spectrum
  $command = "punlearn dmextract; dmextract infile=\"$bgfile\[sky=region($sourcereg)\]\[bin pi\]\" "
    ."outfile=${dpfile} clobber=yes verbose=$verb";
  system($command);

  # check that it worked or return an error
  if (-e $dpfile) {
    $fail = "no";
  } else {
    $fail = "yes";
  }
}

#######################
#######################

sub sub_logerror {

  my($offender) = @_;
  chdir("$Bin");
  open  ERRFILE,">>err_ext_local.log";
  print "${obsid} # failure in extract_localbgd.pl, $offender ",scalar(localtime),"\n";
  print ERRFILE "${obsid} # failure in extract_localbgd.pl, $offender ",scalar(localtime),"\n";
  close ERRFILE;
}

#######################
#######################
