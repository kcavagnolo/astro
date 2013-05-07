#! /usr/bin/perl -w
#
# NAME:
#     find_pt_src.pl
#
# PURPOSE:
#     Create an image of and observation and locate
#     point sources within that image
#
# EXPLANATION:
#     This script utilizes the wavdetect tool in CIAO to find
#     point source. More info on wavdetect can be found here:
#     http://cxc.harvard.edu/ciao/ahelp/wavdetect.html
#
#     This script assumes the following directory structure:
#     all pertinent Chandra data files are in a dir labeled with
#     the obsid, which is then in a dir labeled acis/. The location
#     of acis/ relative to the dir from which this script is run is
#     set with the variable $datadir.
#
#     e.g.: for Abell 644 obsid 2211, this script will look to
#     $datadir/acis/2211/$rootdir for all the files needed to complete
#     the data reduction
#
# CALLING SEQUENCE:
#     find_pt_src.pl <reference list>
#
# INPUTS:
#     the assumed format for the list is as follows:
#     in the case of X and Y being the centroid position in pixels and Rmax in pixels
#     Name              ObsID        X        Y   Rmax     MinCts         z  Nh20     Tx     Fe  Lbol
#     ABELL_0644         2211   3908.5   4332.5  243.9       5000    0.0704  6.41   8.64   0.35 45.00
#     ABELL_1651         4185   4222.5   4034.5  132.3       5000    0.0844  1.88   5.97   0.30 45.00
#
# OUTPUTS:
#     Output source list:            <name>_<obsid>_scell.fits
#     Source cells:                  <name>_<obsid>_scell.fits
#     Reconstructed source image:    <name>_<obsid>_imgfile.fits
#     Default normalized background: <name>_<obsid>_nbgd.fits
#     ASCII region output:           <obsid>_exclude.reg
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$ellsigma = 2.0;
$scales   = "\"1.0 2.0 4.0 8.0 12.0\"";
$dump_reg = "yes";
$use_exp  = "no";
$onlycore = "no";
$core     = 20;
$binning  = 4;
$thresh   = 1e-07;
$emin     = 300;
$emax     = 10000;
$rootdir  = "reprocessed";
$verb     = 0;

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
use Cwd;
use FindBin qw($Bin);
die "## ERROR: ciao is not loaded.\n" unless ($ENV{'ASCDS_BIN'});
die "## ERROR: Wrong number of command line arguments.\n" if (@ARGV != 1);
open(LOGFILE,">ptsrc.log") || die "## ERROR: Cannot open log file.\n";

# read in the reference file
%refdata  = &sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get obsid
    $fail    = "no";
    $name    = $data[0];
    $obsid   = $data[1];
    $x       = $data[2];
    $y       = $data[3];
    $datadir = $data[15];

    # write to log file
    print "## STATUS: Started $name (ObsId $obsid) ",scalar(localtime),"\n";

    # make directory to store reprocessed and new files
    chdir("$datadir/$obsid/$rootdir");

    # set badpix file
    &sub_set_ardlib();

    # get evt2 file
    $evtfile = "${obsid}_evt2.fits";
    print "## STATUS: Using $evtfile\n";

    # get exposure map and time
    if ($use_exp eq "yes") {
	$expfile = &sub_get_exp();
	if ($fail eq "yes") {
	    chdir("$Bin");
	    open ERRFILE,">>errors_ptsrc.log";
	    print "## ERROR: ${obsid} # failure in get_exp\n";
	    print ERRFILE "${obsid} # failure in get_exp \n";
	    close ERRFILE;
	    next;
	}
    }
    $expt = &sub_get_info($evtfile,"EXPOSURE");

    # define file names
    $imgroot = "${name}_${obsid}";
    if ($onlycore eq "yes") {
	$regfile="${obsid}_exclcore.reg";
    } else {
	$regfile="${obsid}_exclude.reg";
    }

    # run wavdetect to get point sources
    print "## STATUS: detecting sources for:\n"
	."Binning: $binning\n"
	."Scales: $scales\n"
	."Dump reg?  $dump_reg\n"
	."Exp corr?  $use_exp\n"
	."Core only? $onlycore\n"
	."Threshold: $thresh\n"
	."Energy: $emin eV --> $emax eV\n\n\n";
    &sub_run_wavdetect($evtfile,$regfile,$imgroot);

    # check for radius=0 and NAN values
    unless ($dump_reg eq "no") {
	&sub_check_reg($regfile);

	# get number of sources detected
	$wc = `wc $regfile`;
	@wc = split /\s+/, $wc;
	$num = $wc[1];
	print LOGFILE "${name} $num point sources found\n";
      
	# write to log file
	print "## STATUS: Finished $name (ObsId $obsid) ",scalar(localtime),"\n\n";
    }

    # clean-up temp files
    unlink <*_stk>;

    # change back to original directory
    chdir($Bin);
}
close LOGFILE;
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

