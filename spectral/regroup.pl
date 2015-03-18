#! /usr/bin/perl -w

$dir = "/Volumes/GALACTUS/";
$reg = "inner50";
$grpcts = 25;
open(A,"$ARGV[0]");
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @line=split;
    $name = $line[0];
    $obs = $line[1];
    $rdir = "$dir/$obs/reprocessed/";
    $srcspec = "$rdir/${name}_${obs}_${reg}_src1.pi";
    $srcgrp  = "$rdir/${name}_${obs}_${reg}_src1_grp.pi";
    $command = "grppha infile=\"${srcspec}\" outfile=\"\!${srcgrp}\" chatter=0 comm=\"group min $grpcts & exit\"";
    system($command);
}
close A;
exit 0;
