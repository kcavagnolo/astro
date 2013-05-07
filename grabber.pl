#! /usr/bin/perl -w

$byname = "no";
$printfromin = "no";

open(A,"$ARGV[0]");
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @line=split;
    if ($byname eq "yes") {
	$get = $line[0];
    } else {
#	$get = $line[1];
	$get = $line[0];
    }
    $a{$get}=$_;
}
close A;

open(IN,"$ARGV[1]");
open(FOUND,">out");
open(MISSING,">err");
while(<IN>){
    chomp;
    @line=split;
    if ($byname eq "yes") {
	$get = $line[0];
    } else {
	$get = $line[1];
    }
    if (exists $a{$get}){
	if ($printfromin eq "yes") {
	    print FOUND "$a{$get}\n";
	} else {
	    print FOUND "$_\n";
	}
    } else {
	print MISSING "$_\n";
    }
}
close IN;
close FOUND;
close MISSING;
exit 0;
