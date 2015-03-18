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

$evtext   = "mosaic";
$rootdir  = "merged";
$ellsigma = 3.0;
$scales   = "\"1.0 2.0 4.0 8.0 16.0 32.0\"";
#$emin     = 300;
#$emax     = 10000;
#$binning  = 2;
$thresh   = 1e-07;
$verb     = 1;

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
use Cwd;
use FindBin qw($Bin);
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "## Wrong number of command line arguments\n" if (@ARGV != 1);
open(LOGFILE,">ptsrc.log") || die "Can't open fit_spectra.log\n";
print LOGFILE "###### Started finding point sources at ",scalar(localtime),"######\n";

# read in the reference file
%refdata  = &sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get info
    $fail    = "no";
    $name    = $data[0];
    $datadir = $data[15];

    # make directory to store reprocessed and new files
    chdir("$datadir/$rootdir/$name");

    # get evt2 file
    $evtfile = "${name}_${evtext}.fits";
    print "## Using $evtfile\n";
    $expt = get_info($evtfile,"EXPOSURE");

    # define file names
    $imgroot = "${name}";
    $regfile = "${name}_exclude.reg";

    # run wavdetect to get point sources
    print "\n## STATUS: detecting sources for:\n"
	."Scales: $scales\n"
	."Threshold: $thresh\n";
    &sub_run_wavdetect($evtfile,$regfile,$imgroot);

    # check for radius=0 and NAN values
    &sub_check_reg($regfile);

    # get number of sources detected
    $wc = `wc $regfile`;
    @wc = split /\s+/, $wc;
    $num = $wc[1];
    print LOGFILE "${name}: $num point sources found\n";
      
    # clean-up temp files
    unlink <*_stk>;

    # change back to original directory
    chdir($Bin);
}
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

sub sub_run_wavdetect {

  my($evtfile,$regfile,$imgroot) = @_;
  my($outfile,$scellfile,$imagefile,$nbdgfile);

  # define local file names
  $scellfile = "${imgroot}_scell.fits";
  $imagefile = "${imgroot}_imgfile.fits";
  $nbdgfile  = "${imgroot}_nbgd.fits";
  $outfile   = "${imgroot}_src.fits";

  # run wavdetect
#  $command = "punlearn dmcopy; dmcopy \"$evtfile\[energy=${emin}:${emax}]"
#      ."[bin sky=$binning][opt mem=135]\" temp.fits clobber=yes verbose=$verb";
#  system $command;
  $command = "punlearn wavdetect; wavdetect infile=$evtfile outfile=$outfile scellfile=$scellfile "
      ."imagefile=$imagefile defnbkgfile=$nbdgfile regfile=$regfile ellsigma=${ellsigma} scales=$scales "
      ."sigthresh=$thresh exptime=$expt interdir=/tmp psftable=\"\" clobber=yes verbose=$verb";
  print "## Running wavdetect on $evtfile\n";
  system $command;
  unlink("temp.fits");
  unlink("junk.reg");
  unlink("$scellfile");
  unlink("$nbdgfile");
  unlink("$imagefile");
}

#######################
#######################

sub get_info {

  # get and format keyword value from file
  my($file,$key) = @_;
  $value = `punlearn dmkeypar; dmkeypar ${file} $key; pget dmkeypar value`;
  chomp($value);      # remove any newline
  $value =~ s/\s+//g; # remove white space
  $value =~ s/\'//g;  # remove quotes
  return $value;
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
    next if (/\,0\.00/ || /NAN/ || /nan/);
    print TEMP "$_\n";
  }
  close REG;
  close TEMP;
  system("mv -f $temp $reg");
}

#######################
#######################

sub sub_get_exp {

    my(@exp,$exp);
    @exp = glob("*expmap.fits*");
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

