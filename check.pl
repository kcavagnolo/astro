#! /usr/bin/perl -w

$rootdir = "reprocessed/";
$runname = "annuli";

use Cwd;
use FindBin qw($Bin);

open(IN,$ARGV[0]);
open(OUT,">check.log");
printf OUT "%-20s %10s %10s %10s %10s %8s\n", "#Name", "ObsID", "evt", "bgevt", "expmap", "spec";
while(<IN>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @line = split;
    undef(@checkann);
    printf OUT "%-20s %10s", $line[0], $line[1];
    chdir("$line[15]/$line[1]/$rootdir/");
    sub_check("$line[1]_exclude.fits");
    sub_check("$line[1]_bgevt.fits");
    sub_check("$line[1]_expmap.fits");
    @regions = glob("*_${runname}*.reg");
    foreach $reg (@regions) {
	$anum = $reg;
	$anum =~ s/.*${runname}(\d+)\.reg/$1/;
	$root = "$line[0]_$line[1]_${runname}${anum}_src1";
	push @checkann, "$anum" unless (-e "${root}_grp.pi" && -e "${root}_bgd.pi" && -e "${root}.warf" && -e "${root}.wrmf");
    }
    $dum = join ",", @checkann;
    $dum = "-" if $dum eq "";
    printf OUT "         %-s\n", $dum;
}
close IN;
close OUT;
exit 0;

sub sub_check {
    $file = $_[0];
    unless (-e $file) {
	$check = "FFF";
    } else {
	$check = "-";
    }
    printf OUT "%10s", $check;
}
