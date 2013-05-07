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

$ellsigma = 2.0;
$minkpc   = 100.0;
$scales   = "\"2.0 4.0\"";
$binning  = 2;
$thresh   = 1e-07;
$emin     = 500;
$emax     = 2000;
$datadir  = "/mnt/SINISTER/";
$rootdir  = "reprocessed/";
$verb     = 1;

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

# read in the reference file
%refdata  = sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

  # split up the data line
  @data  = split(/\s+/,$refdata{$key});
  $name  = $data[0];
  $obsid = $data[1];
  $x     = $data[2];
  $y     = $data[3];
  $z     = $data[6];

  # set badpix file
  sub_set_ardlib();

  # change directory
  chdir("$datadir/$obsid/$rootdir/");

  # define and check for file names
  $evtfile  = "${obsid}_clean.fits";
  $bgfile   = "${obsid}_bgevt.fits";

  # get exposure time
  $expt = get_info($evtfile,"EXPOSURE");

  # define file names
  $imgroot = "${obsid}_corona";
  $srcreg  = "${obsid}_corona.reg";
  $bgdreg  = "${obsid}_corona_bgd.reg";

  # run wavdetect to get point sources
  sub_run_wavdetect($evtfile,$srcreg,$imgroot);

  # check for radius=0 and NAN values
  sub_check_reg($srcreg);

  # get number of sources detected
  $wc = `wc $srcreg`;
  @wc = split /\s+/, $wc;
  $num = $wc[1];
  print "${obsid}: $num point sources found\n";

  # clean-up temp files
  unlink <*_stk>;

  # change back to original directory
  chdir($Bin);
}
print "\n###### Finished finding point sources at ",scalar(localtime)," ######\n\n";

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## $obsid:  Can't open $infile\n";
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

  my($chips,@chips,$d,$curdir);

  # change directory
  chdir("$datadir/$obsid/");
  $curdir = cwd();

  # reset the ardlib parameter file
  system("punlearn ardlib.par");

  # change to appropriate dir (they sometimes change the locations)
  # glob for matching file names
  @infile = glob("reprocessed/*bpix1*");

  die "$obsid: No bpix file\n" unless (@infile);
  $bpix = shift @infile;

  # unzip if necesary
  if ($bpix =~ /gz$/) {
    system("gunzip -f $bpix");
    $bpix =~ s/\.gz$//;
  }

  # get the chips to use
  $chips = `dmkeypar $bpix DETNAM ; pget dmkeypar value`;
  chomp($chips);
  $chips =~ s/ACIS\-//;
  @chips = split('', $chips);
  foreach $d (@chips) {
    $command = "pset ardlib AXAF_ACIS${d}_BADPIX_FILE=${curdir}/$bpix\[BADPIX${d}]";
    system($command);
  }
  chdir("$Bin");
}

#######################
#######################

sub sub_run_wavdetect {

  my($evtfile,$srcreg,$imgroot) = @_;
  my($imgfile,$outfile,$scellfile,$imagefile,$nbdgfile);

  # define local file names
  $imgfile   = "temp.fits";
  $outfile   = "${imgroot}_src.fits";
  $scellfile = "${imgroot}_scell.fits";
  $imagefile = "${imgroot}_imgfile.fits";
  $nbdgfile  = "${imgroot}_nbgd.fits";

  # make smaller file for wavdetect to handle
  open(PROFILE,">temp.pro");
  print PROFILE "\!quiet=1\n";
  print PROFILE "cosmology,'$z',result,/silent\n";
  print PROFILE "openw,1,'temp.log'\n";
  print PROFILE "printf,1,strcompress(result[4],/remove_all)\n";
  print PROFILE "close,1\n";
  print PROFILE "exit \n";
  close PROFILE;
  system("\$IDL_DIR/bin/idl temp.pro");
  open(FILE,"temp.log");
  while(<FILE>) {
      chomp;
      next if (/^\#/);
      next if (/^$/);
      s/^\s+//;  # trim leading whitespace
      s/\s+$//;  # trim trailing whitespace
      @line = split;
      $conv = $line[0];
  }
  close FILE;
  system("rm -f temp.log temp.pro");
  delete $ENV{'DYLD_BIND_AT_LAUNCH'};
  $tr = $minkpc/($conv*0.492);
  $command = "punlearn dmcopy; dmcopy \"$evtfile\[sky=circle($x,$y,$tr)]\" $imgfile clobber=yes verbose=$verb";
  system $command;
  $command = "punlearn dmcopy; dmcopy \"$imgfile\[energy=${emin}:${emax}][bin sky=$binning]\" "
    ."$imgfile clobber=yes verbose=$verb";
  print "## Creating image.\n";
  system $command;

  # run wavdetect
  $command = "punlearn wavdetect; wavdetect infile=$imgfile outfile=$outfile scellfile=$scellfile "
    ."imagefile=$imagefile defnbkgfile=$nbdgfile regfile=$srcreg ellsigma=${ellsigma} scales=$scales "
      ."sigthresh=$thresh exptime=$expt clobber=yes verbose=$verb";
  print "## Running wavdetect on $imgfile\n";
  system $command;

  unlink "$imgfile";
  unlink "$scellfile";
  unlink "$nbdgfile";
  unlink "$imagefile";
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
