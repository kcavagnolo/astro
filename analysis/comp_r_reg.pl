#! /usr/bin/perl -w

open(OUT,">log");
while(<>){
  chomp;
  @line=split;
  $tx = $line[8];
  $z = $line[6];
  $file = "../acis/$line[1]/reprocessed/$line[1]_r2500-50.reg";
  if (-e $file) {
    open(TEMP,$file);
    while(<TEMP>) {
      chomp;
      $tline = $_;
      next if (/^\#/); # skip comment lines
      next if (/^$/);  # skip blank lines
      if (/^annulus/) {
	@r25 = (split/\,/,$tline);
	$r25used = $r25[3];
	$r25used =~ s/\)//;
	last;
      }
    }
    close TEMP;
    open(PROFILE,">rdel.pro");
    print PROFILE "!quiet=1\n";
    print PROFILE "a = (rdelta(5000,'$z','$tx',/silent))*1000.\n";
    print PROFILE "cosmology,'$z',result,/silent\n";
    print PROFILE "r2500 = a/result[4]/0.492\n";
    print PROFILE "openw,1,'temp.log'\n";
    print PROFILE "printf,1,num2str(r2500,3)\n";
    print PROFILE "close,1\n";
    print PROFILE "exit \n";
    close PROFILE;
    system("\$IDL_DIR/bin/idl rdel.pro");
    open(FILE,"temp.log");
    while(<FILE>) {
      chomp;
      next if (/^\#/);
      next if (/^$/);
      s/^\s+//;  # trim leading whitespace
      s/\s+$//;  # trim trailing whitespace
      @a = split;
      $r25real = $a[0];
    }
    close FILE;
    $r25used = $line[4];
    if ($r25real > $r25used) {
      print OUT "Dummy! $line[0], $line[1], r25used: $r25used; r25real: $r25real\n";
    }
  } else {
    print OUT "No $file\n";
  }
}
