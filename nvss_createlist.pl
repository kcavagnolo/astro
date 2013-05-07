# can also query NVSS directly:
# http://www.cv.nrao.edu/cgi-bin/NVSSlist.pl?Equinox=3&RA=08+39+14.3&Dec=+28+51+24&SilentRad=1308.883+720
#! /usr/bin/perl -w

$physical = "yes";
$pradius = 70; # in kpc
$sradius = 20; # in arcsec

open(IN,$ARGV[0]);
open(A,">pf_nvss.list");
$hold = "0";
printf A "%-14s %14s %10s %4s %55s\n","#RA","Dec","radius","hold","cluster_obsid";
while(<IN>){
    chomp;
    next if (/\#/);
    @line = split;
    $z = $line[6];
    $label = join "--","cluster",$line[0],$line[1],$z;
    $label =~ s/\_/--/;
    $ra = $line[17];
    $dec = $line[18];
    $ra =~ s/:/ /g;
    $dec =~ s/:/ /g;
    if ($physical eq "yes") {
	open(PROFILE,">nvss.pro");
	print PROFILE "\!quiet=1\n";
	print PROFILE "cosmology,'$z',result,/silent\n";
	print PROFILE "openw,1,'temp.log'\n";
	print PROFILE "printf,1,strcompress(result[4],/remove_all)\n";
	print PROFILE "close,1\n";
	print PROFILE "exit \n";
	close PROFILE;
	system("\$IDL_DIR/bin/idl nvss.pro");
	open(FILE,"temp.log");
	while(<FILE>) {
	    chomp;
	    next if (/^\#/);
	    next if (/^$/);
	    s/^\s+//;  # trim leading whitespace
	    s/\s+$//;  # trim trailing whitespace
	    @line = split;
	    $conv = $line[0];
	}
	close FILE;
	system("rm -f temp.log nvss.pro");
	$nradius = $pradius/$conv;
    } else {
	$nradius = $sradius;
    }
    printf A "%-14s %14s %10.3f %4s %55s\n",$ra,$dec,$nradius,$hold,$label;
}
close A;
