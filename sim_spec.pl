#!/usr/bin/perl -w
#
# NAME:
#     sim_spec.pl
#
# PURPOSE:
#
# EXPLANATION:
#     This script takes in the properties of an object (ie: tx, fe, lbol,
#     nh20, etc), observation specific ARF and RMF, and simulates
#     a spectrum using XSpec's 'fakeit' command.
#
#     This script assumes the following directory structure:
#     all pertinent Chandra data files are in a dir labeled with
#     the obsid, which is then in a dir labeled acis/. The location
#     of acis/ relative to the dir from which this script is run is
#     set with the variable $datadir.
#
#     e.g.: for Abell 644 obsid 2211, this script will look to
#     $datadir/acis/2211/$rootdir for all the files needed to complete
#     the data reduction
#
#
# CALLING SEQUENCE:
#     sim_spec.pl <reference list>
#
# INPUTS:
#     <reference list> = file containing information about each cluster
#     the assumed format for the list is as follows:
#     in the case of X and Y being the centroid position in pixels and Rmax in pixels
#     Name            ObsID      X      Y   Rmax  MinCts        z   Nh20     Tx     Fe   Lbol  Chip    E_obs  Diff
#     ABELL_0611       3194   4131   3943    360    5000   0.2880   4.99   1.23   0.30  45.67    s3   1.5528     n
#     ABELL_2537       4962   3949   4157    360    5000   0.2950   4.26   1.23   0.30  45.67    s3   1.5444     n
#
# OUTPUTS:
#     faked spectrum:     <obsid>_<energy band>_spec.fak
#     xcm file for xspec: <obsid>_<energy band>_fak.xcm
#     log of creation:    <obsid>_<energy band>_fak.xcm.log
#     model parameters:   <obsid>_<energy band>_fak.xcm.model
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

# set system parameters
$datadir1 = "../acis/";                 # Location of /acis/ in relation to this script
$datadir2 = "/Volumes/MBRANE";          # Location of /acis/ in relation to this script
$datadir3 = "/mnt/SINISTER";            # Location of /acis/ in relation to this script
$rootdir  = "reprocessed/";             # where to find the cluster specific data
$specdir  = "$ENV{'HOME'}/research/me_temp_proj/me_fits/spectra";         # where to store sim'ed spectra
$quiet    = "yes";                        # silence screen output of Xspec
$notify   = "no";                         # should you be notified when the script is done?
$mailto   = "cavagnolo\@pa.msu.edu";      # email address to send notifications
$datfile  = "$ENV{'HOME'}/research/me_temp_proj/me_fits/dat/c2fits_final_r2500-50_fefree_7-7.dat";

# set sim parameters
$rmold    = "yes";
$xspecver = "xspec11";       # version of Xspec to invoke
$runname  = "r2500-50";       # name of the source region to simulate
$model    = "mekal";          # model to use in faking spectra
$nhmod    = "wabs";           # e.g., wabs, tbabs, ph
$grpcts   = "25";             # number of counts to group spectrum by
$src      = "src1";           # extension of the RMF and ARF spectral files to use
$bg       = "bgd_adj";        # extension of the BGD spectral files to use
$fetie    = "yes";            # set to "yes" for tying metallicity components in 2T model
$h0       = "70";             # cosmology: value of H_0
$q0        = 0.0;                              # norm. acceleration (ignored by Xspec)
$omegal   = "0.7";            # cosmology: value of Omega_lambda
$syserr   = "0.00";           # % systematic error to add
$con      = 5;                # convergance value as percent of fake/real count rate
@tx2      = ("0.5","0.75","1.0","2.0","3.0");
$txcrit   = 4;                # how many of the elements in @tx2 will we iterate through? remember... 0,1,2,3
$etafid   = 40;               # where to start eta*normbf
$etacrit  = 5;                # where to end eta*normbf

#######################
#######################
##   Main Program    ##
#######################
#######################

# set some parameters
$ENV{'PGPLOT_TYPE'} = "/null";

