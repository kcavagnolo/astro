#! /usr/bin/perl -w

$logfile  = "alt_bgd_9-12.dat";      # Name of the file to be written by script
$emin     = 9500;                    # minimum energy, in eV, to use for bgd count rate
$emax     = 12000;                   # maximum energy, in eV, to use for bgd count rate

$datadir1 = "../acis/";               # Location of /acis/ in relation to this script
$datadir2 = "/Volumes/MBRANE";        # Location of /acis/ in relation to this script
$datadir3 = "/Volumes/GALACTUS";      # Location of /acis/ in relation to this script
$rootdir  = "reprocessed/";           # name of directory storing evt files
$quiet    = "yes";                     # How verbose the script should be
$verb     = 1;                        # verbosity

#######################
#######################

# define the quiescent bgd rate for each period in the 0.3-10.0 keV band
%qrate = ("As2"=>"0.1", "As3"=>"0.2",
	  "Bi0"=>"0.3947", "Bi1"=>"0.4005", "Bi2"=>"0.3959", "Bi3"=>"0.4328",
	  "Bs1"=>"2.2413", "Bs2"=>"0.4327", "Bs3"=>"1.4400", "Bs4"=>"0.4424",
	  "Ci0"=>"0.3415", "Ci1"=>"0.3497", "Ci2"=>"0.3434", "Ci3"=>"0.3519",
	  "Cs1"=>"1.9704", "Cs2"=>"0.3889", "Cs3"=>"1.2747", "Cs4"=>"0.3857",
	  "Di0"=>"0.3873", "Di1"=>"0.3995", "Di2"=>"0.3938", "Di3"=>"0.4045",
	  "Ds1"=>"2.1466", "Ds2"=>"0.3978", "Ds3"=>"1.3177", "Ds4"=>"0.4044",
	  "Dvfi0"=>"0.2674", "Dvfi1"=>"0.2743", "Dvfi2"=>"0.2700", "Dvfi3"=>"0.2772",
	  "Dvfs1"=>"1.8111", "Dvfs2"=>"0.2768", "Dvfs3"=>"1.0772", "Dvfs4"=>"0.2675");

# read in the reference file
%refdata  = get_data($ARGV[0]);

# store the script directory in $Bin
use FindBin qw($Bin);
use Cwd;

# open file to contain results
open(FITFILE,">>$Bin/${logfile}");
print_info();
close FITFILE;

# open err log
open(ERR,">>bgd_err.log");
print ERR "###### Started bgd ratio for ${emin}-${emax}eV at ",scalar(localtime)," ######\n";

# go through each cluster and extract events, images
MAIN: foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get obsid
    $name   = $data[0];
    $obsid  = $data[1];
    $id     = $data[11];
    $loc    = $data[15];
    $datadir = $datadir1 if ($loc eq "NAZGUL");
    $datadir = $datadir2 if ($loc eq "MBRANE");
    $datadir = $datadir3 if ($loc eq "GALACTUS");

    print "## Starting ${obsid}\n";

    # define the ccd to use and file names
    $evtfile = "${obsid}_exclude.fits";
    $bgfile  = "${obsid}_bgevt.fits";
    $bgccd  = "3" if ($id =~ /^i/);
    $bgccd  = "7" if ($id =~ /^s/);

    # change the name if an alternate chip was used
    chdir("$datadir/$obsid/$rootdir/");

    # make sure we have bgd files to work with
    unless (-e $bgfile) {
      print "## No bgd file for $obsid ($name)\n";
      print ERR "${obsid}: No bgd file\n";
      $obsrate = 0;
      $deeprate = 1;
      $qbgd = 1;
      bgd_ratio($obsrate,$deeprate,$qbgd);
      chdir($Bin);
      next;
    }

    # make sure we have events files to work with
    unless (-e $evtfile) {
      print "## No evt file for $obsid ($name)\n";
      print ERR "${obsid}: No evt file\n";
      $obsrate = 0;
      $deeprate = 1;
      $qbgd = 1;
      bgd_ratio($obsrate,$deeprate,$qbgd);
      chdir($Bin);
      next;
    }

    # set badpix file
    set_ardlib($evtfile);

    # set quiescent bgd rate
    $qbgd = set_qbgd($evtfile);
    $qbgd = -1.0 if ($qbgd eq "");

    # extract spectrum for obs background and deep background
    $obsrate  = extract_obsbgd($evtfile);
    $deeprate = extract_deepbgd($bgfile);

    # compute and write ratio of obs bgd to quiescent bgd to output file
    bgd_ratio($obsrate,$deeprate,$qbgd);

    # clean-up
    unlink("deepcts.log");
    unlink("obscts.log");

    # change back to original directory
    chdir("$Bin");

    print "## Finished ${obsid}\n";

}
print ERR "###### Finished bgd ratio ",scalar(localtime)," ######\n\n";
print "\n###### Finished bgd ratio ",scalar(localtime)," ######\n\n";
close ERR;


#######################
#######################
#### Sub routines #####
#######################
#######################

sub get_data {

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
	print $line,"\n" if ($quiet eq "no");
    }
}

#######################
#######################

