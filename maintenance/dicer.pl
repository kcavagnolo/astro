#! /usr/bin/perl -w
# dicer.pl <file> <pieces> <output root>

use POSIX qw(ceil floor);

if (@ARGV != 3) {
    print "## ERROR: Wrong number of command line arguments\n";
    print "## Usage: dicer.pl <file> <pieces> <output root>\n";
    die;
}

open(A,$ARGV[0]);
$counter = 1;
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    $counter++;
}
close A;

$div = $ARGV[1];
$pieces = $counter/$div;

open(A,$ARGV[0]);
$i = 1;
$j = 1;
open(B,">$ARGV[2]${i}.list");
while(<A>) {
  chomp;
  next if (/^\#/);
  next if (/^$/);
  if ($j > $pieces) {
    $j = 1;
    $i++;
    close B;
    open(B,">$ARGV[2]${i}.list");
  }
  print B "$_\n";
  $j++;
}
close A;
close B;
exit 0;
