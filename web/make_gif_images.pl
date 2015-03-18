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

$onlynew  = "no";                           # only bother making new images, saves time
$mkimg    = "no";                            # make an image of the cluster DEPRACATED
$imgdir   = "/mnt/DROBO/accept/images";   # dir to put cluster image
$mktx     = "no";                            # make a master image of spectra DEPRACATED
$txdir    = "/mnt/DROBO/accept/spectra";  # dir to put specmaster image
$mklc     = "yes";                           # make image of the light curve
$lcdir    = "/mnt/DROBO/accept/lc";       # dir to put light curve image
$mksdss   = "yes";                           # basically copies SDSS image from get_images.pl to web dir
$sdssdir  = "/mnt/DROBO/accept/images";   # dir to put image
$mkdss    = "yes";                           # basically copies DSS image from get_images.pl to web dir
$dssdir   = "/mnt/DROBO/accept/images";   # dir to put image
$mkspec   = "yes";                           # make images of spectra
$specdir  = "/mnt/DROBO/accept/spectra";  # dir to put images
$psdir    = $ENV{'HOME'}."/research/pf_clusters/pf_fits/plots/spectra"; # location of dir containing PS of spectra
$trfile   = $ENV{'HOME'}."/research/pf_clusters/pf_fits/dat/pf_temp_profs.dat"; # location of best-fit spectral results
$ext      = "clean";
$ibin     = "2";
$zoom     = "-6";
$txbin    = "2";
$txzoom   = "-10";
$nlevs    = "200";
$mosaic   = "no";
$survey   = "DSS";
$scale1   = "sqrt";
$scale2   = "log";
$rootdir  = "reprocessed";

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
use Math::Complex;

# Read in the reference file
%refdata  = sub_read_file($ARGV[0]);

# open logfile
open(ERR,">err_gifs.log") || die "## ERROR: Can't open err log... this is ironic\n";

# make dirs
if ($mkimg eq "yes") {
    mkdir($imgdir,0777) unless (-d $imgdir);
}
if ($mktx eq "yes") {
    mkdir($txdir,0777) unless (-d $txdir);
}
if ($mklc eq "yes") {
    mkdir($lcdir,0777) unless (-d $lcdir);
}
if ($mksdss eq "yes") {
    mkdir($sdssdir,0777) unless (-d $sdssdir);
}
if ($mkdss eq "yes") {
    mkdir($dssdir,0777) unless (-d $dssdir);
}
if ($mkspec eq "yes") {
    mkdir($specdir,0777) unless (-d $specdir);
}

# loop through each cluster
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # get values specific to each cluster
  $name   = $data[0];
  $obsid  = $data[1];
  $x      = $data[2];
  $y      = $data[3];
  $datadir= $data[15];

  # change directory
  chdir("$datadir/$obsid/$rootdir");

  # aspect solution for ref obs of merged file
  if ($mkimg eq "yes" || $mktx eq "yes") {
      $evtfile  = "${obsid}_${ext}.fits";
      $imgfile  = "${obsid}.png";
      $specfile = "${obsid}_specmaster.png";
      $asol = sub_get_asolfile();
      ($ra,$dec) = sub_conv_radec($x,$y,$evtfile,$asol);
      $xcen = "ra=$ra";
      $ycen = "dec=$dec";
      sub_pngimg($imgfile,$xcen,$ycen,$evtfile) if ($mkimg eq "yes");
      sub_specimg($specfile,$xcen,$ycen,$evtfile) if ($mktx eq "yes");
  }

  # make a png of the cluster
  if ($mklc eq "yes") {
      $infile = "${obsid}_lc.ps";
      unless (-e $infile) {
	  print "## ERROR: no $infile\n";
	  print ERR "$obsid -- no $infile\n";
      } else {
	  $lcfile = "${obsid}_lc.png";
	  sub_pnglc($infile,$lcfile);
      }
  }

  # make a png of the cluster
  if ($mksdss eq "yes") {
      $infile = "${obsid}_sdss.png";
      unless (-e $infile) {
	  print "## ERROR: no $infile\n";
	  print ERR "$obsid -- no $infile\n";
      } else {
	  $sdssfile = "${obsid}_sdss.png";
	  sub_pngsdss($infile,$sdssfile);
      }
  }

  # make a png of the cluster
  if ($mkdss eq "yes") {
      $infile = "${obsid}_DSS.png";
      unless (-e $infile) {
	  print "## ERROR: no $infile\n";
	  print ERR "$obsid -- no $infile\n";
      } else {
	  $dssfile = "${obsid}_dss.png";
	  sub_pngdss($infile,$dssfile);
      }
  }

  # make a png of the cluster
  if ($mkspec eq "yes") {
      unless (-e $trfile) {
	  print "## ERROR: no $trfile\n";
	  print ERR "$obsid -- no $trfile\n";
      } else {
	  sub_pngspec($trfile);
      }
  }

  # go back to script directory
  chdir("$Bin");
}

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## $obsid:  Can't open $infile\n";
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

