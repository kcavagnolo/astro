#! /usr/bin/perl -w

$outfile  = "sample_info.dat";
$rootdir  = "reprocessed";                    # name of dir with data
$emin     = "0.001";                          # min and max energy ranges for fitting,
$emax     = "100.0";                          # needs to be a string so PERL don't cut off decimal pts.
$h0       = 70;                               # cosmology h0
$q0        = 0.0;                              # norm. acceleration (ignored by Xspec)
$omegal   = 0.7;                              # cosmology imega_lambda
$model    = "mekal";                          # spectral model to use
$nhmod    = "wabs";                           # e.g., wabs,tbabs, ph
$coordsys = "Galactic";
$region   = "annulus";
$quiet    = "yes";
$fitfile  = "$ENV{'HOME'}/research/me_temp_proj/me_fits/dat/final_r2500-50_fefree_7-7.dat";
$altfitfile  = "$ENV{'HOME'}/research/me_temp_proj/me_fits/dat/final_r5000-50_fefree_7-7.dat";

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});

# Check the number of arguments given
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# Load useful libraries
# Store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);
use constant PI => 4*atan2(1,1);

# open file to new reference
sub_print_info();

open(LOGFILE,">>extra_info.log");

# Read in the reference file
%refdata = read_file($ARGV[0]);
%fitdata = read_specfile($fitfile);
%altfitdata = read_specfile($altfitfile);

# build a counter
$counter = scalar(keys %refdata);

# Go through each cluster
{
  foreach $key (sort keys %refdata) {

    $fail = "no";

    # split up the data line
    @data = split(/\s+/,$refdata{$key});
    $cname = $data[0];
    $obsid = $data[1];
    $x     = $data[2];
    $y     = $data[3];
    $rmax  = $data[4];
    $z     = $data[6];
    $nh    = $data[7];
    $tx    = $data[8];
    $fe    = $data[9];
    $datadir = $data[15];

    if (exists $fitdata{$cname}) {
      @fitdata = split(/\s+/,$fitdata{$cname});
      $rin   = $fitdata[2];
      $rout  = $fitdata[3];
      $nh    = $fitdata[4]*1e-2;
      $tx    = $fitdata[7];
      $data[8] = $fitdata[7];
      $tlo   = $fitdata[8];
      $thi   = $fitdata[9];
      $fe    = $fitdata[10];
      $data[9] = $fitdata[10];
      $norm  = $fitdata[13];
      $z     = $fitdata[22];
      $cr    = $fitdata[23];
    } elsif (exists $altfitdata{$cname}) {
      print "## Not in main fit, but in alt fit\n";
      @fitdata = split(/\s+/,$altfitdata{$cname});
      $data[0] .= "_dag";
      $rin   = $fitdata[2];
      $rout  = $fitdata[3];
      $nh    = $fitdata[4]*1e-2;
      $tx    = $fitdata[7];
      $data[8] = $fitdata[7];
      $tlo   = $fitdata[8];
      $thi   = $fitdata[9];
      $fe    = $fitdata[10];
      $data[9] = $fitdata[10];
      $norm  = $fitdata[13];
      $z     = $fitdata[22];
      $cr    = $fitdata[23];
    } else {
      print "## No fit data for $key -- $cname.\n";
      print LOGFILE "${key}: No fit data in $fitfile\n";
      $rin   = -1.00;
      $rout  = -1.00;
      $tlo   = -1.00;
      $thi   = -1.00;
      $norm  = -1.00;
      $cr    = -1.00;
    }

    # change directory
    chdir("$datadir/$obsid/$rootdir");

    # define file names
    $asol = sub_get_asol();
    if ($fail eq "yes") {
      print "## No asol file for $obsid\n";
      print LOGFILE "${obsid}: No asol file\n";
      chdir("$Bin");
      next;
    }

    # make sure we have events files to work with
    $evt = "${obsid}_evt2.fits";
    unless (-e $evt) {
      print "## No event file for $obsid\n";
      print LOGFILE "${obsid}: No event file\n";
      chdir("$Bin");
      next;
    }

    # get the ra and dec for the centroid
    sub_get_radec($evt,$asol);
    if ($fail eq "yes") {
      print "## No RA or Dec for $obsid\n";
      print LOGFILE "${obsid}: No ra or dec\n";
      chdir("$Bin");
      next;
    }

    # determine the exposure time for this observation
    $exposure = sub_get_info($evt,"EXPOSURE");
    @exposure = split(/\./,$exposure);
    $exposure = $exposure[0]/1000;
    if ($fail eq "yes") {
      print "## No exposure time for $obsid\n";
      print LOGFILE "${obsid}: no exposure time found\n";
      chdir("$Bin");
      next;
    }

    # find RASS R14, R45, R67
    $inner = "n%2Fa";
    $rawouter = $rmax*0.492/60/60;
    $outer = "$rawouter";
    $area = PI*(($rout**2.)-($rin**2.));
    $check = "no";
    while ($check ne "ok") {
      @rass = &sub_lynx($ra,$dec,$coordsys,$inner,$region,$outer,$area);
      if (@rass) {
	$check = "ok";
      } else {
	$outer = $outer+0.1;
	$outer = "$outer";
      }
    }
    $rat12 = $rass[0]/$cr*100;
    $rat45 = $rass[1]/$cr*100;
    $rat67 = $rass[2]/$cr*100;

    # determine the mode
    $mode = sub_get_info($evt,"DATAMODE");
    if ($fail eq "yes") {
      print "## No mode for $obsid\n";
      print LOGFILE "${obsid}: no mode found\n";
      chdir("$Bin");
      next;
    }

    # print tx model to XCMFILE and get lumin
    $xcmfile = "${obsid}_lumin.xcm";
    sub_make_xcmfile($nhmod,$model,$tx,$xcmfile);
    ($lum, $dum, $dum) = sub_run_xspec($xcmfile);

    # print tlo model to XCMFILE and get lumin
    $xcmfile = "${obsid}_lumin.xcm";
    sub_make_xcmfile($nhmod,$model,$tlo,$xcmfile);
    ($lumlo, $dum, $dum) = sub_run_xspec($xcmfile);

    # print thi model to XCMFILE and get lumin
    $xcmfile = "${obsid}_lumin.xcm";
    sub_make_xcmfile($nhmod,$model,$thi,$xcmfile);
    ($lumhi, $dum, $dum) = sub_run_xspec($xcmfile);

    # write to ref file
    pop(@data); # this removes the 'location' field
#    pop(@data); # this removes the 'aps' field
    push @data, @rass;
    sub_write_ref($outfile,@data);

    # change back to original directory
    unlink("$xcmfile");
    unlink("xautosav.xcm");
    chdir("$Bin");

    # finish-up
    print "## Done with $obsid\n";
    $counter--;
    print "## $counter left to go\n";
  }
}

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "## Can't open $infile\n";
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

