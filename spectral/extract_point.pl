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

$extract_source = "yes";            # Extract spectrum for one region around source
@regex          = qw(90eef);        # source region to extract
$evtext         = qw(clean);        # extension of file to use
$localext       = qw(psfbgd);       # Extension of local bgd spec
$bintype        = "NUM_CTS";        # grouping designation
$binspec        = "15";             # counts per bin
$rootdir        = "reprocessed";    # where to find data
$verb           = 1;                # wordiness of ciao

#######################
#######################

# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});

foreach $regex (@regex) {

# read in the reference file
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
    $sourcereg = "${obsid}_${regex}.reg";
    $localbgd  = "${obsid}_${localext}.reg";
    $root      = "${name}_${obsid}_${regex}";

    # catch error and move-on
    unless (-e $evtfile && -e $localbgd && -e $sourcereg) {
      $offender = "no $evtfile" unless (-e $evtfile);
      $offender = "no $sourcereg" unless (-e $sourcereg);
      $offender = "no $localbgd" unless (-e $localbgd);
      print "## $offender for $obsid ($name)\n";
      chdir($Bin);
      sub_logerror($offender);
      next;
    };

    # set badpix file
    sub_set_ardlib($evtfile);

    # get the asol file or files
    my $asol = get_asolfile();
    print "## Using aspect solution: $asol\n";

    # get the asol file or files
    my $pbk = get_pbkfile();
    print "## Using pbk file: $pbk\n";

    # extract spectrum for entire cluster
    print "## Extracting source spectrum\n";
    sub_extract_src($evtfile,$sourcereg,$localbgd,$root,$asol,$pbk) if ($extract_source eq "yes") ;
    if ($fail eq "yes") {
      $offender = "sub_extract_src";
      sub_logerror($offender);
      next;
    }
    print "## Source spectrum extraction complete\n";

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

    die "## ERROR: No evt1 file for $obsid\n" unless (@infile);
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
    $rmax = sprintf("%.2f",$rout*0.492/60);
    return $rmax;
}

#######################
#######################

sub sub_extract_src {
  my($command);
  my($evtfile,$sourcereg,$localbgd,$root,$asol,$pbk) = @_;

  # run psextract
  $command = "punlearn psextract ; psextract events=\"$evtfile\[sky=region($sourcereg)\]\" bgevents=\"$evtfile\[sky=region($localbgd)\]\" ".
      "pbkfile=$pbk dafile=CALDB root=$root asol=$asol bgasol=$asol ptype=pi gtype=$bintype gspec=$binspec clobber=yes verbose=$verb";
  system($command);

  # delete grouping keyword which confuses XSPEC
  $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=del key=GROUPING file=\"\"";
  system($command);

  # delete quality keyword which confuses XSPEC
  $command = "punlearn dmhedit; dmhedit infile=${root}.pi operation=del key=QUALITY file=\"\"";
  system($command);

  # check that it worked or return an error
  unless (-e "${root}.pi") {
    $fail = "yes";
  } else {
    $fail = "no";
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

  die "## ERROR: No asol files found.  Exiting.\n" unless (@infile);
  $asol = join(",",@infile);

  # return the name(s)
  chdir($curdir);
  return $asol;
}

#######################
#######################

sub get_pbkfile {

  # get the asol file or files
  my($curdir,@infile,$pbk,@dir,@globlist);
  $curdir = cwd();

  # change to appropriate dir (they sometimes change the locations)
  @dir = qw(primary secondary);
  @infile = ();
  foreach $dir (@dir) {
    chdir "../$dir";
    @globlist =  <*pbk*.fits*>;
    if (@globlist) {
	@globlist = map { "../$dir/" . $_} @globlist;
	push @infile, @globlist;
	chdir $curdir;
	last;
    }
  }
  die "## ERROR: No pbk files found.  Exiting.\n" unless (@infile);
  $pbk = join(",",@infile);

  # return the name(s)
  chdir($curdir);
  return $pbk;
}

#######################
#######################