sub sub_get_asolfile {

  # get the asol file or files
  my($indir,$curdir,@infile,$asol,@dir,@globlist);
  $curdir = cwd();

  # change to appropriate dir (they sometimes change the locations)
  @dir = qw(primary secondary);
  @infile = ();
  foreach $dir (@dir) {
    chdir("../$dir");
    @globlist = <pcad*asol*>;
    @globlist = map { "$dir/" . $_} @globlist if (@globlist);
    push @infile, @globlist;
    chdir $curdir;
  }

  die "## ERROR: $obsid, No asol files found.  Exiting.\n" unless (@infile);
  $asol = join(",",@infile);

  # return the name(s)
  chdir($curdir);
  return $asol;
}

#######################
#######################

sub sub_conv_radec {

  my($x,$y,$evt,$asol) = @_;
  my $command = "punlearn dmcoords; dmcoords $evt $asol x=$x y=$y opt=sky";
  system($command);
  my $ra  = `pget dmcoords ra`;
  my $dec = `pget dmcoords dec`;
  $ra  =~ s/^\s+//;
  $ra  =~ s/\s+$//;
  $dec =~ s/^\s+//;
  $dec =~ s/\s+$//;
  print "converted $x --> $ra :: $y --> $dec\n";
  return($ra,$dec);
}

#######################
#######################

sub sub_pngimg {

  my($png,$xcen,$ycen,$evt) = @_;

  # make images using ximage
  open(XCO,">image.xco") || die "Can't open image.xco\n";
  print XCO "cpd temp.gif/gif\n";
  print XCO "cey 2000\n";
  print XCO "read/fits/$xcen/$ycen/size=$zoom $evt\n";
  print XCO "cct/reverse/set spectrum.tab\n";
  print XCO "levels/sqrt/num=$nlevs\n";
  print XCO "rebin $ibin\n";
  print XCO "smooth\n";
  if ($mosaic eq "yes") {
    print XCO "disp/$scale1/noframe/left\n";
  } else {
    print XCO "disp/$scale1/noframe\n";
  }
  print XCO "grid/abbrev/ticks_only\n";

  if ($mosaic eq "yes") {
    # load image(s) from another survey like DSS or VLA First
    print XCO "skyview/survey_name=$survey\n";
    print XCO "read/fits/$xcen/$ycen/size=$zoom skyview.fits\n";
    print XCO "cct/set spectrum.tab\n";
    print XCO "levels/sqrt/num=$nlevs\n";
    print XCO "rebin $ibin\n";
    print XCO "smooth\n";
    print XCO "title \"DSS Image\"\n";
    print XCO "disp/$scale2/noframe/right/overlay\n";
    print XCO "grid/abbrev/ticks_only\n";
  }
  print XCO "exit\n";
  close XCO;
  system("ximage \@image.xco");

  # check that ximage was sucessful
  unless (-e "temp.gif") {
    print "## ERROR: $name $obsid ximage failed\n";
    unlink("image.xco");
    chdir("$Bin");
    next;
  }

  # crop out empty space and convert gif file to png
  system("mogrify -crop 0x0 temp.gif");
  system("convert temp.gif $png");
  if (-e $png) {
    system("mv $png $imgdir");
  }

  # clean up temp files
  unlink("temp.gif","image.xco");
}

#######################
#######################

