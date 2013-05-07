#! /usr/bin/perl -w

use Cwd;
use FindBin qw($Bin);

open(A,"first_result.dat");
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @a=split;
    $key = join("_",$a[1],$a[2],$a[4],$a[5]);
    $ref{$key}=$_;
}
close A;

open(A,"first.list");
open(B,">out");
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @a=split;
    $ra = join(" ",$a[0],$a[1],$a[2]);
    $dec = join(" ",$a[3],$a[4],$a[5]);
    $name = $a[6];
    $obsid = $a[7];
    $z = $a[8];
    $key = join("_",$a[0],$a[1],$a[3],$a[4]);
    printf B "%-28s %7s %8.4f %14s %14s",$name,$obsid,$z,$ra,$dec;
    printf "%-28s %7s %8.4f %14s %14s",$name,$obsid,$z,$ra,$dec;
    if (exists $ref{$key}) {
	print "$ref{$key}\n";
	print B "$ref{$key}\n";
    } else {
	print "$key\n";
	print B " MISSING MISSING MISSING\n";
    }
}
close A;
close B;
exit 0;
