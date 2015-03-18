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
#######################
#######################
##    Set Options    ##
#######################
#######################

$dopeak = "yes";
$dop10min = "yes";
$outcen = "peak";          # either peak or p10min written as new center
$newref = "newref.list";   # name of new reference file
$evtext = "exclude";       # FITS file name extension, e.g. exclude, clean, evt2...
$emin = 500;               # minimum energy to filter events on
$emax = 2000;              # maximum energy to filter events on
$binning = 64;             # initial binning of image (larger means faster)
$skernel = 'lib:gaus(2,4,1,8,8)';
$rootdir = "reprocessed";  # where to find and make new files
$verb = 1;                 # how much screen output

#######################
#######################
##   Main Program    ##
#######################
#######################

# Load useful libraries, make checks
use Cwd;
use FindBin qw($Bin);
use IPC::Open3;
use Math::Complex;
use Math::Round;
die "## ERROR: Wrong number of command line arguments.\n" if (@ARGV != 1);
die "## ERROR: CIAO is not loaded, type 'ciao' at the command line.\n" unless ($ENV{'ASCDS_BIN'});

# open new ref file
print "## WARNING: $newref exists! I refuse to clobber the file, will append instead.\n" if (-e $newref);
open(NEWREF,">>$Bin/${newref}");
open(LOGFILE,">peak_emi.log");
printf LOGFILE "%-25s %6s %20s %20s %20s %20s\n", "## Name", "Obsid", "Xpeak", "Ypeak", "Xp10", "Yp10\n";

# open file to new reference
&sub_print_info();

# Read in the reference file
%refdata  = read_file($ARGV[0]);

