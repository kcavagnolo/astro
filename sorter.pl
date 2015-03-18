#! /usr/bin/perl -w

open(A,"$ARGV[0]");
$i=0;
while (<A>) {
    chomp;
    next if (/^$/);  # skip blank lines
    s/^\s+//;        # trim leading whitespace
    s/\s+$//;        # trim trailing whitespace
    push @hdr,"$_" if (/^\#/);
    next if (/^\#/);
    @data = split;
#    $name = join "_", $data[0],$data[1],$i;
#    $name = join "_", $data[0],$data[1];
    $name = join "_", $data[0];
    $info{$name} = $_;
    $i++;
}
close A;
open(B,">$ARGV[1]");
foreach $line (@hdr) {
    print B "$line\n";
}
foreach $key (sort keys %info) {
    print B "$info{$key}\n";
}
close B;
