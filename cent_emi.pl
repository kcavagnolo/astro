#!/usr/bin/perl -w
#
# NAME:
#     cent_emi.pl
#
# PURPOSE:
#     This script finds the centroid of extended emission and writes
#     out the PHYSICAL coordinates to a new reference file. The
#     centroid positon is very important and will be used by many
#     other scripts... SO CHECK IT BY EYE!!! Check 2008ApJ...682..821C
#     for centroiding method explanation.
#
# EXPLANATION:
#     This script assumes the following directory structure:
#     $loc/$obsid/$rootdir
#
#     $loc is specified as the last column of the input file
#     $obsid is specified as the second column of the input file
#     $rootdir is specified in the 'options' section of this script
#
#     Example:
#     For $loc /mnt/DROBO and $obsid 2211 and $rootdir reprocessed,
#     this script will look in /mnt/DROBO/2211/reprocessed for all the
#     files needed to complete the data reduction
#
# CALLING SEQUENCE:
#     cent_emi.pl <reference list>
#
# INPUTS:
#     <reference list> -- File containing information about each cluster. Example:
#     #Name                      ObsID      X      Y   Rmax  MinCts        z   Nh20     Tx     Fe   Lbol  Chip    E_obs  Diff   Robs   Location
#     1E0657_56                   3184   3776   4026    590    5000   0.2960   6.53  11.64   0.23  46.20    i3   1.5432     y    200   /mnt/DROBO
#
# OUTPUTS:
#     New reference file with X and Y coords of the centroid; file name is set below w/ $newref
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$newref = "newcent.list";  # name of new reference file
$make_expmap = "no";      # are we going to do this right and use an exposure map?
$rm_ptsrc = "no";          # if set to 'no' then script looks for ptsrc clean <obsid>_exclude.fits as file to centroid
$emin = 700;               # minimum energy to filter events on
$emax = 2500;              # maximum energy to filter events on
$binning = 64;             # initial binning of image (larger means faster)
$imbin = 2;                # final binning of image (smaller means slower but -sometimes- more accurate)
$scales = "\"1.0 2.0 4.0\""; # pixel scales to search for sources, don't go too big, !! may remove core !!
$iter = 1;                 # number of wavdetect iterations to run (larger means cleaner, but slower)
$sigma = 2;                # number of sigma to make ellipse around srcs
$rootdir = "reprocessed";  # where to find and make new files
$verb = 0;                 # how much screen output

#######################
#######################
##   Main Program    ##
#######################
#######################

# Load useful libraries, make checks
use Cwd;
use FindBin qw($Bin);
use Math::Complex;
die "## ERROR: Wrong number of command line arguments.\n" if (@ARGV != 1);
die "## ERROR: CIAO is not loaded, type 'ciao' at the command line.\n" unless ($ENV{'ASCDS_BIN'});

# open new ref file
print "## WARNING: $newref exists! I refuse to clobber the file, will append instead.\n" if (-e $newref);
open(NEWREF,">>$Bin/${newref}");

# Define the chip number based on chip id
%chip_id = ("" =>"0", "i0" =>"0", "i1" =>"1", "i2" =>"2", "i3" =>"3", "s0"
            =>"4", "s1" =>"5", "s2" =>"6", "s3" =>"7", "s4" =>"8",
            "s5" =>"9");
%det_chip = ("i0" =>"ACIS-I0", "i1" =>"ACIS-I1", "i2" =>"ACIS-I2", "i3" =>"ACIS-I3", "s0"
             =>"ACIS-S0", "s1" =>"ACIS-S1", "s2" =>"ACIS-S2", "s3" =>"ACIS-S3", "s4" =>"ACIS-S4",
             "s5" =>"ACIS-S5");

# open file to new reference
&sub_print_info();

# Read in the reference file
%refdata  = read_file($ARGV[0]);

