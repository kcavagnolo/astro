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
#######################
#######################
##    Set Options    ##
#######################
#######################

# other options needed
$make_bgd = "yes";
$make_addbgd = "no";
$verb = 1;
$rootdir  = "reprocessed/";
$caldir   = "/usr/local/CALDB/data/chandra/acis/bcf/bkgrnd/";

#######################
#######################
##   Main Program    ##
#######################
#######################

# reference array for all chip ids
%chip_id = ("i0" =>"0", "i1" =>"1", "i2" =>"2", "i3" =>"3",
	    "s0"=>"4", "s1" =>"5", "s2" =>"6", "s3" =>"7",
	    "s4" =>"8", "s5" =>"9");
%addid = ("i2" =>"2s", "i3" =>"3s",
	  "s2" =>"6i", "s3" =>"7i");

# check the number of arguments given
die "## ERROR: Wrong number of command line arguments.\n" if (@ARGV != 1);

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
    $id      = $data[11];
    $datadir = $data[15];

    # change directory
    chdir("$datadir/$obsid/$rootdir/");

    # set badpix file
    sub_set_ardlib();

    # figure out which detector is in use
    $instr = "s" if ($id =~ /^s/);
    $instr = "i" if ($id =~ /^i/);
    $src = $chip_id{$id};

    # define file names
    $evtfile = "${obsid}_evt2.fits";
    $bgdfile = "${obsid}_bgevt.fits";
    $fail    = "";

    # check which add chip to use
    if ($make_addbgd eq "yes") {
      $fail = sub_find_addchip($evtfile);
      if ($fail eq "yes") {
	$offender = "sub_find_addchip";
	logerror($offender);
	next;
      }
      $addbgdfile  = "${obsid}_${aid}_bgevt.fits";
    }

    # first try doing each chip individually
    if ($make_bgd eq "yes"){
      @bgdfiles = sub_do_all($evtfile);
      if (@bgdfiles) {
	
	# make the bgd
	$fail = sub_make_bgd($evtfile,$bgdfile,@bgdfiles);
	if ($fail eq "yes") {
	  $offender = "sub_make_bgd";
	  logerror($offender);
	  next;
	}
	print "## ${obsid}: Created blank-sky background(s)\n";
	next;
      } else {
	print "\n## No bgd files found, forcing bgd creation using proper period.\n";
	
	# find the matching bgd files for period, ignoring all else
	@bgdfiles = sub_find_bgd($evtfile);
	if ($fail eq "yes") {
	  $offender = "sub_find_bgd";
	  logerror($offender);
	  next;
	}

	# make the bgd
	$fail = sub_make_bgd($evtfile,$bgdfile,@bgdfiles);
	if ($fail eq "yes") {
	  $offender = "sub_make_bgd";
	  logerror($offender);
	  next;
	}
	print "## ${obsid}: Created blank-sky background(s)\n";
      }
    }

    # extract additional bgd chip
    print "## Using $addbgd\n";
    $fail = sub_make_addbgd($evtfile,$addbgdfile,$addbgd) if ($make_addbgd eq "yes");
    if ($fail eq "yes") {
      $offender = "sub_make_addbgd";
      logerror($offender);
      next;
    }

    # change back to original directory
    chdir("$Bin");
  }
}

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

sub sub_read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## ERROR: Can't open $infile\n";
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
    system("pwd");
    @globlist = <*bpix*.fits*>;
    @globlist = map { "../$dir/" . $_} @globlist if (@globlist);
    last if (@globlist);;
    chdir $curdir;
  }

  die "## ERROR: $obsid: No bpix file\n" unless (@globlist);
  $bpix = $globlist[0];
  print "## Using bad pixel file: $bpix\n";

  # unzip if necesary
  if ($bpix =~ /gz$/) {
    system("gunzip -f $bpix");
    $bpix =~ s/\.gz$//;
  }

  # return the name
  chdir($curdir);

  # get the chips to use
  $chips = get_info($bpix,"DETNAM");

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

sub logerror {

  my($offender) = @_;

  chdir("$Bin");
  open  ERRFILE,">>err_force_bgd.log";
  print "${obsid} # failure in reprocess.pl, $offender ",scalar(localtime),"\n";
  print ERRFILE "${obsid} # failure in reprocess.pl, $offender ",scalar(localtime),"\n";
  close ERRFILE;

}

#######################
#######################

