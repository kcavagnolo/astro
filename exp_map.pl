#! /usr/bin/perl -w
#
# NAME:
#     exp_map.pl
#
# PURPOSE:
#     Create an exposure map from evt2 file using asphist, mkinstmap,
#     and mkexpmap.
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
#     exp_map.pl <reference list>
#
# FILES ASSUMED TO EXIST:
#     Flare clean, pt src free evt file:     <obsid>_exclude.fits
#     This file is generated from running:
#     reprocess.pl --> find_pt_src.pl --> reprocess.pl (w/ exclude src opt on)
#
# INPUTS:
#     <reference list> -- File containing information about each cluster
#     Example:
#     #Name                      ObsID      X      Y   Rmax  MinCts        z   Nh20     Tx     Fe   Lbol  Chip    E_obs  Diff   Robs   Location
#     1E0657_56                   3184   3776   4026    590    5000   0.2960   6.53  11.64   0.23  46.20    i3   1.5432     y    200   /mnt/DROBO
#
# OUTPUTS:
#     aspect histogram file: <obsid>_asphist.fits
#     instrument map file:   <obsid>_instmap.fits
#     exposure map file:     <obsid>_expmap.fits
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$evtext       = "exclude"; # extension of evt file to use
$onlynew      = "yes";    # if an exp map exists, then don't make a new one
$e_peak       = "yes";    # find the peak monoenergy of the spectrum "yes", or "no" calc spec weights
$avgasp       = "no";     # "yes" -> use avg. aspect soln, much faster; "no" -> full asp soln used, more precise
$normal       = "no";     # "no" -> units of [cm2*s*counts/photon]; "yes" -> units of [cm2*counts/photon]
$make_asphist = "yes";    # does the script need to make an aspect histogram?
$make_instmap = "yes";    # does the script need to make an instrument map?
$make_img     = "yes";    # should an image of the cluster be created !!**needed for exp map**!!
$make_expmap  = "yes";    # does the script need to make an exposure map?
$make_normal  = "yes";    # does the script need to make a normalized image?
$threshcut    = "yes";    # make a threshold cut before normalizing?
$cut          = 1.5;      # percent of cut
$binning      = 1;        # binning specification for final exp map
$addbinname   = "no";     # should the bin size be added to the name?
$emin         = 300;      # minimum of the energy filter in eV
$emax         = 10000;    # maximum of the energy filter in eV
$verb         = 0;        # how much verbosity should CIAO use?
$rootdir      = "reprocessed/"; # where to find and make files
$datfile      = "$ENV{'HOME'}/research/me_temp_proj/me_fits/dat/c2fits_final_r2500_fefree_7-7.dat"; # dat file used for cal spec weights
$altdat       = "$ENV{'HOME'}/research/me_temp_proj/me_fits/dat/c2fits_final_r5000_fefree_7-7.dat"; # dat file used for cal spec weights

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
use Cwd;
use FindBin qw($Bin);
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "Wrong number of command line arguments\n" if (@ARGV != 1);

# Define the chip number based on chip id
%chip_id = ("" =>"0", "i0" =>"0", "i1" =>"1", "i2" =>"2", "i3" =>"3", "s0"
	    =>"4", "s1" =>"5", "s2" =>"6", "s3" =>"7", "s4" =>"8",
	    "s5" =>"9");

%det_chip = ("i0" =>"ACIS-I0", "i1" =>"ACIS-I1", "i2" =>"ACIS-I2", "i3" =>"ACIS-I3", "s0"
	     =>"ACIS-S0", "s1" =>"ACIS-S1", "s2" =>"ACIS-S2", "s3" =>"ACIS-S3", "s4" =>"ACIS-S4",
	     "s5" =>"ACIS-S5");

# open a a log file
open(LOGFILE,">>exp_map.log") || die "Can't open exp_map.log\n";
print LOGFILE "###### Starting run at ",scalar(localtime)," ######\n";