sub sub_specimg {

  my($master,$xcen,$ycen,$evt) = @_;
  my(@annuli);

  # search for annuli file in current directory
  undef @annuli;
  @annuli = glob("*_annuli*.reg");

  # make images using ximage
  open(XCO,">image.xco") || die "Can't open image.xco\n";
  print XCO "cpd temp.gif/gif\n";
  print XCO "cey 2000\n";
  print XCO "read/fits/$xcen/$ycen/size=$txzoom $evt\n";
  print XCO "cct/reverse/set spectrum.tab\n";
  print XCO "levels/num=$nlevs\n";
  print XCO "rebin $txbin\n";
  print XCO "smooth\n";
  print XCO "disp/$scale1/noframe\n";
  print XCO "title \"Temperature Annuli\"\n";
  print XCO "grid/abbrev/ticks_only\n";
  foreach $annreg (@annuli) {
    $num = $annreg;
    $num =~ s/\.reg//;
    @num = (split/annuli/,$num);
    $num = $num[1];
    open(INFILE,$annreg);
    while (<INFILE>) {
      chomp;
      next if (/^\#/); # skip comment lines
      next if (/^$/);  # skip blank lines
      @r = (split/\,/,$_);
      $rout = $r[3];
      $rout =~ s/\)//g;
    }
    close INFILE;
    print XCO "draw/lwidth=1/color=500/circ $x $y $rout\n";
    $xt = $x+$rout;
    print XCO "label/x=$xt/y=$y/text=$num/color=5000\n";
  }
  print XCO "exit\n";
  close XCO;
  system("ximage \@image.xco");

  # check that ximage was sucessful
  unless (-e "temp.gif") {
    print "## ERROR: $name $obsid ximage failed\n";
    unlink("image.xco");
    chdir("$Bin");
    return;
  }

  # crop out empty space and convert gif file to png
  system("mogrify -crop 0x0 temp.gif");
  system("convert temp.gif $master");
  if (-e $master) {
    system("mv $master $txdir");
  }

  # clean up temp files
  unlink("temp.gif","image.xco");
}

#######################
#######################

sub sub_pnglc {

  my($in,$out) = @_;
  if (-e "${lcdir}/$out" && $onlynew eq "yes") {
      print "## $out exists and \$onlynew eq \"yes\", skipping...\n";
      return;
  }
  system("convert $in $out");

  if (-e $out) {
    print "## Made $out\n";
    system("mv -f $out $lcdir");
  } else {
    print "## ERROR: $out no made\n";
  }
}

#######################
#######################

sub sub_pngsdss {

  my($in,$out) = @_;
  if (-e "${sdssdir}/$out" && $onlynew eq "yes") {
      print "## $out exists and \$onlynew eq \"yes\", skipping...\n";
      return;
  }
  print "## Copying $in to $sdssdir/$out\n";
  system("cp -f $in $sdssdir/$out");
}

#######################
#######################

sub sub_pngdss {

  my($in,$out) = @_;
  if (-e "${dssdir}/$out" && $onlynew eq "yes") {
      print "## $out exists and \$onlynew eq \"yes\", skipping...\n";
      return;
  }
  print "## Copying $in to $dssdir/$out\n";
  system("cp -f $in $dssdir/$out");
}

#######################
#######################

sub sub_pngspec {

  my($in) = @_;
  my($iter,@a,@b,$spec,$out);

  # for each instance of cluster in specfile
  # find spec ps and convert to png
  open(A,$in);
  $iter = 0;
  while(<A>){
      chomp;
      next if (/^\#/);
      next if (/^$/);
      s/^\s+//;
      s/\s+$//;
      my @a = split;
      if ($a[0] eq $name) {
	  $iter++;
	  undef @b;
	  @b = glob("$psdir/${obsid}_*annuli${iter}_spec.ps");
	  @b = glob("$psdir/*_${obsid}_*annuli${iter}_spec.ps") unless (@b);
	  unless (@b) {
	      print "## ERROR: No spectrum for $obsid $iter\n";
	      print ERR "$obsid -- no spec for $iter\n";
	      next;
	  }
	  $spec = $b[0];
	  $out = "$specdir/${obsid}_annuli${iter}.png";
	  if (-e "$out" && $onlynew eq "yes") {
	      print "## $out exists and \$onlynew eq \"yes\", skipping...\n";
	      next;
	  }
	  print "## Converting... $spec --> $out\n";
	  system("convert $spec $out");
      }
  }
}

#######################
#######################
