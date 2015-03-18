#! /usr/bin/perl -w

# input file example:
#
##name           obsid   x       y       bin     majin           majmax          aspect          angle           location
#RBS_0797        merged  4389    4014    2       13.352334       63.352334       0.847123928     12.7499         /mnt/DROBO

$rootdir = "reprocessed";

use Cwd;
use FindBin qw($Bin);

open(A,$ARGV[0]);
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @line = split;
    $name = $line[0];
    $obsid = $line[1];
    $x = $line[2];
    $y = $line[3];
    $binsize = $line[4];
    $majin = $line[5];
    $majmax = $line[6];
    $aspect = $line[7];
    $phi = $line[8];
    $datadir = $line[9];

    if ($obsid eq "merged") {
	chdir("$datadir/$obsid/$name/");
    } else {
	chdir("$datadir/$obsid/$rootdir/");
    }
    $sbreg  = "${name}_sbprof_ell${binsize}pix.reg";
    $minin = $majin*$aspect;
    while ($majin <= $majmax) {
	$majout = $majin+$binsize;
	$minout = $majout*$aspect;
	$line = "ellipse(${x},${y},${majout},${minout},${phi})\*\!ellipse(${x},${y},${majin},${minin},${phi})\n";
	push @lines,$line;
	$majin = $majout;
	$minin = $minout;
    }
    open(SBREG,">$sbreg");
    print SBREG @lines;
    close SBREG;
    if (-e $sbreg) {
	print "## Created region file $sbreg\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
    chdir("$Bin");
}
close A;
exit 0;
