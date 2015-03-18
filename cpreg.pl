#! /usr/bin/perl -w

use Cwd;
use FindBin qw($Bin);

open(A,"newobs");
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @line=split;
    system("cp /mnt/SINISTER/4954/reprocessed/4954_exclude.reg /mnt/SINISTER/$line[1]/reprocessed/$line[1]_exclude.reg");
}
close A;
exit 0;
