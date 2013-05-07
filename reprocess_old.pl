#! /usr/bin/perl -w
#
# NAME:
#     reprocess.pl
#
# PURPOSE:
#     Take raw level one events file and create new level
#     two events file.
#
# EXPLANATION:
#     This script assumes the following directory structure:
#     all pertinent Chandra data files are in a dir labeled with
#     the obsid, which is then in a dir labeled acis/. The location
#     of acis/ relative to the dir from which this script is run is
#     set with the variable $datadir.
#
#     e.g.: for Abell 644 obsid 2211, this script will look to
#     $datadir/acis/2211/ for all the files needed to complete
#     the data reduction
#
#     New files will be placed in the directory defined by the
#     variable $rootdir.
#
#     e.g.: after reduction, new evt2 files will be located in
#     $datadir/acis/$obsid/$rootdir

# CALLING SEQUENCE:
#     reprocess.pl <reference list>
#
# INPUTS:
#     Region file containing pt srcs:              <obsid>_exclude.reg
#
#     <reference list> = file containing information about each cluster
#     in the case of X and Y being the centroid position in pixels and Rmax in pixels
#     Name                           ObsID        X        Y   Rmax     MinCts         z  Nh20     Tx     Fe  Lbol ChipID
#     ABELL_0644                      2211   3908.5   4332.5  243.9       5000    0.0704  6.41   8.64   0.35 45.00     s3
#     ABELL_1651                      4185   4222.5   4034.5  132.3       5000    0.0844  1.88   5.97   0.30 45.00     i2
#
# OUTPUTS:
#     new level one event file:           <obsid>_evt1.fits
#     new level two event file:           <obsid>_evt2.fits
#     Good time intervals file:           <obsid>_<chipid>_gti.fits
#     FITS file cleaned of flares:        <obsid>_clean.fits
#     Light curve FITS file:              <obsid>_lc.fits
#     Postscript of Light Curve:          <obsid>_lc.ps
#     FITS file with pt srcs excluded:    <obsid>_exclude.fits
#     Deep bgd for source chip:           <obsid>_bgevt.fits
#     Add'n deep bgd for off source:      <obsid>_<alt chip>_bgevt.fits
#
#
#######################
#######################
##    Set Options    ##
#######################
#######################

# tasks to be completed
$remove_afterglow   = "yes";
$create_bpix        = "yes";
$make_evt           = "yes";
$make_new_evt1      = "yes";
$make_new_evt2      = "yes";
$exclude            = "no";
$clean_events       = "yes";
$make_blank_bgd     = "yes";
$make_addblank_bgd  = "yes";
$rootdir            = "reprocessed/";
$flarefile          = $ENV{'HOME'}."/research/redux/redux_info/flares.list";
$lcdir              = $ENV{'HOME'}."/research/redux/redux_info/lightcurves/";
$verb               = 1;

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
open(LOGFILE,">>reprocess.log") || die "\n## $obsid: Cannot open reprocess.log\n";
print LOGFILE "## Started reprocessing at ",scalar(localtime)," ##\n";

# reference array for all chip ids
%chip_id = ("i0" =>"0", "i1" =>"1", "i2" =>"2", "i3" =>"3", "s0"
	    =>"4", "s1" =>"5", "s2" =>"6", "s3" =>"7", "s4" =>"8",
	    "s5" =>"9");

# find the version of CALDB presently in use
$command = "dmlist \"\$CALDB/docs/chandra/caldb_version/caldb_version.fits[cols caldb_ver]\" data,clean outfile=temp.dat";
system($command);
$caldb = &sub_use_dmlist("temp.dat");
unlink("temp.dat");
print "## STATUS: You're current version of the CALDB is: $caldb\n";

# find the version of CIAO presently in use
$command = "dmlist \"\$CALDB/docs/chandra/caldb_version/caldb_version.fits[cols ciao_ver]\" data,clean outfile=temp.dat";
system($command);
$ciaover = &sub_use_dmlist("temp.dat");
unlink("temp.dat");
print "## STATUS: You're current version of CIAO is: $ciaover\n";
print LOGFILE "## STATUS: CALDB version used is: $caldb\n";
print LOGFILE "## STATUS: CIAO  version used is: $ciaover\n";

# read in the reference file
%refdata = &sub_get_data($ARGV[0]);

