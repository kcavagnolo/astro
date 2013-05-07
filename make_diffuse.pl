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

$evtext         = "clean";
#$make_exposure  = "no";
#$make_smoothed  = "no";
$rootdir        = "reprocessed";
$imagedir       = "images";
@sbands         = ("300:8000");
@ibands         = ("300:8000");
$verb           = 2;

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});

# check the number of arguments given
die "Wrong number of command line arguments\n" if (@ARGV != 1);

# set some parameters
#%chip_id = ("i0" =>"0", "i1" =>"1", "i2" =>"2", "i3" =>"3", "s0"
#	    =>"4", "s1" =>"5", "s2" =>"6", "s3" =>"7", "s4" =>"8",
#	    "s5" =>"9");

# load useful libraries; store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# read in the reference file
%refdata  = read_file($ARGV[0],0,1);

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});
    
    # get obsid
#    $name    = $data[0];
    $obsid   = $data[1];
#    $z       = $data[6];
#    $nh      = $data[7]*1e-2;
#    $tx      = $data[8];
#    $fe      = $data[9];
    $chip    = $data[11];
    $datadir = $data[15];

    # change directory 
    chdir("$datadir/$obsid/");

    # change to image directory
    mkdir($imagedir,0777) unless (-d $imagedir);
    chdir($imagedir) || die "## ERROR: $imagedir directory not created\n";
    chdir("$datadir/$obsid/$rootdir");

    # set badpix file
    set_ardlib();

    # figure out which detector to use
    if ($chip =~ /^s/) {
	$ids = "7";
	@bands = @sbands
    } elsif ($chip =~ /^i/) {
	$ids = "0,1,2,3";
	@bands = @ibands
    } else {
	die "## ERROR: Bad ccd_id --> $chip for $obsid.\n";
    }

    # get file names
    $evtfile = "${obsid}_${evtext}.fits";
    $regfile = "${obsid}_chipregs.fits";
    $expfile = "${obsid}_expmap.fits"; 
    die "## ERROR: Cannot locate $evtfile for $obsid\n" unless (-e $evtfile);
    die "## ERROR: Cannot locate $regfile for $obsid\n" unless (-e $regfile);
    die "## ERROR: Cannot locate $expfile for $obsid\n" unless (-e $expfile);

    # make an image
    make_image($evtfile,$regfile);

    # make an image
    make_normal($expfile);

#    # make exposure map
#    make_expomap($evtfile) if ($make_exposure eq "yes");
    
#    # smooth image with exposure map
#    make_smoothed($imgroot) if ($make_smoothed eq "yes");

    # change back to original directory
    chdir("$Bin");
}

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

sub make_image  {
    
    # set parameters
    my($evtfile,$regs) = @_;

    # make image for each band
    foreach $band (@bands) {
	$command = "dmcopy \"${evtfile}\[energy=$band\]\" temp.fits clob+ verbose=$verb";
	system($command);
	$command = "dmcopy \"temp.fits\[sky=region($regs\[ccd_id=$ids\])\]\[bin sky\]\" ${obsid}_${band}_img.fits clob+ verbose=$verb";
	system($command);
	system("rm -f temp.fits");
    }
}

#######################
#######################

sub make_normal {
    
    # set parameters
    my($exp) = @_;

    # make image for each band
    foreach $band (@bands) {
	$command = "punlearn dmimgcalc ; dmimgcalc ${obsid}_${band}_img.fits $exp ${obsid}_${band}_norm.fits div clob+ verbose=$verb";
	system($command);
    }
}

#######################
#######################

