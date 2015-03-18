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

# other options needed
$verb = 1;
$datadir1  = "/mnt/SINISTER";
$datadir2  = "/mnt/SINISTER";
$datadir3  = "/mnt/SINISTER";
$rootdir   = "reprocessed/";

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
# load useful libraries
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "## Wrong number of command line arguments\n" if (@ARGV != 1);
use Cwd;
use FindBin qw($Bin);

open(A,$ARGV[0]);
while(<A>){
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    @data = split;
    $obsid  = $data[1];
    $loc    = $data[15];
    $datadir = $datadir1 if ($loc eq "NAZGUL");
    $datadir = $datadir2 if ($loc eq "MBRANE");
    $datadir = $datadir3 if ($loc eq "GALACTUS");
    chdir("$datadir/$obsid/$rootdir");
    $regfile = "${obsid}_exclcore.reg";

    # check for an empty file
    $wc = `wc $regfile`;
    my @data = split(/\s+/, $wc);
    my $check = $data[1];
    if ($check == 0) {
	print "## ERROR: skipping $regfile, it's empty.\n";
	next;
    }
    $infile = "${obsid}_exclude.fits";
    $outfile = "${obsid}_exclude.fits";
    unless (-e $regfile && -e $infile) {
	print "## ERROR: missing either $regfile or $infile\n";
	open(B,">> err_rm_cen_ptsrc.log");
	printf B "${obsid} # missing either $regfile or $infile\n";
	close B;
	next;
	chdir("$Bin");
    }
    print "\n## Found ${regfile}. Excluding core sources from $infile.\n\n";
    $command = "punlearn dmcopy ; dmcopy \"$infile\[exclude sky=region($regfile)]\" temp.fits clobber=yes verbose=$verb\n";
    system $command;
    system("mv -f temp.fits $outfile");
    chdir("$Bin");
}
exit 0;
