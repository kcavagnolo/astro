#! /usr/bin/perl -w
#
# NAME:
#     ds9_viewreg.pl
#
# PURPOSE:
#     display evt2 file with specified region(s) also loaded
#
# EXPLANATION:
#     This script assumes the following directory structure:
#     all pertinent Chandra data files are in a dir labeled with
#     the obsid, which is then in a dir labeled acis/. The location
#     of acis/ relative to the dir from which this script is run is
#     set with the variable $datadir.
#
#     e.g.: for Abell 644 obsid 2211, this script will look to
#     $datadir/acis/2211/ for all the files needed to complete
#     the data reduction
#
# CALLING SEQUENCE:
#     ds_ptsrc.pl <reference list>
#
# INPUTS:
#     FITS file of some sort:                      <obsid>_ima.fits
#     Region file:                                 <obsid>_lookie.reg
#     <reference list> = file containing information about each cluster
#     the assumed format for the list is as follows:
#     Name                           ObsID        X        Y   Rmax     MinCts         z  Nh20     Tx     Fe  Lbol ChipID
#     ABELL_0644                      2211   3908.5   4332.5  243.9       5000    0.0704  6.41   8.64   0.35 45.00     s3
#     ABELL_1651                      4185   4222.5   4034.5  132.3       5000    0.0844  1.88   5.97   0.30 45.00     i2
#
# OUTPUTS:
#     display
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$delay    = 0.5;
$merged   = "merged";
$rootdir  = "reprocessed";

# input file params
$evtext   = "merged";
$regext   = "";

# basic visual stuff
$loadmode = "";                 # wide, core, tx, multi, smooth: supercedes all following commands
$dopan    = "yes";
$centr    = "no";
$contours = "no";
$smooth   = "";                 # -smooth yes -smooth radius 2";
$scale    = "-scale sqrt";      # -sqrt log | sqrt | linear | pow ...
$mode     = "";                 # -scale mode minmax
$minmax   = "";                 # -minmax mode sample
$bin      = "-bin factor 1";
$cmap     = "-cmap b";
$zoom     = "-zoom 1.0";
$grid     = "$ENV{HOME}/research/redux/scripts/coords.grd";

# window controls
$geom     = "800x800";
$barsize  = "-1";

# get extra images
$extimg   = "no";
$addscale = "log";
$addmode  = "99.5";
$addcmap  = "grey";
@surveys  = ("dssstsci");

# save image
$svimg    = "no";
$exit     = "";
$output   = "_specmaster";
$outdir   = "/mnt/DROBO/accept/spectra";
$imgform  = "png";

#######################
#######################
# set the input mode
if ($loadmode ne "") {
    $outdir  = "/mnt/DROBO/accept/images";
    $imgform = "png";
    $evtext  = "merged";
    $dopan   = "yes";
    $centr   = "no";
    $geom    = "800x800";
    $exit    = "-exit";
    $svimg   = "yes";
    if ($loadmode eq "wide") {
	$smooth = "-smooth yes";
	$scale  = "-scale sqrt";
	$mode   = "-scale mode minmax";
	$minmax = "-minmax mode sample";
	$bin    = "-bin factor 8";
	$cmap   = "-cmap b";
	$zoom   = "-zoom 1.0";
	$output = "_wide";
	$regext = "draw";
	$barsize = -1;
    }
    if ($loadmode eq "core") {
	$smooth = "-smooth yes -smooth radius 2";
	$scale  = "-scale sqrt";
	$mode   = "";
	$minmax = "";
	$bin    = "-bin factor 1";
	$cmap   = "-cmap b";
	$zoom   = "-zoom 1.0";
	$output = "_core";
	$regext = "";
	$barsize = 50;
    }
    if ($loadmode eq "tx") {
	$smooth = "";
	$scale  = "-scale sqrt";
	$mode   = "-scale mode minmax";
	$minmax = "-minmax mode sample";
	$bin    = "-bin factor 3";
	$cmap   = "-cmap b";
	$zoom   = "-zoom 1.0";
	$output = "_tx";
	$regext = "annuli";
	$barsize = -1;
    }
    if ($loadmode eq "multi") {
	$smooth = "-smooth yes -smooth radius 2";
	$scale  = "-scale sqrt";
	$mode   = "-scale mode minmax";
	$minmax = "-minmax mode sample";
	$bin    = "-bin factor 1";
	$cmap   = "-cmap b";
	$zoom   = "-zoom 0.9";
	$output = "_multi";
	$regext = "SDSS";
	$barsize = -1;
    }
    if ($loadmode eq "smooth") {
	$smooth = "";
	$scale  = "-scale sqrt";
	$mode   = "-scale mode minmax";
	$minmax = "-minmax mode sample";
	$bin    = "-bin factor 2";
	$cmap   = "-cmap b";
	$zoom   = "-zoom 1.0";
	$output = "_smooth";
	$regext = "";
	$barsize = -1;
	$geom    = "400x600";
    }
}

