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

$evtext = "exclude";
$makeflux = "yes";
$makeprof = "yes";
$makelum = "no";
$binname = "sbprof_2pix";
$h0 = 70.1;
$lam = 0.72;
$mat = 1.0-$lam;
$emin = "300";
$emax = "10000";
$rootdir = "reprocessed/";
$verb = 1;

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

# read in the reference file and store fiducial info
%refdata = &sub_get_data($ARGV[0]);
foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get values specific to each cluster
    $obsid = $data[1];
    $z = $data[6];
    $datadir = $data[15];

    # change directory
    chdir("$datadir/$obsid/$rootdir");

    # get files
    @glob = glob("*${evtext}*");
    $in = $glob[0];
    $outfits = "${obsid}_flux.fits";
    $outimg  = "${obsid}_flux.img";
    $lumfits = "${obsid}_lum.img";

    # calculate flux image
    if ($makeflux eq "yes") {
	$command = "punlearn eff2evt; eff2evt \"$in\[energy=$emin:$emax\]\" $outfits verbose=$verb clob+";
	system($command);
	$command = "punlearn dmcopy; dmcopy \"${outfits}[bin x,y;flux][opt mem=250]\" $outimg verbose=$verb clob+";
	system($command);
    }

    # calculate luminosity image
    &calc_lum($outimg,$lumfits) if ($makelum eq "yes");

    # calculate a flux profile
    &calc_flux($outfits) if ($makeprof eq "yes");
}
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_get_data {

    my($infile) = @_;
    my(@data, $name, %info);
    open(INFILE,$infile) || die "## ERROR: Cannot open $infile\n";
    while (<INFILE>) {
        chomp;
        next if (/^\#/);
        next if (/^$/);
        s/^\s+//;
        s/\s+$//;
        @data = split;
        $name = $data[0];
        $info{$name} = $_;
    }
    close INFILE;
    return %info;
}

#######################
#######################

sub calc_flux {

    my($in) = @_;

    # get reg file
    undef @glob;
    my @glob = glob("*${binname}*.reg");
    my $reg = $glob[0];

    # open log file
    $out = "${obsid}_fluxprof_${binname}.dat";
    open(LOG,">${out}");
    print LOG "# Cosmology used for lum calc: z=$z, H0=$h0, Lambda=$lam, Matdens=$mat\n";
    print LOG "# Energy range of event file used: $emin eV --> $emax eV\n";
    printf LOG "%-15s %8s %8s %8s %8s %15s %15s %15s %15s\n",
    "#Annulus", "Cell", "Rin", "Rout", "Rmid", "Flux", "Flux_Err", "Lum", "Lum_Err";

    # for each bin, calc flux
    open(REG,$reg) || die "## ERROR: Cannot open $reg\n";
    $i = 1;
    while(<REG>) {
	chomp;
        next if (/^\#/);
        next if (/^$/);
        s/^\s+//;
        s/\s+$//;
	my $ann = $_;
	my $command = "punlearn dmstat; dmstat \"${in}\[sky=${ann}\]\[cols flux\]\" verbose=0";
	system($command);

	# retrieve fluxes
	my $flux = `pget dmstat out_sum`;
	my $ferr = `pget dmstat out_sigma`;
	$flux  =~ s/^\s+//;
	$flux  =~ s/\s+$//;
	$ferr =~ s/^\s+//;
	$ferr =~ s/\s+$//;

	# calc luminosities
	delete $ENV{'DYLD_BIND_AT_LAUNCH'};
	open(PROFILE,">flux.pro");
	print PROFILE "\!quiet=1\n";
	print PROFILE "lum = flux2lum($flux, $z, $h0, $mat, $lam, /silent)\n";
	print PROFILE "lerr = flux2lum($ferr, $z, $h0, $mat, $lam, /silent)\n";
	print PROFILE "openw,1,'temp.log'\n";
	print PROFILE "printf,1,strcompress(lum,/remove_all)+'      '+strcompress(lerr,/remove_all)\n";
	print PROFILE "close,1\n";
	print PROFILE "exit \n";
	close PROFILE;
	system("\$IDL_DIR/bin/idl flux.pro");
	open(FILE,"temp.log");
	while(<FILE>) {
	    chomp;
	    next if (/^\#/);
	    next if (/^$/);
	    s/^\s+//;
	    s/\s+$//;
	    @line = split;
	    $lum = $line[0];
	    $lerr = $line[1];
	}
	close FILE;
	system('rm -f flux.pro');
	system('rm -f temp.log');

	# print to a logfile
        $ann =~ s/^.*\(//;
        $ann =~ s/\)//;
	($x0,$y0,$rin,$rout) = split(/\,/,$ann);
	$x0 = $y0; # junk command to avoid warning msg from perl
	$rmid = ($rin+$rout)/2.0;
	printf LOG "%-15s %8i %8i %8i %8i %15.3e %15.3e %15.3e %15.3e\n",
	$i, 1, $rin, $rout, $rmid, $flux, $ferr, $lum, $lerr;
	$i++;
    }
    close REG;
    close LOG;
}

#######################
#######################
