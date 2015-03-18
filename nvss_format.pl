#! /usr/bin/perl -w

open(A,">formatted_radio.dat");
printf A "%-20s %8s %14s %14s %8s %6s %6s %6s %10s %10s %8s %8s %6s %6s\n",
    "#Cluster","Obsid","RA","Dec","Sep","Maj","Min","Theta","Flux","Flerr","Found","z","type","notes";
printf A "%-20s %8s %14s %14s %8s %6s %6s %6s %10s %10s %8s %8s %6s %6s\n",
    "# ---","---","hh:mm:ss.ss","hh:mm:ss.s","\"","\"","\"","deg.","mJy","mJy","---","---","---","---";
while(<>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    if (/WARNING/) {
	$ra = "00:00:00.00";
	$dec = "00:00:00.0";
	$maj = 0.0;
	$min = 0.0;
	$ang = 0.0;
	$sep = 0.0;
	$flux = -444;
	$ferr = -555;
	$fnd  = "OA";
	printinfo();
	$name = "warn";
	next;
    }
    if (/SOURCE/ && $name ne "warn") {
      $ra = "00:00:00.00";
      $dec = "00:00:00.0";
      $maj = 0.0;
      $min = 0.0;
      $ang = 0.0;
      $sep = 0.0;
      $flux = 2.50;
      $ferr = 0.25;
      $fnd  = "NF";
      printinfo();
      next;
    }
    if (/cluster/) {
      @line = split;
      $line[0] =~ s/://;
      $line[0] =~ s/dag//g;
      $line[0] =~ s/cluster--//;
      $line[0] =~ s/--/_/g;
      @temp = split "_", $line[0];
      $z = pop(@temp);
      $obsid = pop(@temp);
      $name = join "_",@temp;
      next;
    }
    if (/^\s/) {
      @line = split;
      $ferr = $line[3];
      $fnd  = "F";
      printinfo();
      next;
    }
    if (/\d/) {
      ($ra1,$ra2,$ra3,$dec1,$dec2,$dec3,$sep,$flux,$maj,$min,$ang) =
	unpack("A2 A3 A6 A4 A3 A5 A6 A7 A6 A6 A6 A64",$_);
      push @junk, $junk;
      $ra1 =~ s/\s+//;
      $ra2 =~ s/\s+//;
      $ra3 =~ s/\s+//;
      $dec1 =~ s/\s+//;
      $dec2 =~ s/\s+//;
      $dec3 =~ s/\s+//;
      $maj =~ s/<//;
      $maj =~ s/\s+//;
      $min =~ s/<//;
      $min =~ s/\s+//;
      $flux =~ s/\s+//;
      $sep =~ s/\s+//;
      $ang =~ s/\s+//;
      $ang = 0.00 if ($ang eq "");
      $ra = join ":",$ra1,$ra2,$ra3;
      $dec = join ":",$dec1,$dec2,$dec3;
      next;
    }
}
close A;

sub printinfo {
    printf A "%-20s %8s %14s %14s %8.3f %6.1f %6.1f %6.1f %10.2f %10.2f %8s %8.4f %6s %6s\n",
    $name,$obsid,$ra,$dec,$sep,$maj,$min,$ang,$flux,$ferr,$fnd,$z,"na","na";
}
