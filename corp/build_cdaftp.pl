#! /usr/bin/perl -w
#
# NAME:
#     build_cdaftp.pl
#
# PURPOSE:
#     This script learns the entire structure of the CDA and stores
#     the results in an ASCII file which can then be read by
#     query_cda.pl to automatically download data. This scripts is
#     best run as a weekly cron job since the CDA is updated
#     frequently and then you'll always have an up-to-date CDA tree
#     from which to download.
#
# EXPLANATION:
#     This script assumes nothing.
#
# CALLING SEQUENCE:
#     unix%> perl build_cdaftp.pl <output_file>
#
# FILES ASSUMED TO EXIST:
#     None
#
# INPUTS:
#     None
#
# KEY OUTPUTS:
#     A logfile containing the CDA structure, the name of the output
#     file is specified on the command line
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$ftpadd   = 'ftp://cdaftp.harvard.edu/pub/science/';   # address for the CDA ftp, shouldn't change... but...

#######################
#######################
##   Main Program    ##
#######################
#######################

# open and ouput file
no warnings('once');
use Cwd;
use FindBin qw($Bin);
die "## No output file name given\n" if (@ARGV != 1);
open(OUT,">$ARGV[0]");

# build hash of CDA dir struc
print "## Learning CDAFTP directory structure.\n";
system("wget -nv $ftpadd -O temp");
@dir1 = sub_getdirs("temp");
system("rm -f temp");
foreach $dir1 (@dir1) {
  print "## Descending into CDAFTP tree.\n";
  $fdir1 = $dir1;
  $fdir1 =~ s/\///;
  $newadd = "${ftpadd}${dir1}";
  $log = "temp_$fdir1";
  system("wget -nv $newadd -O $log");
  @dir2 = sub_getdirs($log);
  system("rm -f $log");
  foreach $dir2 (@dir2) {
    print "## Picking ObsIDs from CDAFTP limbs.\n";
    $fdir2 = $dir2;
    $fdir2 =~ s/\///;
    $newadd = "${ftpadd}${dir1}${dir2}";
    $log = "temp_$fdir2";
    system("wget -nv $newadd -O $log");
    @dir3 = sub_getdirs($log);
    system("rm -f $log");
    foreach $obsid (@dir3) {
      $obsid =~ s/\///;
      $value = "${dir1} ${dir2}";
      print OUT "$obsid $value\n";
    }
  }
}
close OUT;
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_getdirs {
  my ($in) = @_;
  my (@dirs);
  undef(@dirs);
  open(A,"$in");
  while(<A>){
    chomp;
    my $line = $_;
    next unless ($line =~ /href\=/);
    $line =~ s/^.*">//g;
    $line =~ s/<\/.*$//g;
    push(@dirs,$line);
  }
  close A;
  return @dirs;
}

#######################
#######################