# read in the reference file
%refdata = read_file($ARGV[0]);
%fitdata = read_file(${datfile}) if $e_peak eq "no";
%altfit  = read_file(${altdat}) if $e_peak eq "no";

# go through each cluster and extract events, images
{
  foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get values specific to each cluster
    $name    = $data[0];
    $obsid   = $data[1];
    $id      = $data[11];
    $datadir = $data[15];

    # write to log file
    print "## STATUS: Starting $name (ObsId $obsid) ",scalar(localtime),"\n";
    print LOGFILE "## Starting $name (ObsId $obsid) ",scalar(localtime),"\n";

    # change directory
    chdir("$datadir/$obsid/$rootdir");

    # make only new files                                                     
    if ($onlynew eq "yes") {
        $fizzile = "${obsid}_expmap.fits";
        if (-e $fizzile) {
	    print "## STATUS: Already have $obsid exp map\n";
	    next;
        }
    }

    # get the asol file or files
    ($aspfile,$pbk) = get_asolfile();
    print "## STATUS: Using aspect solution: $aspfile\n";
    print "## STATUS: Using parameter block file: $pbk\n";

    # figure out which detector to use
    $instr = "s" if ($id =~ /^s/);
    $instr = "i" if ($id =~ /^i/);
    @acisi = ("i0", "i1", "i2", "i3");

    # define file names	
    $monen        = 1000;
    $evt2file     = "${obsid}_${evtext}.fits";
    $bpix         = "${obsid}_bpix.fits";
    $srcimg       = "${obsid}_img.fits";
    $sourcereg    = "${obsid}_source.reg";
    $enhistfile   = "${obsid}_energy.fits";
    $asphistfile  = "${obsid}_asphist.fits";
    $instmapfile  = "${obsid}_instmap.fits";
    if ($addbinname eq "no") {
	$expmapfile = "${obsid}_expmap.fits";
	$normfile   = "${obsid}_norm.fits";
    } else {
	$expmapfile = "${obsid}_bin${binning}_expmap.fits";
	$normfile   = "${obsid}_bin${binning}_norm.fits";
    }
    $fail = "no";

    # set badpix file
    system(`punlearn ardlib.par; punlearn acis_set_ardlib`);
    system(`acis_set_ardlib $bpix verb=0`);

    # file existance check
    unless (-e $evt2file) {
      chdir("$Bin");
      open  ERRFILE,">>err_expmap.log";
      print "## ERROR: ${obsid} # essential files missing.\n";
      print ERRFILE "${obsid} missing $evt2file\n";
      close ERRFILE;
      next;
    }

    # create a source region and find peak energy or...
    # create spectral weights based on naive model of cluster emission
    if ($make_instmap eq "yes") {
	if ($e_peak eq "yes") {
	    $monen = e_peak($sourcereg,$evt2file,$enhistfile);
	    $monen = $monen/1000;
	    print "## STATUS: Peak energy found: $monen keV\n";
	    print LOGFILE "Peak energy found: $monen keV\n";
	    $weightfile = "nihil";
	} else {
	    if (exists $fitdata{$key}) {
		@fit = split(/\s+/,$fitdata{$key});
		$z     = $fit[23];
		$nh    = $fit[4]*1e-2;
		$tx    = $fit[7];
		$fe    = $fit[10];
		$norm  = $fit[13];
		$monen = 1.0; # this will be ignored by mkinstmap if a specfile is given, but is necessary
		$weightfile = specweights();
		print "## STATUS: Spectral weights calculated for instrument map\n";
		print LOGFILE "Spectral weights calculated for instrument map\n";
	    } elsif (exists $altfit{$key}) {
		print "## WARNING: No data for $key in main fit file, checking alt fit file...\n";
		@fit = split(/\s+/,$altfit{$key});
		$z     = $fit[23];
		$nh    = $fit[4]*1e-2;
		$tx    = $fit[7];
		$fe    = $fit[10];
		$norm  = $fit[13];
		$monen = 1.0; # this will be ignored by mkinstmap if a specfile is given, but is necessary
		$weightfile = specweights();
		print "## STATUS: Spectral weights calculated for instrument map\n";
		print LOGFILE "Spectral weights calculated for instrument map\n";
	    } else {
		print "## ERROR: No data for $key in fit file, resorting to E_peak...\n";
		$monen = e_peak($sourcereg,$evt2file,$enhistfile);
		$monen = $monen/1000;
		$weightfile = "nihil";
		print "## STATUS: Peak energy found: $monen keV\n";
		print LOGFILE "Peak energy found: $monen keV\n";
	    }
	}
    }

    # generate aspect histogram file
    $fail = make_asphist($evt2file,$asphistfile) if ($make_asphist eq "yes");
    if ($fail eq "yes") {
      chdir("$Bin");
      open  ERRFILE,">>err_expmap.log";
      print "## ERROR: ${obsid} # failure in make_asphist ",scalar(localtime),"\n";
      print ERRFILE "${obsid} # failure in make_asphist ",scalar(localtime),"\n";
      close ERRFILE;
      next;
    };

    # generate instrument map
    $fail = make_instmap($asphistfile,$instmapfile) if ($make_instmap eq "yes");
    if ($fail eq "yes") {
      chdir("$Bin");
      open  ERRFILE,">>err_expmap.log";
      print "## ERROR: ${obsid} # failure in make_instmap ",scalar(localtime),"\n";
      print ERRFILE "${obsid} # failure in make_instmap ",scalar(localtime),"\n";
      close ERRFILE;
      next;
    };

    # generate images for creating exposure map
    $fail = make_img($evt2file,$srcimg) if ($make_img eq "yes");
    if ($fail eq "yes") {
      chdir("$Bin");
      open  ERRFILE,">>err_expmap.log";
      print "## ERROR: ${obsid} # failure in make_img ",scalar(localtime),"\n";
      print ERRFILE "${obsid} # failure in make_img ",scalar(localtime),"\n";
      close ERRFILE;
      next;
    };

    # generate the exposure map
    $fail = make_expmap($evt2file,$instmapfile,$asphistfile,$expmapfile,$srcimg) if ($make_expmap eq "yes");
    if ($fail eq "yes") {
      chdir("$Bin");
      open  ERRFILE,">>err_expmap.log";
      print "## ERROR: ${obsid} # failure in make_expmap ",scalar(localtime),"\n";
      print ERRFILE "${obsid} # failure in make_expmap ",scalar(localtime),"\n";
      close ERRFILE;
      next;
    };

    # generate the normalized image
    $fail = sub_make_normal($srcimg,$expmapfile,$normfile) if ($make_normal eq "yes");
    if ($fail eq "yes") {
	chdir("$Bin");
	open  ERRFILE,">>err_expmap.log";
	print "## ERROR: ${obsid} # failure in make_normal ",scalar(localtime),"\n";
	print ERRFILE "${obsid} # failure in make_normal ",scalar(localtime),"\n";
	close ERRFILE;
	next;
    };

    # cleanup temp files that might have been created
    unlink <xsel*>;
    unlink <*_i0_*>;
    unlink <*_i1_*>;
    unlink <*_i2_*>;
    unlink <*_i3_*>;
    unlink <*sherpa*>;
    unlink($srcimg);

    # write to log file
    print LOGFILE "## Finished $name (ObsId $obsid) ",scalar(localtime),"\n\n";
    print "## STATUS: Finished $name (ObsId $obsid) ",scalar(localtime),"\n\n";

    # change back to original directory
    chdir("$Bin");
  }
}

