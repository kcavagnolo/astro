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

$outdir    = "/mnt/GIDEON/merged";
$evtext    = "exclude";
$rootdir   = "reprocessed/";
$pixelsize = '0.492"';
$binning   = "1";
$emin      = "700";
$emax      = "2000";
$cut       = '1.5%';
$cval      = 0.0;
$kernel    = '"lib:gaus(2,1,1,2,2)"';
$smethod   = "fft";
$verb      = 0;

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
use Cwd;
use FindBin qw($Bin);
die "## ERROR: CIAO is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "## ERROR: Incorrect number of input arguments\n" if (@ARGV != 1);

# read in the reference file and store fiducial info
%refdata = &sub_get_data($ARGV[0]);

# loop through each cluster
$prevname = 'dsfsfsd';
$num = 0;
open(IN,$ARGV[0]);
while (<IN>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;
    s/\s+$//;
    @data = split;
    $fail = "no";

    # get all obsids associated with name
    $name = $data[0];
    if (($name eq $prevname) || ($num == 0)) {
	push @obsids, $data[1];
	$prevname = $name;
	$num++;
    }
    if (($name ne $prevname) || (eof(IN))) {
	$name = $prevname;
	print "## STATUS: Working on $name\n";
	@info = split(/\s+/,$refdata{$name});
	$fobsid = $info[1];
	$x = $info[2];
	$y = $info[3];
	$xsize = $ysize = $info[4];
	$datadir = $info[15];

	# get the evt and exp files for each obsid
	&sub_getevts($name,@obsids);

	# convert x and y to ra and dec, also
	$asol = &sub_get_asol();
	if ($fail eq "yes") {
	    $offender = "get_asol";
	    logerror($offender);
	    next;
	}
	($xcenter,$ycenter) = &sub_get_radec($evts[0],$asol);
	if ($fail eq "yes") {
	    $offender = "get_radec";
	    logerror($offender);
	    next;
	}

	# create images for each obsid
	chdir("/tmp");
	system('rm -f *fits* *img');
	&sub_mkimgs();
	if ($fail eq "yes") {
	    $offender = "mkimgs";
	    logerror($offender);
	    next;
	}

	# regrid all images to common coord tangent point
 	$outfile = "${name}_mosaic.fits";
	&sub_regrid($outfile,$xsize,$ysize,$xcenter,$ycenter,$pixelsize);
	if ($fail eq "yes") {
	    $offender = "img_regrid";
	    logerror($offender);
	    next;
	}
	push @allout, $outfile;

	# regrid exposure maps to common coord tangent point
 	$eoutfile = "${name}_expmap.fits";
	$match = $outfile;
	&sub_regrid_exp($eoutfile,$match);
	if ($fail eq "yes") {
	    $offender = "exp_regrid";
	    logerror($offender);
	    next;
	}
	push @allout, $eoutfile;

	# exposure correct and normalize
	$in = $outfile;
	$exp = $eoutfile;
	$flux = "${name}_norm.fits";
	&sub_normalize($in,$exp,$flux);
	if ($fail eq "yes") {
	    $offender = "normalize";
	    logerror($offender);
	    next;
	}
	push @allout, $flux;

	# create a smoothed version
	$in = $flux;
	$smooth = "${name}_smooth.fits";
	&sub_smooth($in,$smooth);
	if ($fail eq "yes") {
	    $offender = "smooth";
	    logerror($offender);
	    next;
	}
	push @allout, $smooth;

	# copy all files somewhere
	foreach $file (@allout) {
	    mkdir("$outdir/$name",0777) unless (-d "$outdir/$name");
	    system("mv -f $file $outdir/$name/");
	}

	# clear the obsid array and start a new one
	@allout = @obsids = @evts = @exps = undef;
	push @obsids, $data[1];
	$prevname = $data[0];
    }

    # return home
    chdir("$Bin");
}
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_get_data {

    my($infile) = @_;
    my(@data, $name, %info, $prevname);
    $prevname = 'dasdas';
    open(INFILE,$infile) || die "## ERROR: Cannot open $infile\n";
    while (<INFILE>) {
	chomp;
	next if (/^\#/);
	next if (/^$/);
	s/^\s+//;
	s/\s+$//;
	@data = split;
	$name = $data[0];
	next if ($name eq $prevname);
	$info{$name} = $_;
	$prevname = $name;
    }
    close INFILE;
    return %info;
}

#######################
#######################

sub sub_getevts {

    my($name,@obsids) = @_;
    my($obs,@glob,@eglob);
    foreach $obs (@obsids) {
	if (-d "$datadir/$obs/$rootdir/") {
	    chdir("$datadir/$obs/$rootdir/");
	} else {
	    die "## ERROR: No such directory $datadir/$obs/$rootdir/\n";
	    next;
	}
	my $curdir = cwd();
	@glob = glob("${obs}_${evtext}.fits*");
	@eglob = glob("${obs}_expmap.fits*");
	if (@glob && @eglob) {
	    @glob = map { "$curdir/" . $_} @glob;
	    @eglob = map { "$curdir/" . $_} @eglob;
	    push @evts, $glob[0];
	    push @exps, $eglob[0];
	    print "## STATUS: Found $glob[0], $eglob[0]\n";
	} else {
	    die "## ERROR: No evt for $obs\n" unless (@glob);
	    die "## ERROR: No exp for $obs\n" unless (@eglob);
	}
    }
}

#######################
#######################

sub sub_mkimgs {

    my($evt,$exp);
    open(A,">images.lis");
    foreach $evt (@evts) {
	print "## STATUS: generating image for $evt\n";

	# get the active ccds for each obs
	my $detname  = get_info($evt,"DETNAM");
	$detname =~ s/ACIS-//;
	my @ccds = split(//,$detname);
	my $ccds = join(",",@ccds);
	print "## STATUS: Active CCDs are $ccds\n";

	# make image
	system(`cp $evt .`);
	my @junk = split(/\//,$evt);
	my $imgfile = pop(@junk);
	$imgfile =~ s/\.fits//;
	$imgfile .= '.img';
	my $command = "punlearn dmcopy; dmcopy \"$evt\[energy=${emin}:${emax}][ccd_id=${ccds}]"
	    ."[bin sky=$binning][opt mem=135]\" $imgfile clobber=yes verbose=$verb";
	system $command;
	unless (-e $imgfile) {
	    $fail = "yes";
	    close A;
	    return;
	}
	print A "$imgfile\n";
    }
    close A;
    open(B,">expmaps.lis");
    foreach $exp (@exps) {
	system(`cp $exp .`);
	@junk = split(/\//,$exp);
	my $expfile = pop(@junk);
	unless (-e $expfile) {
	    $fail = "yes";
	    close B;
	    return;
	}
	print B "$expfile\n";
    }
    close B;
}

#######################
#######################

sub sub_regrid {

    my($outfile,$xsize,$ysize,$xcent,$ycent,$pixelsize) = @_;
    print "## STATUS: Ignore the following warnings...\n";
    my $command = "punlearn reproject_image_grid; reproject_image_grid infile=\@images.lis"
	." outfile=$outfile xsize=$xsize ysize=$ysize xcenter=\"$xcent\" ycenter=\"$ycent\""
	." theta=\"0\" method=sum pixelsize=\'$pixelsize\' clob\+ verbose=$verb";
    system($command);
    print "\n";
    unless (-e $outfile) {
	$fail = "yes";
	return;
    }
}

#######################
#######################

sub sub_regrid_exp {

    my($outfile,$match) = @_;
    print "## STATUS: Ignore the following warnings...\n";
    $command = "punlearn reproject_image; reproject_image infile=\@expmaps.lis matchfile=$match"
	." outfile=$outfile method=average";
    system($command);
    print "\n";
    unless (-e $outfile) {
	$fail = "yes";
	return;
    }
}

#######################
#######################

sub get_info {

    # get and format keyword value from file
    my($file,$key) = @_;
    $value = `punlearn dmkeypar; dmkeypar ${file} $key; pget dmkeypar value`;
    chomp($value);
    $value =~ s/\s+//g;
    $value =~ s/\'//g;
    return $value;
}

#######################
#######################

sub sub_get_asol {

    # get the asol file for files
    my($curdir,@infile,$asol,@dir,@globlist);
    $curdir = cwd();
    
    # change to appropriate dir (they sometimes change the locations)
    chdir("$datadir/$fobsid/$rootdir/");
    @dir = qw(primary secondary);
    @infile = ();
    foreach $dir (@dir) {
	chdir "../$dir";
	my $adir = cwd();
	@globlist =  <pcad*asol*fits*>;
	@globlist = map { "$adir/" . $_} @globlist if (@globlist);
	push @infile, @globlist;
	chdir $curdir;
    }
    unless (@infile) {
	$fail = "yes";
	return;
    }
    $asol = join(",",@infile);
    chdir($curdir);
    return $asol;
}

#######################
#######################

sub sub_get_radec {

    my($evt,$asol) = @_;

    # run dmcoords
    $command = "punlearn dmcoords; dmcoords infile=$evt asolfile=\"$asol\" x=$x y=$y opt=sky celfmt=deg";
    system($command);
    
    # get output ra and dec
    $ra = `pget dmcoords ra`;
    $dec = `pget dmcoords dec`;
    $ra =~ s/^\s+//;
    $ra =~ s/\s+$//;
    $dec =~ s/^\s+//;
    $dec =~ s/\s+$//;
    if ($ra ne "" && $dec ne "") {
	return($ra,$dec);
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_normalize {

    my($in,$exp,$flux) = @_;
    $command = "punlearn dmimgthresh; dmimgthresh infile=$in outfile=temp.fits expfile=$exp cut=$cut value=$cval clob\+ verbose=$verb";
    system($command);
    $command = "punlearn dmimgcalc; dmimgcalc infile=temp.fits infile2=$exp outfile=$flux operation=div clob\+ verbose=$verb";
    system($command);
    unlink("temp.fits");
    unless (-e $flux) {
	$fail = "yes";
	return;
    }
}

#######################
#######################

sub sub_smooth {

    my($in,$out) = @_;
    $command = "punlearn aconvolve; aconvolve $in $out $kernel method=$smethod";
    system($command);
    unless (-e $smooth) {
	$fail = "yes";
	return;
    }
}

#######################
#######################

sub logerror {
    my($offender) = @_;
    open  ERRFILE,">>${Bin}/err_mosaic.log";
    print "${name} # failure in mosaic.pl, $offender ",scalar(localtime),"\n";
    print ERRFILE "${name} # failure in mosaic.pl, $offender ",scalar(localtime),"\n";
    close ERRFILE;
}

#######################
#######################