# Go through each cluster
{
    foreach $key (sort keys %refdata) {

	# split up the data line
	@data = split(/\s+/,$refdata{$key});
	if ($data[0] =~ /^\#/) {
	    &sub_write_ref(@data);
	    next;
	}

	# get values specific to each cluster
	$fail    = "no";
	$name    = $data[0];
	$obsid   = $data[1];
	$id      = $data[11];
	$diffuse = $data[13];
	$datadir = $data[15];

	# write to log file
	print "\n###### Started $name (ObsId $obsid) ",scalar(localtime),"\n\n";
	
	# figure out which detector to use
	$instr = "s" if ($id =~ /^s/);
	$instr = "i" if ($id =~ /^i/);
	@acisi = ("i0", "i1", "i2", "i3");
	
	# change directory
	chdir("$datadir/$obsid/$rootdir");
	
	# set badpix file
	&sub_set_ardlib();
	
	# define file names
	$regfile = "${obsid}_centroid.reg";
	if ($rm_ptsrc eq "yes") {
	    $evtfile = &sub_get_evtfile;
	} else {
	    $evtfile = "${obsid}_exclude.fits";
	    die unless (-e $evtfile);
	}
	print "## Using event file $evtfile\n";
	
	# make sure we have events files to work with
	unless (-e $evtfile) {
	    $offender = "no evt file";
	    logerror($offender);
	    next;
	}
	
	# rough out exp map
	&sub_expmap($evtfile) if ($make_expmap eq "yes");
	if ($fail eq "yes") {
	    $offender = "sub_expmap";
	    logerror($offender);
	    next;
	}

	# detect and remove point sources
	if ($rm_ptsrc eq "yes") {
	    &sub_rm_ptsrc();
	    if ($fail eq "yes") {
		$offender = "sub_rm_ptsrc";
		logerror($offender);
		next;
	    }
	    
	    # create background region for each pt src
	    &sub_mkbgreg();
	    if ($fail eq "yes") {
		$offender = "sub_mkbgreg";
		logerror($offender);
		next;
	    }
	    
	    # subtract source region from background region
	    &sub_mksubbgreg();
	    if ($fail eq "yes") {
		$offender = "sub_submkbgreg";
		logerror($offender);
		next;
	    }
	    
	    # fill the holes created by the point sources
	    &sub_fill_holes();
	    if ($fail eq "yes") {
		$offender = "sub_fill_holes";
		logerror($offender);
		next;
	    }
	}
	
	# get the centroid value of the emission
	&sub_centroid();
	if ($fail eq "yes") {
	    $offender = "sub_centroid";
	    logerror($offender);
	    next;
	}
	
	# write X and Y to the reference file
	&sub_write_ref(@data);
	if ($fail eq "yes") {
	    $offender = "sub_write_ref";
	    logerror($offender);
	    next;
	}

	# clean-up files
	unlink("img_full.fits");
	unlink("sources.fits");
	unlink("bkg.fits");
	unlink("scell.fits");
	unlink("image.fits");
	unlink("sources.reg");
	unlink("bkg.reg");
	unlink("bkg_sub.reg");
	unlink("img_filled.fits");
	unlink<*_stk>;
	unlink<temp*>;
	unlink<img*>;
	unlink("srcimg.fits");
	
	# write to log file
	print "\n###### Finished $name (ObsId $obsid) ",scalar(localtime),"\n\n";
	
	# write a region file for the centroid for easy viewing
	open(REGFILE,">$regfile");
	print REGFILE "circle(${x},${y},20)\n";
	close REGFILE;
	
	# change back to original directory
	chdir("$Bin");
    }
}