# go through each cluster and extract events, images
{
  foreach $key (sort keys %refdata) {

      # split up the data line
      @data = split(/\s+/,$refdata{$key});

      # get values specific to each cluster
      $name    = $data[0];
      $obsid   = $data[1];
      $fidx    = $data[2];
      $fidy    = $data[3];
      $rmax    = $data[4];
      $id      = $data[11];
      $datadir = $data[15];

      # write to log file
      print "\n## STATUS: Started $name (ObsId $obsid) ",scalar(localtime),"\n\n";

      # change directory
      chdir("$datadir/$obsid/");

      # set badpix file
      &sub_set_ardlib();

      # make directory to store reprocessed and new files
      mkdir($rootdir,0777) unless (-d $rootdir);
      chdir($rootdir) || die "\n## $obsid: Cannot change to $rootdir directory\n";

      # figure out which detector is in use
      $instr = "s" if ($id =~ /^s/);
      $instr = "i" if ($id =~ /^i/);

      # get the asol file or files
      $asol = &sub_get_asolfile();
      print "## STATUS: Using $asol\n";

      # get flt files
      $flt = &sub_get_fltfile();
      print "## STATUS: Using $flt\n";

      # define file names	
      $newevt1   = "${obsid}_evt1.fits";
      $newevt2   = "${obsid}_evt2.fits";
      $newbpix   = "${obsid}_new_bpix1.fits";
      $lcfile    = "${obsid}_lc.fits";
      $cleanfile = "${obsid}_clean.fits";
      $regfile   = "${obsid}_exclude.reg";
      $exclfile  = "${obsid}_exclude.fits";
      $chipfits  = "${obsid}_chipregs.fits";

      # empty the fail var per loop
      $fail = "";

      # generate new evt1 and evt2 files with updated calib info
      if ($make_evt eq "yes") {
	  $fail = &sub_make_evt($newevt1,$newevt2,$newbpix);
	  if ($fail eq "yes") {
	      $offender = "make_evt";
	      &sub_logerror($offender);
	      next;
	  }

	  # make a general log file of obs info
	  &sub_write_log();

	  # create a FITS file containing all the chip regions
	  &sub_make_regions($newevt2,$chipfits);
      }

      # remove point sources from light curve cleaned events file
      if ($exclude eq "yes") {
	  if (-e $regfile) {
	      print "\n## STATUS: Found ${regfile}.  Excluding sources from events.\n\n";
	      $command = "dmcopy \"$newevt2\[exclude sky=region($regfile)]\" $exclfile clob+ verbose=$verb\n";
	      system $command;
	  } else {
	      $adir = cwd();
	      print "\n## ERROR: You asked me to exclude events, but there is no exclusion region.\n";
	      $offender = "exclude_events";
	      &sub_logerror($offender);
	      chdir("$adir");
	  }
      }

      # clean bad times using the light curve
      $fail = &sub_clean_events($exclfile,$lcfile,$newevt2,$cleanfile) if ($clean_events eq "yes");
      if ($fail eq "yes") {
	  $offender = "clean_events";
	  &sub_logerror($offender);
	  next;
      }

      # make blank sky background
      $fail = &sub_make_blank_bgd($cleanfile) if ($make_blank_bgd eq "yes");
      if ($fail eq "yes") {
	$offender = "make_blank_bgd";
	&sub_logerror($offender);
	next;
      }

      # make an additional blank background file for ACIS-S obs
      # to allow a source free comparison of background rates for
      # deep bgd and obs bgd
      $fail = &sub_make_addblank_bgd($cleanfile) if ($make_addblank_bgd eq "yes");
      if ($fail eq "yes") {
	$offender = "make_addblank_bgd";
	&sub_logerror($offender);
	next;
      }

      # cleanup temp files that might have been created
      unlink <xsel*>;

      # write to log file
      print "\n## STATUS: Finished $name (ObsId $obsid) ",scalar(localtime),"\n\n";

      # change back to original directory
      chdir("$Bin");
  }
}

