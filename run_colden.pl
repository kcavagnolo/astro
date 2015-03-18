#!/usr/bin/perl -w
#
# NAME:
#     run_colden.pl
#
# PURPOSE:
#     Retrieve N_H values for selected targets
#
# EXPLANATION:
#     This script takes-in a list of object R.A. and Dec.
#     and returns N_H values in the file colden.dat.
#
# CALLING SEQUENCE:
#     run_colden.pl <download.list>
#
# INPUTS:
#     1) a list of downloaded targets created by parsing the Chaser table file
#     with the following format-
#     #Name        ObsID   Instr  ExpTime  RA           Dec
#     ABELL_1221    1111  ACIS-S  92.100   14 11 20.53  +52 12 09.69
#
# OUTPUTS:
#     Formatted data file: colden.dat
#
# MODIFICATION HISTORY:
#     None
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$outfile = "colden.dat";

#######################
#######################
##   Main Program    ##
#######################
#######################

# write the file header
sub_print_info();

# get name, obsid, ra, and dec from the download file
%refdata = sub_get_data($ARGV[0]);

# get NH for each cluster
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # define vars
  $name = $data[0];
  $obsid = $data[1];
  $instr = $data[2];

  # get the three coords for R.A.
  $ra1 = $data[4];
  $ra2 = $data[5];
  $ra3 = $data[6];
  $ra = join " ", $ra1, $ra2, $ra3;
#$ra = $data[17];
#$ra =~ s/:/ /g;

  # get the three coords for Dec.
  $dec1 = $data[7];
  $dec2 = $data[8];
  $dec3 = $data[9];
  $dec = join " ", $dec1, $dec2, $dec3;
#$dec = $data[18];
#$dec =~ s/:/ /g;

  # run the RA and Dec through colden
  print "## ${obsid}: Using RA:$ra DEC:$dec\n";
  $nh = sub_colden($ra,$dec);
  print "## Calculated $nh for $obsid\n";

  # write the data to the ref file
  sub_write_data($name,$obsid,$instr,$nh);
}

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_print_info {

  open(OUT,">${outfile}");
  printf OUT "%-25s %8s %6s %15s\n",
    "#Name","ObsID","Instr","NH(10^20 cm^2)";
  close OUT;
}

#######################
#######################

sub sub_get_data {

  my($infile) = @_;
  my($data,$name,%info);

  open(INFILE,$infile) || die "## Can't open $infile\n";
  while(<INFILE>) {
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

sub sub_colden {

  my($ra,$dec) = @_;
  my(@data,$value);

  # invoke prop_colden
  open(COLDEN, "prop_colden data nrao eval $ra $dec |");
  while (<COLDEN>) {
    chomp;
    @data = split;
    $value = $data[8];
  }
  close(COLDEN);
  return $value;
}

#######################
#######################

sub sub_write_data {

  my($name,$obsid,$instr,$nh) = @_;

  # print the info to a file
  open(OUT,">>${outfile}");
  printf OUT "%-25s %8s %6s %15.2f\n",
    $name,$obsid,$instr,$nh;
  close OUT;
}

#######################
#######################
