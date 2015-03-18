#! /usr/bin/perl -w

open(A,$ARGV[0]);
while(<A>){
  chomp;
  @line=split;
  next if (/^\#/);
  $ref{$line[0]} = $line[0];
}
close A;

open(OUT,">$ARGV[2]");
open(B,$ARGV[1]);
while(<B>){
  chomp;
  @line=split;
  if (exists $ref{$line[0]}) {
      print "## Removing $line[0] $line[1] from $ARGV[1]...\n";
      next;
  }
  print OUT "$_\n";
}
close B;
close OUT;
