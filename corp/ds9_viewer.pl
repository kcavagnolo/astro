#! /usr/bin/perl -w
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

$delay    = 1.25;
$rootdir  = "reprocessed";
$evtext   = "exclude";
$regext   = "annuli";
$dopan    = "yes";
$centr    = "";
$smooth   = "-smooth no -smooth radius 4";       #"-smooth yes -smooth radius 2";
$scale    = "-sqrt";                              # -sqrt log | sqrt | linear | pow ...
$mode     = "";                                   # -scale mode minmax
$minmax   = "";                                   # -minmax mode sample
$bin      = "-bin factor 4";                      # -bin factor 1
$cmap     = "-cmap b";
$zoom     = "-zoom 1.0";
$grid     = "$ENV{'HOME'}/research/redux/scripts/coords.grd";
$geom     = "1200x1000";
$barsize  = -1;
$extimg   = "no";
@surveys  = ("dss");#"nvss","first");
@skyview  = ("");
$addscale = "sqrt";
$addmode  = "minmax";
$addcmap  = "b";
$loadmode = "";                                   # wide, core, tx, multi, smooth: supercedes all following commands
$onlynew  = "no";

#######################
#######################

# set the input mode
$exit = "";
$svimg = "";
if ($loadmode ne "") {
  $outdir  = "/mnt/DROBO/accept/images";
  $imgform = "png";
  $evtext  = "clean";
  $dopan   = "yes";
  $centr   = "no";
  $geom    = "800x800";
  $exit    = "-exit";
  $svimg   = "yes";
  $extimg  = "no";
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
      $regext = "sdss";
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
open(IN,$ARGV[0]);
while (<IN>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    s/^\s+//;        # trim leading whitespace
    s/\s+$//;        # trim trailing whitespace
    @data = split;

    # get values specific to each cluster
    $name    = $data[0];
    $obsid   = $data[1];
    $x       = $data[2];
    $y       = $data[3];
    $rmax    = $data[4];
    $z       = $data[6];
    $datadir = $data[15];

    # change directory
    if (-d "$datadir/$obsid/$rootdir/") {
	chdir("$datadir/$obsid/$rootdir/");
    } else {
	print "## ERROR: No such directory $datadir/$obsid/$rootdir/\n";
	next;
    }

    # set files to be opened
    if ($evtext eq "") {
	@evtfile = glob("*evt2*.fits*");
	if (@evtfile) {
	    $evtfile = shift(@evtfile);
	} else {
	    @evtfile = glob("../primary/*evt2*");
	    $evtfile = pop(@evtfile);
	}
    } else {
	@evtfile = glob("*${evtext}*.fits*");
	$evtfile = shift(@evtfile);
    }

    # convert x-y to ra-dec if loading other images
    if ($extimg eq "yes") {
	$asol = sub_get_asol();
	sub_convert($evtfile,$asol,$x,$y);
    }

    # load images
    &ds9_image();
    sleep $delay;
    unlink("temp.reg","bar.reg","tempext.reg");

    # change back to original directory
    chdir("$Bin");
}
close IN;

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};
exit 0;

#######################
#######################
##   Sub-routines    ##
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
  die "No asol for $obsid\n" unless (@infile);
  $asol = join(",",@infile);

  # return the name(s)
  chdir($curdir);
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

    # add fixed region for centroid
    $regfile = "";
    if ($centr eq "yes") {
      open(REG,">temp.reg");
      print REG "\# Region file format: DS9 version 4.0\n";
      print REG "global color=green font=\"helvetica 10 normal\" "
	."select=1 highlite=1 edit=1 move=1 delete=1 include=1 fixed=0 source\n";
      print REG "physical\n";
      my $in = 10;
      print REG "circle(${x},${y},${in}) # color=white width=3\n";
      close REG;
      $regfile .= " -region temp.reg ";
    }

    # build the proper command to display all of the annuli at once
    if ($regext eq "annuli") {
      @annuli = glob("*${regext}*.reg");
      @annuli = map { "-region " . $_} @annuli if (@annuli);
      $regfile .= join " ", @annuli;
    } elsif ($regext eq "") {
      $regfile .= "";
    } elsif ($regext eq "draw") {
	open(REG,">temp.reg");
	print REG "circle(${x},${y},${rmax})\n";
	close REG;
	$regfile .= " -region temp.reg";
    } else {
	if (-e "${obsid}_${regext}.reg") {
	    $regfile .= "-region ${obsid}_${regext}.reg";
	} else {
	    print "## ERROR: ${obsid}_${regext}.reg does not exist\n";
	    $regfile .= "";
	}
    }
    if ($dopan eq "yes") {
	$pan = "-pan to $x $y physical";
    } else {
	$pan = "";
    }

    # add image if wanted
    if ($extimg eq 'yes') {

      # add image for each survey
      foreach $survey (@surveys) {
	  next if ($survey eq "");
	  if ($svimg eq 'yes') {
	      $addimg .= "-view colorbar no -grid load $grid -grid yes ";
	  }
#	  open(REG,">tempext.reg");
#	  print REG "global color=green font=\"helvetica 10 normal\" "
#	      ."select=1 highlite=1 edit=1 move=1 delete=1 include=1 fixed=0 source\n";
#	  print REG "fk5\n";
#	  print REG "circle(${ra},${dec},5\" # color=black width=3\n";
#	  close REG;
	  $addimg .= "-$survey coord $ra $dec -pan to $ra $dec wcs fk5 -scale $addscale -scale mode $addmode -cmap $addcmap ";#-region tempext.reg ";
      }
      foreach $skyview (@skyview) {
	  next if ($skyview eq "");
	  $addimg .= "-skyview survey $skyview -pan to $ra $dec wcs fk5 -scale $addscale -scale mode $addmode -cmap $addcmap ";
      }
      $match = "-frame first -match frames wcs ";
    }

    # save image if wanted
    if ($svimg eq 'yes') {
	$outfile = "${obsid}${output}.${imgform}";
	if ($onlynew eq "yes") {
	    if (-e "${outdir}/${outfile}") {
		print "## Already have $outfile, skipping...\n";
		return;
	    }
	}
	$addsv .= "-view colorbar no ";
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
	system("mv -f $outfile $outdir");
    }
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
