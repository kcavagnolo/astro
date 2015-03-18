#!/usr/bin/perl -w
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

$do_peak = "yes";
$do_cent = "yes";
$outfile = "cent_shift.dat";                  # name of file to be output
$norm = "yes";
$mapbin = "0";
$emin = 700;                                  # minimum energy in eV
$emax = 7000;                                 # maximum energy in eV
$delta = 500;                                 # r_delta -> delta=500,200,...
$incore = 0;                                  # inner radius of core region in kpc
$outcore = 30;                                # outer radius of core region in kpc
$binning = 4;                                 # binning factor for image creation, bigger means faster, lower more precise; ignored is norm = "yes"
$datadir1 = "../../me_temp_proj/arc_jun07_acis/";
$datadir2 = "/Volumes/MBRANE";
$datadir3 = "/Volumes/GALACTUS";
$rootdir = "reprocessed";
$verb = 0;

#######################
#######################
##   Main Program    ##
#######################
#######################

# Check the number of arguments given
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# Load useful libraries
# Store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# open file to new reference
sub_print_info();

# Read in the reference file
%refdata = read_file($ARGV[0]);

# determine how many items there are
open(COUNT,$ARGV[0]);
while(<COUNT>){
  next if (/^\#/);
  next if (/^$/);
  $counter++;
}
close COUNT;

# Go through each cluster
foreach $key (sort keys %refdata) {

  # announce how much longer
  print "## STATUS: $counter clusters(s) left...\n";

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # get values specific to each cluster
  $name = $data[0];
  $obsid = $data[1];
  $z = $data[6];
  $tx = $data[8];
  $loc = $data[15];
  $datadir = $datadir1 if ($loc eq "NAZGUL");
  $datadir = $datadir2 if ($loc eq "MBRANE");
  $datadir = $datadir3 if ($loc eq "GALACTUS");

  # change directory
  chdir("$datadir/$obsid/$rootdir");

  # set badpix file
  sub_set_ardlib();

  # define file names
  if ($norm eq "no") {
    $evtfile = "${obsid}_exclude.fits";
  } else {
      if ($mapbin eq "0") {
	  $evtfile = "${obsid}_norm.fits";
      } else {
	  $evtfile = "${obsid}_bin${mapbin}_norm.fits";
      }
  }

  # make sure we have events files to work with
  unless (-e $evtfile) {
    $offender = "no $evtfile";
    print "## $offender for $obsid ($name)\n";
    sub_logerror($offender);
    next;
  }

  # create image filtered on energy
  if ($do_peak eq "yes") {
      print "## STATUS: finding X-ray peak\n";
      sub_peak($evtfile);
      if ($fail eq "yes") {
	  $offender = "sub_peak";
	  sub_logerror($offender);
	  next;
      }
  }

  if ($do_cent eq "yes") {
      # calculate rdelta
      print "## STATUS: calculating rdelta in pixels\n";
      @val = sub_rdelta();
      if ($fail eq "yes") {
	  $offender = "sub_rdelta";
	  sub_logerror($offender);
	  next;
      }
      $rdel = sprintf "%d",$val[0];
      $inco = sprintf "%d",$val[1];
      $outco = sprintf "%d",$val[2];
      $r500 = sprintf "%d",$val[3];
      print "## Found R_delta: ${rdel} pix\n";
      print "## Found R_500: ${r500} pix\n";
      print "## Found Inner Core: ${inco} pix (${incore} kpc)\n";
      print "## Found Outer Core: ${outco} pix (${outcore} kpc)\n";

      # get the centroid value of the emission
      print "## STATUS: finding X-ray centroid\n";
      sub_centroid($evtfile);
      if ($fail eq "yes") {
	  $offender = "sub_centroid";
	  sub_logerror($offender);
	  next;
      }

      # calculate the shift
      print "## STATUS: calculating centroid shift\n";
      sub_shift();
      if ($fail eq "yes") {
	  $offender = "sub_shift";
	  sub_logerror($offender);
	  next;
      }
  }

  # write to outfile
  sub_write_ref();
  if ($fail eq "yes") {
    $offender = "sub_write_ref";
    sub_logerror($offender);
    next;
  }

  # write to log file
  $counter--;
  print "\n## Finished $name (ObsId $obsid) ",scalar(localtime),"##\n\n";

  # change back to original directory
  chdir("$Bin");
}

# email user that the task is complete
print "###### Finished making profiles at ",scalar(localtime),"######\n";

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

sub read_file {

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

sub sub_peak {

  my($evt,$bgd) = @_;

  # change datatype depending on binning
  # binning too high overwhelms dmcopy and
  # requires 4-byte instead of 2-byte
  if ($binning <= 64) {
    $dtype = "i2";
  } else {
    $dtype = "i4";
  }

  # find the most likely center by binning coarsely
  # and looking for the maximum value in the image
  if ($norm eq "no") {
    $command = "punlearn dmcopy; dmcopy \"${evt}[bin sky=$binning][energy=$emin:$emax][opt type=$dtype]\" "
      ."temp.fits verbose=$verb clobber=yes";
    system($command);
    $command = "punlearn dmstat; dmstat temp.fits centroid=no";
    system($command);
  } else {
    system("cp -f $evt temp.fits");
    $command = "punlearn dmstat; dmstat temp.fits centroid=yes";
    system($command);
  }
  unlink("temp.fits");

  # get the phys location of the max
  my $peak = `pget dmstat out_max_loc`;
  my @data = split /\,/, $peak;
  my @peakx = split /\./, $data[0];
  my @peaky = split /\./, $data[1];
  chomp($peakx = $peakx[0]);
  chomp($peaky = $peaky[0]);

  # trap any errors
  if ($peakx > 0 && $peaky > 0) {
    print "## Peak of ($peakx,$peaky) found\n";
    $fail = "no";
  } else {
    $fail = "yes";
    return
  }
}

#######################
#######################

sub sub_rdelta {

  my(@val);

  # CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
  # By unsetting this variable, it is possible to get IDL to run
  delete $ENV{'DYLD_BIND_AT_LAUNCH'};

  # write all IDL commands to a file and then run
  open(PROFILE,">rdel.pro");
  print PROFILE "a = (rdelta('$delta','$z','$tx',/silent))*1000.\n";
  print PROFILE "cosmology,'$z',result,/silent\n";
  print PROFILE "rdel = a/result[4]/0.492\n";
  print PROFILE "incore = '$incore'/result[4]/0.492\n";
  print PROFILE "outcore = '$outcore'/result[4]/0.492\n";
  print PROFILE "r500 = (rdelta(500,'$z','$tx',/silent))*1000.\n";
  print PROFILE "r500 = r500/result[4]/0.492\n";
  print PROFILE "openw,1,'temp.log'\n";
  print PROFILE "printf,1,strcompress(rdel,/remove_all)\n";
  print PROFILE "printf,1,strcompress(incore,/remove_all)\n";
  print PROFILE "printf,1,strcompress(outcore,/remove_all)\n";
  print PROFILE "printf,1,strcompress(r500,/remove_all)\n";
  print PROFILE "close,1\n";
  print PROFILE "exit \n";
  close PROFILE;
  system("\$IDL_DIR/bin/idl rdel.pro");
  unlink("rdel.pro");

  open(FILE,"temp.log");
  while(<FILE>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;  # trim leading whitespace
    s/\s+$//;  # trim trailing whitespace
    @line = split;
    push @val, $line[0];
  }
  close FILE;
  unlink("temp.log");

  # check that it worked or return an error
  if ($val[0] > 0.00 && $val[1] >= 0.00 && $val[2] >= 0.00 && $val[3] >= 0.00) {
    $fail = "no";
  } else {
    $fail = "yes";
  }
  return @val;
}

#######################
#######################

sub sub_centroid {

  my($evt) = @_;
  my @val;
  my $x = $peakx;
  my $y = $peaky;
  my $rad = $rdel;

  # create core
  open(CORER,">core.reg");
  print CORER "# Region file format: CIAO version 1.0\n";
  print CORER "annulus($x,$y,$inco,$outco)\n";
  close CORER;

  # remove the core
  $command = "punlearn dmcopy; dmcopy \"${evt}[exclude sky=region(core.reg)]\" "
    ."temp.fits verbose=$verb clobber=yes";
  system($command);

  # begin loop
  undef @centx;
  undef @centy;
  while ($rad >= 0.05*$rdel) {
    print "## STATUS: iterating...\n";

    # create aperture
    open(AP,">ap.reg");
    print AP "# Region file format: CIAO version 1.0\n";
    print AP "circle($x,$y,$rad)\n";
    close AP;

    # focus on the aperture only
    if ($norm eq "no") {
      $command = "punlearn dmcopy; dmcopy \"temp.fits[sky=region(ap.reg)][bin sky]\" "
	."temp2.fits verbose=$verb clobber=yes";
      system($command);
    } else {
      $command = "punlearn dmcopy; dmcopy \"temp.fits[sky=region(ap.reg)]\" "
	."temp2.fits verbose=$verb clobber=yes";
      system($command);
    }

    # get the centroid
    $command = "punlearn dmstat; dmstat temp2.fits centroid=yes";
    system($command);
    $centroid = `pget dmstat out_cntrd_phys`;
    my @data = split /\,/, $centroid;
    my @cx = split /\./, $data[0];
    my @cy = split /\./, $data[1];
    chomp($x = $cx[0]);
    chomp($y = $cy[0]);
    print "## ... found $x,$y this time...\n";
    push @centx, $x;
    push @centy, $y;

    # set the new outer radius
    $rad = $rad-(0.05*$rdel);
  }
  print "## STATUS: done\n";

  # clean-up
  unlink("core.reg");
  unlink("ap.reg");
  unlink("temp.fits");
  unlink("temp2.fits");

  # check that it worked or return an error
  if ($x > 0 && $y > 0) {
    $fail = "no";
  } else {
    $fail = "yes";
  }
}

#######################
#######################

sub sub_shift {

  my($n,$px,$py,$cx,$cy,$d,@dist,$sum,$val,$mean);

  # calculate distance between peak and centroids
  $n = $#centx;;
  $px = $peakx;
  $py = $peaky;
  for ($i=0; $i <= $n; $i++) {
    $cx = $centx[$i];
    $cy = $centy[$i];
    $d = sqrt(($px-$cx)**2.+($py-$cy)**2.);
    $d = $d/$r500;
    push @dist, $d;
  }

  # measure variance in d, call this w
  $sum = 0;
  foreach $val (@dist) {
    $sum += $val;
  }
  $mean = $sum/$n;
  $sum = 0;
  foreach $val (@dist) {
    $sum += ($val-$mean)**2.;
  }
  $w = sqrt($sum/$n);
  $werr = $w/(2*$n-2);
  $w = $w/(10**(-2));
  $werr = $werr/(10**(-2));
  print "## Found centroid shift $w +/- $werr [10^-2 R500]\n";
}

#######################
#######################

sub sub_print_info {

  open(OUT,">$Bin/${outfile}");
  printf OUT "%-25s %6s %6s %6s %6s %6s\n",
    "#Name","ObsID","PeakX","PeakY","<w>","<w>err";
  close OUT;
}

#######################
#######################

sub sub_write_ref {

  open OUT, ">>/$Bin/${outfile}";
  printf OUT "%-25s %6s %6.0f %6.0f %6.3f %6.3f\n",
    $name,$obsid,$peakx,$peaky,$w,$werr;
  close OUT;
}

#######################
#######################

sub sub_logerror {

  my($offender) = @_;

  chdir("$Bin");
  open  ERRFILE,">>err_cent_shift.log";
  print "## ERROR: ${obsid} # failure in cent_shift.pl, $offender\n";
  print ERRFILE "${obsid} # failure in cent_shift.pl, $offender\n";
  close ERRFILE;
}

#######################
#######################