sub print_info {

  printf FITFILE "%-25s %6s %6s %10s %10s %10s %10s %10s\n",
    "# Cluster","ObsID","BgdCCD","ObsCts","DeepCts","Obs/Qui","Deep/Qui","Obs/Deep";

}

#######################
#######################

sub set_ardlib {
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

sub extract_obsbgd {

  my($command,$cts,$exp,$rate);
  my($evtfile) = @_;

  # extract the background spectrum
  $command = "punlearn dmcopy; dmcopy \"${evtfile}\[ccd_id=${bgccd}\]\[energy=${emin}:${emax}\]\" "
    ."temp_cts.fits clobber=yes verbose=$verb";
  system($command);

  # query for the number of counts in the file
  $command = "punlearn dmlist; dmlist \"temp_cts.fits\[events\]\" counts outfile=obscts.log";
  system($command);

  # store those counts as a variable
  $cts = use_dmlist("obscts.log");
  unlink("obscts.log");

  # check that there are counts
  if ($cts <= 0) {
    print "## ERROR: ${obsid} ($name) no counts in observation\n";
    print ERR "${obsid}: no counts in observation\n";
    return -1;
  }

  # get the exposure time
  $exp = `dmkeypar ${evtfile} EXPOSURE; pget dmkeypar value`;
  chomp($exp);

  # return the count rate per chip
  $rate = $cts/$exp;

  unlink("temp_cts.fits");
  return $rate;
}

#######################
#######################

sub extract_deepbgd {

  my($command,$cts,$exp,$rate);
  my($bgfile) = @_;

  # extract the background spectrum
  $command = "punlearn dmcopy; dmcopy \"${bgfile}\[ccd_id=${bgccd}\]\[energy=${emin}:${emax}\]\" "
    ."temp_cts.fits clobber=yes verbose=$verb";
  system($command);

  # query for the number of counts in the file
  $command = "punlearn dmlist; dmlist \"temp_cts.fits\[events\]\" counts outfile=deepcts.log";
  system($command);

  # store those counts as a variable
  $cts = use_dmlist("deepcts.log");
  unlink("deepcts.log");

  # check that there are counts
  if ($cts == 0) {
    print "## ERROR: ${obsid} ($name) no counts in deep bgd\n";
    print ERR "${obsid}: no counts in deep bgd\n";
    return -1;
  }

  # get the exposure time
  $exp = `punlearn dmkeypar; dmkeypar ${bgfile} EXPOSURE; pget dmkeypar value`;

  # return the count rate per chip
  $rate = $cts/$exp;

  unlink("temp_cts.fits");
  return $rate;
}

#######################
#######################

sub bgd_ratio {

  my($obsrate,$deeprate,$qbgd) = @_;

  my $bgdratio = $obsrate/$deeprate;
  my $oqratio = $obsrate/$qbgd;
  my $dqratio = $deeprate/$qbgd;

  # print out the info
  open(FITFILE,">>${Bin}/${logfile}");
  printf FITFILE "%-25s %6s %6s %10.4f %10.4f %10.4f %10.4f %10.4f\n",
    ${name},${obsid},${bgccd},${obsrate},${deeprate},${oqratio},${dqratio},${bgdratio};
  close FITFILE;

}

#######################
#######################

sub set_qbgd {
  my ($evtfile) = @_;
  my ($mode, $date, $year, $mon, $day, $per, $qid, $qbgd);

  # determine the quiescent background rate to use
  # find the obs date
  chomp($mode = `dmkeypar $evtfile DATAMODE ; pget dmkeypar value`);
  $date = `dmkeypar $evtfile DATE-OBS ; pget dmkeypar value`;
  @date = split("T",$date);
  $date = $date[0];
  @date = split("-",$date);
  $year = $date[0];
  $mon  = $date[1];
  $day  = $date[2];

  # determine the qbgd period to use
  # periods:
  # A: <= 1999-09-16
  # B: 1999-09-17 -> 2000-01-28
  # C: 2000-01-29 -> 2000-11-30
  # D: 2000-12-01 -> 2003-12-31
  # perform a logic test on date
  if ($year != 0) {
    if ($year <= 1999) {
      $per = "A" if ($mon < 9);
      $per = "A" if ($mon == 9 && $day <= 16);
      $per = "B" if ($mon > 9 || ($mon == 9 && $day > 16));
    } elsif ($year == 2000) {
      $per = "B" if ($mon == 1 && $day <= 28);
      $per = "C" if ($mon == 1 && $day > 28);
      $per = "C" if ($mon > 1 && $mon < 11);
      $per = "C" if ($mon == 11 && $day <= 30);
      $per = "D" if ($mon == 12);
    } elsif ($year > 2000) {
      $per = "D";
    }
  }
  $per = "Dvf" if ($per eq "D" && $mode eq "VFAINT");

  # read from the qbgd array
  $qid = "${per}${id}";
  $qbgd = $qrate{$qid};
  return $qbgd;
}

#######################
#######################

sub use_dmlist {

  my($infile) = @_;
  my(@line,$value);

  open(FILE,$infile);
  while(<FILE>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;  # trim leading whitespace
    s/\s+$//;  # trim trailing whitespace
    @line = split;
    $value = $line[0];
  }
  close FILE;
  return $value;
}

#######################
#######################
