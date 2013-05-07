#!/usr/bin/perl -w

$datadir  = "/mnt/SINISTER";
$rootdir  = "reprocessed";

use Cwd;
use FindBin qw($Bin);

#Read in the reference file
%refdata = read_file($ARGV[0]);

# Go through each cluster
{
  foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get values specific to each cluster
    $obsid = $data[1];

    # change dir
    chdir("$datadir/$obsid/$rootdir/");

    # files to work with
    @ext = ("${obsid}*expmap.fits","${obsid}*norm.fits","${obsid}*img.fits");

    # perform the put calls
    &sub_zip_files();

    # finish-up
    print "## Done with $obsid\n";
    $counter--;
    print "## $counter left to go\n";
    chdir("$Bin");
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
  open(INFILE,$infile) || die "\n## $obsid:  Can't open $infile\n";
  while (<INFILE>) {
    chomp;
    next if (/^\#Name/); # skip comment lines
    next if (/^$/);  # skip blank lines
    s/^\s+//;        # trim leading whitespace
    s/\s+$//;        # trim trailing whitespace
    @data = split;
    $name = join "_", $data[0],$data[1];
    $info{$name} = $_;
    $counter++;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub sub_zip_files {

  # get files to work with
  @files = ();
  foreach $ext (@ext) {
    @glob = glob("*${ext}");
    foreach $a (@glob) {
      push @files, $a;
    }
  }

  # zip the files
  foreach $file (@files) {
    print "GZipping $file\n";
    system("gzip $file");

  }
}

#######################
#######################