sub sub_do_all {

  my($in) = @_;
  my(@chips,$id,@files,$a,@bgdfiles);

  # check source chip first, if no bgd, there is no point in going on
  chomp(@files = `punlearn acis_bkgrnd_lookup; acis_bkgrnd_lookup "${in}\[ccd_id=${src}\]\"`);
  unless (@files) {
    print "## WARNING: No bgd files for source chip, moving on to force the issue.\n";
    return @bgdfiles;
  }

  # get the bgd file from CALDB
  @chips = qw(0 1 2 3 4 5 6 7 8);
  foreach $id (@chips) {
    undef @files;
    chomp(@files = `punlearn acis_bkgrnd_lookup; acis_bkgrnd_lookup "${in}\[ccd_id=${id}\]\"`);
    if (@files) {
      $a = $files[0];
      print "## Found $a for ccd_id=$id\n";
      push @bgdfiles,$files[0];
    } else {
      print "\n\n## IGNORE ERROR ## IGNORE ERROR ## IGNORE ERROR ## IGNORE ERROR ##\n";
      print "## IGNORE ERROR ## IGNORE ERROR ## IGNORE ERROR ## IGNORE ERROR ##\n\n";
    }
  }
  return @bgdfiles;
}

#######################
#######################

sub sub_find_bgd {

  my($in) = @_;
  my(%cald,$date,$year,$mon,$day,$per,
     @chips,$chip,$version,$file,$cti,
     @bgdfiles);

  %cald = ("A"=>"1999-09-16", "B"=>"1999-09-16",
	   "C"=>"2000-01-29", "D"=>"2000-12-01");

  $cti  = get_info($in,"CTI_CORR");
  $date = get_info($in,"DATE-OBS");
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

  # define the files
  # ACIS-S
  undef @bgdfiles;
  if ($instr eq "s") {
    if ($per eq "A") {
      push @bgdfiles,("$caldir/acis6sD$cald{$per}bkgrndN0002.fits",
		      "$caldir/acis7sD$cald{$per}bkgrndN0002.fits");
      $addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrndN0002.fits" if ($addbgd eq "nihil");
    }elsif ($per eq "B") {
      push @bgdfiles,("$caldir/acis6sD$cald{$per}bkgrndN0002.fits",
		      "$caldir/acis7sD$cald{$per}bkgrndN0002.fits",
		      "$caldir/acis8sD$cald{$per}bkgrndN0002.fits");
      $addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrndN0002.fits" if ($addbgd eq "nihil");
    } elsif ($per eq "C") {
      push @bgdfiles,("$caldir/acis7sD$cald{$per}bkgrndN0004.fits",
		      "$caldir/acis8sD$cald{$per}bkgrndN0004.fits");
      if ($cti =~ /^no/) {
	push @bgdfiles,("$caldir/acis6sD$cald{$per}bkgrndN0003.fits");
	$addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrndN0003.fits" if ($addbgd eq "nihil");
      } else {
	push @bgdfiles,("$caldir/acis6sD$cald{$per}bkgrnd_ctiN0004.fits");
	$addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrnd_ctiN0004.fits" if ($addbgd eq "nihil");
      }
    } elsif ($per eq "D") {
      push @bgdfiles,("$caldir/acis7sD$cald{$per}bkgrndN0005.fits",
		      "$caldir/acis8sD$cald{$per}bkgrndN0005.fits");
      if ($cti =~ /^no/) {
	push @bgdfiles,("$caldir/acis6sD$cald{$per}bkgrndN0002.fits");
	$addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrnd_N0002.fits" if ($addbgd eq "nihil");
      } else {
	push @bgdfiles,("$caldir/acis6sD$cald{$per}bkgrnd_ctiN0005.fits");
	$addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrnd_ctiN0003.fits" if ($addbgd eq "nihil");
      }
    } else {
      die "## ERROR: bad period, $per.\n";
    }
  }

  # ACIS-I
  if ($instr eq "i") {
    if ($per eq "A") {
      die "## ERROR: no bgds for $per and $instr\n";
    }elsif ($per eq "B") {
      push @bgdfiles,("$caldir/acis0iD$cald{$per}bkgrndN0002.fits",
		      "$caldir/acis1iD$cald{$per}bkgrndN0002.fits",
		      "$caldir/acis2iD$cald{$per}bkgrndN0002.fits",
		      "$caldir/acis3iD$cald{$per}bkgrndN0002.fits");
      $addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrndN0002.fits" if ($addbgd eq "nihil");
    } elsif ($per eq "C") {
      if ($cti =~ /^no/) {
	push @bgdfiles,("$caldir/acis0iD$cald{$per}bkgrnd_ctiN0004.fits",
			"$caldir/acis1iD$cald{$per}bkgrnd_ctiN0004.fits",
			"$caldir/acis2iD$cald{$per}bkgrnd_ctiN0004.fits",
			"$caldir/acis3iD$cald{$per}bkgrnd_ctiN0004.fits");
	$addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrnd_ctiN0004.fits" if ($addbgd eq "nihil");
      } else {
	push @bgdfiles,("$caldir/acis0iD$cald{$per}bkgrndN0003.fits",
			"$caldir/acis1iD$cald{$per}bkgrndN0003.fits",
			"$caldir/acis2iD$cald{$per}bkgrndN0003.fits",
			"$caldir/acis3iD$cald{$per}bkgrndN0003.fits");
	$addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrnd_ctiN0004.fits" if ($addbgd eq "nihil");
      }
    } elsif ($per eq "D") {
      if ($cti =~ /^no/) {
	push @bgdfiles,("$caldir/acis0iD$cald{$per}bkgrnd_ctiN0003.fits",
			"$caldir/acis1iD$cald{$per}bkgrnd_ctiN0003.fits",
			"$caldir/acis2iD$cald{$per}bkgrnd_ctiN0003.fits",
			"$caldir/acis3iD$cald{$per}bkgrnd_ctiN0003.fits");
	$addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrnd_ctiN0003.fits" if ($addbgd eq "nihil");
      } else {
	push @bgdfiles,("$caldir/acis0iD$cald{$per}bkgrndN0002.fits",
			"$caldir/acis1iD$cald{$per}bkgrndN0002.fits",
			"$caldir/acis2iD$cald{$per}bkgrndN0002.fits",
			"$caldir/acis3iD$cald{$per}bkgrndN0002.fits");
	$addbgd = "$caldir/acis$addid{$aid}D$cald{$per}bkgrndN0002.fits" if ($addbgd eq "nihil");
      }
    } else {
      die "## ERROR: bad period, $per.\n";
    }
  }

  # exit subroutine
  return @bgdfiles;
}