# load useful libraries
# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# check for ciao env loaded
$check = $ENV{'ASCDS_BIN'};
die "## ERROR: ciao is not loaded\n" unless ($check);

# read in the reference file
%refdata = &read_file($ARGV[0]);

# load images in DS9 and overlay region
MAIN: foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # get values specific to each cluster
  $name    = $data[0];
  @obsid   = ($data[1],$data[2],$data[3],$data[4]);
  $obsstr  = join "_", @obsid;
  $obsstr  =~ s/\_0000//g;
  $x       = $data[5];
  $y       = $data[6];
  $rmax    = $data[7];
  $z       = $data[9];
  $datadir = $data[18];
  
  # change directory
  chdir("$datadir/$merged/$name/");

  # define file names
  $evtfile = "${obsstr}_${evtext}.fits";

  # catch no file
  unless (-e $evtfile) {
    print "## ERROR: No $evtfile.\n";
    chdir($Bin);
    next;
  }

  # get files
  $con = "${obsstr}.con" if ($contours eq "yes");

  # convert x-y to ra-dec if loading other images
  if ($extimg eq "yes") {
    $asol = sub_get_asol();
    sub_convert($evtfile,$asol,$x,$y);
  }

  # load images
  &ds9_image();
  sleep $delay;
  unlink("temp.reg","bar.reg");

  # change back to original directory
  chdir("$Bin");
}

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};

#######################
#######################
##   Sub-routines    ##
#######################
#######################

sub sub_get_asol {

  # get the asol file or files
  my($indir,$curdir,@infile,$asol,@dir,@globlist);
  $indir = cwd();
  chdir("$datadir/$obsid[0]/");
  $curdir = cwd();

  # change to appropriate dir (they sometimes change the locations)
  @dir = qw(primary secondary);
  @infile = ();
  foreach $dir (@dir) {
    chdir("$dir");
    @globlist =  <pcad*asol*.fits*>;
    @globlist = map { "$dir/" . $_} @globlist if (@globlist);
    push @infile, @globlist;
    chdir $curdir;
  }

  die "No asol files found.  Exiting.\n" unless (@infile);
  $asol = join(",",@infile);

  # return the name(s)
  chdir($indir);
  return $asol;
}

#######################
#######################

sub sub_convert {
  my($evt,$asol,$x,$y)=@_;
  $command = "punlearn dmcoords; dmcoords $evt $asol x=$x y=$y opt=sky";
  system($command);
  chomp($ra = `pget dmcoords ra`);
  chomp($dec = `pget dmcoords dec`);
}

#######################
#######################