# check input params
$nargs = @ARGV;
die "Incorrect number of parameters\n" if ($nargs != 1);

# read in the reference file
%refdata = sub_get_data($ARGV[0]);
%fitdata = sub_get_data(${datfile});

# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# open a log file
open(LOGFILE,">>sim_spec_${runname}.log");
print LOGFILE "###### Started simulating spectra at ",scalar(localtime)," ######\n";
printf LOGFILE "%-20s %6s %6s %6s %6s %10s %10s %10s %10s %10s\n","# Cluster","ObsID","Tx1","Tx2","Eta","RealCTR","FakeCTR","Norm1","Norm2","N2/N1";

# go through each cluster in reference list
foreach $key (sort keys %refdata) {

  # get values from ref file
  @ref = split(/\s+/,$refdata{$key});
  $name  = $ref[0];
  $obsid = $ref[1];
  $z     = $ref[6];
  $loc   = $ref[15];
  $datadir = $datadir1 if ($loc eq "NAZGUL");
  $datadir = $datadir2 if ($loc eq "MBRANE");
  $datadir = $datadir3 if ($loc eq "GALACTUS");

  # check for fit data
  unless (exists $fitdata{$key}) {
    print "## Missing fit info for ${obsid} ${name}, check logfile for report.\n";
    print LOGFILE "#########################\n";
    print LOGFILE "# ${obsid}: no fit data in ${datfile}\n";
    chdir("$Bin");
    $offender = "no fit data";
    sub_send_mail("error",$offender) if ($notify eq "yes");
    next;
  }

  # get values from dat file
  @fit = split(/\s+/,$fitdata{$key});
  $nh       = $fit[4]*1e-2;
  $tx       = $fit[7];
  $fe       = $fit[10];
  $normbf   = $fit[13];
  $realrate = $fit[23];

  # change directory
  chdir("$datadir/$obsid/$rootdir");

  # define some names
  $bgd  = "${name}_${obsid}_${runname}_${bg}.pi";
  $rmf  = "${name}_${obsid}_${runname}_${src}.wrmf";
  $arf  = "${name}_${obsid}_${runname}_${src}.warf";

  # exit via next if there are errors
  unless ((-e $rmf && -e $arf && -e $bgd)
	  || $normbf <= 0 || $normbf eq "" || $realrate <= 0) {
    print "## Missing files for ${obsid}, check logfile for report.\n";
    if ($normbf <= 0 || $normbf eq "" || $realrate <= 0) {
      print LOGFILE "# ${obsid}: bad fit data, check ${datfile}\n";
      $offender = "bad fit data";
    } else {
      print LOGFILE "#########################\n";
      print LOGFILE "# ${obsid}: no BGD file for ${runname}\n" unless (-e $bgd);
      print LOGFILE "# ${obsid}: no ARF file for ${runname}\n" unless (-e $arf);
      print LOGFILE "# ${obsid}: no RMF file for ${runname}\n" unless (-e $rmf);
      $offender = "no arf and/or rmf and/or bgd";
    }
    chdir("$Bin");
    sub_send_mail("error",$offender) if ($notify eq "yes");
    next;
  }

  # get rid of spec from previous runs
  if ($rmold eq "yes") {
      @keys = ("${obsid}_${runname}_*_grp.fak",
	       "${obsid}_${runname}_*_spec.fak",
	       "${obsid}_${runname}_*_bkg.*",
	       "${obsid}_${runname}_*_fakspec.ps",
	       "${obsid}_${runname}_*_fak.xcm");
      foreach $key (@keys) {
	  @deadfiles = glob("$key");
	  foreach $d (@deadfiles) {
	      print "## REMOVING: $d\n";
	      unlink($d);
	  }
      }
  }

  # determine the exposure time for this observation
  $exposure = sub_get_expotime();
  if ($fail eq "yes") {
    print LOGFILE "#########################\n";
    print LOGFILE "# ${obsid}: no exposure time found\n";
    chdir("$Bin");
    $offender = "no exposure time";
    sub_send_mail("error",$offender) if ($notify eq "yes");
    next;
  }

  # initialize the tx counter
  $txiter = 0;
  $txcrit = 0 if ($txcrit eq "");
  while ($txiter <= $txcrit) {

    # don't bother with T2 > T1
    last if ($fidtx2[$txiter] >= $tx);

    # initialize the eta counter
    $eta = $etafid;
    while ($eta >= $etacrit) {

      # initialize the FAIL control
      $fail    = "no";

      # build some other variables
      $norm1   = 0.5;
      $norm2   = ($eta/100.0)*$normbf if ($normbf > 0);
      $otx     = $tx2[$txiter];
#      $tx2     = $tx2[$txiter]/(1+${z});                 # the 1+z is to account for cosmo. redshift
      $tx2     = $tx2[$txiter];
      $etaf    = $eta/100.0;                             # this step is from when I switched from nomenclature of 0.95 to 95
      $root    = "${obsid}_${runname}_${otx}_${etaf}";
      $fak     = "${root}_spec.fak";
      $fakgrp  = "${root}_spec_grp.fak";
      $xcmfile = "${root}_fak.xcm";

      # intialize some counters
      $crit = $con+100;  # initial value of $crit, ensures that the loop alays runs
      $oldfrac = 0.0001; # initial percentage of real/fake rate
      $iter = 0;         # counter for number of iterations where real/fake < 1%, prevents stagnated faking
      $n = 0;            # counter for number of total iterations, prevents runaway

      print "\n## Working on ${obsid}, Tx2 = ${otx}keV, Eta = ${etaf}\n";

      # loop through the fakeit commands to get
      # (fake ct rate)/(real ct rate) <= $con
      while ($crit > $con && $iter < 5 && $n < 25) {

	# print model to XCMFILE, get parameters for con limit determination
	sub_make_xcmfile($nhmod,$model,$xcmfile,$norm1,$norm2);

	# run xspec (see subroutine sub_run_xspec) with a timeout
	# $frac is ratio of fake to real
	$frac = sub_run_xspec($xcmfile,$rmf,$arf,$fak,$exposure,$realrate,$root);

	# calculate the convergance criteria
	$crit = abs($frac-1)*100;

	# if the last iteration was within 5% of the present iteration
	# increment a counter to prevent stagnation of norm2 calc
	if ((abs($oldfrac/$frac)-1) <= 0.01) {
	  $iter++;
	} else {
	  $iter = 0;
	}

	# check that the last iteration did not satisfy the convergance criterion
	# for cases where $crit is greater than 0
	if ($frac > 1) {
	  # increase the value of norm1 and fakeit again
	  if ($frac >= 1.5) {
	    $norm1 = $norm1 - 0.75*$norm1;
	  }
	  elsif ($frac >= 1.2) {
	    $norm1 = $norm1 - 0.40*$norm1;
	  }
	  elsif ($frac >= 1.1) {
	    $norm1 = $norm1 - 0.15*$norm1;
	  }
	  elsif ($frac >= 1.05) {
	    $norm1 = $norm1 - 0.10*$norm1;
	  }
	  elsif ($frac < 1.05) {
	    $norm1 = $norm1 - 0.05*$norm1;
	  }
	}

	# check that the last iteration did not satisfy the convergance criterion
	if ($frac < 1) {
	  # increase the value of norm1 and fakeit again
	  if ($frac <= 0.5) {
	    $norm1 = $norm1 + 0.75*$norm1;
	  }
	  elsif ($frac <= 0.8) {
	    $norm1 = $norm1 + 0.40*$norm1;
	  }
	  elsif ($frac <= 0.9) {
	    $norm1 = $norm1 + 0.15*$norm1;
	  }
	  elsif ($frac <= 0.95) {
	    $norm1 = $norm1 + 0.10*$norm1;
	  }
	  elsif ($frac > 0.95) {
	    $norm1 = $norm1 + 0.05*$norm1;
	  }
	}

	# store the value of the present $frac
	$oldfrac = $frac;

	# increment the overflow counter
	$n++;

	# echo the progress of the fitter in quiet mode
	$out1 = sprintf("%3.2f",abs($crit));
	$out2 = sprintf("%.6f",$norm1);
	$out3 = sprintf("%.6f",$norm2);
	if ($quiet eq "yes") {
	  print "## fake/real: $out1\% ; ",
	    "norm1: $out2 ; ",
	      "norm2: $out3\n";
	}
      }

      # group the spectra to the proper number of counts
      $command = "grppha infile=\"$fak\" outfile=\"\!$fakgrp\" chatter=0 comm=\"group min $grpcts & exit\"";
      system($command);

      # print fitting info to log file
      printf LOGFILE "%-20s %6s %6.2f %6.2f %6.2f %10.6f %10.6f %10.3e %10.3e %10.4f\n",$name,$obsid,$tx,$otx,$etaf,$realrate,$fakerate,$norm1,$norm2,$norm2/$norm1;

      # build array for psnuping ps files
      push(@ps,"${root}_fakspec.ps");

      # increment the eta counter
      if ($eta > 20) {
        $eta -= 10;
      } else {
        $eta -= 5;
      }
    }

    #increment the tx counter
    $txiter++;
  }

  # put the ps files together
  $p = join " ",@ps;
  system "cat $p > temp.123";
  system "ps2ps temp.123 temp.234";
  system "psnup -4 temp.234 junk.ps";

  # take care of gif image
  mkdir("$specdir",0777) unless (-d "$specdir");
  system("mv -f junk.ps $specdir/${obsid}_fakspec.ps");

  # clean-up the resulting mess of files
  @ps = undef;
  unlink <*fakspec*.ps>;
  unlink <*spec.fak>;
  unlink <*fak*.xcm>;
  unlink <xautosav*>;
  unlink("temp.123");
  unlink("temp.234");
  unlink("junk.ps");

  # change back to original directory
  chdir("$Bin");
}

