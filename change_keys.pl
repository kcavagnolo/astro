#! /usr/bin/perl -w

use Cwd;
use FindBin qw($Bin);

while(<>){
    chomp;
    @line=split;
    chdir("$line[15]/$line[1]/reprocessed/");
    @glob = glob("*_src1.pi");
#    @glob = glob("$line[0]*");
    foreach $file (@glob) {
	$grp = $file;
	$grp =~ s/\_src1.pi/\_src1\_grp.pi/;
	$arf = $file;
	$arf =~ s/\_src1.pi/\_src1.warf/;
	$rmf = $file;
	$rmf =~ s/\_src1.pi/\_src1.wrmf/;
	$bgd = $file;
	$bgd =~ s/\_src1.pi/\_bgd.pi/;

#	$newfile = $file;
#	$newfile =~ s/\_/-/;
#	$newfile =~ s/RXJ/RX\_J/;
#	printf "%-50s %-5s %-50s\n","$file","--->","$newfile";
#	system("mv $file $newfile");

	print "$file and $grp get:\n";
	print "$arf, $rmf, $bgd\n";
 	system("punlearn dmhedit; dmhedit infile=$file operation=del key=ANCRFILE filelist=\"\"");
 	system("punlearn dmhedit; dmhedit infile=$file operation=add key=ANCRFILE value=$arf filelist=\"\"");
 	system("punlearn dmhedit; dmhedit infile=$file operation=del key=RESPFILE filelist=\"\"");
 	system("punlearn dmhedit; dmhedit infile=$file operation=add key=RESPFILE value=$rmf filelist=\"\"");
 	system("punlearn dmhedit; dmhedit infile=$file operation=del key=BACKFILE filelist=\"\"");
 	system("punlearn dmhedit; dmhedit infile=$file operation=add key=BACKFILE value=$bgd filelist=\"\"");
 	system("punlearn dmhedit; dmhedit infile=$grp operation=del key=ANCRFILE filelist=\"\"");
 	system("punlearn dmhedit; dmhedit infile=$grp operation=add key=ANCRFILE value=$arf filelist=\"\"");
 	system("punlearn dmhedit; dmhedit infile=$grp operation=del key=RESPFILE filelist=\"\"");
	system("punlearn dmhedit; dmhedit infile=$grp operation=add key=RESPFILE value=$rmf filelist=\"\"");
 	system("punlearn dmhedit; dmhedit infile=$grp operation=del key=BACKFILE filelist=\"\"");
 	system("punlearn dmhedit; dmhedit infile=$grp operation=add key=BACKFILE value=$bgd filelist=\"\"");
    }
    chdir("$Bin");
}
