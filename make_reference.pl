#!/usr/bin/perl -w
#
# NAME:
#     make_reference.pl
#
# PURPOSE:
#     Construct the master reference list for
#     selected targets.
#
# EXPLANATION:
#     This script takes-in a list of objects to be downloaded,
#     their obsids, chips, and nH values, then spits out
#     a formatted ref list with dummy x, y, rmax, mincts,
#     redshift, tx, fe, lbol, and eobs.
#
# CALLING SEQUENCE:
#     make_reference.pl
#
# INPUTS:
#     None taken from command line
#     Assumed to be present are two files:
#     1) a list of downloaded targets created by parsing the Chaser table file
#     with the following format-
#     #Name        ObsID    Chip
#     ABELL_1221    1111  ACIS-S
#
#     2) a list of column densities from using the colden tool and parsing the output
#     to add cluster name and obsid-
#     #Name        ObsID    nH
#     ABELL_1221    1111  2.22
#
# OUTPUTS:
#     New, formatted reference list:  set by var $newref below
#
# MODIFICATION HISTORY:
#     None
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$newref = "unused_ref.list";
$col = "colden.dat";

#######################
#######################
##   Main Program    ##
#######################
#######################

# write the file header
sub_print_info();

# get nh from the nh file
open(NH,"$col");
while(<NH>) {
  chomp;
  next if (/^\#/);
  next if (/^$/);
  s/^\s+//;
  s/\s+$//;
  @data = split;
  push (@name, $data[0]);
  push (@obsid, $data[1]);
  $data[2] =~ s/^ACIS\-S/s/;
  $data[2] =~ s/^ACIS\-I/i/;
  push (@id, $data[2]);
  push (@nh, $data[3]);
}
close NH;

# define the blank vars
$x = -111;
$y = -222;
$rmax = -33;
$cts = -444;
$z = -0.555;
$tx = -6.66;
$fe = -0.77;
$lbol = -88.88;
$eobs = -9.999;
$diff = "y";
$robs = 000;
$loc  = "GALACTUS";

# write the data to the ref file
sub_write_ref();

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_print_info {

  open(NEWREF,">${newref}");
  printf NEWREF "%-25s %6s %6s %6s %6s %7s %8s %6s %6s %6s %6s %5s %8s %5s %6s %10s\n",
    "#Name","ObsID","X","Y","Rmax","MinCts","z","Nh20","Tx","Fe","Lbol","Chip","E_obs","Diff","Robs","Location";
  close NEWREF;
}

#######################
#######################

sub sub_write_ref {

  open(NEWREF,">>${newref}");
  $i = 0;
  foreach (@name) {
    printf NEWREF "%-25s %6s %6.0f %6.0f %6.0f %7.0f %8.4f %6.2f %6.2f %6.2f %6.2f %5s %8.4f %5s %6i %10s\n",
      $name[$i],$obsid[$i],$x,$y,$rmax,$cts,$z,$nh[$i],$tx,$fe,$lbol,$id[$i],$eobs,$diff,$robs,$loc;
    $i++;
  }
  close NEWREF;
}

#######################
#######################
