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

# SDSS options:
# G-Grid
# L-Label
# P-PhotoObjs
# S-SpecObjs
# T-TargetObjs
# O-Outline
# B-BoundingBox
# F-Fields
# M-Masks
# Q-Plates
# I-InvertImage

$onlynew  = "yes";
$sdssopts = "GLS";
$getsdss  = "yes";                                  # should SDSS be queried
$getskyv  = "yes" ;                                  # should SkyView be queried, useful if no SDSS image found
$rootdir  = "reprocessed";                          # directory to store images
$scale    = "0.3961";                               # pixel scale of output SDSS image
$width    = "512";                                  # width of output SDSS image
$height   = "512";                                  # height of output SDSS image
@surveys  = ("digitized+sky+survey");               # the query to SkyView
%surveynames = ("digitized+sky+survey" => "DSS");   # Name associated with each SkyView query
$size     = "0.1";                                  # size of field on sky to query SkyView

#######################
#######################
##   Main Program    ##
#######################
#######################

# Check the number of arguments given
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# check for ciao env loaded
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});

# Load useful libraries
# Store the script directory in $Bin
use LWP::Simple;
use Cwd;
use FindBin qw($Bin);

# Read in the reference file
%refdata = sub_read_file($ARGV[0]);
$count = scalar (keys %refdata);

# loop through each cluster
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});
  print "## STATUS: $count left to download.\n";

  # get values specific to each cluster
  $fail    = "no";
  $obsid   = $data[1];
  $x       = $data[2];
  $y       = $data[3];
  $datadir = $data[15];

  # change directory
  chdir("$datadir/$obsid/$rootdir/");

  # define file names
  $evt  = "${obsid}_evt2.fits";
  $asol = sub_get_asol();

  # get the ra and dec for the centroid
  ($ra,$dec) = sub_get_radec($evt,$asol);
  if ($fail eq "yes") {
    print "## ERROR: No RA or Dec for $obsid\n";
    $count--;
    chdir("$Bin");
    next;
  }

  # query sdss
  if ($getsdss eq "yes") {
    sub_sdss($ra,$dec,$scale,$width,$height);
    if ($fail eq "yes") {
      print "## ERROR: No SDSS image for $obsid\n";
      $count--;
      chdir("$Bin");
      next;
    }
  }

  # query ad hoc surveys
  if ($getskyv eq "yes") {
    foreach $survey (@surveys) {
      $fail = "no";
      $fsurvey = $surveynames{$survey};
      sub_query($survey,$fsurvey,$ra,$dec,$size,$width,$height);
      if ($fail eq "yes") {
	print "## ERROR: No $survey image for $obsid\n";
	next;
      }
    }
  }

  # count down and go home
  $count--;
  chdir($Bin);
}
print "## STATUS: done.\n";
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "## ERROR: Can't open $infile\n";
  while (<INFILE>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    s/^\s+//;        # trim leading whitespace
    s/\s+$//;        # trim trailing whitespace
    @data = split;
    $name = join "_", $data[0],$data[1];
    $info{$name} = $_;
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
  return $asol;
}

#######################
#######################

sub sub_get_radec {

  my($evt,$asol) = @_;

  # run dmcoords
  my $command = "punlearn dmcoords; dmcoords $evt $asol x=$x y=$y opt=sky celfmt=deg";
  system($command);

  # get output ra and dec
  my $ra = `pget dmcoords ra`;
  my $dec = `pget dmcoords dec`;
  $ra =~ s/^\s+//;
  $ra =~ s/\s+$//;
  $dec =~ s/^\s+//;
  $dec =~ s/\s+$//;

  if ($ra ne "" && $dec ne "") {
    return($ra,$dec);
  } else {
    $fail = "yes";
  }
}

#######################
#######################

sub sub_sdss {

  my($ra,$dec,$scale,$width,$height) = @_;

  # define file names
  my $img = "${obsid}_sdss.png";
  my $reg = "${obsid}_sdss.reg";
  if ($onlynew eq "yes") {
      if (-e $img && -e $reg) {
	  print "## WARNING: $obsid SDSS image and region already exist, skipping...\n";
	  return;
      }
  }

  # query sdss
  my $url = "http://casjobs.sdss.org/ImgCutoutDR6/getjpeg.aspx?ra=${ra}&dec=${dec}&scale=${scale}&opt=&width=${width}&height=${height}&opt=${sdssopts}\n";
  my $temp = "/tmp/sdss.jpeg";
  my $content = getstore($url,$temp);
  unless (defined $content) {
    $fail = "yes";
    return;
  }
  print "## ${obsid}: Downloaded the SDSS image\n";

  # convert to png
  print "## ${obsid}: Converting to png\n";
  system("convert $temp $img");
  unlink("$temp");

  # make a region for image
  my $sidea = $scale*$width;
  my $sideb = $scale*$height;
  open(REG,">$reg");
  print REG "# Region file format: DS9 version 4.0\n";
  print REG "fk5\n";
  print REG "box(${ra},${dec},${sidea}\",${sideb}\",0) \# color=white width=2 font=\"helvetica 12 normal\" text={SDSS}\n";
  close REG;
}

#######################
#######################

sub sub_query {

  my($survey,$fsurvey,$ra,$dec,$size,$width,$height) = @_;

  # define file names
  my $img = "${obsid}_${fsurvey}.png";
  my $reg = "${obsid}_${fsurvey}.reg";
  if (-e $img && -e $reg) {
      print "## WARNING: $obsid $fsurvey image and region already exist, skipping...\n";
      return;
  }

  # query sdss
  my $url = "http://skyview.gsfc.nasa.gov/cgi-bin/images?Survey=${survey}&position=${ra},${dec}&Size=${size}&Pixels=${width},${height}&Return=PNG\n";
  my $content = getstore($url,$img);

  # check output image size
  chomp(my $ident = `identify -format "%w %h" "$img"`);
  my($cw, $ch) = split ' ', $ident;
  unless (defined $content && $cw == $width) {
    print "## ERROR: no image downloaded\n";
    unlink($img,$reg);
    $fail = "yes";
    return;
  }
  print "## ${obsid}: Downloaded the $fsurvey image\n";

  # make a region for image
  my $sidea = $size*3600.0;
  my $sideb = $size*3600.0;
  open(REG,">$reg");
  print REG "# Region file format: DS9 version 4.0\n";
  print REG "fk5\n";
  print REG "box(${ra},${dec},${sidea}\",${sideb}\",0) \# color=white width=2 font=\"helvetica 12 normal\" text={$fsurvey}\n";
  close REG;
}

#######################
#######################
