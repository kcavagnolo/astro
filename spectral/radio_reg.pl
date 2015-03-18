#! /usr/bin/perl -w

#######################
#######################

$datadir = "/mnt/DROBO/";  # location of data in relation to location of this script
$rootdir = "reprocessed";         # name of directory where new files will be placed

#######################
#######################

# load useful libraries
# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# Read in the reference file
%refdata = sub_read_file($ARGV[0]);

# Go through each cluster
{
  foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get values
    $fail = "no";
    $obsid = $data[1];
    $ra    = $data[2];
    $dec   = $data[3];
    $sep   = $data[4];
    $maj   = sprintf("%.1f",$data[5]/0.492);
    $min   = sprintf("%.1f",$data[6]/0.492);
    $ang   = sprintf("%.1f",$data[7]+90);
    $check = $data[9];

    if ($check eq "OA") {
      print "## $obsid < -40 dec., not in NVSS.\n";
      next;
    } elsif ($check eq "NF") {
      print "## $obsid < flux lim., moving on.\n";
      next;
    }

    # change directory
    chdir("$datadir/$obsid/$rootdir");

    # define file names
    $evt  = "${obsid}_evt2.fits";
    $asol = sub_get_asol();
    if ($fail eq "yes") {
      print "## No asol file for $obsid\n";
      chdir("$Bin");
      next;
    }
    $reg  = "${obsid}_nvss.reg";

    # make sure we have events files to work with
    unless (-e $evt) {
      print "## No event file for $obsid\n";
      chdir("$Bin");
      next;
    }

    # get ra and dec in phys coords
    sub_get_radec($evt,$asol,$ra,$dec);
    if ($fail eq "yes") {
      print "## No RA or Dec for $obsid\n";
      chdir("$Bin");
      next;
    }
    print "## found $x and $y for $obsid\n";

    # make region file for radio sources
    sub_make_reg($reg);
    if ($fail eq "yes") {
      print "## No region file made for $obsid\n";
      chdir("$Bin");
      next;
    }

    # change back to original directory
    chdir("$Bin");
  }
}

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## Can't open $infile\n";
  $i = 0;
  while (<INFILE>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    s/^\s+//;        # trim leading whitespace
    s/\s+$//;        # trim trailing whitespace
    @data = split;
    $name = join "_", $data[0],$data[1],$i;
    $info{$name} = $_;
    $i++;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub sub_get_asol {

  # get the asol file for files
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

  unless (@infile) {
    $fail = "yes";
    return;
  }

  $asol = join(",",@infile);

  # return the name(s)
  chdir($curdir);
}

#######################
#######################

sub sub_get_radec {

  my($evt,$asol,$ra,$dec) = @_;

  # run dmcoords
  $command = "punlearn dmcoords; dmcoords $evt $asol ra=$ra dec=$dec opt=cel";
  system($command);

  # get output ra and dec
  chomp($x = `pget dmcoords x`);
  chomp($y = `pget dmcoords y`);
  $x =~ s/^\s+//;
  $y =~ s/\s+$//;
  $x =~ s/^\s+//;
  $y =~ s/\s+$//;
  $x = sprintf("%4i",$x);
  $y = sprintf("%4i",$y);

  if ($x ne "" && $y ne "") {
    return;
  } else {
    $fail = "yes";
  }
}

#######################
#######################

sub sub_make_reg {

  my($reg) = @_;

  if (-e $reg) {
    open(REG,">>$reg");
  } else {
    open(REG,">$reg");
  }
  print REG "# Region file format: CIAO version 1.0\n";
  print REG "ellipse(${x},${y},${maj},${min},${ang})\n";
  close REG;

  if (-e $reg) {
    return;
  } else {
    $fail = "yes";
  }
}

#######################
#######################
