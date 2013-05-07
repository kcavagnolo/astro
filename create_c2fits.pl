#! /usr/bin/perl -w
open(A,"$ARGV[0]");
open(B,">$ARGV[1]");
while(<A>){
  chomp;
  @line = split;
  if ($line[1] =~ /\+/) {
    @obs = split /\+/, $line[1];
    foreach $obs (@obs) {
      printf B "%-25s %6s %6s %6s %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f "
	."%5.2f %5.2f %10.2e %10.2e %10.2e %5.2f %5.2f %5.2f %10.2e %10.2e %10.2e "
	  ."%7.4f %6.3f %6s %6.2f %6i\n",$line[0],$obs,$line[2],$line[3],$line[4],$line[5],
	    $line[6],$line[7],$line[8],$line[9],$line[10],$line[11],$line[12],$line[13],$line[14],
	      $line[15],$line[16],$line[17],$line[18],$line[19],$line[20],$line[21],$line[22],$line[23],
		$line[24],$line[25],$line[26];
    }
  } else {
    print B "$_\n";
  }
}
close A;
close B;
