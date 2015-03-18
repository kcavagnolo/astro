#! /usr/bin/perl -w

use Cwd;
use FindBin qw($Bin);

$addr ='http://bax.ast.obs-mip.fr/servlets/omp.servlet.ClusterQueryByName?nextSequence=result&clustername=';
$outdir = "$ENV{'HOME'}/research/redux/redux_info/";

open(A,"$ARGV[0]");
open(ERR,">$Bin/bax_err.log");
open(TX,">$Bin/tx.dat");
chdir("$outdir");
mkdir("bax",0777) unless (-d "bax");
chdir("bax");
$oldname = 'dsdasd';
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @line=split;
    $oname = $line[0];
    next if ($oname eq $oldname);
    $name = $oname;
    $name =~ s/\_000/ /g;
    $name =~ s/\_00/ /g;
    $name =~ s/\_0/ /g;
    $name =~ s/\_/\+/g;
    $name =~ s/ /\+/g;
    $name .= '#';
    $baxfile = "${oname}_bax.dat";
    @args = ("wget","-nv","\'${addr}$name\'","-Otemp.dat");
    $command = join(" ",@args);
    system($command);
    open(B,"temp.dat");
    $getdat = "n";
    $good = "y";
    undef(@data);
    while(<B>){
        chomp;
        if (/does not exist/) {
	    printf ERR "%-30s %20s\n", $oname,"No data in BAX";
	    printf TX "%-30s %10.2f %10.2f %10.2f %30s\n",$oname,-99.0,-99.0,-99.0,"NA";
	    $good = "n";
            last;
        }
        if (/\<\/table\>/) {
            $getdat = "n";
            last;
        }
        if (/External/) {
            $getdat = "y";
            next;
        }
        if ($getdat eq "y") {
            push @data, $_;
        }
    }
    if ($good ne "n") {
	open(OUT,">$baxfile");
	print OUT "# NB: Fx is in units of 10**-12 erg/s/cm**2 in the 0.1-2.4 keV band\n";
	print OUT "# NB: Lx is in units of 10**44 erg/s in the 0.1-2.4 keV band\n";
	print OUT "# NB: Tx is in units of keV\n";
	$a = join("",@data);
	$a =~ s/<a.*?>//g;
	$a =~ s/<\/a>//g;
	$a =~ s/<input.*?>//g;
	$a =~ s/<font.*?>//g;
	$a =~ s/<sub>\(/,/g;
	$a =~ s/\)<\/sub>//g;
	$a =~ s/<\/font>//g;
	$a =~ s/ width.*?>/>/g;
	$a =~ s/<\/tr>//g;
	$a =~ s/<td>//g;
	$a =~ s/<tr>//g;
	$a =~ s/References:/References/g;
	$a =~ s/<\/td>/\n/g;
	@info = split(/\n/,$a);
	$bname = $info[0];
	$nameref = $info[8];
	printf OUT "%-10s %30s %30s\n","Name",$bname,$nameref;
	$ra = $info[1];
	$raref = $info[9];
	printf OUT "%-10s %30s %30s\n","RA",$ra,$raref;
	$dec = $info[2];
	$decref = $info[10];
	printf OUT "%-10s %30s %30s\n","Dec",$dec,$decref;
	$z = $info[3];
	$zref = $info[11];
	if ($z eq '&nbsp;') {
	    $z = -99.0;
	    $zref = 'NA';
	}
	printf OUT "%-10s %30.4f %30s\n","z",$z,$zref;
	$fx = $info[4];
	$fxref = $info[12];
	if ($fx eq '&nbsp;') {
	    $fx = -99.0;
	    $fxref = 'NA';
	}
	printf OUT "%-10s %30.6f %30s\n","Fx",$fx,$fxref;
	$lx = $info[5];
	$lxref = $info[13];
	if ($lx eq '&nbsp;') {
	    $lx = -99.0;
	    $lxref = 'NA';
	}
	printf OUT "%-10s %30.6f %30s\n","Lx",$lx,$lxref;
	$tx = $info[6];
	$tx =~ s/\-//g;
	$tx =~ s/\+//g;
	$txref = $info[14];
	if ($tx eq '&nbsp;') {
	    $tx = '-99.0,-99.0,-99.0';
	    $txref = 'NA';
	}
	printf OUT "%-10s %30s %30s\n","Tx",$tx,$txref;
	@tx = split(/,/,$tx);
	printf TX "%-30s %10.2f %10.2f %10.2f %30s\n",$oname,$tx[0],$tx[1],$tx[2],$txref;
	close OUT;
    }
    close B;
    system("rm -f temp.dat");
    $oldname = $oname;
}
chdir("$Bin");
close A;
close ERR;
close TX;
exit 0;