# close files
close NEWREF;
print "\n###### Finished centroiding emission ",scalar(localtime)," ######\n\n";

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub read_file {

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

    unless (@globlist) {
	print "## ERROR: $obsid, No bpix file\n";
	$fail = "yes";
	return;
    }
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

sub sub_get_evtfile {
    
    my(@infile,$evt);

    # change to appropriate dir
    # glob for matching file names
    @infile = glob("*evt2*");
    die "\n## $obsid: No evt file\n" unless (@infile);
    $evt   = shift @infile;

    # return the name
    return $evt;
  }

#######################
#######################

sub sub_expmap {
    
    my($evt) = @_;

    # get files
    my $asol = get_asolfile();
    print "## Using aspect solution: $asol\n";
    my $msk = get_mskfile();
    print "## Using mask file: $msk\n";
    my $pbk = get_pbkfile();
    print "## Using block file: $pbk\n";

    # construct the aspect histogram command
    print "## Making aspect histo\n";
    if ($instr eq "s") {
	$command = "punlearn asphist; asphist infile=$asol"
	    ." outfile=tempasp.fits evtfile=\"$evt\[ccd_id=$chip_id{$id}\]\" clob+ verbose=$verb";
	system($command);
    } else {
	foreach $d (@acisi) {
	    $outfile = "tempasp_${d}.fits";
	    $command = "punlearn asphist; asphist infile=$asol"
		." outfile=$outfile evtfile=\"$evt\[ccd_id=$chip_id{$d}\]\" clob+ verbose=$verb";
	    system($command);
	}
    }

    # construct the inst map
    print "## Making inst map\n";
    if ($instr eq "s") {
	$command = "punlearn mkinstmap; mkinstmap obsfile=\"tempasp.fits\[asphist\]\" outfile=\"tempinst.fits\""
	    ." detsubsys=\"$det_chip{$id}\" pixelgrid=\"1:1024:#1024,1:1024:\#1024\" spectrumfile=NONE"
	    ." dafile=CALDB grating=NONE maskfile=$msk pbkfile=$pbk monoenergy=1.5 clob+ verbose=$verb";
	system($command);
    } else {
	foreach $d (@acisi) {
	    $aspfile = "tempasp_${d}.fits";
	    $outfile = "tempinst_${d}.fits";
	    $command = "punlearn mkinstmap; mkinstmap obsfile=\"$aspfile\[asphist\]\" outfile=\"$outfile\""
		." detsubsys=\"$det_chip{$d}\" pixelgrid=\"1:1024:#1024,1:1024:\#1024\" spectrumfile=NONE grating=NONE"
		." dafile=CALDB maskfile=$msk pbkfile=$pbk monoenergy=1.5 clob+ verbose=$verb";
	    system($command);
	}
    }
    
    # make a region containing entire chip in sky coords
    if ($instr eq "s") {
	$regfile = make_skyreg();
	$command = "dmcopy \"$evt\[energy=$emin:$emax\]\[sky=region\($regfile\[ccd_id=$chip_id{$id}\]\)\]\[bin sky=$imbin\]\""
	    ." srcimg.fits clob+ verbose=$verb";
	system($command);
	unlink($regfile);
    } else {
	$command = "dmcopy \"$evt\[energy=$emin:$emax\]\[bin sky=$imbin]\" srcimg.fits clob+ verbose=$verb";
	system($command);
    }

    # find the chip limits
    $command = "punlearn get_sky_limits; get_sky_limits srcimg.fits verbose=1";
    system($command);

    # construct the exposure map command
    print "## Creating exposure map, this will take some time...\n";
    if ($instr eq "s") {
	$command = "punlearn mkexpmap; mkexpmap instmapfile=tempinst.fits outfile=tempexpmap.fits xygrid=\"\)get_sky_limits.xygrid\""
	    ." asphistfile=tempasp.fits useavgaspect=no normalize=no clob+ verbose=$verb";
	system($command);
    } else {
	@expmaps = ();
	foreach $d (@acisi) {
	    print "## Working on $d of ACIS-I array...\n";
	    $instfile = "tempinst_${d}.fits";
	    $aspfile = "tempasp_${d}.fits";
	    $out = "tempexpmap_${d}.fits";
	    $command = "punlearn mkexpmap; mkexpmap instmapfile=$instfile outfile=$out xygrid=\"\)get_sky_limits.xygrid\""
		." asphistfile=$aspfile useavgaspect=no normalize=no clob+ verbose=$verb";
	    push (@expmaps, "$out\n");
	    system($command);
	}
    }

    # make a file listing exp maps
    open(LISFILE,">list");
    print LISFILE @expmaps;
    close LISFILE;

    # handle the binning
    $blo = 1;
    $bhi = 8192/$imbin;

    # combine the expsoure maps for I array
    print "## Regridding...\n";
    if ($instr eq "i") {
	$command = "punlearn dmregrid; dmregrid infile=\@list outfile=tempexpmap.fits bin=\"${blo}:${bhi}:1,${blo}:${bhi}:1\""
	    ." rotangle=0 npts=1 xoffset=0 yoffset=0 rotxcenter=0 rotycenter=0 clob+ verbose=$verb";
	system($command);
    }
    unlink("list");

    # check that it worked or return an error
    if (-e "tempexpmap.fits") {
	print "## Done with expmap\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
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

    die "No asol files found.  Exiting.\n" unless (@infile);
    $asol = join(",",@infile);

    # return the name(s)
    chdir($curdir);
    return $asol;
}

#######################
#######################

sub get_mskfile {

    # get the msk file or files
    my($curdir,@infile,$msk,@dir,@globlist);
    $curdir = cwd();

    # change to appropriate dir (they sometimes change the locations)
    @dir = qw(primary secondary);
    @infile = ();
    foreach $dir (@dir) {
        chdir "../$dir";
        @globlist =  <*msk1*.fits*>;
        @globlist = map { "../$dir/" . $_} @globlist if (@globlist);
        push @infile, @globlist;
        chdir $curdir;
    }

    unless (@infile) {
      print "## No msk1 files found. Defaulting to \"NONE\". **WARNING** CCD edge effects now part of analysis!\n";
      $msk = "NONE";
    } else {
      $msk = join(",",@infile);
    }

    # return the name(s)
    chdir($curdir);
    return $msk;
}

#######################
#######################

sub get_pbkfile {

    # get the pbk file or files
    my($curdir,@infile,$pbk,@dir,@globlist);
    $curdir = cwd();

    # change to appropriate dir (they sometimes change the locations)
    @dir = qw(primary secondary);
    @infile = ();
    foreach $dir (@dir) {
        chdir "../$dir";
        @globlist =  <*pbk*.fits*>;
        @globlist = map { "../$dir/" . $_} @globlist if (@globlist);
        push @infile, @globlist;
        chdir $curdir;
    }

    die "No pbk files found.  Exiting.\n" unless (@infile);
    $pbk = join(",",@infile);

    # return the name(s)
    chdir($curdir);
    return $pbk;
}

#######################
#######################

sub make_skyreg {

    # input parameters
    my($evt2,$aspfile,$regfile);

    # define some names
    $evt2 = $evtfile;
    $aspfile = get_asolfile();
    $regfile = "chips_reg.fits";

    # construct the aspect histogram command
    $command = "punlearn skyfov; skyfov infile=$evt2 outfile=$regfile aspect=$aspfile clob+ verbose=$verb";
    system($command);

    # check that it worked
    if (-e $regfile) {
        print "## Region file creation complete\n";
    } else {
        die "No region file\n";
    }
    return $regfile;
}

#######################
#######################

sub sub_make_img {

    my($inimg) = @_;
    
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
    $command = "punlearn dmcopy; dmcopy \"${evtfile}[bin sky=$binning][opt type=$dtype]\" "
	."temp.fits verbose=$verb clob+";
    system($command);
    $command = "punlearn dmstat; dmstat temp.fits centroid=no";
    system($command);
    unlink("temp.fits");

    # get the phys location of the max
    my $max = `pget dmstat out_max_loc`;
    my @data = split(/\,/, $max);
    my @maxx = split(/\./, $data[0]);
    my @maxy = split(/\./, $data[1]);
    $maxx = $maxx[0];
    $maxy = $maxy[0];
    
    # trap any errors
    if ($maxx > 0 && $maxy > 0) {
	print "## Coarse center of ($maxx,$maxy) found\n";
    } else {
	$fail = "yes";
	return
    }

    # make a finer grid, recenter
    my $reg = "circle(${maxx},${maxy},100)";
    my $tbin = 4;
    $command = "punlearn dmcopy; dmcopy \"${evtfile}[sky=$reg][bin sky=$tbin][opt type=$dtype]\" "
	."temp.fits verbose=$verb clob+";
    system($command);
    $command = "punlearn dmstat; dmstat temp.fits centroid=no";
    system($command);
    unlink("temp.fits");

    # get the phys location of the max
    $max = `pget dmstat out_max_loc`;
    @data = split(/\,/, $max);
    @maxx = split(/\./, $data[0]);
    @maxy = split(/\./, $data[1]);
    $maxx = $maxx[0];
    $maxy = $maxy[0];

    # trap any errors
    if ($maxx > 0 && $maxy > 0) {
	print "## New coarse center of ($maxx,$maxy) found\n";
    } else {
	$fail = "yes";
	return
    }

    # construct a reasonably sized region around the coarse center
    if ($instr eq "i") {
	$maxr = 800;
    } else {
	$maxr = 500;
    }
    $reg = "circle(${maxx},${maxy},${maxr})";

    # create the images
    $command = "punlearn dmcopy; dmcopy \"${inimg}[sky=$reg]\" tempimg.fits verbose=$verb clob+";
    $command2 = "punlearn dmcopy; dmcopy \"tempexpmap.fits[sky=$reg]\" tempexpmapexcl.fits verbose=$verb clob+";
    print "## Creating image\n";
    system($command);
    system($command2);

    # construct the normalization command
    $command = "punlearn dmimgcalc; dmimgcalc tempimg.fits tempexpmapexcl.fits cent_norm.fits div"
	." clob+ verbose=$verb";
    system($command);
}

#######################
#######################

sub sub_rm_ptsrc {

    my $img = "srcimg.fits";
    my $outfile = "sources.fits";
    my $scell = "scell.fits";
    my $image = "image.fits";
    my $bkg = "bkg.fits";
    my $reg = "sources.reg";

    # create the image
    $command = "punlearn wavdetect; wavdetect infile=$img outfile=$outfile scellfile=$scell "
	."imagefile=$image defnbkgfile=$bkg regfile=$reg ellsigma=$sigma scales=$scales maxiter=$iter "
	."verbose=$verb clob+";
    print "## Detecting point sources\n";
    system($command);
    unlink "*_stk";
    
    # open the file
    my $temp = "temp.reg";
    open(TEMP,">$temp");
    open(REG,"$reg");
    while(<REG>){
	chomp;
	next if (/\,0\.00/ || /NAN/ || /nan/);
	print TEMP "$_\n";
    }
    close REG;
    close TEMP;
    system("mv -f $temp $reg");

    # check that it worked or return an error
    if (-e $reg) {
	print "## Point sources detected and stored in $reg\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_mkbgreg {

    my $regionFile = "sources.reg";
    my $radius = 1.5;
    my $outfile = "bkg.reg";

    # check for an empty file
    $wc = `wc $regionFile`;
    my @data = split(/\s+/, $wc);
    my $check = $data[1];
    if ($check == 0) {
	$skip = "yes";
    } else {
	$skip = "no";
    }

    # exit if there are no sources
    if ($skip eq "yes") {
	print "## No sources to exclude\n";
	open (SRC, ">$regionFile");
	print SRC "circle(0,0,0)\n";
	close SRC;
	open (RFILE, ">$outfile");
	print RFILE "circle(0,0,0)\n";
	close (RFILE);
	return;
    }

    @regionList = ();
    open (FILE, "<$regionFile") || die "## Can't open $regionFile";
    @regionList = <FILE>;
    close (FILE);
    @bkgList = ();
    # delete first line if it's a comment
    if ($regionList[0] =~ s/#//) {
	shift (@regionList);
    }
    
    foreach $line (@regionList){
	chomp $line;
	@radVals = split(/,/, $line);
	$shape = $radVals[0];
	# for circular regions
	if ( $shape =~ s/circle// ) {
	    ($radVal = $radVals[2]) =~ s/\)//;
	    $radNew = $radVal * $radius;
	    $newline = join ",", $radVals[0],$radVals[1],"$radNew)\n";
	    push @bkgList, $newline;
	    # assume it's ellipses otherwise
	} else {
	    $radVal1 = $radVals[2];
	    $radVal2 = $radVals[3];
	    $radNew1 = $radVal1 * $radius;
	    $radNew2 = $radVal2 * $radius;
	    $newline = join ",", $radVals[0],$radVals[1],$radNew1,$radNew2,"$radVals[4]\n";
	    push @bkgList, $newline;
	}
    }

    open (RFILE, ">$outfile");
    print RFILE (@bkgList);
    close (RFILE);

    # check that it worked or return an error
    if (-e $outfile) {
	print "## A region file for the point source backgrounds has been created\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_mksubbgreg {

    my $sourceFile = "sources.reg";
    my $bgFile = "bkg.reg";
    my $outfile = "bkg_sub.reg";

    # no need for this step if there are no sources from prev step
    if ($skip eq "yes") {
	open (OUTFILE, ">$outfile");
	print OUTFILE "circle(0,0,0)";
	close (OUTFILE);
	return;
    }

    @srcList = ();
    open (FILE, "<$sourceFile") || die "## Can't open source file\n";
    @srcList = <FILE>;
    close (FILE);

    @bgList = ();
    open (FILE, "<$bgFile") || die "## Can't open background file\n";
    @bgList = <FILE>;
    close (FILE);

    # delete first line if it's a comment
    if ($srcList[0] =~ s/#//) {
	shift (@srcList);
    }

    # delete first line if it's a comment
    if ($bgList[0] =~ s/#//) {
	shift (@bgList);
    }

    @new = ();
    $a = 0;

    foreach $line (@bgList) {
	chomp $line;
	$newline = "$line-$srcList[$a]";
	$a++;
	push @new, $newline;
    }

    open (OUTFILE, ">$outfile") || die "Can't write output file $outfile\n";
    print OUTFILE (@new);
    close (OUTFILE);

    # check that it worked or return an error
    if (-e $outfile) {
	print "## A region file for the subtracted regions has been created\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_fill_holes {
    my $img = "srcimg.fits";
    my $outfile = "img_filled.fits";
    my $src = "sources.reg";
    my $bkg = "bkg_sub.reg";

    # exit if there are no sources
    if ($skip eq "yes") {
	print "## No holes to fill\n";
	system("cp -f $img $outfile");
	return;
    }

    # create the image
    $command = "punlearn dmfilth; dmfilth infile=$img outfile=$outfile method=POISSON "
	."srclist=\@$src bkglist=\@$bkg randseed=123 clob+ verbose=$verb";
    print "## Filling holes\n";
    system($command);
    
    # check that it worked or return an error
    if (-e $outfile) {
	print "## Holes left by pt srcs have been filled\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_centroid {
    my($img,$centroid);
    if ($rm_ptsrc eq "yes") {
	$img = "img_filled.fits";
    } else {
	$img = $evtfile;
    }

    # create the image
    &sub_make_img($img);
    $img = "cent_norm.fits";
    $command = "punlearn dmstat; dmstat $img centroid=yes";
    print "## Centroiding\n";
    system($command);

    # get the value for the centroid and parse
    if ($diffuse =~ /^y/) {
	$centroid = `pget dmstat out_cntrd_phys`;
    } else {
	$centroid = `pget dmstat out_max_loc`;
    }
    my @data = split(/,/, $centroid);
    @x = split(/\./, $data[0]);
    @y = split(/\./, $data[1]);
    chomp($x = $x[0]);
    chomp($y = $y[0]);

    # find distance between max and cent
    my $d = sqrt((($x-$maxx)**2.0)+(($y-$maxy)**2));

    # at a z of 0.7, 7 kpc/", this is 3.4 kpc/pix
    # or ~20 pix for 70 kpc
    if ($d <= 50) {
	$x = $maxx;
	$y = $maxy;
    }

    # check that it worked or return an error
    if ($x > 0 && $y > 0) {
	print "## Centroid of ($x,$y) found\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_write_ref {
    my(@oldref) = @_;
    my @newref = @oldref;
    $newref[2] = $x unless ($oldref[0] =~ /^\#/);
    $newref[3] = $y unless ($oldref[0] =~ /^\#/);
    printf NEWREF "%-25s %6s %8.0f %8.0f %6.0f %7.0f %8.4f %6.2f %6.2f %6.2f %6.2f %5s %8.4f %5s %6.0f %20s\n",
    $newref[0],$newref[1],$newref[2],$newref[3],$newref[4],$newref[5],$newref[6],$newref[7],
    $newref[8],$newref[9],$newref[10],$newref[11],$newref[12],$newref[13],$newref[14],$newref[15];
}

#######################
#######################

sub logerror {
    my($offender) = @_;
    chdir("$Bin");
    open  ERRFILE,">>cent_errors.log";
    print "## ERROR: ${obsid} failure in cent_emi.pl, $offender ",scalar(localtime),"\n";
    print ERRFILE "${obsid} # failure in cent_emi.pl, $offender ",scalar(localtime),"\n";
    close ERRFILE;
}

#######################
#######################

sub sub_print_info {
    printf NEWREF "%-25s %6s %8s %8s %6s %7s %8s %6s %6s %6s %6s %5s %8s %5s %6s %20s\n",
    "#Name","ObsID","X","Y","Rmax","MinCts","z","Nh20","Tx","Fe","Lbol","Chip","E_obs","Diff","Robs","Location";
}

#######################
#######################
