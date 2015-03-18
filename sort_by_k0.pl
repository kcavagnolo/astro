#! /usr/bin/perl -w

system("rm -f all_results.log");
system("ls -1 ~/research/pf_clusters/pf_fits/s_results/*_results.log > junk");
open(A,"junk");
open(B,">temp");
while(<A>){
    chomp;
    @a = split;
    $file = $a[0];
    open(C,$file);
    while(<C>){
        chomp;
        next if (/\#/);
        next if (/^$/);
        print B "$_\n";
    }
    close C;
}
close A;
close B;
system("perl sorter.pl temp all_results.log");
system("rm -f junk temp");

open(A,"all_results.log");
$i = 0;
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @line = split;
    $i = 0 if ($i == 4);
    $ref{$line[0]} = $line[6] if ($i == 2);
    $i++;
}
close A;

open(B,">sorted_k0.list");
open(C,">sorted_k0_dub.list");
foreach $key (sort{$ref{$a} <=> $ref{$b}} keys %ref) {
    open(REF,"/home/cavagnolo/research/pf_clusters/pf_fits/done.list");
    while(<REF>){
	chomp;
	next if (/^\#/);
	next if (/^$/);
	@line = split;
	print B "$_\n" if ($line[0] eq $key);
    }
    close REF;
    open(REF,"/home/cavagnolo/research/redux/redux_info/pf_dub.list");
    while(<REF>){
	chomp;
	next if (/^\#/);
	next if (/^$/);
	@line = split;
	print C "$_\n" if ($line[0] eq $key);
    }
    close REF;
}
close B;
close C;
unlink<"all_results.log">;
exit 0;
