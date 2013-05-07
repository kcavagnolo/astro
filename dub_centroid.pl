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

$newref   = "dub_cent.list";
$binning  = 128;
$imbin    = 4;
$mkimg    = "yes";
$rm_ptsrc = "yes";
$docent   = "no";
$scales   = "\"1.0 2.0 4.0\"";
$iter     = 1;
$sigma    = 2;
$datadir1 = "../acis/";                       # Location of /acis/ in relation to this script
$datadir2 = "/Volumes/MBRANE";                # Location of /acis/ in relation to this script
$datadir3 = "/Volumes/GALACTUS";              # Location of /acis/ in relation to this script
$rootdir  = "merged";
$verb     = 1;

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

# open file to new reference
sub_print_info();

# Open a a log file
open(LOGFILE,">>cent_emi.log") || die "\n## $obsid: Can't open cent_emi.log\n";
print LOGFILE "###### Started centroiding emission at ",scalar(localtime)," ######\n";

# Read in the reference file
%refdata = sub_read_file($ARGV[0]);

# Go through each cluster
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # get values specific to each cluster
  $name    = $data[0];
  @obsid   = ($data[1],$data[2],$data[3],$data[4]);
  $obsstr  = join "_", @obsid;
  $obsstr  =~ s/\_0000//g;
  $x       = $data[5];
  $y       = $data[6];
  $id      = $data[14];
  $diffuse = $data[16];
  $loc     = $data[18];
  $datadir = $datadir1 if ($loc eq "NAZGUL");
  $datadir = $datadir2 if ($loc eq "MBRANE");
  $datadir = $datadir3 if ($loc eq "GALACTUS");
  $instr   = "s" if ($id =~ /^s/);
  $instr   = "i" if ($id =~ /^i/);
  $fail    = "no";

  # write to log file
  print "\n###### Started $name (ObsId $obsstr) ",scalar(localtime),"\n\n";
  print LOGFILE "###### Started $name (ObsId $obsstr) ",scalar(localtime),"\n";

  # change directory
  chdir("$datadir/$rootdir/$name");

  # define file names
  $evtfile = "$datadir/$rootdir/$name/${obsstr}_merged.fits";
  $regfile = "${obsstr}_centroid.reg";

  # make sure we have events files to work with
  unless (-e $evtfile) {
    print "## No event file for $obsstr\n";
    print LOGFILE "${obsstr}: No event file\n";
    chdir("$Bin");
    next;
  }

  # aspect solution for ref obs of merged file
  $asol = get_asolfile();
  print "## Using aspect solution for $obsid[0]: $asol\n";

  # make an image
  if ($mkimg eq "yes") {
    $command = "dmcopy \"$evtfile\[bin sky=$imbin]\" srcimg.fits clobber=yes verbose=$verb";
    system($command);
  }

  # detect and remove point sources
  if ($rm_ptsrc eq "yes") {
    sub_rm_ptsrc();
    if ($fail eq "yes") {
      $offender = "sub_rm_ptsrc";
      logerror($offender);
      next;
    }
    print LOGFILE "${obsstr}: Removed point sources\n";
  }

  # get the centroid value of the emission
  if ($docent eq "yes") {

    # create background region for each pt src
    sub_mkbgreg();
    if ($fail eq "yes") {
      $offender = "sub_mkbgreg";
      logerror($offender);
      next;
    }
    print LOGFILE "${obsstr}: Created bgd regions for point sources\n";

    # subtract source region from background region
    sub_mksubbgreg();
    if ($fail eq "yes") {
      $offender = "sub_submkbgreg";
      logerror($offender);
      next;
    }
    print LOGFILE "${obsstr}: Created subtracted regions for point sources\n";

    # fill the holes created by the point sources
    sub_fill_holes();
    if ($fail eq "yes") {
      $offender = "sub_fill_holes";
      logerror($offender);
      next;
    }
    print LOGFILE "${obsstr}: Filled holes left by point sources\n";

    sub_centroid();
    if ($fail eq "yes") {
      $offender = "sub_centroid";
      logerror($offender);
      next;
    }
    print LOGFILE "${obsstr}: Centroid of ($x,$y) in physical coords found\n";

    # convert RA Dec to X Y for *all* obs
    sub_conv_radec();
    if ($fail eq "yes") {
      $offender = "sub_centroid";
      logerror($offender);
      next;
    }

    # write a region file for the centroid for easy viewing
    open(REGFILE,">$regfile");
    print REGFILE "circle(${x},${y},20)\n";
    close REGFILE;
  }

  # clean-up files
  unlink("img_full.fits");
  unlink("sources.fits");
  unlink("bkg.fits");
  unlink("scell.fits");
  unlink("image.fits");
