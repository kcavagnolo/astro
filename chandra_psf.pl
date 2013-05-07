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

$rootdir = "reprocessed/";
$emin = "300";
$emax = "10000";
$ebin = "100";
@eef  = qw(1.0 0.9 0.75 0.5);
$verb = "0";

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
# check for psf files
use Cwd;
use FindBin qw($Bin);
die "## ERROR: CIAO is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "## ERROR: Wrong number of command line arguments\n" if (@ARGV != 1);

# for ciao <=3.4
#$check = `ls $ENV{'CALDB'}/data/chandra/acis/cpf/2dpsf/`;
#die "## ERROR: No ACIS PSF library installed.\n" if ($check eq "");
#$check = `ls $ENV{'CALDB'}/data/chandra/hrc/cpf/2dpsf/`;
#die "## ERROR: No HRC PSF library installed.\n" if ($check eq "");

# for ciao >=4.0
$check = `ls $ENV{'CALDB'}/data/chandra/acis/2d_psf/`;
die "## ERROR: No ACIS PSF library installed.\n" if ($check eq "");
$check = `ls $ENV{'CALDB'}/data/chandra/hrc/2d_psf/`;
die "## ERROR: No HRC PSF library installed.\n" if ($check eq "");

# read in the reference file
%refdata  = &sub_get_data($ARGV[0]);

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get obsid
    $name    = $data[0];
    $obsid   = $data[1];
    $datadir = $data[15];

    # change directory
    chdir("$datadir/$obsid/$rootdir");
    
    # define the ccd to use and file names
    $evt       = "${obsid}_clean.fits";
    $srcreg    = "${obsid}_source.reg";
    $psfreg    = "${obsid}_psf.reg";
    $psfbgdreg = "${obsid}_psfbgd.reg";
    $img       = "${obsid}_psf_img.fits";
    $outfile   = "${obsid}_psf_ehist.fits";
    $outpsf    = "${obsid}_psf.fits";

    # check for files
    unless (-e $evt) {
        $offender = "no $evt file";
        logerror($offender);
	chdir("$Bin");
        next;
    }
    unless (-e $srcreg) {
        $offender = "no $srcreg file";
        logerror($offender);
	chdir("$Bin");
        next;
    }
    unless ((-e $psfreg) && (-e $psfbgdreg)) {
        $offender = "no psf region files";
        logerror($offender);
	chdir("$Bin");
        next;
    }

    # make array of PSF energies
    @psfen = (0.277, 1.4967, 4.510, 6.400, 8.600);

    # get x, y, and size of region used for psf
    open(INFILE,$psfreg);
    while (<INFILE>) {
	chomp;
	next if (/^\#/);
	next if (/^$/);
	$line = $_;
	$line =~ s/^.*\(//;
	$line =~ s/\)//;
	($x,$y,$r) = split(/\,/,$line);
    }
    close INFILE;
    $srcx = sprintf("%.2f",$x);
    $srcy = sprintf("%.2f",$y);
    $srcr = sprintf("%.2f",$r);

    # get x, y, and size of region used for psf *BGD*
    open(INFILE,$psfbgdreg);
    while (<INFILE>) {
	chomp;
	next if (/^\#/);
	next if (/^$/);
	$line = $_;
	$line =~ s/^.*\(//;
	$line =~ s/\)//;
	($x,$y,$rin,$rout) = split(/\,/,$line);
    }
    close INFILE;
    $bgdrin = sprintf("%.2f",$rin);
    $bgdrout = sprintf("%.2f",$rout);

    # make an image filtered on energy
    $command = "punlearn dmcopy; dmcopy \"${evt}\[energy=${emin}:${emax}\]\" temp.fits clob+ verbose=$verb";
    system($command);
    
    #make an image of the region of interest
    $command = "punlearn dmcopy; dmcopy \"temp.fits\[sky=region(${srcreg})\]\[bin sky\]\" ${img} clob+ verbose=$verb";
    system($command);
    system("rm -f temp.fits");

    # make an energy histogram
    $command = "punlearn dmextract; dmextract \"${evt}\[sky=region(${psfreg})\]\[bin energy=${emin}:${emax}:${ebin}\]\" $outfile opt=generic clob+ verbose=$verb";
    system($command);

    # find the peak ct rate
    $command = "punlearn dmstat; dmstat \"${outfile}\[cols count_rate\]\"";
    system($command);
    chomp($max = `pget dmstat out_max`);
    print "## STATUS: Maximum count rate: ${max}.\n";
    $max = $max-(0.01*$max);

    # find the energy associated w/ peak ct rat
    $command = "punlearn dmlist; dmlist \"$outfile\[count_rate > $max\]\[cols energy,count_rate\]\" data,clean";
    $prevcts = $max;
    open TEMP, "${command}|";
    while (<TEMP>) {
	chomp;
	next if (/^\#/);
	next if (/^$/);
	s/^\s+//;
	@data = split /\s+/, $_;
	if ($data[1] > $prevcts) {
	    $maxen = $data[0];
	}
	$prevcts = $data[1];
    }
    close TEMP;
    $maxen = $maxen/1000.;
    print "## STATUS: Energy at maximum count rate: ${maxen} keV.\n";
    $preven = 999999.;
    foreach $pe (@psfen) {
	$dur = abs($maxen-$pe);
	$psfen = $pe if ($dur < $preven);
	$preven = $pe;
    }
    print "## STATUS: PSF grid energy of $psfen keV found to be closest.\n";

    # make plot of ct rate vs. energy
#     open(PRO,">a.pro");
#     printf PRO "a=mrdfits('agn_energy.fits',1)\n";
#     printf PRO "set_plot,'PS'\n";
#     printf PRO "device,filename='agn_energy.ps'\n";
#     printf PRO "plot,a.energy,a.count_rate,xtitle='Energy [eV]',ytitle='Count Rate [cts/s]'\n";
#     printf PRO "device,/close\n";
#     printf PRO "set_plot,'X'\n";
#     close PRO;
#     $idldir = $ENV{'IDL_DIR'};
#     $pid = open3(\*IDL_INPUT, \*IDL_OUTPUT, \*IDL_ERR, "${idldir}/bin/idl") ||
# 	die "## ERROR: Cannot start IDL\n";
#     print IDL_INPUT "print, '--Now in IDL--'\n";
#     print IDL_INPUT "a\n";
#     while (<IDL_OUTPUT>) {
# 	chomp;
# 	print "idl: $_\n";
# 	print IDL_INPUT "exit\n";
#     }   
#     print "idl: --Exiting IDL--\n";
#     close IDL_INPUT;
#     close IDL_OUTPUT;
#     close IDL_ERR;
#     waitpid($pid,0);

    # determine off-axis angle
    $asol = &sub_get_asolfile();
    $command = "punlearn dmcoords; dmcoords ${evt} option=sky x=$x y=$y asolfile=$asol";
    system($command);
    chomp($theta = `pget dmcoords theta`);
    print "## STATUS: Off-axis angle is: $theta arcminutes.\n";

    # number of counts in source
    $command = "punlearn dmstat; dmstat \"${img}\[sky=region($psfreg)\]\" centroid=no sigma=no";
    system($command);
    chomp($srccts = `pget dmstat out_sum`);
    print "## STATUS: Source counts: ${srccts}.\n";

    # number of bgd cts
    $command = "punlearn dmstat; dmstat \"${img}\[sky=region($psfbgdreg)\]\" centroid=no sigma=no";
    system($command);
    chomp($bgdcts = `pget dmstat out_sum`);
    print "## STATUS: Background counts: ${bgdcts}.\n";

    # find scale of src reg to bgd reg
    use constant PI => 4*atan2(1,1);
    $scale = (PI * $srcr**2.0) / (PI*($bgdrout**2.0 - $bgdrin**2.0));
    print "## STATUS: src_area/bgd_area: ${scale}.\n";

    # calc total counts
    $totcts = $srccts - ($scale * $bgdcts);
    print "## STATUS: Background subtracted source counts: ${totcts}.\n";

    # create the psf
    $command = "punlearn mkpsf; mkpsf infile=$img outfile=temp_psf.fits binspax=INDEF binspay=INDEF sizeoutx=INDEF sizeouty=INDEF"
	." outpsffile=\"\" coord=SKY x=$srcx y=$srcy energy=$maxen \"psflibfile=CALDB\(DETECTOR=ACIS-I\)\" rotpts=20 clob+ verbose=$verb mode=h";
    system($command);

    # normalize the psf
    $command = "punlearn dmstat; dmstat temp_psf.fits centroid=no sigma=no";
    system($command);
    chomp($psfcts = `pget dmstat out_sum`);
    print "## STATUS: Signal in PSF: ${psfcts}.\n";
    $norm = $totcts/$psfcts;
    $command = "punlearn dmimgcalc; dmimgcalc infile=temp_psf.fits infile2=none weight=$norm operation=add out=${outpsf} clob+ verbose=$verb";
    system($command);
    $command = "punlearn dmstat; dmstat $outpsf centroid=no sigma=no";
    system($command);
    chomp($psfcts = `pget dmstat out_sum`);
    print "## STATUS: Signal in normalized PSF: ${psfcts}.\n";

    # calculate the enclosed energy fractions
    foreach $eef (@eef) {
	$teef = $eef*100.;
	$teef = sprintf("%i",$teef);
	$outreg = "${obsid}_${teef}eef.reg";
	$command = "punlearn dmellipse; dmellipse $outpsf $outreg $eef verbose=$verb clob+";
	system($command);
    }

    # clean-up
    system("rm -f temp_psf.fits");
    system("rm -f $img");
    chdir("$Bin");
}

# all done
exit 0;

#######################
#######################
#### Sub routines #####
#######################
#######################

sub sub_get_data {

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

sub logerror {

    my($offender) = @_;
    open  ERRFILE,">>${Bin}/err_psf.log";
    print "## ERROR: ${obsid} failure in chandra_psf.pl, $offender ",scalar(localtime),"\n";
    print ERRFILE "${name} ${obsid} failure in chandra_psf.pl, $offender ",scalar(localtime),"\n";
    close ERRFILE;
}

#######################
#######################