#
# sub make_expomap {
#
#     my($evtfile) = @_;
#
#     # make exposuremap for each band
#     foreach $band (@bands) {
#
# 	# check that necessary files exist
# 	die "No $evtfile\n" unless (-e $evtfile);
# 	die "No image file\n" unless (-e "${obsid}_${band}_img.fits");
#
# 	# get the asol file or files
# 	$asol = get_asolfile();
# 	print "Using $asol\n";
#
# 	# use a spectrum to create a weights file for exposure map create
# 	# make weights file
# 	# make ascii spectrum file using SHERPA; See http://cxc.harvard.edu/ciao/threads/spectral_weights/
# 	@energy = split(/\:/,$band);
# 	$e1 = $energy[0]/1000;
# 	$e2 = $energy[1]/1000;
# 	unlink "weights.model";
# 	open(XCMFILE,">weights.shp") || die "## ERROR: Cannott open weights.shp.\n";
# 	print XCMFILE "dataspace ($e1:$e2:0.01) histogram\n"
# 	    ."paramprompt off\n"
# 	    ."source = xswabs[abs]*xsmekal[p1]\n"
# 	    ."abs.nH = $nh\n"
# 	    ."p1.kT = $tx\n"
# 	    ."p1.nH = 1\n"
# 	    ."p1.Abund = $fe\n"
# 	    ."p1.Redshift = $z\n"
# 	    ."p1.Switch = 0\n"
# 	    ."p1.norm = $norm\n"
# 	    ."write model weights.model\n"
# 	    ."exit\n";
# 	close XCMFILE;
# 	system("sherpa weights.shp");
# 	open(XCMFILE,">sherpa.shp") || die "Can't open weights.shp\n";
# 	print XCMFILE 
# 	    "()=evalfile(\"$Bin/spectrum.sl\")","\n",
# 	    "runtest(\"weights.model\")","\n",
# 	    "exit\n";
# 	close XCMFILE;
# 	system("sherpa sherpa.shp");
#
# 	# energy for exposure map
# 	@energy = split(/\:/,$band);
# 	$energy = sprintf("%.2f",($energy[1]+$energy[0])/2/1000);
#
# 	# get xygrid for image
# 	system("get_sky_limits ${obsid}_${band}_img.fits");
# 	$xygrid = `pget get_sky_limits xygrid`;
# 	chomp $xygrid;
#
# 	# use merge_all script to creat exposure map
# 	$command = "merge_all evtfile\"=$evtfile\" asol=\"$asol\" chip=$chip_id{$chip} xygrid=\"$xygrid\" energy=$energy expmap=\"${obsid}_${band}_exp.fits\" expcorr=\"${obsid}_${band}_expcorr.fits\" mode=h clobber=yes";
# 	$command = "merge_all evtfile\"=$evtfile\" asol=\"$asol\" chip=$chip_id{$chip} xygrid=\"$xygrid\" energy=\"weights.txt\" expmap=\"${obsid}_${band}_exp.fits\" expcorr=\"${obsid}_${band}_expcorr.fits\" mode=h clobber=yes";
# 	system($command);
#     }
#    
# }
#
#######################
#######################

# sub make_smoothed {


#     # set parameters
#     my($imgroot) = @_;

#     # smooth each image
#     foreach $band (@bands) {
# 	$command = "punlearn csmooth; csmooth
# 	infile=${obsid}_${band}_img.fits
# 	outfile=${obsid}_${band}_img_smoothed.fits
# 	outsigfile=${obsid}_${band}_sig.fits
# 	outsclfile=${obsid}_${band}_scl.fits sigmin=3 verbose=1
# 	clobber=yes conmeth=fft mode=h";
# 	system $command;

# 	# smooth exposure map
# 	if (-e "${obsid}_${band}_exp.fits") {
# 	    $command = "punlearn csmooth; csmooth
# 	    infile=${obsid}_${band}_exp.fits
# 	    outfile=${obsid}_${band}_exp_smoothed.fits
# 	    sclmap=${obsid}_${band}_scl.fits
# 	    outsigfile=${obsid}_${band}_exp_sig.fits
# 	    outsclfile=${obsid}_${band}_exp_scl.fits sigmin=3
# 	    verbose=1 clobber=yes sclmode=user conmeth=fft mode=h";
# 	    system $command;
	    
# 	    # create final image
# 	    $command = "punlearn dmimgthresh; dmimgthresh
# 	    infile=${obsid}_${band}_img_smoothed.fits
# 	    outfile=${obsid}_${band}_final.fits
# 	    expfile=${obsid}_${band}_exp_smoothed.fits cut=\"1.5%\"
# 	    value=\"0.0\"";
# 	    system $command;
# 	}
#     }
# }

#######################
#######################

# sub get_asolfile {

#     # get the asol file for files
#     my($curdir,@infile,$asol,@dir,@globlist);
#     $curdir = cwd();

#     # change to appropriate dir (they sometimes change the locations)
#     @dir = qw(primary secondary);
#     @infile = ();
#     foreach $dir (@dir) {
# 	chdir "../$dir";
# 	@globlist =  <pcad*asol*.fits*>;
# 	@globlist = map { "../$dir/" . $_} @globlist if (@globlist);
# 	push @infile, @globlist;
# 	chdir $curdir;	
#     }

#     die "No asol files found.  Exiting.\n" unless (@infile);
#     $asol = join(",",@infile);

#     # return the name(s)
#     chdir($curdir);
#     return $asol;

# }

#######################
#######################

sub set_ardlib {

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
        last if (@globlist);;
        chdir $curdir;  
    }

    die "$obsid: No bpix file\n" unless (@globlist);
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