sub read_specfile {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "## Can't open $infile\n";
  while (<INFILE>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    s/^\s+//;        # trim leading whitespace
    s/\s+$//;        # trim trailing whitespace
    @data = split;
    $info{$data[0]} = $_;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub sub_print_info {

  open(OUT,">$Bin/${outfile}");
  printf OUT "%-25s %6s %6s %6s %6s %7s %8s %6s %6s %6s "
    ."%7s %7s %7s %5s %8s %5s %6s %13s %13s %7s %8s %6s %6s %6s %8s %8s %8s\n",
      "#Name","ObsID","X","Y","Rmax","MinCts","z","Nh20","Tx","Fe","Lx44",
	"Lxlo","Lxhi","Chip","E_obs","Diff","Robs","RA","Dec","ExpT","Mode",
	  "R12","R45","R67","R12/CR%","R45/CR%","R67/CR%";
  close OUT;
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
    @globlist =  <pcad*asol*fits*>;
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

sub sub_get_info {

  # get and format keyword value from file
  my($file,$key) = @_;
  $value = `punlearn dmkeypar; dmkeypar ${file}+1 $key; pget dmkeypar value`;
  chomp($value);      # remove any newline
  $value =~ s/\s+//g; # remove white space
  $value =~ s/\'//g;  # remove quotes

  # check that it worked or return an error
  if ($value ne "" || $value > 0) {
    $fail = "no";
    return $value;
  } else {
    $fail = "yes";
  }
}

#######################
#######################

sub sub_lynx {

  my($ra,$dec,$coordsys,$inner,$region,$outer,$area) = @_;
  my($line,$r12,$r45,$r67,@rass,@dat);

  open(LYNX,"lynx -dump "
       ."\"http://heasarc.gsfc.nasa.gov/cgi-bin/Tools/xraybg/xraybg.pl?"
       ."Entry=${ra}%2C+${dec}"
       ."&NR=GRB%2FSIMBAD%2FNED"
       ."&CoordSys=${coordsys}"
       ."&radius=${outer}"
       ."&region=${region}"
       ."&inner_radius=${inner}"
       ."&results=integrate"
       ."&scaling=hist\" 2>&1 |");
  while(<LYNX>){
    chomp($line = $_);
    print "lynx: $line\n" if ($quiet eq "no");
    if ($line =~ /\(1\/4 keV\)/) {
      if ($line =~ /arcmin\^2$/) {
	@dat = split;
	push @rass, $dat[2]*$area*1e-6;
      }
    }
    if ($line =~ /\(3\/4 keV\)/) {
      if ($line =~ /arcmin\^2$/) {
	@dat = split;
	push @rass, $dat[2]*$area*1e-6;
      }
    }
    if ($line =~ /\(1.5 keV\)/) {
      if ($line =~ /arcmin\^2$/) {
	@dat = split;
	push @rass, $dat[2]*$area*1e-6;
      }
    }
  }
  close LYNX;
  return @rass;
}

#######################
#######################

sub sub_make_xcmfile {

  # input vaules
  my($nhmod,$model,$t,$xcmfile) = @_;

  # other local variables
  my($modstring,$line);

  # print to XCM file
  open(XCMFILE,">${xcmfile}");
  print XCMFILE "query yes\n";
  print XCMFILE "cosmo ${h0} ${q0} ${omegal}\n";
  print XCMFILE "dummyrsp $emin $emax\n";
  print XCMFILE "model wabs(mekal) & $nh,0 & $t,0 & 1.0 & $fe,0 & $z,0 & 0 & $norm,0\n";
  print XCMFILE "lumin $emin $emax $z err 100 90\n";
  print XCMFILE "tclout lumin\n";
  print XCMFILE "scan \$xspec_tclout \"%f %f %f\" lum lumlo lumhi\n";
  print XCMFILE "puts \"Hey lumin \$lum \$lumlo \$lumhi\"\n";

  # done with the xcm file, close
  close XCMFILE;
}

#######################
#######################

sub myprint {
    my $line;
    foreach $line (@_) {
        print $line if ($quiet eq "no");
        print XSPEC_INPUT $line;
    }
}

#######################
#######################

sub sub_run_xspec {

  my ($xcmfile) = @_;
  my ($parameters,$line,$done,$conlim,$params,@lum);

  # starts xspec (perl and read and write from/to it)
  # $pid is a global variable that can be used to kill xspec
  use IPC::Open3;
  $pid = open3(*XSPEC_INPUT,*XSPEC_OUTPUT,*XSPEC_ERR,"xspec11") || die "Can't run xspec\n";

  # open the xcmfile written earlier and feed to xspec
  myprint "\@$xcmfile\n";

  while (<XSPEC_OUTPUT>) {
    chomp;
    $line = $_;
    print "xspec: $line\n" if ($quiet eq "no");
    if ($line =~ m/^Hey lumin/) {
      @line = split(" ",$line);
      myprint "exit\n\n";
    }
  }
  close XSPEC_INPUT;
  close XSPEC_OUTPUT;
  close XSPEC_ERR;
  waitpid($pid,0);
  return ($line[2],$line[3],$line[4]);
}

#######################
#######################

sub sub_write_ref {

  my($ref,@data) = @_;
  open OUT, ">>/$Bin/$ref";
  printf OUT "%-25s %6s %6.0f %6.0f %6.0f %7.0f %8.4f %6.2f %6.2f %6.2f %7.3f "
    ."%7.3f %7.3f %5s %8.4f %5s %6.0f %13s %13s %7.1f %8s %6.4f %6.4f %6.4f %8.2f %8.2f %8.2f\n",
      $data[0],$data[1],$data[2],$data[3],$data[4],$data[5],$data[6],
	$data[7],$data[8],$data[9],$lum,$lumlo,$lumhi,$data[11],$data[12],
	  $data[13],$data[14],$ra,$dec,$exposure,$mode,$data[15],$data[16],$data[17],$rat12,$rat45,$rat67;
  close OUT;
}

#######################
#######################