sub sub_set_ardlib {

    my($chips,@chips,$evtfile,$d,$curdir,$bpix);
    $curdir = cwd();

    # reset the ardlib parameter file
    system("punlearn ardlib.par");

    # glob for matching file names
    @dir = qw(reprocessed primary secondary);
    foreach $dir (@dir) {
        chdir("../$dir");
        @globlist = <*bpix*.fits*>;
        @globlist = map { "../$dir/" . $_} @globlist if (@globlist);
        last if (@globlist);
        chdir $curdir;
    }
    die "## ERROR: No bpix file for $obsid\n" unless (@globlist);
    $bpix = $globlist[0];

    # get the chips to use
    $chips = `dmkeypar $bpix DETNAM ; pget dmkeypar value`;
    chomp($chips);
    $chips =~ s/ACIS\-//;
    @chips = split('', $chips);
    foreach $d (@chips) {
        $command = "pset ardlib AXAF_ACIS${d}_BADPIX_FILE=${curdir}/$bpix\[BADPIX${d}]";
        system($command);
    }
    chdir($curdir);
}

#######################
#######################

sub sub_run_wavdetect {

    my($evtfile,$regfile,$imgroot) = @_;
    my($imgfile,$outfile,$scellfile,$imagefile,$nbdgfile);

    # define local file names
    $imgfile   = "temp.fits";
    $scellfile = "${imgroot}_scell.fits";
    $imagefile = "${imgroot}_imgfile.fits";
    $nbdgfile  = "${imgroot}_nbgd.fits";

    # make smaller file for wavdetect to handle
    print "## STATUS: Creating image.\n";
    if ($onlycore eq "yes") {
	my $temp = "circle($x,$y,$core)";
	$command = "punlearn dmcopy; dmcopy \"$evtfile\[energy=${emin}:${emax}][sky=$temp][opt mem=135]"
	    ."[bin sky=$binning]\" $imgfile clobber=yes verbose=$verb";
	system $command;
	$inexp = $expfile;
	$outfile = "${imgroot}_src_core.fits";

	# handle exp map
	if ($use_exp eq "yes") {
	    $command = "punlearn dmcopy; dmcopy \"$expfile\[sky=$temp][opt mem=135]\" tempexp.fits clobber=yes verbose=$verb";
	    print "$command\n";
	    system $command;
	    $inexp = "tempexp.fits";
	}
    } else {
	$command = "punlearn dmcopy; dmcopy \"$evtfile\[energy=${emin}:${emax}][bin sky=$binning][opt mem=135]\" "
	    ."$imgfile clobber=yes verbose=$verb";
	system $command;
	$inexp = $expfile;
	$outfile = "${imgroot}_src.fits";
    }

    # run wavdetect
    if ($dump_reg eq "yes") {
	$command = "punlearn wavdetect; wavdetect infile=$imgfile outfile=$outfile scellfile=$scellfile "
	    ."imagefile=$imagefile defnbkgfile=$nbdgfile regfile=$regfile ellsigma=${ellsigma} scales=$scales "
	    ."sigthresh=$thresh exptime=$expt clobber=yes verbose=$verb";
    } else {
	$command = "punlearn wavdetect; wavdetect infile=$imgfile outfile=$outfile scellfile=$scellfile "
	    ."imagefile=$imagefile defnbkgfile=$nbdgfile regfile=junk.reg ellsigma=${ellsigma} scales=$scales "
	    ."sigthresh=$thresh exptime=$expt clobber=yes verbose=$verb";
    }
    $command .= " expfile=$inexp" if ($use_exp eq "yes");
    print "## STATUS: Running wavdetect on $imgfile\n";
    system $command;
    unlink("junk.reg");
    unlink("$imgfile");
    unlink("$scellfile");
    unlink("$nbdgfile");
    unlink("$imagefile");
}

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
    print "## STATUS: Found $exp for expsoure map.\n";
    if ($exp =~ /gz$/) {
	print "## STATUS: Unzipping $exp\n";
	system("gunzip -f $exp");
	$exp =~ s/\.gz$//;
    }
    return $exp;
}

#######################
#######################

