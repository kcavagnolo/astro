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

$evtext   = "dmerged";
$binning  = "1";
$emin     = "500";
$emax     = "2500";
$kernelspec = "lib:gaus(2,1,1,3,3)";
$method   = "fft";
$verb     = 1;
$rootdir  = "reprocessed/";

#######################
#######################
##   Main Program    ##
#######################
#######################

# reference array for all chip ids
%chip_id = ("i0" =>"0", "i1" =>"1", "i2" =>"2", "i3" =>"3", "s0"
            =>"4", "s1" =>"5", "s2" =>"6", "s3" =>"7", "s4" =>"8",
            "s5" =>"9");

# check the number of arguments given
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# load useful libraries
# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# read in the reference file
%refdata  = sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
{
  foreach $key (sort keys %refdata) {

      # split up the data line
      @data = split(/\s+/,$refdata{$key});

      # get values specific to each cluster
      $fail    = "no";
      $obsid   = $data[1];
      $id      = $data[11];
      $datadir = $data[15];

      # set some file name
      $evtfile = "${obsid}_${evtext}.fits";
      $smimg   = "${obsid}_smooth.fits";

      # change directory
      chdir("$datadir/$obsid/$rootdir");

      # generate image
      sub_make_img($evtfile);
      if ($fail eq "yes") {
	  chdir("$Bin");
	  open  ERRFILE,">>err_montage.log";
	  print "## ${obsid} # failure in make_img\n";
	  print ERRFILE "${obsid} # failure in make_img\n";
	  close ERRFILE;
	  next;
      };

      # smooth the image
      sub_make_smooth("img.fits",$smimg);
      if ($fail eq "yes") {
	  chdir("$Bin");
	  open  ERRFILE,">>err_montage.log";
	  print "## ${obsid} # failure in make_smooth\n";
	  print ERRFILE "${obsid} # failure in make_smooth\n";
	  close ERRFILE;
	  next;
      };

      # clean-up
      unlink<"img.fits">;

      # change back to original directory
      chdir("$Bin");
  }
}

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};

# exit clean
exit 0;

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

sub sub_make_img {

    #input params
    my($evt) = @_;

    # make a region containing entire chip in sky coords
#     if ($id =~ /s/) {
# 	$command = "dmcopy \"$evt\[energy=$emin:$emax\]\[ccd_id=$chip_id{$id}\]\[bin sky=$binning\]\""
# 	    ." img.fits clobber=yes verbose=$verb";
# 	system($command);
#     } else {
# 	$command = "dmcopy \"$evt\[energy=$emin:$emax\]\[ccd_id=0,1,2,3\]\[bin sky=$binning\]\""
# 	    ." img.fits clobber=yes verbose=$verb";
# 	system($command);
#     }
    $command = "dmcopy \"$evt\[energy=$emin:$emax\]\[bin sky=$binning\]\""
	." img.fits clobber=yes verbose=$verb";
    system($command);

    # check that it worked
    if (-e "img.fits") {
	print "## Images creation complete\n";
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_make_smooth {

    #input params
    my($img,$out) = @_;

    # make a region containing entire chip in sky coords
    $command = "aconvolve $img $out kernelspec=\"$kernelspec\" method=\"$method\" clobber=yes verbose=$verb";
    system($command);

    # check that it worked
    if (-e $out) {
        print "## Smoothing complete\n";
    } else {
        $fail = "yes";
    }
}

#######################                                                                                                                                                            
#######################                     
