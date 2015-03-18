#! /usr/bin/perl -w
open(A,">junk");
while(<>){
    chomp;
    next if (/^\#/);
    @line=split;
    push @obs,$line[1] unless (-e "../$line[1]/reprocessed/$line[1]_exclude.fits");
    print A "$_\n" unless (-e "../$line[1]/reprocessed/$line[1]_exclude.fits");
}
#foreach $a (@obs) {
#    print "$a\n";
#    system(`emacs ../${a}/reprocessed/${a}_exclude.reg`);
#}