print LOGFILE "## STATUS: Finished reprocessing ",scalar(localtime)," ##\n\n";
print "\n## STATUS: Finished reprocessing ",scalar(localtime)," ##\n\n";
close LOGFILE;

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_get_info {

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

sub sub_get_data {

    my($infile) = @_;
    my(@data,$name,%info);
    open(INFILE,$infile) || die "\n## ERROR: Cannot open $infile\n";
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

sub sub_make_evt {

    # run acis_process_events and creates new evt1 and new evt2 files
    my($newevt1,$newevt2,$newbpix) = @_;

    # get the evt1 file name
    $evt1 = &sub_get_evt1name();
    print "## STATUS: Using $evt1\n";

    # unzip file if neccessary
    if ($evt1 =~ /\.gz$/) {
	 system("gunzip -f $evt1");
	 $evt1 =~ s/\.gz$//;
    }

    # figure out CALDB version and processing version of data
    $caldbver = &sub_get_info($evt1,"CALDBVER");
    $date     = &sub_get_info($evt1,"DATE");
    $cticorr  = &sub_get_info($evt1,"CTI_CORR");
    $ctiapp   = &sub_get_info($evt1,"CTI_APP");
    $sdpver   = &sub_get_info($evt1,"ASCDSVER");
    $readmode = &sub_get_info($evt1,"READMODE");
    $detname  = &sub_get_info($evt1,"DETNAM");
    $fptemp   = &sub_get_info($evt1,"FP_TEMP");
    $datamode = &sub_get_info($evt1,"DATAMODE");

    #format sdpver for numerical comparison
    @sdpver  = split//,$sdpver;
    $sdpver0 = $sdpver[0];
    $sdpver1 = $sdpver[2];
    $sdpver  = join('',$sdpver0,$sdpver1);
    $sdpver  = 00 if ($sdpver =~ /^R/);

    # print the values of each var
    print "## STATUS: dmkeypar ERROR acceptable, no CTI correction in SDP\n\n" if ($cticorr eq "");
    print "## STATUS: dmkeypar ERROR acceptable, no CTI correction in SDP\n\n" if ($ctiapp eq "");
    print "## STATUS: Analyzing evt1 file for OBSID $obsid, $name\n";
    print "## STATUS: CALDB version:  $caldbver\n";
    print "## STATUS: Date of obs:    $date\n";
    print "## STATUS: Readmode:       $readmode\n";
    print "## STATUS: Datamode:       $datamode\n";
    print "## STATUS: SDP version:    $sdpver\n";
    print "## STATUS: Active CCDs:    $detname\n";
    print "## STATUS: FP temperature: $fptemp K\n";

    # set eventdef
    if ($readmode eq "TIMED" && ($datamode eq "FAINT" || $datamode eq "VFAINT")) {
      $eventdef = ")stdlev1";
    } elsif ($readmode eq "TIMED" && $datamode eq "GRADED") {
      $eventdef = ")grdlev1";
    } elsif ($readmode eq "CONTINUOUS" && ($datamode eq "CC_FAINT" || $datamode eq "CC33_FAINT")) {
      $eventdef = ")cclev1";
    } elsif ($readmode eq "CONTINUOUS" && ($datamode eq "CC_GRADED" || $datamode eq "CC33_GRADED")) {
      $eventdef = ")ccgrdlev1";
    } else {
      die "\n## ERROR: $obsid: Don't know $readmode + $datamode combination for $obsid\n";
    }

    # remove afterglow correction if sdpver lower than 7.4
    if ($remove_afterglow eq "yes") {
      if ($sdpver < 74) {
	print "## STATUS: SDP version lower than 7.4.0, removing ACIS afterglow correction for ${obsid}\n";
	system("punlearn dmtcalc; dmtcalc infile=$evt1 outfile=${obsid}_reset_evt1.fits "
	       ."expression=\"status=status,status=X15F,status=X14F,status=X13F,status=X12F\" clob+ verbose=$verb");
	${evt1} = "${obsid}_reset_evt1.fits";
      }
    }

    # now create a new badpix file if necessary
    if ($create_bpix eq "yes") {
      if ($sdpver < 74 && ($datamode eq "FAINT" || $datamode eq "GRADED")) {
	print "## STATUS: Creating new bpix file\n";
	$fail = &sub_make_bpix(${evt1});
      } elsif ($sdpver < 76 && $datamode eq "VFAINT") {
	print "## STATUS: Creating new bpix file\n";
	$fail = &sub_make_bpix(${evt1});
      }
      if (-e ${newbpix}) {
	$tempdir = cwd();
	$tempbpix = join('/',$tempdir,${newbpix});
	$command = "punlearn ardlib; acis_set_ardlib ${tempbpix} absolutepath=yes verbose=$verb";
	system($command);
	print "## STATUS: New badpix file created: ${newbpix}\n";
      }
      if ($fail eq "yes") {
	$offender = "make_bpix";
	&sub_logerror($offender);
	next;
      }
    }

    # check if the CTI correction has been applied
    # no cti for -90 C, -100 C, -110 C (163.14 K), spatial, or timing
    if ($fptemp < 162) {
      print "## STATUS: CTI correction will be applied for ${obsid}\n";
      $apply_cti = "yes";
    } else {
      $apply_cti = "no";
    }

    # make a new evt1 file
    if ($make_new_evt1 eq "yes") {
      # make new evt1 file
      print "## STATUS: Running acis_process_events to make new evt1 file ($newevt1)\n";

      # construct appropriate acis_process_events command
      system("punlearn acis_process_events");
      if ($datamode eq "VFAINT") {
	$command = "acis_process_events infile=$evt1 outfile=$newevt1 acaofffile=\"$asol\" "
	  ."eventdef=\"$eventdef\" apply_cti=$apply_cti mode=h rand_pix_size=0.0 "
	    ."check_vf_pha=yes clob+ verbose=$verb";
      } else {
	$command = "acis_process_events infile=$evt1 outfile=$newevt1 acaofffile=\"$asol\" "
	  ."eventdef=\"$eventdef\" apply_cti=$apply_cti mode=h rand_pix_size=0.0 "
	    ."clob+ verbose=$verb";
      }
      system($command);

      # check that it worked or return an error
      if (-e $newevt1) {
	print "\n## STATUS: New evt1 file created: ${newevt1}\n\n";
      } else {
	return "yes";
      }
    }

    # make a new evt2 file
    if ($make_new_evt2 eq "yes") {

      # do grade selection
      print "## STATUS: Doing grade selection\n";
      $command = "punlearn dmcopy; dmcopy \"${newevt1}[EVENTS][grade=0,2,3,4,6,status=0]\" "
	."evt2_pre1.fits opt=all clob+ verbose=$verb";
      system($command);

      # apply GTIs
      print "## STATUS: Applying GTIs\n";
      $command = "punlearn dmcopy; dmcopy \"evt2_pre1.fits[EVENTS][${flt}]\" evt2_pre2.fits opt=all "
	."clob+ verbose=$verb";
      system($command);

      # destreak chip s4 (chip 8)
      if (${id} eq "s4") {
	$command = "punlearn destreak; destreak infile=evt2_pre2.fits outfile=$newevt2 ccd_id=8 "
	  ."clob+ verbose=$verb";
	system($command);
      } else {
	system(`mv evt2_pre2.fits ${newevt2}`);
      }

      # cleanup
      print "## STATUS: Cleaning up temp files\n";
      unlink "evt2_pre1.fits";
      unlink "evt2_pre2.fits";

      # check that it worked or return an error
      if (-e $newevt2) {
	print "\n## STATUS: New evt2 file created: ${newevt2}\n\n";
      } else {
	return "yes";
      }
    }
}

#######################
#######################

sub sub_clean_events {

    # input parameters
    my($evt2file,$lcfile,$fidfile,$outfile) = @_;

    # make sure events file exists
    die "\n## ERROR: Cannot find $evt2file\n" unless (-e $evt2file);

    # local variables
    my($output,$gti,$total);
    my($nbins_bi) = 1037.12; # use same binlength as Markevitch backgrounds for BI chips
    my($nbins_fi) = 259.28;  # FI chips
    my($psfile)  = "${obsid}_lc";
    my($pngfile) = "${obsid}_lc.png";
    my($gtifile) = "${obsid}_${id}_gti.fits";
    my($regfile) = "${obsid}_clean.reg";

    # set bin size for fi, bi, or s3
    if (${id} eq "s1" || ${id} eq "s3") {
	$nbins = $nbins_bi;
    } else {
	$nbins = $nbins_fi;
    }
    
    # make a source region using x, y, and rmax
    if (($fidx =~ /\./) || ($rmax <= 0.0)) {
	print "## WARNING: Either the fiducial (x,y) coordinates are RA and Dec,\n";
	print "##          or rmax is <= 0.0. You pretty much have to use a source\n";
	print "##          free region for lc filtering, so you need to set (x,y) \n";
	print "##          in phys coords and give me an rmax which is not zero.\n";
	die "## ERROR: Cannot remove source region for lightcurve filtering\n";
    } elsif ($instr eq "i") {
	open(SREG,">$regfile");
	printf SREG "circle(${fidx},${fidy},${rmax})\n";
	close SREG;
    } else {
	my $rout = $rmax/2.0;
	open(SREG,">$regfile");
	printf SREG "circle(${fidx},${fidy},${rout})\n";
	close SREG;
    }

    # delete old files
    unlink $gtifile if (-e $gtifile);
    unlink $lcfile  if (-e $lcfile);
    unlink $psfile  if (-e $psfile.'.ps');
    unlink $pngfile if (-e $pngfile);
    unlink $outfile if (-e $outfile);


    # make new events file excluding cluster region and use energy
    # range as given by Markevtich in the cookbook for appropriate
    # chip (BI or FI).
    if (${id} eq "s3") {
	$command = "punlearn dmcopy; dmcopy \"${evt2file}\[energy=2500:7000,ccd_id=7]\" "
	    ."tempclean1.fits clob+ verbose=$verb";
    } elsif (${id} eq "s1") {
	$command = "punlearn dmcopy; dmcopy \"${evt2file}\[energy=2500:6000,ccd_id=5]\" "
	    ."tempclean1.fits clob+ verbose=$verb";
    } else {
	if ($instr =~ "i") {
	    $command = "punlearn dmcopy; dmcopy \"${evt2file}\[energy=300:12000,ccd_id=0,1,2,3]\" "
		."tempclean1.fits clob+ verbose=$verb";
	} else {
	    $command = "punlearn dmcopy; dmcopy \"${evt2file}\[energy=300:12000,ccd_id=$chip_id{$id}]\" "
		."tempclean1.fits clob+ verbose=$verb";
	}
    }
    system($command);

    # make an event file cleaned of bright sources
    if (-e ${regfile}) {
	print "\n## STATUS: Found ${regfile}.  Excluding sources from events.\n\n";
	print "## STATUS: Cleaning events file of sources\n";
	$command = "punlearn dmcopy; dmcopy \"tempclean1.fits\[exclude sky=region(${regfile})]\" "
	    ."tempclean2.fits clob+ verbose=$verb";
	system $command;
	$tempevt = "tempclean2.fits";
    } else {
	$tempevt = "tempclean1.fits";
    }

    # make the lightcurve
    $command = "punlearn dmextract; dmextract infile=\"${tempevt}\[bin time=::${nbins}]\" "
	."outfile=$lcfile opt=ltc1 clob+ verbose=$verb";
    print "$command\n";
    system($command);

    # for light curves with strong flares the mean bgd rate must be set
    if (-e "${flarefile}") {
	open(FLAREFILE,"${flarefile}");
	while (<FLAREFILE>) {
	    chomp;
	    $line = $_;
	    next if (/^\#/); # skip comment lines
	    next if (/^$/);  # skip blank lines
	    s/^\s+//;        # trim leading whitespace
	    s/\s+$//;        # trim trailing whitespace
	    @a = split(/\s+/,$line);
	    $fobsid = $a[0];
	    $fmean  = $a[1];
	    if ($fobsid ne $obsid) {
		$chflare = "";
		next;
	    } else {
		$chflare = "mean=${fmean},\n";
		last;
	    }
	}
	close FLAREFILE;
    } else {
	$chflare = "";
    }

    # use get good time intervals and produce plot
    print "\n## STATUS: Running lightcurve cleaning\n\n";
    open(CHFILE,">chips.py") || die "\n## ERROR: $obsid: Cannot open chips.py\n";
    print CHFILE 'from lightcurves import *'."\n";
    print CHFILE "lc_clean(\"${lcfile}\", outfile=\"${gtifile}\", ${chflare} plot=True, pattern=\"none\", verbose=1)\n";
    print CHFILE "print_window(\"${psfile}\", \[\"fittopage\", True, \"clobber\", True, \"orientation\", \"landscape\"])\n";
    print CHFILE "exit\n";
    system("chips -n -l python -b chips.py");

#####################################
# deprecated < ciao4.0 style lc_clean
#     open(CHFILE,">chips.sl") || die "\n## ERROR: $obsid: Cannot open chips.sl\n";
#     print CHFILE "() = evalfile(\"/bin/lc_clean.sl\")\n";
#     print CHFILE "lc->verbose = 1\n";
#     print CHFILE "$chflare" if ($chflare ne "");
#     print CHFILE "lc->outfile = \"${gtifile}\"\n";
#     print CHFILE "lc_clean(\"$lcfile\")\n";
#     print CHFILE "print postfile $psfile\n";
#     print CHFILE  "exit\n";
#     close CHFILE;
#     system("chips --batch chips.sl");
#####################################

    # check that it worked
    if (-e $gtifile) {
	print "## STATUS: Light curve processing complete\n";

	# set GTI table in events file
	print "\n## STATUS: Creating new events file ($outfile) from GTI info\n\n";
	system("dmcopy \"${fidfile}\[\@${gtifile}]\" $outfile clob+");
	system("dmcopy \"${evt2file}\[\@${gtifile}]\" $evt2file clob+");

	# make directory to store light curves
	mkdir("$lcdir",0777) unless (-d "$lcdir");

	# copy light curve to a dir
	$command = "cp -f ${psfile}.ps ${lcdir}/";
	system($command);
	print "## STATUS: Copied light curve ${psfile}.ps to $lcdir\n";
	unlink("tempclean1.fits");
	unlink("tempclean2.fits");
	unlink("chips.sl");
    } else {
	unlink("tempclean1.fits");
	unlink("tempclean2.fits");
	unlink("chips.sl");
	return "yes";
    }
}

#######################
#######################

sub sub_make_regions {

    my($evtfile,$regfits) = @_;

    # create the fits file
    print "## STATUS: Creating FITS file $regfits containing defined chip boundaries.\n";
    $command = "punlearn skyfov ; skyfov $evtfile $regfits aspect=$asol kernel=FITS clob+ verbose=0";
    system($command);
}

#######################
#######################

sub sub_make_blank_bgd {

    my($evtfile) = @_;
    my($a,$bgdfile,@bgfiles,@pcadfiles,$pcad,
       @mergefiles,@rmfiles,$aim,$expt,$ont,$lvt);

    # define and clear filename
    my($bgevtfile) = "${obsid}_bgevt.fits";
    unlink $bgevtfile if (-e $bgevtfile);

    # get the bgd file from CALDB
    chomp(@bgfiles = `punlearn acis_bkgrnd_lookup; acis_bkgrnd_lookup ${evtfile}`);
    $bgdfile = join(",",@bgfiles);

    # only proceed if we have file(s)
    if ($bgdfile ne "") {

	# only do the following filter for vfaint mode
	$datamode = &sub_get_info($evtfile,"DATAMODE");

	# get proper times for AIM chip
	my $src = $chip_id{${id}};
	$aim = "${src}${instr}D";
	foreach $a (@bgfiles) {
	    if ($a =~ /$aim/) {
		print "## STATUS: Using $a times for merged file\n";
		$expt = &sub_get_info($a,"EXPOSURE");
		$ont  = &sub_get_info($a,"ONTIME");
		$lvt  = &sub_get_info($a,"LIVETIME");
		last;
	    }
	}

	# filter the background if status column exists
	$i = 0;
	undef @mergefiles;
	undef @rmfiles;
	foreach $a (@bgfiles) {

	    # check for status column
	    unlink("temp");
	    system("punlearn dmlist ; dmlist \"$a\[cols status\]\" opt=data rows=1 cells=1 outfile=temp verbose=0");
	    if (-e "temp") {
		if ($datamode eq "VFAINT") {
		    print "## STATUS: Data taken in VFAINT mode and status exists, filtering bgd...\n";
		    $command = "punlearn dmcopy ; dmcopy \"${a}[events][status=b0]\" temp.fits verbose=$verb clob+";
		    system($command);
		    $command = "punlearn dmcopy ; dmcopy \"temp.fits[cols -status]\" ${i}.fits verbose=$verb clob+";
		    system($command);
		    push @mergefiles,"${i}.fits";
		    push @rmfiles,"${i}.fits";
		    unlink("temp.fits");
		} else {
		    print "## STATUS: Data taken in FAINT mode no filtering required.\n";
		    $command = "punlearn dmcopy ; dmcopy \"${a}[cols -status]\" ${i}.fits verbose=$verb clob+";
		    system($command);
		    push @mergefiles,"${i}.fits";
		    push @rmfiles,"${i}.fits";
		}
	    } else {
		print "## STATUS: ignore the above error, it's okay.\n";
		push @mergefiles,"${a}";
	    }
	    $i++;
	}
	unlink("temp");
	$bgdfile = join(",",@mergefiles);

	# merge all the bgd files into one
	print "## STATUS: Merging...\n";
	$command = "punlearn dmmerge; dmmerge \"$bgdfile\" tempbgd.fits outBlock=\"\" columnList=\"\" clob+ verbose=0";
	system($command);

	# check the gain file used
	my $gain = &sub_get_info($evtfile,"GAINFILE");
	my $bgdgain = &sub_get_info("tempbgd.fits","GAINFILE");
	if ($gain ne $bgdgain) {
	    print "## WARNING: Gain files do not match between events file and blank-sky backgrounds:\n";
	    print "## Events: $gain\n";
	    print "## Bgd:    $bgdgain\n";
	    print "## STATUS: Updating bgd gain file...\n";
	    $command = "punlearn acis_process_events; acis_process_events infile=tempbgd.fits outfile=tempbgd2.fits"
		." acaofffile=NONE stop=\"none\" doevtgrade=no apply_cti=yes apply_tgain=no"
		." calculate_pi=yes gainfile=\$CALDB/data/chandra/acis/det_gain/${gain}"
		." eventdef=\"\{s:ccd_id,s:node_id,i:expno,s:chip,s:tdet,f:det,f:sky,s:phas,l:pha,l:pha_ro,f:energy,l:pi,s:fltgrade,s:grade,x:status\}\""
		." verbose=$verb clob+";
	    system($command);
	    die "## ERROR: Updating the gain file failed.\n" unless (-e "tempbgd2.fits");
	    system("mv -f tempbgd2.fits tempbgd.fits");
	}

	# reproject events
	print "## STATUS: Reprojecting...\n";
	$command = "punlearn reproject_events; reproject_events infile=\"tempbgd.fits\" outfile=\"$bgevtfile\" aspect=\"$asol\" "
	    ."match=$evtfile random=0 mode=h verbose=$verb clob+";
	system($command);

	# clean up the temp files
	unlink("tempbgd.fits");

	# correct the summed header keywords
	$command = "dmhedit $bgevtfile filelist=\"\" op=add key=EXPOSURE value=$expt unit=s";
	system($command);
	$command = "dmhedit $bgevtfile filelist=\"\" op=add key=ONTIME value=$expt unit=s";
	system($command);
	$command = "dmhedit $bgevtfile filelist=\"\" op=add key=LIVETIME value=$expt unit=s";
	system($command);
    } else {
	print "## ERROR: no bgd files found\n";
	return "yes";
    }
    unlink(@rmfiles);
    if (-e $bgevtfile) {
	return "no";
    } else {
	return "yes";
    }
}

#######################
#######################

sub sub_make_addblank_bgd {

  my($evtfile) = @_;
  my($bgdfile,@pcadfiles,$pcad);

  if ($instr eq "s") {
    @bgd_id = ("i2", "i3");
  } elsif ($instr eq "i") {
    @bgd_id = ("s2", "s3");
  } else {
    die "## ERROR: You've given me an unknown chip_id... sinner >:)\n";
  }

  my $i = 0;
  my $check = "no";
  while ($i < 2 && $check ne "ok") {

    # isolate the input chip
    $isoid = "$bgd_id[$i]";
    $isoevt = "temp_${isoid}.fits";
    $command = "punlearn dmcopy; dmcopy \"${evtfile}\[ccd_id=$chip_id{$isoid}\]\" $isoevt clob+ verbose=$verb";
    system($command);

    # check that the chip exists, if not move to i3
    $command = "punlearn dmlist; dmlist \"${isoevt}[events]\" counts outfile=temp.log";
    system($command);

    # store those counts as a variable
    $cts = &sub_use_dmlist("temp.log");
    unlink("temp.log");

    # move to another chip if no counts
    if ($cts == 0) {
      print "## STATUS: No counts on $isoid, moving to new chip\n";
      unlink($isoevt);
      $check = "no";
      $i++;
    } else {
      # check for a bgd file from CALDB
      @bgdfile = `acis_bkgrnd_lookup ${isoevt}`;
      if (@bgdfile) {
	chomp($bgdfile = $bgdfile[0]);
	print "## STATUS: Using $isoid\n";
	print "## STATUS: With bgd file $bgdfile\n";
	$check = "ok";
	last;
      } else {
	print "## STATUS: No bgd file found for $isoid\n";
	unlink($isoevt);
	$check = "no";
	$i++;
      }
    }
    if ($i == 2) {
      print "## STATUS: No viable off source chip background to use\n";
      unlink($isoevt);
      return "yes";
    }
  }

  # proceed only if bgdfile exists, otherwise,
  my $dname = $bgdfile;
  $dname =~ s/\[.*?\]//g;
  if (-e $dname) {

    # single chip
    my $tempbgd = "bgevt_${isoid}.fits";
    $command = "punlearn dmcopy; dmcopy \"${bgdfile}[ccd_id=$chip_id{$isoid}]\" $tempbgd clob+ verbose=$verb";
    system($command);

    # reproject events
    my($xbgevtfile) = "x${obsid}_bgevt.fits";
    system("punlearn reproject_events");
    my($bgevtfile) = "${obsid}_${isoid}_bgevt.fits";
    unlink $bgevtfile if (-e $bgevtfile);
    $command = "reproject_events infile=\"${tempbgd}\" outfile=\"$bgevtfile\" "
      ."aspect=\"$asol\" match=$isoevt random=0 mode=h verbose=$verb clob+";
    system($command);

    # clean up the temp file
    unlink $xbgevtfile;

    # check the datamode of the obs
    $datamode = &sub_get_info($evtfile,"DATAMODE");

    # filter the background if it's needed
    if ($datamode eq "VFAINT") {
      print "## STATUS: Data taken in VFAINT mode, background needs check_vf_pha filter applied\n";
      $command = "dmcopy \"${bgevtfile}[events][status=b0]\" tempbgd.fits verbose=$verb clob+";
      system($command);
      system(`mv -f tempbgd.fits ${bgevtfile}`);
      unlink("tempbgd.fits");
    }

    # clean-up
    unlink($isoevt);
    unlink($tempbgd);

  } else {
    # if anything goes wrong report an error
    return "yes";
  }
}

#######################
#######################

sub sub_get_evt1name {

    # get the evt1 file name

    my($curdir,$dir,@infile,$evt1,@dir,@globlist);
    $curdir = cwd();

    # change to appropriate dir (they sometimes change the locations)
    # glob for matching file names
    @dir = qw(primary secondary);
    @infile = ();
    foreach $dir (@dir) {
	chdir $dir;
	@globlist = glob("acis*evt1*");
	@globlist = map { "../$dir/" . $_} @globlist if (@globlist);
	push @infile, @globlist;
	chdir "../";	
    }

    die "\n## ERROR: $obsid: No evt1 file\n" unless (@infile);
    $evt1   = shift @infile;

    # return the name
    chdir($curdir);
    return $evt1;
}

#######################
#######################

sub sub_get_asolfile {

    # get the asol file for files
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

    die "\n## ERROR: $obsid: No asol files found.\n" unless (@infile);
    $asol = join(",",@infile);

    # return the name(s)
    chdir($curdir);
    return $asol;
}

#######################
#######################

sub sub_get_fltfile {

    # get the flt file for files
    my($curdir,@infile,$flt,@dir,@globlist);
    $curdir = cwd();

    # change to appropriate dir (they sometimes change the locations)
    @dir = qw(primary secondary);
    @infile = ();
    foreach $dir (@dir) {
	chdir $dir;
	@globlist =  <acis*flt*.fits*>;
	@globlist = map { "@../$dir/" . $_} @globlist if (@globlist);
	push @infile, @globlist;
	chdir "../";	
    }

    die "\n## ERROR: $obsid: No flt files to make aspect histogram.\n" unless (@infile);
    $flt = join(",",@infile);

    # return the name(s)
    chdir($curdir);
    return $flt;

}

#######################
#######################

sub sub_set_ardlib {

    # define local vars
    my(@bpix,$bpix,$curdir,$command,@dir,$dir,@globlist);
    $curdir = cwd();

    # glob for matching file names
    @dir = qw(reprocessed primary secondary);
    foreach $dir (@dir) {
	chdir("$datadir/$obsid/$dir");
        @globlist = <*bpix*.fits*>;
        @globlist = map { "$datadir/$obsid/$dir/" . $_} @globlist if (@globlist);
        last if (@globlist);
        chdir $curdir;
    }
    die "## ERROR: No bpix file for $obsid\n" unless (@globlist);
    $bpix = $globlist[0];

    # unzip if necesary
    if ($bpix =~ /gz$/) {
	system("gunzip -f $bpix");
	$bpix =~ s/\.gz$//;
    }

    # go bakc to orig dir
    chdir($curdir);

    # get the chips to use
    $command = "punlearn ardlib; acis_set_ardlib ${bpix} absolutepath=yes verbose=$verb";
    system($command);
}

#######################
#######################

sub sub_logerror {

    my($offender) = @_;
    chdir("$Bin");
    open  ERRFILE,">>errors.log";
    print "## ERROR: Failure in reprocess.pl at $offender for ObsID $obsid at ",scalar(localtime),"\n";
    print ERRFILE "${obsid} # failure in reprocess.pl, $offender ",scalar(localtime),"\n";
    close ERRFILE;
}

#######################
#######################

sub sub_make_bpix {

  my($evt1) = @_;
  my($curdir,$bpix,$bias,$mask,$pbk);
  $curdir = cwd();

  # change to appropriate dir (they sometimes change the locations)
  # glob for matching file names
  @bpix = glob("../primary/acis*bpix1*");
  die "\n## ERROR: $obsid: No bpix file\n" unless (@bpix);
  $bpix = shift @bpix;

  @mask = glob("../secondary/acis*msk1*");
  die "\n## ERROR: $obsid: No mask file\n" unless (@mask);
  $mask = shift @mask;

  system(`ls -1 ../secondary/acis*bias0* > ${obsid}_bias.lis`);
  $bias = "${obsid}_bias.lis";

  @pbk = glob("../secondary/acis*pbk0*");
  die "\n## ERROR: $obsid: No pbk file\n" unless (@pbk);
  $pbk = shift @pbk;

  # unzip if necesary
  if ($bpix =~ /gz$/) {
    system("gunzip -f $bpix");
    $bpix =~ s/\.gz$//;
  }
  if ($mask =~ /gz$/) {
    system("gunzip -f $mask");
    $mask =~ s/\.gz$//;
  }
  if ($bias =~ /gz$/) {
    system("gunzip -f $bias");
    $bias =~ s/\.gz$//;
  }
  if ($pbk =~ /gz$/) {
    system("gunzip -f $pbk");
    $pbk =~ s/\.gz$//;
  }

  # build new bpix file
  print "## STATUS: Creating new badpix file\n";
  $command = "punlearn acis_build_badpix; punlearn acis_run_hotpix; acis_run_hotpix infile=${evt1} outfile=${newbpix} badpixfile=${bpix}"
      ." biasfile=\@${bias} maskfile=${mask} pbkfile=${pbk} clob+ verbose=$verb";
  system($command);

  # clean-up
  unlink("${obsid}_bias.lis");

  # return the name
  chdir($curdir);

}

#######################
#######################

sub sub_use_dmlist {

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

sub sub_write_log {

    # get the evt1 file name
    my $evt = &sub_get_evt1name();
    my $caldbver = &sub_get_info($evt,"CALDBVER");
    my $readmode = &sub_get_info($evt,"READMODE");
    my $detname  = &sub_get_info($evt,"DETNAM");
    my $fptemp   = &sub_get_info($evt,"FP_TEMP");
    my $datamode = &sub_get_info($evt,"DATAMODE");
    my $sdpver   = &sub_get_info($evt,"ASCDSVER");
    my @sdpver   = split//,$sdpver;
    my $sdpver0  = $sdpver[0];
    my $sdpver1  = $sdpver[2];
    $sdpver      = join('',$sdpver0,$sdpver1);
    $sdpver      = 00 if ($sdpver =~ /^R/);
    my $dateobs  = &sub_get_info($evt,"DATE-OBS");
    my $dateend  = &sub_get_info($evt,"DATE-END");
    my $exp      = &sub_get_info($evt,"EXPOSURE");
    my $gain     = &sub_get_info($evt,"GAINFILE");
    my $grat     = &sub_get_info($evt,"GRATING");
    my $obj      = &sub_get_info($evt,"OBJECT");
    my $obsy     = &sub_get_info($evt,"OBSERVER");
    my $ranom    = &sub_get_info($evt,"RA_NOM");
    my $decnom   = &sub_get_info($evt,"DEC_NOM");
    my $rollnom  = &sub_get_info($evt,"ROLL_NOM");
    my $ratarg   = &sub_get_info($evt,"RA_TARG");
    my $dectarg  = &sub_get_info($evt,"DEC_TARG");
    my $equin    = &sub_get_info($evt,"EQUINOX");
    my $title    = &sub_get_info($evt,"TITLE");
    my $seqnum   = &sub_get_info($evt,"SEQ_NUM");
    my $dtcor    = &sub_get_info($evt,"DTCOR");

    my $out = "${obsid}_info.txt";
    print "## STATUS: Writing observation info to $out\n";
    open(A,">$out");
    print A "############################################\n";
    print A "############################################\n";
    print A "\n";
    print A "Observation Information for $name ($obsid)\n";
    print A "\n";
    print A "############################################\n";
    print A "############################################\n";
    print A "\n";
    printf A "%-20s %-s\n","Prop Title:",$title;
    printf A "%-20s %-s\n","Observer:",$obsy;
    printf A "%-20s %-s\n\n","Object:",$obj;
    printf A "%-20s %20s\n","SeqNum:",$seqnum;
    printf A "%-20s %20s\n","Started:",$dateobs;
    printf A "%-20s %20s\n","Ended:",$dateend;
    printf A "%-20s %20s\n","Equinox:",$equin;
    printf A "%-20s %20i\n","Exposure (sec):",$exp;
    printf A "%-20s %20s\n\n","Detectors:",$detname;
    printf A "%-20s %20.4f\n","Target RA:",$ratarg;
    printf A "%-20s %20.4f\n","Nominal RA:",$ranom;
    printf A "%-20s %20.4f\n","Target Dec:",$dectarg;
    printf A "%-20s %20.4f\n","Nominal Dec:",$decnom;
    printf A "%-20s %20.4f\n\n","Nominal Roll:",$rollnom;
    printf A "%-20s %20s\n","CalDB Version:",$caldbver;
    printf A "%-20s %20s\n","Pipeline Version:",$sdpver;
    printf A "%-20s %20.2f\n","Focal Temp (K):",$fptemp;
    printf A "%-20s %20s\n","Read Mode:",$readmode;
    printf A "%-20s %20s\n","Data Mode:",$datamode;
    printf A "%-20s %20s\n","Grating:",$grat;
    printf A "%-20s %-s\n","Gain File:",$gain;
    close A;
}

#######################
#######################