#close the logfile
print LOGFILE "###### Finished simulating spectra ",scalar(localtime)," ######\n\n";
print "\n###### Finished simulating spectra ",scalar(localtime)," ######\n\n";
close LOGFILE;

# email user that the task is complete
sub_send_mail("complete","") if ($notify eq "yes");

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_get_data {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## Can't open $infile\n";
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

sub myprint {
  my $line;
  foreach $line (@_) {
    print $line unless ($quiet eq "yes");
    print XSPEC_INPUT $line;
  }
}

#######################
#######################

sub sub_make_xcmfile {

  # input vaules
  my($nhmod,$model,$xcmfile,$norm1,$norm2) = @_;

  # other local variables
  my($modstring,$line);

  # clean up any files left over from previous runs
  unlink "$xcmfile";

  # print to XCM file
  open(XCMFILE,">$xcmfile");
  print XCMFILE "query yes\n";
  print XCMFILE "cosmo ${h0} ${q0} ${omegal}\n";

  # MEKAL+MEKAL model###################################################
  if ($model eq "mekal") {
    $modstring = "${nhmod}(mekal + mekal)";
    #            NH22   Tx   nHmod  Z     red  swi  norm     Tx2  nhmod2  Z2  red2 swi2 norm2
    if ($fetie eq "yes") {
      $moline = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & $norm1 & $tx2 & 1.0 & =4 & =5 & 0 & $norm2 /*";
    } else {
      $moline = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & $norm1 & $tx2 & 1.0 & $fe & =5 & 0 & $norm2 /*";
    }
    # Unknown model or error##############################################
  } else {
    die "Unknown model: $model\n";
  }

  # print the fakeit commands
  $fakline = "fakeit $bgd & $rmf & $arf & y & \\n & $fak & $exposure /*";

  # print out model
  print XCMFILE "model $modstring $moline\n",
  "$fakline\n";

  # add in systematic error
  print XCMFILE "systematic $syserr\n" unless ($syserr == 0);
  print XCMFILE "tclout rate\n";
  print XCMFILE "puts \"Hey rate \$xspec_tclout\"\n";

  # done with the xcm file, close
  close XCMFILE;
}

#######################
#######################

sub sub_run_xspec {

  my ($xcmfile,$rmf,$arf,$fak,$exp,$realrate,$root) = @_;

  # get rid of old files
  unlink("$fak");
  unlink("${xcmfile}.model");
  unlink("${xcmfile}.log");
  unlink("${root}_fakspec.ps");

  # starts xspec (perl and read and write from/to it)
  # $pid is a global variable that can be used to kill xspec
  use IPC::Open3;
  $pid = open3(*XSPEC_INPUT,*XSPEC_OUTPUT,*XSPEC_ERR,"$xspecver") || die "Can't run xspec\n";

  # open the xcmfile written earlier and feed to xspec
  myprint "\@${xcmfile}\n";
  myprint "query no\n";
  myprint "tclout rate\n";
  myprint 'puts "Rate $xspec_tclout"',"\n";

  while (<XSPEC_OUTPUT>) {
    chomp($line = $_);
    print "xspec: $line\n" unless ($quiet eq "yes");
    if ($line =~ m/^Hey rate/) {
      @fakerate = split(/\s+/,$line);
      $fakerate = $fakerate[2];
      $fakerate =~ s/\+\/\-//; # remove +/- on some values
      $frac = $fakerate/$realrate;

      # make a gif image of the spectrum
      myprint
	"setplot energy\n",
	  "setplot rebin 5 10\n",
	    "notice **-**\n",
	      "ignore **-0.3 10.0-**\n",
		"iplot data resid\n",
		  "label top $name $obsid\n",
		    "time off\n",
		      "cpd ${root}_fakspec.ps/vcps\n",
			"plot\n",
			  "cpd /null\n",
			    "exit\n";

      # all done quit XSPEC
      myprint "exit\n\n";
    }
  }

  close XSPEC_INPUT;
  close XSPEC_OUTPUT;
  close XSPEC_ERR;
  waitpid($pid,0);
  return $frac;

}

#######################
#######################

sub sub_get_expotime {

  # get and format keyword value from file
  my($evt2) = "${obsid}_exclude.fits";
  my $value = `punlearn dmkeypar; dmkeypar ${evt2} EXPOSURE; pget dmkeypar value`;
  chomp($value);      # remove any newline
  $value =~ s/\s+//g; # remove white space
  $value =~ s/\'//g;  # remove quotes

  # check that it worked or return an error
  if ($value > 0) {
    $fail = "no";
    return $value;
  } else {
    $fail = "yes";
  }
}

#######################
#######################

sub sub_send_mail {
    my($status,$offender) = @_;

    if ($status eq "complete") {
        open (MAIL,"|mail -s \"\[Pipeline\] sim_spec.pl is finished\" $mailto,");
        print MAIL
            "Greetings User,\n\n",
            "HOORAY!\n",
            "The perl script for simulating spectra\n",
            "has finished. Check sim_spec_${runname}.log\n",
            "file for any errors. If no errors have occurred\n",
            "then proceed to the next step in data reduction.\n\n",
            "Cheers\n",
            "Ken Cavagnolo\n";
        close MAIL;
    }

    if ($status eq "error") {
        open (MAIL,"|mail -s \"\[Pipeline\]make_profile.pl has erred\" $mailto,");
        print MAIL
            "Greetings User,\n\n",
            "I have bad news :\(\n",
            "The perl script sim_spec.pl has erred.\n",
            "The script has either died or moved on to another cluster.\n",
            "This error is for ${obsid} created by ${offender}.\n",
            "Check sim_spec_${runname}.log for more detail.\n\n",
            "Cheers,\n",
            "Ken Cavagnolo\n";
        close MAIL;
    }
    return 0;
}

#######################
#######################
