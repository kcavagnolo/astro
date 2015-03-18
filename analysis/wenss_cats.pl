#! /usr/bin/perl -w

$dout = "wenss_cats.dat";
open(A,"$ARGV[0]");
open(OUT,">$dout");
printf OUT "%-20s %8s %14s %14s %8s %6s %6s %6s %10s %10s %8s %8s %6s %6s\n",
    "#Cluster","Obsid","RA","Dec","Sep","Maj","Min","Theta","Flux","Flerr","Found","z","type","notes";
printf OUT "%-20s %8s %14s %14s %8s %6s %6s %6s %10s %10s %8s %8s %6s %6s\n",
    "# ---","---","hh:mm:ss.ss","hh:mm:ss.s","\"","\"","\"","deg.","mJy","mJy","---","---","---","---";
$new = "no";
while(<A>){
    chomp;
    next if (/^$/);
    $line = $_;
    if ($new eq "yes") {
	@line = split(/cluster--/,$line);
	$line[1] =~ s/--/_/g;
	@temp = split "_", $line[1];
	$z = pop(@temp);
	$obsid = pop(@temp);
	$name = join "_",@temp;
	print "$name\n";
	chdir("/Volumes/TRANSCEND/$name");
	open(B,">wenss.reg");
	close B;
	open(B,">cats.reg");
	close B;
	$new = "no";
    }
    if (/^WN/) {
	open(B,">>wenss.reg");
	@data=split;
	$ra = join ":",$data[7],$data[8],$data[9];
	$dec = join ":",$data[10],$data[11],$data[12];
	$a = $data[16]/60.;
	$b = $data[17]/60.;
	$pa = $data[18]+90.0;
	$flux = $data[15];
	$ferr = 0.1*$flux;
	$fnd = "F";
	$a = 1.0 if ($a <= 0.0);
	$b = 1.0 if ($b <= 0.0);
	print B "ellipse($ra,$dec,$a\',$b\',$pa)\n";
	close B;
	printf OUT "%-20s %8s %14s %14s %8.3f %6.1f %6.1f %6.1f %10.2f %10.2f %8s %8.4f %6s %6s\n",
	$name,$obsid,$ra,$dec,0.0,$a,$b,$pa,$flux,$ferr,$fnd,$z,"325","WENSS";
    }
    if (/^CATS/) {
	open(B,">>cats.reg");
	@data=split;
	$ra = join ":",$data[3],$data[4],$data[5];
	$dec = join ":",$data[7],$data[8],$data[9];
	$surv = $data[1];
	$flux = $data[12]*1000.0;
	$ferr = $data[13]*1000.0;
	$fnd = "F";
	$freq = $data[11];
	print B "circle($ra,$dec,0.25\')\n";
	close B;
	if (($freq >= 250) && ($freq <= 500)) {
	    printf OUT "%-20s %8s %14s %14s %8.3f %6.1f %6.1f %6.1f %10.2f %10.2f %8s %8.4f %6s %6s\n",
	    $name,$obsid,$ra,$dec,0.0,0.25,0.25,0.0,$flux,$ferr,$fnd,$z,$freq,$surv;
	}
    }
    $new = "yes" if (/new/);
}
close A;
close OUT;
exit 0;