sub ds9_image {
    my($regfile);

    # initialize values
    $regfile = "";
    $addimg  = "";
    $addsv   = "";
    $match   = "";
    $cont    = "";

    # build the proper command to display all of the annuli at once
    if ($regext eq "annuli") {
      $indir = cwd();
      chdir("$datadir/$obsid[0]/$rootdir");
      $curdir = cwd();
      @annuli = glob("*${regext}*.reg");
      @annuli = map { "-region $curdir/" . $_} @annuli if (@annuli);
      $regfile = join " ", @annuli;
      chdir($indir);
    } elsif ($regext eq "") {
      $regfile = "";
    } elsif ($regext eq "draw") {
      open(REG,">temp.reg");
      print REG "circle(${x},${y},${rmax})\n";
      close REG;
      $regfile .= " -region temp.reg";
    } else {
      $regfile = "-region ${obsstr}_${regext}.reg";
    }
    if ($dopan eq "yes") {
      $pan = "-pan to $x $y physical";
    } else {
      $pan = "";
    }

    # add fixed region for centroid
    if ($centr eq "yes") {
      open(REG,">temp.reg");
      print REG "\# Region file format: DS9 version 4.0\n";
      print REG "global color=green font=\"helvetica 10 normal\" "
	."select=1 highlite=1 edit=1 move=1 delete=1 include=1 fixed=0 source\n";
      print REG "physical\n";
      my $in = 5;
      my $out = 10;
      print REG "epanda(${x},${y},0,360,4,${in},${in},${out},${out},1,0) \# color=red width=1\n";
      print REG "circle(${x},${y},${in}) \# color=white width=1\n";
      close REG;
      $regfile .= " -region temp.reg";
    }

    # setup contours
    $cont = "-contour load $con wcs fk5 green 1" if ($contours eq "yes");

    # add image if wanted
    if ($extimg eq 'yes') {
      foreach $survey (@surveys) {
	if ($svimg eq 'yes') {
	  $addimg .= "-view colorbar no -grid load $grid -grid yes ";
	}
	$addimg .= "-$survey coord $ra $dec -pan to $ra $dec wcs fk5 $cont -scale $addscale -scale mode $addmode -cmap $addcmap";
      }
      $match = "-frame first -match frames wcs";
    }

    # save image if wanted
    # save image if wanted
    if ($svimg eq 'yes') {
	$outfile = "${obsstr}${output}.${imgform}";
	$addsv .= "-view colorbar no";
	$addsv .= " -grid load $grid -grid yes" unless ($loadmode eq "smooth");
	$addsv .= " -saveimage $imgform $outfile";
    }

    # make physical scale bar
    if ($barsize > 0.) {
      my $sz = sub_physwin();
      $sz = sprintf("%i",$sz);
      my $by = sprintf("%i",$y+0.033*$y);
      my $bx = sprintf("%i",$x-0.5*$sz);
      my $bx2 = $bx+$sz;
      open(BAR,">bar.reg");
      print BAR "# Region file format: DS9 version 4.0\n";
      print BAR "physical\n";
      print BAR "line(${bx},${by},${bx2},${by}) # line=1 1 color=white width=2 font=\"helvetica 12 bold\" text={${barsize} kpc}\n";
      close BAR;
      $regfile .= " -region bar.reg";
    }

    # execute ds9
    $command = "ds9 $evtfile $pan $regfile $scale $mode $minmax $zoom $bin $cmap $smooth $addimg -geometry $geom $addsv $match $exit";
    print "$command\n";
    print "Displaying...\n";
    print "File: $evtfile\n";
    print "Cluster: $name\n";
    system $command;

    if ($svimg eq 'yes') {
      mkdir($outdir,0777) unless (-d $outdir);
      foreach $obs (@obsid) {
	if ($obs ne "0000") {
	  $tout = "${obs}${output}.${imgform}";
	  system("cp -f $outfile $outdir/$tout");
	}
      }
      unlink("$outfile");
    }
}

#######################
#######################

sub read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## ERROR: Can't open $infile\n";
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

sub sub_physwin {

  my($conv,@line,$win);
  delete $ENV{'DYLD_BIND_AT_LAUNCH'};
  open(PROFILE,">temp.pro");
  print PROFILE "\!quiet=1\n";
  print PROFILE "cosmology,'$z',result,/silent\n";
  print PROFILE "openw,1,'temp.log'\n";
  print PROFILE "printf,1,strcompress(result[4],/remove_all)\n";
  print PROFILE "close,1\n";
  print PROFILE "exit \n";
  close PROFILE;
  system("\$IDL_DIR/bin/idl temp.pro");
  open(FILE,"temp.log");
  while(<FILE>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;
    s/\s+$//;
    @line = split;
    $conv = $line[0];
  }
  close FILE;
  system("rm -f temp.log temp.pro");
  delete $ENV{'DYLD_BIND_AT_LAUNCH'};
  $win = $barsize/($conv*0.492);
  return $win;
}

#######################
#######################
