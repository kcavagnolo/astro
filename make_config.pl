#! /usr/local/bin/perl -w
#
# NAME:
#     make_config.pl
#
# PURPOSE:
#     construct a config file which can be read into 1tdeproj.pl
#     or 2tdeproj.pl
#
# EXPLANATION:
#
# CALLING SEQUENCE:
#     make_config.pl <reference file>
#     i.e.: perl make_config.pl 1tpr_nhfrozen.dat
#
# INPUTS:
#     <reference file> = file containing information about each cluster
#     The assumed order of the params is based on the output of
#     fit_projected.pl and goes in order of:
#     Cluster, ObsID, Rin, Rout, nh20, nlo, nhi, Tx, Tlo, Thi, Fe, Felo,
#     Fehi, Norm, Normlo, Normhi, Tx2, Tlo2, Thi2, Norm2, Normlo2, Normhi2,
#     z, Cr, chisq, dof
#
# OUTPUTS:
#     configuration file used for 1tdeproj.pl or 2tdeproj.pl with name
#     specified by the variable $configfile below:
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$configfile = "1tde.config";
$model      = "mekal";
$tienh      = "yes";

#######################
#######################
##   Main Program    ##
#######################
#######################

# check the number of arguments given
die "Wrong number of command line arguments\n" if (@ARGV != 1);

# write the header line for the file
open(CONFIGFILE,">${configfile}") || die "Can't open ${configfile}\n";
printf CONFIGFILE "%-20s %25s %10s %6s %10s %10s %10s %10s %10s %10s %10s\n","#Name","ObsID","z","Ann","model","nh20","Tx","Fe","Norm","Tx2","Norm2";
close CONFIGFILE;

# intialize name and i for incrementing use
$obsid = "";
$i = 0;

# begin the loop
while (<>) {

    # split up the data line
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    s/^\s+//;  # trim leading whitespace
    s/\s+$//;  # trim trailing whitespace
    @data = split;

    # get values specific to each annulus
    $prevobsid = $obsid;
    $name   = $data[0];
    $obsid  = $data[1];
    $nh     = $data[4];
    $tx     = $data[7];
    $fe     = $data[10];
    $norm   = $data[13];
    $tx2    = $data[16];
    $norm2  = $data[19];
    $z      = $data[22];

    # perform a name comparison to determine annulus incrementing
    if ($prevobsid eq $obsid) {
	$ann = $i+1;
	$i++;
    } else {
	$i = 1;
	$ann = $i;
    }

    # set nh value to "=1" if tying is wanted
    if ($tienh eq "yes" && $ann != 1) {
	$nh = "=1";
    }

    # write the proper line to the configuration file
    open(CONFIGFILE,">>${configfile}") || die "Can't open ${configfile}\n";
    printf CONFIGFILE "%-20s %25s %10s %6s %10s %10s %10s %10s %10s %10s %10s\n",$name,$obsid,$z,$ann,$model,$nh,$tx,$fe,$norm,$tx2,$norm2;
    close CONFIGFILE;
}