#  unlink("sources.reg");
  unlink("bkg.reg");
  unlink("bkg_sub.reg");
  unlink("img_filled.fits");
  unlink<*_stk>;
  unlink<temp*>;
  unlink<img*>;
  unlink("srcimg.fits");

  # write to log file
  print LOGFILE "###### Finished $name (ObsId $obsstr) ",scalar(localtime),"\n";
  print "\n###### Finished $name (ObsId $obsstr) ",scalar(localtime),"\n\n";

  # change back to original directory
  chdir("$Bin");
}

print LOGFILE "###### Finished centroiding emission ",scalar(localtime)," ######\n\n";
print "\n###### Finished centroiding emission ",scalar(localtime)," ######\n\n";
close LOGFILE;

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
  open(INFILE,$infile) || die "\n## ERROR: Can't open $infile\n";
  while (<INFILE>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;
    s/\s+$//;
    @data = split;
    $name = join "_", $data[0],$data[1],$data[2],$data[3],$data[4];
    $info{$name} = $_;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub sub_make_img {

  my($inimg) = @_;

  # change datatype depending on binning
  # binning too high overwhelms dmcopy and
  # requires 4-byte instead of 2-byte
  if ($binning <= 64) {
    $dtype = "i2";
  } else {
    $dtype = "i4";
  }

  # find the most likely center by binning coarsely
  # and looking for the maximum value in the image
  $command = "punlearn dmcopy; dmcopy \"${evtfile}[bin sky=$binning][opt type=$dtype]\" "
    ."temp.fits verbose=$verb clobber=yes";
  system($command);
  $command = "punlearn dmstat; dmstat temp.fits centroid=no";
  system($command);
  unlink("temp.fits");

  # get the phys location of the max
  my $max = `pget dmstat out_max_loc`;
  my @data = split /\,/, $max;
  my @maxx = split /\./, $data[0];
  my @maxy = split /\./, $data[1];
  $maxx = $maxx[0];
  $maxy = $maxy[0];

  # trap any errors
  if ($maxx > 0 && $maxy > 0) {
    print "## Coarse center of ($maxx,$maxy) found\n";
  } else {
    $fail = "yes";
    return
  }

  # make a finer grid, recenter
  my $reg = "circle(${maxx},${maxy},100)";
  my $tbin = 4;
  $command = "punlearn dmcopy; dmcopy \"${evtfile}[sky=$reg][bin sky=$tbin][opt type=$dtype]\" "
    ."temp.fits verbose=$verb clobber=yes";
  system($command);
  $command = "punlearn dmstat; dmstat temp.fits centroid=no";
  system($command);
  unlink("temp.fits");

  # get the phys location of the max
  $max = `pget dmstat out_max_loc`;
  @data = split /\,/, $max;
  @maxx = split /\./, $data[0];
  @maxy = split /\./, $data[1];
  $maxx = $maxx[0];
  $maxy = $maxy[0];

  # trap any errors
  if ($maxx > 0 && $maxy > 0) {
    print "## New coarse center of ($maxx,$maxy) found\n";
  } else {
    $fail = "yes";
    return
  }

  # construct a reasonably sized region around the coarse center
  if ($instr eq "i") {
    $maxr = 800;
  } else {
    $maxr = 500;
  }
  $reg = "circle(${maxx},${maxy},${maxr})";

  # create the images
  $command = "punlearn dmcopy; dmcopy \"${inimg}[sky=$reg]\" tempimg.fits verbose=$verb clobber=yes";
#  $command2 = "punlearn dmcopy; dmcopy \"${expmap}[sky=$reg]\" tempexpmapexcl.fits verbose=$verb clobber=yes";
  print "## Creating image\n";
  system($command);
#  system($command2);

#  # construct the normalization command
#  $command = "punlearn dmimgcalc; dmimgcalc tempimg.fits tempexpmapexcl.fits cent_norm.fits div"
#    ." clobber=yes verbose=$verb";
#  system($command);
}

#######################
#######################

sub sub_rm_ptsrc {

  my $img = "srcimg.fits";
  my $outfile = "sources.fits";
  my $scell = "scell.fits";
  my $image = "image.fits";
  my $bkg = "bkg.fits";
  my $reg = "sources.reg";
  my $radecreg = "sources_radec.reg";

  # create the image
  $command = "punlearn wavdetect; wavdetect infile=$img outfile=$outfile scellfile=$scell "
    ."imagefile=$image defnbkgfile=$bkg regfile=$reg ellsigma=$sigma scales=$scales maxiter=$iter "
      ."verbose=$verb clobber=yes";
  print "## Detecting point sources\n";
  system($command);
  unlink "*_stk";

  # open the file
  my $temp = "temp.reg";
  open(TEMP,">$temp");
  open(REG,"$reg");
  while(<REG>){
    chomp;
    next if (/\,0\.00/ || /NAN/ || /nan/);
    print TEMP "$_\n";
  }
  close REG;
  close TEMP;
  system("mv -f $temp $reg");

  # check that it worked or return an error
  if (-e $reg) {
    print "## Point sources detected and stored in $reg\n";
  } else {
    $fail = "yes";
    return;
  }

#   # run dmcoords
#   open(A,"$reg");
#   open(B,">$radecreg");
#   while(<A>) {
#     chomp;
#     $_ =~ s/ellipse\(//;
#     $_ =~ s/\)//;
#     @a = split(",",$_);
#     $x = $a[0];
#     $y = $a[1];
#     $command = "punlearn dmcoords; dmcoords $img $asol x=$x y=$y opt=sky";
#     system($command);

#     # get output ra and dec
#     $ra = `pget dmcoords ra`;
#     $dec = `pget dmcoords dec`;
#     $ra =~ s/^\s+//;
#     $ra =~ s/\s+$//;
#     $dec =~ s/^\s+//;
#     $dec =~ s/\s+$//;

#     # print out new values
#     print B "ellipse($ra,$dec,$a[2],$a[3])\n";
#   }
#   close A;
#   close B;

#   # check that it worked or return an error
#   if (-e $radecreg) {
#     print "## Point sources locations converted to RA and Dec.\n";
#     $fail = "no";
#   } else {
#     $fail = "yes";
#   }
}

#######################
#######################

sub sub_mkbgreg {

  my $regionFile = "sources.reg";
  my $radius = 1.5;
  my $outfile = "bkg.reg";

  # check for an empty file
  $wc = `wc $regionFile`;
  my @data = split /\s+/, $wc;
  my $check = $data[1];
  if ($check == 0) {
    $skip = "yes";
  } else {
    $skip = "no";
  }

  # exit if there are no sources
  if ($skip eq "yes") {
    print "## No sources to exclude\n";
    print LOGFILE "${obsstr}: No pt srcs to remove\n";
    open (SRC, ">$regionFile");
    print SRC "circle(0,0,0)\n";
    close SRC;
    open (RFILE, ">$outfile");
    print RFILE "circle(0,0,0)\n";
    close (RFILE);
    return;
  }

  @regionList = ();
  open (FILE, "<$regionFile") || die "## Can't open $regionFile";
  @regionList = <FILE>;
  close (FILE);
  @bkgList = ();
  # delete first line if it's a comment
  if ($regionList[0] =~ s/#//) {
    shift (@regionList);
  }

  foreach $line (@regionList){
    chomp $line;
    my $new = $line;
    $new =~ s/^.*\(//;
    $new =~ s/\)//;
    @radVals = split(",",$new);

    # for circular regions
    if ($line =~ /circle/ ) {
      $radVal = $radVals[2];
      $radNew = $radVal * $radius;
      $newline = join ",", $radVals[0],$radVals[1],"$radNew)\n";
      push @bkgList, $newline;

    # assume it's ellipses otherwise
    } else {
      $radVal1 = $radVals[2];
      $radVal2 = $radVals[3];
      $radNew1 = $radVal1 * $radius;
      $radNew2 = $radVal2 * $radius;
      $newline = "ellipse($radVals[0],$radVals[1],$radNew1,$radNew2,$radVals[4])\n";
      push @bkgList, $newline;
    }
  }

  open (RFILE, ">$outfile");
  print RFILE (@bkgList);
  close (RFILE);

  # check that it worked or return an error
  if (-e $outfile) {
    print "## A region file for the point source backgrounds has been created\n";
    $fail = "no";
  } else {
    $fail = "yes";
  }
}

#######################
#######################

sub sub_mksubbgreg {

  my $sourceFile = "sources.reg";
  my $bgFile = "bkg.reg";
  my $outfile = "bkg_sub.reg";

  # no need for this step if there are no sources from prev step
  if ($skip eq "yes") {
    open (OUTFILE, ">$outfile");
    print OUTFILE "circle(0,0,0)";
    close (OUTFILE);
    return;
  }

  @srcList = ();
  open (FILE, "<$sourceFile") || die "## Can't open source file\n";
  @srcList = <FILE>;
  close (FILE);

  @bgList = ();
  open (FILE, "<$bgFile") || die "## Can't open background file\n";
  @bgList = <FILE>;
  close (FILE);

  # delete first line if it's a comment
  if ($srcList[0] =~ s/#//) {
    shift (@srcList);
  }
  # delete first line if it's a comment
  if ($bgList[0] =~ s/#//) {
    shift (@bgList);
  }

  @new = ();
  $a = 0;

  foreach $line (@bgList) {
    chomp $line;
    $newline = "$line-$srcList[$a]";
    $a++;
    push @new, $newline;
  }

  open (OUTFILE, ">$outfile") || die "Can't write output file $outfile\n";
  print OUTFILE (@new);
  close (OUTFILE);

  # check that it worked or return an error
  if (-e $outfile) {
    print "## A region file for the subtracted regions has been created\n";
    $fail = "no";
  } else {
    $fail = "yes";
  }
}

#######################
#######################

sub sub_fill_holes {

  my $img = "srcimg.fits";
  my $outfile = "img_filled.fits";
  my $src = "sources.reg";
  my $bkg = "bkg_sub.reg";

  # exit if there are no sources
  if ($skip eq "yes") {
      print "## No holes to fill\n";
      system("cp -f $img $outfile");
      return;
  }

  # create the image
  $command = "punlearn dmfilth; dmfilth infile=$img outfile=$outfile method=POISSON "
    ."srclist=\@$src bkglist=\@$bkg randseed=123 clobber=yes verbose=$verb";
  print "## Filling holes\n";
  system($command);

  # check that it worked or return an error
  if (-e $outfile) {
    print "## Holes left by pt srcs have been filled\n";
    $fail = "no";
  } else {
    $fail = "yes";
  }
}

#######################
#######################

sub sub_centroid {

  my($img,$centroid);

  $img = "img_filled.fits";

  # create the image
  sub_make_img($img);
  $img = "tempimg.fits";

  $command = "punlearn dmstat; dmstat $img centroid=yes";
  print "## Centroiding\n";
  system($command);

  # get the value for the centroid and parse
  if ($diffuse =~ /^y/) {
      $centroid = `pget dmstat out_cntrd_phys`;
  } else {
      $centroid = `pget dmstat out_max_loc`;
  }
  my @data = split /\,/, $centroid;
  @x = split /\./, $data[0];
  @y = split /\./, $data[1];
  chomp($x = $x[0]);
  chomp($y = $y[0]);

  # find distance between max and cent
  my $d = sqrt((($x-$maxx)**2.0)+(($y-$maxy)**2));

  # at a z of 0.7, 7 kpc/", this is 3.4 kpc/pix
  # or ~20 pix for 70 kpc
  if ($d <= 50) {
    $x = $maxx;
    $y = $maxy;
  }

  # check that it worked or return an error
  if ($x > 0 && $y > 0) {
    print "## Centroid of ($x,$y) found\n";
    $fail = "no";
  } else {
    $fail = "yes";
    return;
  }

  $command = "punlearn dmcoords; dmcoords $img $asol x=$x y=$y opt=sky";
  system($command);

  # get output ra and dec
  $ra = `pget dmcoords ra`;
  $dec = `pget dmcoords dec`;
  $ra =~ s/^\s+//;
  $ra =~ s/\s+$//;
  $dec =~ s/^\s+//;
  $dec =~ s/\s+$//;
}

#######################
#######################

sub logerror {

    my($offender) = @_;

    chdir("$Bin");
    open  ERRFILE,">>cent_errors.log";
    print "${obsstr} # failure in cent_emi.pl, $offender ",scalar(localtime),"\n";
    print ERRFILE "${obsstr} # failure in cent_emi.pl, $offender ",scalar(localtime),"\n";
    close ERRFILE;
}

#######################
#######################

sub sub_print_info {

  open(NEWREF,">$Bin/${newref}");
  printf NEWREF "%-25s %6s %15s %15s %6s %6s\n","#Name","ObsID","RA","Dec","X","Y";
  close NEWREF;
}

#######################
#######################

sub get_asolfile {

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

sub sub_conv_radec {

  my($obs,$evt,$indir,$curdir,@infile,$asol,@dir,@globlist);
  $indir = cwd();
#  my $srcreg = "sources_radec.reg";

  foreach $obs (@obsid) {
    next if ($obs eq "0000");
    chdir("$datadir/$obs/reprocessed");
    undef @infile;
    @infile = glob("${obs}_*evt2*.fits");
    die "\n## $obs: No evt file\n" unless (@infile);
    $evt = shift @infile;
    undef @infile;
    @infile = glob("../primary/pcad*asol*.fits*");
    die "\n## $obs: No asol file\n" unless (@infile);
    $asol = shift @infile;
    $command = "punlearn dmcoords; dmcoords $evt $asol ra=$ra dec=$dec opt=cel";
    system($command);
    my $nx = `pget dmcoords x`;
    my $ny = `pget dmcoords y`;
    $nx =~ s/^\s+//;
    $nx =~ s/\s+$//;
    $ny =~ s/^\s+//;
    $ny =~ s/\s+$//;
    chdir($indir);
    print "converted $ra --> $nx :: $dec --> $ny for $obs\n";
    open NEWREF, ">>/$Bin/${newref}";
    printf NEWREF "%-25s %6s %15s %15s %6i %6i\n",$name,$obs,$ra,$dec,$nx,$ny;
    close NEWREF;
  }
}

#######################
#######################
