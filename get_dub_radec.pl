$output   = "centroids.dat";
$datadir1 = "../acis/";                       # Location of /acis/ in relation to this script
$datadir2 = "/Volumes/MBRANE";                # Location of /acis/ in relation to this script
$datadir3 = "/Volumes/GALACTUS";              # Location of /acis/ in relation to this script

use Cwd;
use FindBin qw($Bin);
use Math::Complex;

# Read in the reference file
%refdata = sub_read_file($ARGV[0]);

open(NEWREF,">$Bin/$output");
printf NEWREF "%-25s %6s %15s %15s %6s %6s\n","#Name","ObsID","RA","Dec","X","Y";
close NEWREF;

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

  # aspect solution for ref obs of merged file
  @asol = glob("$datadir/$obsid[0]/primary/pcad*asol*.fits*");
  $asol = $asol[0];
  $evt  = "$datadir/$obsid[0]/reprocessed/$obsid[0]_evt2.fits";
  $command = "punlearn dmcoords; dmcoords $evt $asol x=$x y=$y opt=sky";
  system($command);
  $ra = `pget dmcoords ra`;
  $dec = `pget dmcoords dec`;
  $ra =~ s/^\s+//;
  $ra =~ s/\s+$//;
  $dec =~ s/^\s+//;
  $dec =~ s/\s+$//;
  print "## Found fiducial RA: $ra and Dec: $dec\n";

  foreach $obs (@obsid) {
    next if ($obs eq "0000");
    undef @asol;
    @asol = glob("$datadir/$obs/primary/pcad*asol*.fits*");
    $asol = $asol[0];
    $evt  = "$datadir/$obs/reprocessed/${obs}_evt2.fits";
    $command = "punlearn dmcoords; dmcoords $evt $asol ra=$ra dec=$dec opt=cel";
    system($command);
    my $nx = `pget dmcoords x`;
    my $ny = `pget dmcoords y`;
    $nx =~ s/^\s+//;
    $nx =~ s/\s+$//;
    $ny =~ s/^\s+//;
    $ny =~ s/\s+$//;
    print "converted $ra --> $nx :: $dec --> $ny for $obs\n";
    open NEWREF, ">>/$Bin/$output";
    printf NEWREF "%-25s %6s %15s %15s %6i %6i\n",$name,$obs,$ra,$dec,$nx,$ny;
    close NEWREF;
  }
}
exit 0;

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
