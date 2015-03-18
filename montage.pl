#! /usr/bin/perl -w

open(A,$ARGV[0]);
$oldname = "asdbsada";
while(<A>){
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    @line = split;
    $name = $line[0];
    next if ($name eq $oldname);
    $tname = $name;
    $tname =~ s/\_/-/;
    $obsid = $line[1];
    push @a, "-label $tname /mnt/DROBO/accept/images/${obsid}_smooth.png";
#    push @a, "/mnt/DROBO/accept/images/${obsid}_smooth.png";
    $oldname = $name;
}
close A;
system("rm -f montage.jpg");
$a = join " ", @a;
$a .= " -border 1";
#$a .= " -tile 5x5";
$a .= " -mode Concatenate";
$a .= " montage.jpg";
system("montage $a");
exit 0;
