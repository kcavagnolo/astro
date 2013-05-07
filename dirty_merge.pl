#! /usr/bin/perl -w

$use_redux = "no";
$evtext = "evt2";
$chips = "0,1,2,3,4,5,6,7";
#$chips = "6";
$doall = "no";
$view = "no";
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "## Wrong number of command line arguments\n" if (@ARGV != 1);
use Cwd;
use FindBin qw($Bin);

$prevname = "fsdfsd";
$new = "yes";
$i = 0;
open(A,$ARGV[0]);
chdir("/tmp/");
open(B,">list");
while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @line = split;
    if ($doall ne "yes") {
	if (($line[0] ne $prevname) && ($new ne "yes")) {
	    close B;
	    $out = "$Bin/${prevname}_dmerged.fits";
	    $command = "punlearn merge_all ; merge_all evtfile=\"\@list\" asol=\"\" "
		."dtffile=\"\" chip=\"${chips}\" xygrid=\"\" energy=\"\" "
		."expmap=\"\" expcorr=\"\" refcoord=temp1.fits merged=$out clob+";
	    print "$command\n";
	    system($command);
	    system("rm -f list temp*.fits");
	    system("ds9 $out -scale sqrt -cmap b") if ($view eq "yes");
	    open(B,">list");
	    $i = 0;
	}
    }
    $dir = $line[15];
    if ($use_redux eq "yes") {
	@evt = glob("${dir}/$line[1]/reprocessed/*${evtext}*");
    } else {
	@evt = glob("${dir}/$line[1]/primary/*evt2*");
    }
    unless (@evt) {
	print "## ERROR: Missing evt2 for $line[1]\n";
	$i++;
	$prevname = $line[0];
	$new = "no";
	next;
    }
    $a = $evt[0];
    print "## Pruning $a to temp${i}.fits\n";
    $command = "punlearn dmcopy; dmcopy \"$a\[cols -pha_ro\]\" temp${i}.fits clob+";
    system($command);
    print B "temp${i}.fits\n";
    $i++;
    $prevname = $line[0];
    $new = "no";
}
close A;
close B;
$out = "$Bin/${prevname}_dmerged.fits";
$command = "punlearn merge_all ; merge_all evtfile=\"\@list\" asol=\"\" "
    ."dtffile=\"\" chip=\"0,1,2,3,4,5,6,7\" xygrid=\"\" energy=\"\" "
    ."expmap=\"\" expcorr=\"\" refcoord=temp1.fits merged=$out clob+";
print "$command\n";
system($command);
system("rm -f list temp*.fits");
system("ds9 $out -scale sqrt -cmap b") if ($view eq "yes");
chdir("$Bin");
exit 0;
