#!/usr/bin/perl -w
#
# NAME:
#
# PURPOSE:
#
# EXPLANATION:
#
# CALLING SEQUENCE:
#
# INPUTS:
#
# OUTPUTS:
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$wwwpath = "/mnt/DROBO/accept/data";
$tcdir   = $ENV{'HOME'}."/research/pf_clusters/pf_fits/tables";
$depmdir = $ENV{'HOME'}."/research/pf_clusters/pf_fits/tables";
$keVdyne = 1.62e-9;

#######################
#######################
##   Main Program    ##
#######################
#######################

# Check the number of arguments given
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# Load useful libraries
# Store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# Read in the reference file
%refdata  = sub_read_file($ARGV[0]);

# make data dir
mkdir($wwwpath,0777) unless (-d $wwwpath);
die "## ERROR: no $wwwpath\n" unless (-d $wwwpath);

# open logfile
open(ERR,">err_www_tables.log") || die "## ERROR: Can't open err log... this is ironic\n";

# loop through each cluster
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # get values specific to each cluster
  $name   = $data[0];
  $obsid  = $data[1];

  # get cooling time data
  undef @a;
  @a = glob("$tcdir/${obsid}_*tcool.dat");
  @a = glob("$tcdir/*_${obsid}_*tcool.dat") unless (@a);
  unless (@a) {
    print "## ERROR: No tcool file for $obsid\n";
    print ERR "$obsid -- no tcool file\n";
    next;
  }
  $infile = $a[0];
  &sub_get_tcool($infile);

  # get density data
  undef @a;
  @a = glob("$depmdir/${obsid}_*table.dat");
  @a = glob("$depmdir/*_${obsid}_*table.dat") unless (@a);
  unless (@a) {
    print "## ERROR: No depm file for $obsid\n";
    print ERR "$obsid -- no depm file\n";
    next;
  }
  $infile = $a[0];
  &sub_get_depm($infile);

  # check array sizes are same
  $asize = scalar @tx;
  $bsize = scalar @kf;
  unless ($asize == $bsize) {
    print "## ERROR: $obsid tcool and depm arrays differ in length: $asize to $bsize\n";
    print ERR "$obsid -- tcool and depm arrays differ in length\n";
    next;
  }

  # print all the results to a file
  $outfile = "$wwwpath/${name}_profiles.dat";
  &sub_printout($outfile);

  # go back to script directory
  chdir("$Bin");
}

# make a master file
$outfile = "$wwwpath/all_profiles.dat";
&sub_merge($outfile);

# close ERR log
close ERR;

exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## ERROR: Can't open $infile\n";
  while (<INFILE>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;
    s/\s+$//;
    @data = split;
    $name = join "_", $data[0],$data[1];
    $info{$name} = $_;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub sub_get_tcool {

  my($in) = @_;

  undef @tx;
  undef @txerr;
  undef @lambda;
  undef @tc52;
  undef @tc52err;
  undef @tc32;
  undef @tc32err;
  open(TC,$in);
  @lines = reverse <TC>;
  close TC;
  foreach $line (@lines) {
    chomp($line);
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    next if ($line =~ /^\#/);
    next if ($line =~ /^$/);
    next if ($line =~ /^\D+/);
    my @tc = split(/\s+/,$line);
    push @tx, $tc[4];
    push @txerr, $tc[5];
    push @lambda, $tc[6];
    push @tc52, $tc[7];
    push @tc52err, $tc[8];
    push @tc32, $tc[9];
    push @tc32err, $tc[10];
  }
}

#######################
#######################

sub sub_get_depm {

  my($in,$out) = @_;

  undef @rin;
  undef @rout;
  undef @nelec;
  undef @neerr;
  undef @ki;
  undef @kf;
  undef @kerr;
  undef @pi;
  undef @pf;
  undef @perr;
  undef @m;
  undef @merr;
  open(DEPM,$in);
  @lines = <DEPM>;
  close DEPM;
  shift @lines;
  foreach $line (@lines) {
    chomp($line);
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    next if ($line =~ /^\D+/);
    next if ($line =~ /^\#/);
    next if ($line =~ /^$/);
    my @a = split(/\s+/,$line);
    push @rin, $a[0];
    push @rout, $a[1];
    push @nelec, $a[2];
    push @neerr, $a[3];
    push @ki, $a[4];
    push @kf, $a[5];
    push @kerr, $a[6];
    push @pi, $a[7];
    push @pf, $a[8];
    push @perr, $a[9];
    push @m, $a[10];
    push @merr, $a[11];
  }
}

#######################
#######################

sub sub_printout {

  my($out) = @_;

  open(OUT,">$out");
  printf OUT "%-25s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s\n",
    "#Name","Rin","Rout","nelec","neerr","Kitpl","Kflat","Kerr","Pitpl","Pflat",
      "Perr","Mgrav","Merr","Tx","Txerr","Lambda","tcool5/2","t52err","tcool3/2","t32err";
  printf OUT "%-25s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s\n",
    "###","Mpc","Mpc","cm^-3","cm^-3","keV cm^2","keV cm^2","keV cm^2",
      "dyne cm^-2","dyne cm^-2","dyne cm^-2","M_solar","M_solar",
 	"keV","keV","ergs-cm^3/s","Gyr","Gyr","Gyr","Gyr";
  $count = scalar @rin;
  for ($j=0; $j < $count; $j++) {
    printf OUT "%-25s %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e %-15.4e\n",
      $name, $rin[$j], $rout[$j], $nelec[$j], $neerr[$j], $ki[$j], $kf[$j], $kerr[$j], $pi[$j]*$keVdyne,
	$pf[$j]*$keVdyne, $perr[$j]*$keVdyne, $m[$j], $merr[$j], $tx[$j], $txerr[$j], $lambda[$j], $tc52[$j],
	  $tc52err[$j], $tc32[$j], $tc32err[$j];
  }
  close OUT;
}

#######################
#######################

sub sub_merge {

  my($out) = @_;

  chdir("$wwwpath");
  system("rm -f $out");
  system("ls -1 *_profiles.dat > junk");
  open(A,"junk");
  open(B,">$out");
  printf B "%-25s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s\n",
    "#Name","Rin","Rout","nelec","neerr","Kitpl","Kflat","Kerr","Pitpl","Pflat",
      "Perr","Mgrav","Merr","Tx","Txerr","Lambda","tcool5/2","t52err","tcool3/2","t32err";
  printf B "%-25s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s\n",
    "###","Mpc","Mpc","cm^-3","cm^-3","keV cm^2","keV cm^2","keV cm^2",
      "dyne cm^-2","dyne cm^-2","dyne cm^-2","M_solar","M_solar",
 	"keV","keV","ergs-cm^3/s","Gyr","Gyr","Gyr","Gyr";
  while(<A>){
    chomp;
    @a = split;
    $file = $a[0];
    open(C,$file);
    while(<C>){
      chomp;
      next if (/^\#/);
      next if (/^$/);
      s/^\s+//;
      s/\s+$//;
      print B "$_\n";
    }
    close C;
  }
  close A;
  close B;
  unlink("junk");
}

#######################
#######################