#######################
#######################

sub sub_make_bgd {

  my($evtfile,$outfile,@bgdfiles) = @_;
  my($a,@mergefiles,@rmfiles,$mergefile);

  # get the asol file or files
  my $asol = get_asolfile();
  print "## Using $asol\n";

  # only do the following filter for vfaint mode
  my $datamode = get_info($evtfile,"DATAMODE");

  # get proper times for AIM chip
  my $aim = "${src}${instr}D";
  foreach $a (@bgdfiles) {
    if ($a =~ /$aim/) {
      $expt = get_info($a,"EXPOSURE");
      $ont  = get_info($a,"ONTIME");
      $lvt  = get_info($a,"LIVETIME");
      last;
    }
  }
  unless ($expt > 0 && $ont > 0 && $lvt > 0) {
    return "yes";
  }

  # filter the background if status column exists
  $i = 0;
  undef @mergefiles;
  undef @rmfiles;
  foreach $a (@bgdfiles) {

    # check for status column
    unlink("temp");
    system("punlearn dmlist ; dmlist \"$a\[cols status\]\" opt=data rows=1 cells=1 outfile=temp verbose=0");
    if (-e "temp") {
      if ($datamode eq "VFAINT") {
	print "## Data taken in VFAINT mode and status exists, filtering bgd...\n";
	$command = "punlearn dmcopy ; dmcopy \"${a}[events][status=b0]\" temp.fits verbose=$verb clobber=yes";
	system($command);
	$command = "punlearn dmcopy ; dmcopy \"temp.fits[cols -status]\" ${i}.fits verbose=$verb clobber=yes";
	system($command);
	push @mergefiles,"${i}.fits";
	push @rmfiles,"${i}.fits";
	unlink("temp.fits");
      } else {
	print "## Data taken in FAINT mode no filtering required.\n";
	$command = "punlearn dmcopy ; dmcopy \"${a}[cols -status]\" ${i}.fits verbose=$verb clobber=yes";
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
  $mergefile = join(",",@mergefiles);

  # merge all the bgd files into one
  print "## Merging...\n";
  $command = "punlearn dmmerge; dmmerge \"$mergefile\" tempbgd.fits outBlock=\"\" columnList=\"\" clobber=yes verbose=0";
  system($command);

  # reproject events
  print "## Reprojecting...\n";
  $command = "punlearn reproject_events; reproject_events infile=\"tempbgd.fits\" outfile=\"$outfile\" aspect=\"$asol\" "
    ."match=$evtfile random=0 mode=h verbose=$verb clobber=yes verbose=$verb";
  system($command);

  # clean up the temp files
  unlink("tempbgd.fits");

  # correct the summed header keywords
  $command = "dmhedit $outfile filelist=\"\" op=add key=EXPOSURE value=$expt unit=s";
  system($command);
  $command = "dmhedit $outfile filelist=\"\" op=add key=ONTIME value=$ont unit=s";
  system($command);
  $command = "dmhedit $outfile filelist=\"\" op=add key=LIVETIME value=$lvt unit=s";
  system($command);

  # clean-up
  unlink(@rmfiles);

  if (-e $outfile) {
    return "no";
  } else {
    return "yes";
  }
}

#######################
#######################

sub get_asolfile {

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

  die "\n## ERROR: $obsid:  No asol files found.\n" unless (@infile);
  $asol = join(",",@infile);

  # return the name(s)
  chdir($curdir);
  return $asol;
}

#######################
#######################

sub sub_make_addbgd {

  my($evtfile,$outfile,$bgdfile) = @_;

  # get the asol file or files
  my $asol = get_asolfile();
  print "## Using $asol\n";

  # only do the following filter for vfaint mode
  my $datamode = get_info($evtfile,"DATAMODE");

  # check for status column
  unlink("temp");
  system("punlearn dmlist ; dmlist \"$bgdfile\[cols status\]\" opt=data rows=1 cells=1 outfile=temp verbose=0");
  if (-e "temp") {
    if ($datamode eq "VFAINT") {
      print "## Data taken in VFAINT mode and status exists, filtering bgd...\n";
      $command = "punlearn dmcopy ; dmcopy \"${bgdfile}[events][status=b0]\" temp.fits verbose=$verb clobber=yes";
      system($command);
      $command = "punlearn dmcopy ; dmcopy \"temp.fits[cols -status]\" temp.fits verbose=$verb clobber=yes";
      system($command);
    } else {
      print "## Data taken in FAINT mode no filtering required.\n";
      $command = "punlearn dmcopy ; dmcopy \"${bgdfile}[cols -status]\" temp.fits verbose=$verb clobber=yes";
      system($command);
    }
  } else {
    print "## STATUS: ignore the above error, it's okay.\n";
  }

  # reproject events
  print "## Reprojecting...\n";
  $command = "punlearn reproject_events; reproject_events infile=\"temp.fits\" outfile=\"$outfile\" aspect=\"$asol\" "
    ."match=$evtfile random=0 mode=h verbose=$verb clobber=yes verbose=$verb";
  system($command);

  # clean up the temp files
  unlink("temp.fits");

  # clean-up
  unlink("temp.fits");

  if (-e $outfile) {
    return "no";
  } else {
    return "yes";
  }
}

#######################
#######################

sub sub_find_addchip {

  my($evtfile) = @_;
  my(@bgd_id,$isoevt,$command,$cts,@bgdfile);

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
    $aid = "$bgd_id[$i]";
    $isoevt = "temp_${aid}.fits";
    $command = "punlearn dmcopy; dmcopy \"${evtfile}\[ccd_id=$chip_id{$aid}\]\" $isoevt clobber=yes verbose=$verb";
    system($command);

    # check that the chip exists, if not move on...
    $command = "punlearn dmlist; dmlist \"${isoevt}[events]\" counts outfile=temp.log";
    system($command);

    # store those counts as a variable
    $cts = use_dmlist("temp.log");
    unlink("temp.log");

    # move to another chip if no counts
    if ($cts == 0) {
      print "## No counts on $aid, moving to new chip\n";
      unlink($isoevt);
      $check = "no";
      $i++;
    } else {
      # check for a bgd file from CALDB
      print "## Using $aid\n";
      @bgdfile = `acis_bkgrnd_lookup ${isoevt}`;
      if (@bgdfile) {
        chomp($addbgd = $bgdfile[0]);
        print "## Found addbgd file $addbgd in CALDB\n";
      } else {
	print "## IGNORE ERROR ## IGNORE ERROR\n";
	$addbgd = "nihil";
      }
      unlink($isoevt);
      $check = "ok";
    }
    if ($i == 2) {
      print "## No viable off source chip to use\n";
      unlink($isoevt);
      return "yes";
    }
  }
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
