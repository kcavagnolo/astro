#! /usr/bin/perl -w

use Cwd;
use FindBin qw($Bin);

open(A,"pf_nvss_20kpc.list");
open(B,">out");
print B "#RA DEC NAME OBS Z\n";
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @b = split;
    @a = split("--",$b[8]);
    shift(@a);
    $z = pop(@a);
    $ob = pop(@a);
    $a = join("_",@a);
    $a =~ s/\_dag//;
    print B "$b[0] $b[1] $b[2] $b[3] $b[4] $b[5] $a $ob $z\n";
}
close A;
close B;
exit 0;
