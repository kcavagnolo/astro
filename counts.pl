#! /usr/bin/perl -w

$regex    = "r2500-50";
$logfile  = "counts_${regex}.dat";
$datadir1 = "../acis/";                       # Location of /acis/ in relation to this script
$datadir2 = "/Volumes/MBRANE";                # Location of /acis/ in relation to this script
$datadir3 = "/Volumes/GALACTUS";                # Location of /acis/ in relation to this script
$rootdir  = "reprocessed/";                   # where to find the cluster specific data
$verb     = 2;

#######################
#######################

# read in the reference file
%refdata = get_data($ARGV[0]);

# store the script directory in $Bin
use FindBin qw($Bin);
use Cwd;

open(LOG,">temp");
printf LOG "%-25s\n","#Region: ".${regex};
printf LOG "%-25s %6s %10s\n","#Name","ObsID","Obscts";

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});

  # get obsid
  $name   = $data[0];
  $obsid  = $data[1];
  $loc    = $data[15];
  $datadir = $datadir1 if ($loc eq "NAZGUL");
  $datadir = $datadir2 if ($loc eq "MBRANE");
  $datadir = $datadir3 if ($loc eq "GALACTUS");

  # define the ccd to use and file names
  $evtfile = "${obsid}_exclude.fits";
  $bgdfile = "${obsid}_bgevt.fits";
  $source = "${obsid}_${regex}.reg";

  chdir("$datadir/$obsid/$rootdir/");

  # make sure we have events files to work with
  unless (-e $evtfile && -e $bgdfile && -e $source) {
    print LOG "## Missing files for $obsid ($name)\n";
    chdir($Bin);
    next;
  }

  # set badpix file
  set_ardlib($evtfile);

  # extract spectrum for obs background and deep background
  $obsrate = extract_obsbgd($evtfile,$bgdfile,$source);

  printf LOG "%-25s %6s %10i\n",$name,$obsid,$obsrate;

  # clean-up
  unlink("temp_cts.fits");
  unlink("obscts.log");

  # change back to original directory
  chdir("$Bin");

  print "## Finished ${obsid}\n";

}
close LOG;

# sum-up the counts from different obs but for the same object
open(A,"temp");
open(B,">${logfile}");
$ocl = "";
$total = 0.00;
while(<A>){
  chomp;
  next if (/^\#/);
  next if (/^$/);
  @line=split;
  $ncl = $line[0];
  if ($ncl eq $ocl) {
    $total = $total+$line[2];
  } else {
    printf B "%-20s %10i\n",$ocl,$total;
    $total = $line[2];
  }
  $ocl = $ncl;
}
printf B "%-20s %10i\n",$ocl,$total;
close A;
close B;
unlink("temp");
exit 0;

################
# Sub routines #
################

sub get_data {

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

sub set_ardlib {
    my($chips,@chips,$evtfile,$d,$curdir,$indir);
    $indir = cwd();
    $evtfile = shift;
    system("punlearn ardlib.par");

    # change to appropriate dir (they sometimes change the locations)
    # glob for matching file names
    chdir "../";
    $curdir = cwd();
    @dir = qw(reprocessed primary secondary);
    @infile = ();
    foreach $dir (@dir) {
	chdir $dir;
	@globlist = glob("*bpix1*");
	@globlist = map { "$dir/" . $_} @globlist if (@globlist);
	push @infile, @globlist;
	chdir "../";	
    }

    die "$obsid: No evt1 file\n" unless (@infile);
    $bpix   = shift @infile;

    # unzip if necesary
    if ($bpix =~ /gz$/) {
	system("gunzip -f $bpix");
	$bpix =~ s/\.gz$//;
    }

    # return the name
    chdir($curdir);

    # get the chips to use
    chdir("$rootdir");
    $chips = `dmkeypar $evtfile DETNAM ; pget dmkeypar value`;
    chdir("../");

    chomp($chips);
    $chips =~ s/ACIS\-//;
    @chips = split('', $chips);
    foreach $d (@chips) {
	$command = "pset ardlib AXAF_ACIS${d}_BADPIX_FILE=${curdir}/$bpix\[BADPIX${d}]";
	system($command);
    }

    chdir $indir;
}

#######################
#######################

sub extract_obsbgd {

  my($evtfile,$bgdfile,$source) = @_;

  $command = "punlearn dmextract; dmextract infile=\"${evtfile}\[bin sky=region(${source})]\" outfile=temp_cts.fits "
    ."bkg=\"${bgdfile}\[bin sky=region(${source})]\" clobber=yes verbose=$verb";
  system($command);

  open(PROFILE,">a.pro");
  print PROFILE "a=mrdfits('temp_cts.fits',1)\n";
  print PROFILE "openw,1,'obscts.log'\n";
  print PROFILE "printf,1,num2str(total(a.net_counts,4))\n";
  print PROFILE "close,1\n";
  print PROFILE "exit\n";
  close PROFILE;
  system("\$IDL_DIR/bin/idl a.pro");

  # store those counts as a variable
  my $cts = use_dmlist("obscts.log");

  # check that there are counts
  if ($cts == 0) {
    print "${obsid}: no counts in observation\n";
    $rate = 0;
    return $rate;
  }

  # return the count rate per chip
  my $rate = $cts;

  return $rate;
}

#######################
#######################

sub use_dmlist {

  my($infile) = @_;
  my(@line,$value);

  open(FILE,$infile);
  while(<FILE>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;  # trim leading whitespace
    s/\s+$//;  # trim trailing whitespace
    @line = split;
    $value = $line[0];
  }
  close FILE;
  return $value;
}

#######################
#######################
