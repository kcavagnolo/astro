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

$equinox = "2000";
$deg_rad  = 0.5;
$rootdir  = "reprocessed";

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});

# check the number of arguments given
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# load useful libraries
# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# get name, obsid, ra, and dec from the download file
%refdata = sub_get_data($ARGV[0]);

# open a log file
open(LOG,">out_nh.dat");

# get NH for each cluster
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # define vars
  $fail    = "no";
  $name    = $data[0];
  $obsid   = $data[1];
  $x       = $data[2];
  $y       = $data[2];
  $datadir = $data[15];
  
  # change directory
  chdir("$datadir/$obsid/$rootdir");

  # get the asol file or files
  $evt  = "${obsid}_evt2.fits";
  $asol = get_asolfile();

  # get the ra and dec for the centroid
  sub_get_radec($evt,$asol);
  if ($fail eq "yes") {
      print "## No RA or Dec for $obsid\n";
      chdir("$Bin");
      next;
  }
  $ra =~ s/:/ /g;
  $dec =~ s/:/ /g;

  # run the RA and Dec through nh
  $nh = sub_nh($ra,$dec);
  printf LOG "%-20s %10s %15s %15s %10s\n",$name,$obsid,$ra,$dec,$nh;

}
close LOG;
exit 0;

#######################
#######################
##   Sub-Routines    ##
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

sub sub_nh {

  my($ra,$dec) = @_;
  my(@data,$value);

  # invoke prop_nh
  # output is formatted as:
  # LAB >> Weighted average nH (cm**-2)  1.43E+20
  open(NH, "nh equinox=$equinox ra=$ra dec=$dec disio=$deg_rad tchat=4 |");
  while (<NH>) {
      chomp;
      $line = $_;
      if ($line =~ /Weighted/) {
	  @data = split;
	  $value = $data[6];
	  print "## Found N_HI = $value cm**-2 for $name ($obsid)\n";
      }
  }
  close(NH);
  return $value;
}

#######################
#######################

sub get_asolfile {

    # get the asol file or files
    my($curdir,@infile,$asol,@dir,@globlist);
    $curdir = cwd();

    # change to appropriate dir (they sometimes change the locations)
    @dir = qw(primary secondary);
    @infile = ();
    foreach $dir (@dir) {
        chdir "../$dir";
        @globlist =  <pcad*asol*.fits*>;
        @globlist = map { "../$dir/" . $_} @globlist if (@globlist);
        push @infile, @globlist;
        chdir $curdir;
    }

    die "No asol files found for $obsid.  Exiting.\n" unless (@infile);
    $asol = join(",",@infile);

    # return the name(s)
    chdir($curdir);
    return $asol;
}

#######################
#######################

sub sub_get_radec {

    my($evt,$asol) = @_;

    # run dmcoords
    $command = "punlearn dmcoords; dmcoords $evt $asol x=$x y=$y opt=sky celfmt=deg";
    system($command);

    # get output ra and dec
    $ra = `pget dmcoords ra`;
    $dec = `pget dmcoords dec`;
    $ra =~ s/^\s+//;
    $ra =~ s/\s+$//;
    $ra = sprintf("%.4f",$ra);
    $dec =~ s/^\s+//;
    $dec =~ s/\s+$//;
    $dec = sprintf("%.4f",$dec);

    if ($ra ne "" && $dec ne "") {
	return;
    } else {
	$fail = "yes";
    }
}

#######################
#######################
