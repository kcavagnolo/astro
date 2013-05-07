#! /usr/bin/perl -w
#
# NAME:
#     view_cumprof.pl
#
# PURPOSE:
#     display postscript of cumulative count profile
#
# EXPLANATION:
#     This script assumes the following directory structure:
#     all pertinent Chandra data files are in a dir labeled with
#     the obsid, which is then in a dir labeled acis/. The location
#     of acis/ relative to the dir from which this script is run is
#     set with the variable $datadir.
#
#     e.g.: for Abell 644 obsid 2211, this script will look to
#     $datadir/acis/2211/ for all the files needed to complete
#     the data reduction
#
# CALLING SEQUENCE:
#     view_cumprof.pl <reference list>
#
# INPUTS:
#     Level 2 event file:                          <obsid>_evt2.fits
#     Region file containing pt srcs for one chip: <obsid>_exclude.reg
#     <reference list> = file containing information about each cluster
#     the assumed format for the list is as follows:
#     Name                           ObsID        X        Y   Rmax     MinCts         z  Nh20     Tx     Fe  Lbol ChipID
#     ABELL_0644                      2211   3908.5   4332.5  243.9       5000    0.0704  6.41   8.64   0.35 45.00     s3
#     ABELL_1651                      4185   4222.5   4034.5  132.3       5000    0.0844  1.88   5.97   0.30 45.00     i2
#
# OUTPUTS:
#     nothing
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$looklocal = "yes";                         # "yes" = search datadir; "no" = search datadir/OBSID/rootdir
$rootdir   = "reprocessed";                 # name of directory where new files will be placed
#$ext       = "sbprof_10pix";
#$localdir  = "$ENV{'HOME'}/research/smcs/analysis/sbr/";
#$ext       = "cumprof";
#$localdir  = "$ENV{'HOME'}/research/pf_clusters/pf_fits/plots/cumprof/";
$ext       = "lc";
$localdir  = "$ENV{'HOME'}/research/redux/redux_info/lightcurves/";

#######################
#######################
##   Main Program    ##
#######################
#######################


# load useful libraries
# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# read in the reference file
%refdata = read_file($ARGV[0],0,1);

# load postscript in GhostView
MAIN: foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get values specific to each cluster
    $obsid = $data[1];
    $loc   = $data[15];
    if ($looklocal eq "yes") {
	$datadir = $localdir;
    } else {
	$datadir = $loc;
    }

    # change directory
    if ($looklocal eq "yes") {
	chdir("$datadir/");
    } else {
	chdir("$datadir/$obsid/$rootdir/");
    }

    # set files to be opened
    $psfile = "${obsid}_${ext}.ps";	
    unless (-e $psfile) {
	print "## ERROR: No $psfile\n";
	next;
    }

    # load images
    view_ps($psfile);

    # pause to give time to kill the script
    sleep 0.5;

    # change back to original directory
    chdir("$Bin");
}


#######################
#######################
##   Sub-Routines    ##
#######################
#######################


sub view_ps {
    my($psfile) = @_;
    $command = "gv $psfile";
    system $command;
}

#######################
#######################

sub read_file {
    my($infile,@params) = @_;
    my(%info,@data,$name);
    open(INFILE,$infile) || die "Can't open $infile\n";
    while (<INFILE>) {
        chomp;
        next if (/^\#/); # skip comment lines
        next if (/^$/);  # skip blank lines
        s/^\s+//;  # trim leading whitespace
        s/\s+$//;  # trim trailing whitespace
        @data = split;
        $name = "";
        foreach $param (@params) {
            $name .= "$data[$param]_";
        }
        chop $name;
        $info{$name} = $_;
    }
    close INFILE;
    return %info;
}

#######################
#######################