# Go through each cluster
{
    # split up the data line
    foreach $key (sort keys %refdata) {
	@data = split(/\s+/,$refdata{$key});
	if ($data[0] =~ /^\#/) {
	    &sub_write_ref(@data);
	    next;
	}

	# get values specific to each cluster
	$fail      = "no";
	$name      = $data[0];
	$obsid     = $data[1];
	$datadir   = $data[15];
	$peakreg   = "${obsid}_peak.reg";
	$p10minreg = "${obsid}_p10min.reg";
	$evtfile   = "${obsid}_${evtext}.fits";
	$bpix      = "${obsid}_bpix.fits";

	# write to log file
	print "## Started $name (ObsId $obsid) ",scalar(localtime),"\n";
	chdir("$datadir/$obsid/$rootdir");
	
	# make sure we have events files to work with
	unless (-e $evtfile) {
	    $offender = "no evt";
	    logerror($offender);
	    next;
	}
	unless (-e $bpix) {
	    $offender = "no bpix";
	    logerror($offender);
	    next;
	}

	# set badpix file
	`punlearn ardlib.par; punlearn acis_set_ardlib`;
	`acis_set_ardlib $bpix verb=0`;

        # get the asol file or files
        $asol = &sub_get_asolfile();

        # make an image
	&sub_make_img();
        if ($fail eq "yes") {
            $offender = "sub_make_img";
            logerror($offender);
            next;
	}

	# get the peak value of the emission
	if ($dopeak eq "yes") {
	    &sub_peak();
	    if ($fail eq "yes") {
		$offender = "sub_peak";
		logerror($offender);
		next;
	    }
	}

	# get the peak value of the emission
	if ($dop10min eq "yes") {
	    &sub_p10min();
	    if ($fail eq "yes") {
		$offender = "sub_p10min";
		logerror($offender);
		next;
	    }
	}
	
	# write X and Y to the reference file
	&sub_write_ref(@data);
	if ($fail eq "yes") {
	    $offender = "sub_write_ref";
	    logerror($offender);
	    next;
	}

	# close shop
	printf LOGFILE "%-25s %6s %20s %20s %20s %20s\n", $name, $obsid, $xcpeak, $ycpeak, $xcp10min, $ycp10min;
	unlink("smooth.fits");
	print "## Finished $name (ObsId $obsid) ",scalar(localtime),"\n";
	chdir("$Bin");
    }
}

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
close NEWREF;
close LOGFILE;
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub read_file {

    my($infile) = @_;
    my(@data,$name,%info);
    open(INFILE,$infile) || die "## EEROR: Cannot open $infile\n";
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

sub sub_get_asolfile {

    # get the asol file for files
    my($curdir,@infile,$asol,@dir,@globlist);
    $curdir = cwd();

    # change to appropriate dir (they sometimes change the locations)
    my $adir = "../primary/";
    chdir $adir;
    @globlist = <pcad*asol*.fits*>;
    if (@globlist) {
        @infile = map { "$adir" . $_} @globlist;
        $asol = join(",", @infile);
        chdir $curdir;  
        return $asol;
    } else {
        die "## ERROR: No $obsid asol files.\n" unless (@infile);
    }
}

#######################
#######################

sub sub_make_img {

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
    $command = "punlearn dmcopy; dmcopy \"${evtfile}[bin sky=$binning][energy=$emin:$emax][opt type=$dtype]\" "
	."temp.fits verbose=$verb clob+";
    system($command);
    $command = "punlearn dmstat; dmstat temp.fits centroid=no verb=0";
    system($command);
    unlink("temp.fits");

    # get the phys location of the max
    my $max = `pget dmstat out_max_loc`;
    my @data = split(/\,/, $max);
    my @maxx = split(/\./, $data[0]);
    my @maxy = split(/\./, $data[1]);
    chomp($maxx = $maxx[0]);
    chomp($maxy = $maxy[0]);

    # trap any errors
    if ($maxx > 0 && $maxy > 0) {
	print "## Coarse center of ($maxx,$maxy) found\n";
    } else {
	$fail = "yes";
	return
    }

    # make a finer grid, recenter
    my $reg = "circle(${maxx},${maxy},300)";
    $command = "punlearn dmcopy; dmcopy \"${evtfile}[sky=$reg][bin sky=1][energy=$emin:$emax][opt type=$dtype]\" "
	."temp.fits verbose=$verb clob+";
    system($command);

    # smooth the image using a Gaussian
    $command = "punlearn aconvolve; aconvolve infile=temp.fits outfile=smooth.fits kernelspec=\"$skernel\" "
	."method=fft edges=constant const=0 clob+ verbose=0";
    system($command);
    unlink("temp.fits");

    # trap any errors
    if (-e "smooth.fits") {
        print "## Smoothing complete\n";
    } else {
        $fail = "yes";
        return
    }
}

#######################
#######################

sub sub_peak {

    # find the peak
    $command = "punlearn dmstat; dmstat smooth.fits centroid=no verb=0";
    system($command);

    # get the phys location of the max
    my $max = `pget dmstat out_max_loc`;
    my @data = split(/\,/, $max);
    my @maxx = split(/\./, $data[0]);
    my @maxy = split(/\./, $data[1]);
    chomp($xpeak = $maxx[0]);
    chomp($ypeak = $maxy[0]);

    # convert to ra and dec from phys
    ($xcpeak,$ycpeak) = &sub_get_radec($xpeak,$ypeak);

    # trap any errors
    if ($xpeak > 0 && $ypeak > 0) {
	print "## Local maximum found at ($xpeak,$ypeak)\n";
	open(REGFILE,">$peakreg");
	print REGFILE "circle(${xpeak},${ypeak},10)\n";
	close REGFILE;
    } else {
	$fail = "yes";
	return
    }
}

#######################
#######################

sub sub_p10min {

    # make IDL calls
    open(PRO,">junk.pro");
    print PRO "img=mrdfits('smooth.fits',0)\n";
    print PRO "pmin=smallest_p1overp0(img,10)\n";
    print PRO "openw,1,'temp.log'\n";
    print PRO "printf,1,strcompress(pmin,/remove_all)\n";
    print PRO "close,1\n";
    close PRO;
    $idldir = $ENV{'IDL_DIR'};
    $pid = open3(\*IDL_INPUT, \*IDL_OUTPUT, \*IDL_ERR, "${idldir}/bin/idl") ||
	die "## ERROR: Cannot start IDL\n";
    print IDL_INPUT "print, '--Now in IDL--'\n";
    print IDL_INPUT "\@junk\n";
    while (<IDL_OUTPUT>) {
	chomp;
	print "idl: $_\n";
	print IDL_INPUT "exit\n";
    }
    print "idl: --Exiting IDL--\n";
    close IDL_INPUT;
    close IDL_OUTPUT;
    close IDL_ERR;
    waitpid($pid,0);
    delete $ENV{'DYLD_BIND_AT_LAUNCH'};

    # get coords
    open(FILE,"temp.log");
    while(<FILE>) {
	chomp;
	next if (/^\#/);
	next if (/^$/);
	s/^\s+//;
	s/\s+$//;
	@line = split;
	$xp10min = $line[0]+1.0; # to account for IDL using im[0] whereas pixels are numbered 1,2...
	$yp10min = $line[1]+1.0;
    }
    close FILE;
    unlink("temp.log");
    unlink("junk.pro");

    # coords are returned in image space
    # convert to physical space
    $command = "punlearn get_sky_limits; get_sky_limits smooth.fits verbose=0";
    system($command);
    my $grid = `pget get_sky_limits xygrid`;
    my @data = split(/\,/, $grid);
    my @fx = split(/\:/, $data[0]);
    my @fy = split(/\:/, $data[1]);
    $xp10min += round($fx[0]);
    $yp10min += round($fy[0]);

    # convert to ra and dec from phys
    ($xcp10min,$ycp10min) = &sub_get_radec($xp10min,$yp10min);

    # trap any errors
    if ($xp10min > 0 && $yp10min > 0) {
	print "## P1/P0 minimum found at ($xp10min,$yp10min)\n";
	open(REGFILE,">$p10minreg");
	print REGFILE "circle(${xp10min},${yp10min},10)\n";
	close REGFILE;
    } else {
	$fail = "yes";
	return
    }
}

#######################
#######################

sub sub_write_ref {
    my(@oldref) = @_;
    my @newref = @oldref;
    unless ($oldref[0] =~ /^\#/) {
	if ($outcen eq "peak") {
	    ($newref[2],$newref[3]) = ($xpeak,$ypeak);
	} else {
	    ($newref[2],$newref[3]) = ($xp10min,$yp10min);
	}
    }
    printf NEWREF "%-25s %6s %8i %8i %6.0f %7.0f %8.4f %6.2f %6.2f %6.2f %6.2f %5s %8.4f %5s %6.0f %20s %25s\n",
    $newref[0],$newref[1],$newref[2],$newref[3],$newref[4],$newref[5],$newref[6],$newref[7],
    $newref[8],$newref[9],$newref[10],$newref[11],$newref[12],$newref[13],$newref[14],$newref[15], $newref[16];
}

#######################
#######################

sub logerror {
    my($offender) = @_;
    chdir("$Bin");
    open  ERRFILE,">>err_peak_emi.log";
    print "## ERROR: ${obsid} failure in peak_emi.pl, $offender ",scalar(localtime),"\n";
    print ERRFILE "${obsid} # failure in peak_emi.pl, $offender ",scalar(localtime),"\n";
    close ERRFILE;
}

#######################
#######################

sub sub_print_info {
    printf NEWREF "%-25s %6s %8s %8s %6s %7s %8s %6s %6s %6s %6s %5s %8s %5s %6s %20s %25s\n",
    "#Name","ObsID","X","Y","Rmax","MinCts","z","Nh20","Tx","Fe","Lbol","Chip","E_obs","Diff","Robs","Location","Txref";
    printf NEWREF "%-25s %6s %8s %8s %6s %7s %8s %6s %6s %6s %6s %5s %8s %5s %6s %20s %25s\n",
    "#--","--","deg","deg","pix","cts","--","cm^-2","keV","solar","1d44es","--","keV","--","pix","--","--";
}

#######################
#######################

sub sub_get_radec {

    # run dmcoords
    ($inx, $iny) = @_;
    $command = "punlearn dmcoords; dmcoords infile=$evtfile asolfile=\"$asol\" x=$inx y=$iny opt=sky verb=0";
    system($command);
    
    # get output ra and dec
    $ra = `pget dmcoords ra`;
    $dec = `pget dmcoords dec`;
    $ra =~ s/^\s+//;
    $ra =~ s/\s+$//;
    $dec =~ s/^\s+//;
    $dec =~ s/\s+$//;
    return($ra,$dec);
}

#######################
#######################
