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
open(LOG,">out_colden.dat");

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
  print "## Using aspect solution: $asol\n";

  # get the ra and dec for the centroid
  sub_get_radec($evt,$asol);
  if ($fail eq "yes") {
      print "## No RA or Dec for $obsid\n";
      chdir("$Bin");
      next;
  }
  $ra =~ s/:/ /g;
  $dec =~ s/:/ /g;

  # run the RA and Dec through colden
  $nh = sub_colden($ra,$dec);
  printf LOG "%-20s %10s %15s %15s %10.2f\n",$name,$obsid,$ra,$dec,$nh;

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

    die "No asol files found.  Exiting.\n" unless (@infile);
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
    $command = "punlearn dmcoords; dmcoords $evt $asol x=$x y=$y opt=sky";
    system($command);

    # get output ra and dec
    $ra = `pget dmcoords ra`;
    $dec = `pget dmcoords dec`;
    $ra =~ s/^\s+//;
    $ra =~ s/\s+$//;
    $dec =~ s/^\s+//;
    $dec =~ s/\s+$//;

    if ($ra ne "" && $dec ne "") {
	return;
    } else {
	$fail = "yes";
    }
}

#######################
#######################