# close logging
print "###### Finished ",scalar(localtime)," ######\n\n";
print LOGFILE "###### Finished ",scalar(localtime)," ######\n\n";
close LOGFILE;

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
    $value = `punlearn dmkeypar; dmkeypar ${file}+1 $key; pget dmkeypar value`;
    chomp($value);      # remove any newline
    $value =~ s/\s+//g; # remove white space
    $value =~ s/\'//g;  # remove quotes
    return $value;

}

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

sub e_peak {

    # input parameters
    my($source,$evt2,$outfile) = @_;
    my($radius,$a,@data,$maxcts,$maxen,$prevcts);

    # create histogram of count-rate as a function of energy
    # Since we are not binning on pi or pha, we set opt=generic,
    # and we use a bin size of 20 eV to improve the signal to noise.
    $command = "punlearn dmextract; dmextract infile=\"${evt2}\[ccd_id=$chip_id{$id}][bin energy=300:10000:20\]\""
	." outfile=$outfile opt=generic clob+ verbose=$verb";
    system($command);

    # get the max count rate
    $command = "punlearn dmstat; dmstat \"$outfile\[cols count_rate\]\"";
    open TEMP, "${command}|";
    while (<TEMP>) {
        chomp;
        next if (/^\#/); # skip comment lines
        next if (/^$/);  # skip blank lines
        s/^\s+//;  # trim leading whitespace
        if ($_ =~ /^max/) {
	    @data = split /\s+/, $_;
	    $maxcts = $data[1]-(0.01*$data[1]);
	}
    }
    close TEMP;

    # get the energy corresponding to max count rate
    $command = "punlearn dmlist; dmlist \"$outfile\[count_rate>$maxcts\]\[cols energy,count_rate\]\" data,clean";
    $prevcts = $maxcts;
    open TEMP, "${command}|";
    while (<TEMP>) {
        chomp;
        next if (/^\#/); # skip comment lines
        next if (/^$/);  # skip blank lines
        s/^\s+//;  # trim leading whitespace
        @data = split /\s+/, $_;
	if ($data[1] > $prevcts) {
	    $maxen = $data[0];
	}
	$prevcts = $data[1];
    }
    close TEMP;
    return $maxen;
}

#######################
#######################

sub specweights {

    open(CHFILE,">sherpa.shp") || die "\n## ERROR! CANNOT OPEN SHERPA\n";
    print CHFILE "PARAMPROMPT OFF\n";
    print CHFILE "sherpa.clobber=1\n";
    print CHFILE "dataspace (0.1:10.0:0.01) histogram\n";
    print CHFILE "source=xswabs[abs]*xsmekal[m1]\n";
    print CHFILE "abs.nh=${nh}\n";
    print CHFILE "m1.kT=${tx}\n";
    print CHFILE "m1.nH=1\n";
    print CHFILE "m1.Abund=${fe}\n";
    print CHFILE "m1.Redshift=${z}\n";
    print CHFILE "m1.Switch=0\n";
    print CHFILE "m1.norm=${norm}\n";
    print CHFILE "write model weights.mdl\n";
    print CHFILE "exit\n";
    close CHFILE;
    system("sherpa sherpa.shp");
    open(CHFILE,">sherpa.sl") || die "\n## ERROR! CANNOT OPEN SHERPA\n";
    print CHFILE "PARAMPROMPT OFF\n";
    print CHFILE "sherpa.clobber=1\n";
    print CHFILE "()=evalfile(\"/bin/spectrum.sl\")\n";
    print CHFILE "runtest (\"weights.mdl\")\n";
    print CHFILE "exit\n";
    close CHFILE;
    system("sherpa --batch sherpa.sl");
    return ("weights.txt");
}

#######################
#######################

sub make_asphist {

    # input parameters
    my($evt2,$outfile) = @_;

    # construct the aspect histogram command
    print "## STATUS: Making aspect solution histogram...\n";
    if ($instr eq "s") {
	$command = "punlearn asphist; asphist infile=$aspfile outfile=$outfile"
	    ." evtfile=\"$evt2\[ccd_id=chip_id{$id}\]\" clob+ verbose=$verb";
	system($command);
    } else {
	foreach $d (@acisi) {
	    $outfile = "${obsid}_${d}_asphist.fits";
	    $command = "punlearn asphist; asphist infile=$aspfile outfile=$outfile"
		." evtfile=\"$evt2\[ccd_id=chip_id{$d}\]\" mode=h clob+ verbose=$verb";
	    system($command);
	}
    }

    # check that it worked
    if (-e $outfile) {
	print "## STATUS: Aspect histogram construction complete\n";
    } else {
	return "yes";
    }
}

#######################
#######################

sub get_asolfile {

    # get the asol file or files
    my($curdir,@infile,$asol,$pbk,@dir,@globlist);
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
    die "## ERROR: No asol files found. Exiting.\n" unless (@infile);
    $asol = join(",",@infile);
    chdir($curdir);

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
    die "## ERROR: $obsid no pbk files found. Exiting.\n" unless (@infile);
    $pbk = join(",",@infile);
    chdir($curdir);
    return ($asol,$pbk);
}

#######################
#######################

sub make_instmap {

    # input parameters
    my($aspfile,$outfile) = @_;

    # get the asol file or files
    $msk = get_mskfile();
    print "## STATUS: Using mask file: $msk\n";

    # set the specfile param
    if ($weightfile ne "nihil") {
      $specfile = $weightfile;
    } else {
      $specfile = "NONE";
    }
    print "## STATUS: Using spectral weights: $specfile\n";

    # construct the aspect histogram command
    if ($instr eq "s") {
	$command = "punlearn mkinstmap; mkinstmap obsfile=\"$aspfile\[asphist\]\" outfile=\"$outfile\""
	    ." detsubsys=\"$det_chip{$id}\" pixelgrid=\"1:1024:#1024,1:1024:\#1024\" spectrumfile=$specfile"
	    ." dafile=CALDB grating=NONE maskfile=$msk pbkfile=$pbk monoenergy=${monen} clob+ verbose=$verb";
	system($command);
    } else {
        foreach $d (@acisi) {
	    $aspfile = "${obsid}_${d}_asphist.fits";
	    $outfile = "${obsid}_${d}_instmap.fits";
	    $command = "punlearn mkinstmap; mkinstmap obsfile=\"$aspfile\[asphist\]\" outfile=\"$outfile\""
		." detsubsys=\"$det_chip{$d}\" pixelgrid=\"1:1024:#1024,1:1024:\#1024\" spectrumfile=$specfile grating=NONE"
		." dafile=CALDB maskfile=$msk pbkfile=$pbk monoenergy=${monen} clob+ verbose=$verb mode=h";
	    system($command);
	}
    }

    # check that it worked
    if (-e $outfile) {
	print "## STATUS: Instrument map calculation complete\n";
    } else {
	return "yes";
    }
}

#######################
#######################

sub get_mskfile {

    # get the msk file or files
    my($curdir,$msk,@dir,@globlist);
    $curdir = cwd();

    # change to appropriate dir (they sometimes change the locations)
    @dir = qw(primary secondary);
    foreach $dir (@dir) {
        chdir "../$dir";
        @globlist =  <*msk1*.fits*>;
	if (@globlist) {
	    @globlist = map { "../$dir/" . $_} @globlist;
	    last;
	}
        chdir $curdir;
    }

    unless (@globlist) {
	print "## WARNING: No msk1 files found. Defaulting to \"NONE\". **WARNING** CCD edge effects now part of analysis!\n";
	$msk = "NONE";
    } else {
	$msk = join(",",@globlist);
    }

    # return the name(s)
    chdir($curdir);
    return $msk;
}

#######################
#######################

sub make_img {

    #input params
    my($evt2,$srcimg) = @_;

    # make a region containing entire chip in sky coords
    if ($instr eq "s") {
	$regfile = make_skyreg();
	$command = "dmcopy \"$evt2\[energy=$emin:$emax][sky=region\($regfile\[ccd_id=$chip_id{$id}])][bin sky=$binning][opt mem=135]\""
	    ." $srcimg clob+ verbose=$verb";
	system($command);
	unlink($regfile);
    } else {
	$command = "dmcopy \"$evt2\[energy=$emin:$emax][bin sky=$binning][opt mem=135]\" $srcimg clob+ verbose=$verb";
	system($command);
    }

    # check that it worked
    if (-e $srcimg) {
	print "## STATUS: Images creation complete\n";
    } else {
	return "yes";
    }
}

#######################
#######################

sub make_expmap {

    # input parameters
    my($evt2,$instfile,$aspfile,$outfile,$srcimg) = @_;

    # find the chip limits
    $command = "punlearn get_sky_limits; get_sky_limits $srcimg verbose=1";
    system($command);

    # construct the exposure map command
    print "## STATUS: Creating exposure map, this will take some time...\n";
    if ($instr eq "s") {
	$command = "punlearn mkexpmap; mkexpmap instmapfile=$instfile outfile=$outfile xygrid=\"\)get_sky_limits.xygrid\""
	    ." asphistfile=$aspfile useavgaspect=$avgasp normalize=$normal clob+ verbose=$verb";
	system($command);
    } else {
	@expmaps = ();
	foreach $d (@acisi) {
	    print "## STATUS: Working on $d of ACIS-I array...\n";
	    $instfile = "${obsid}_${d}_instmap.fits";
	    $aspfile = "${obsid}_${d}_asphist.fits";
	    $out = "${obsid}_${d}_expmap.fits";
	    $command = "punlearn mkexpmap; mkexpmap instmapfile=$instfile outfile=$out xygrid=\"\)get_sky_limits.xygrid\""
		." asphistfile=$aspfile useavgaspect=$avgasp normalize=$normal clob+ verbose=$verb";
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
    $bhi = 8192/$binning;

    # combine the expsoure maps for I array
    if ($instr eq "i") {
	$command = "punlearn dmregrid; dmregrid infile=\@list outfile=$outfile bin=\"${blo}:${bhi}:1,${blo}:${bhi}:1\""
	    ." rotangle=0 npts=1 xoffset=0 yoffset=0 rotxcenter=0 rotycenter=0 clob+ verbose=$verb";
	system($command);
    }
    
    # check that it worked
    if (-e $outfile) {
	print "## STATUS: Exposure map calculation complete\n";
	system("rm -f list");
    } else {
	return "yes";
    }
}

#######################
#######################

sub make_skyreg {

    # input parameters
    my $regfile = "chips_reg.fits";

    # construct the aspect histogram command
    $command = "punlearn skyfov; skyfov infile=$evt2file outfile=$regfile aspect=$aspfile clob+ verbose=$verb";
    system($command);

    # check that it worked
    if (-e $regfile) {
	print "## STATUS: Region file creation complete\n";
    } else {
	die "No region file\n";
    }
    return $regfile;
}

#######################
#######################

sub sub_make_normal {

    # input parameters
    my($srcimg,$exp,$outfile) = @_;
    my($in);

    # threshold cut
    if ($threshcut eq "yes") {
	$command = "punlearn dmimgthresh; dmimgthresh $srcimg temp.fits expfile=$exp cut=$cut value=0.0 verbose=$verb clob+";
	system($command);
	$in = "temp.fits";
    } else {
	$in = $srcimg;
    }
    
    # construct the normalization command
    $command = "punlearn dmimgcalc; dmimgcalc $in $exp $outfile div"
	." clob+ verbose=$verb";
    system($command);
    
    # check that it worked
    if (-e $outfile) {
	print "## STATUS: Image normalization complete\n";
    } else {
	$fail = "yes";
    }
}

#######################
#######################
