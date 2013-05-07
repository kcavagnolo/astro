#!/usr/bin/perl -w

$datadir  = "../acis";
@rootdir  = ("reprocessed/","primary/","secondary");
$destroot = "/home/cavagnolo";
$action   = "put";
$host     = "tolkien.pa.msu.edu";
$user     = "cavagnolo";
$psswd    = "127gambit";
$mode     = "binary";

use Net::FTP;
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
    $name  = $data[0];
    $obsid = $data[1];

    @ext = ("${obsid}_evt2","${obsid}_exclude","${obsid}_bgevt","asol","msk1","bpix1");
#    @ext = ("${name}*${obsid}_r2500","${name}*${obsid}_r5000","${obsid}*inner","${obsid}_r*.reg");

    # login or die
    $ftp = Net::FTP->new($host) or warn $ftp->message;
    if ($ftp->login($user,$psswd)) {
      print "## Logged into $host\n";
    } else {
      print "## ERROR: Login failed\n";
      $ftp->quit();
      die;
    }

    # set the transfer mode
    $ftp->binary if ($mode eq "binary");
    $ftp->ascii if ($mode eq "ascii");

    # get files
    &sub_get_files();

    # perform the put calls
    &sub_put_files() if ($action eq "put");

    # finish-up
    print "## Done with $obsid\n";
    $counter--;
    print "## $counter left to go\n";
    $ftp->quit();

    # go home
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

sub sub_get_files {

  # get files to work with
  @files = ();
  @names = ();
  foreach $rootdir (@rootdir) {
    $dirs = "$datadir/$obsid/$rootdir";
    foreach $ext (@ext) {
      @glob = glob("$dirs/*${ext}*");
      foreach $a (@glob) {
	$name = $a;
	$name =~ s/$dirs\///;
	push @names, $name;
	push @files, $a;
      }
    }
  }
}

#######################
#######################

sub sub_put_files {

  # change to the destination directory
  $ftp->cwd($destroot);
  $ftp->mkdir($obsid) unless ($ftp->cwd($obsid));
  $ftp->cwd($obsid);
  $ldir = $ftp->pwd();
  print "ftp: Working in $ldir\n";

  # put the files after checking for their existence
  $ch = 0;
  foreach $file (@files) {
    @check = $ftp->ls($names[$ch]);
    if (@check) {
      print "$names[$ch] already exists on host\n";
    } else {
      $ftp->$action($file);
      print "ftp: putting $file\n";
    }
    $ch++;
  }
}

#######################
#######################
