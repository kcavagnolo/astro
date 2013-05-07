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

# set system parameters
$quiet    = "yes";            # silence screen output of Xspec
$xspecver = "xspec11";        # version of Xspec to invoke
$model    = "mekal";          # model to use in faking spectra
$nhmod    = "wabs";           # e.g., wabs, tbabs, ph
$grpcts   = "25";             # number of counts to group spectrum by
$h0       = "70";             # cosmology: value of H_0
$q0        = 0.0;                              # norm. acceleration (ignored by Xspec)
$omegal   = "0.7";            # cosmology: value of Omega_lambda
$syserr   = "0.00";           # % systematic error to add
$con      = 5;                # convergance value as percent of fake/real count rate
$etafid   = 40;               # where to start eta*normbf
$etacrit  = 2;                # where to end eta*normbf
$etastep  = 2;
@fidtx2   = ("0.5","0.75","1.0",
	     "1.25","1.50","1.75","2.0",
	     "2.25","2.50","2.75","3.0");
$rootdir  = "$ENV{'HOME'}/research/redux/temp4/";
$nh = 0.03;
$tx = 5.0;
$z = 0.1;
$fe = 0.3;
$normbf = 0.003;
$respdir = "$ENV{'HOME'}/research/redux/scripts/";
$arf = "acisi_aimpt_cy10.arf";
$rmf = "acisi_aimpt_cy10.rmf";
$exposure = 336000;
$realrate = 0.3591;

#######################
#######################
##   Main Program    ##
#######################
#######################

# set some parameters
$ENV{'PGPLOT_TYPE'} = "/null";

# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# change directory
chdir("$rootdir");

# get rsp
system("cp $respdir/$arf .");
system("cp $respdir/$rmf .");

# exit via next if there are errors
unless (-e $rmf && -e $arf) {
    print "## Missing files check logfile for report.\n";
    chdir("$Bin");
    die;
}

# initialize the tx counter
$txiter = 0;
$txcrit = scalar(@fidtx2)-1;
while ($txiter <= $txcrit) {

    # don't bother with T2 > T1
    last if ($fidtx2[$txiter] >= $tx);

    # initialize the eta counter
    $eta = $etafid;
    while ($eta >= $etacrit) {

      # build some other variables
      $norm1   = 0.5;
      $norm2   = ($eta/100.0)*$normbf;
      $otx     = $fidtx2[$txiter];
      $tx2     = $fidtx2[$txiter];
      $etaf    = $eta/100.0;                             # this step is from when I switched from nomenclature of 0.95 to 95
      $root    = "faked_${otx}_${etaf}";
      $fak     = "${root}_spec.fak";
      $fakgrp  = "${root}_spec_grp.fak";
      $xcmfile = "${root}_fak.xcm";

      system("rm -f $fak $fakgrp $xcmfile");

      # intialize some counters
      $crit = $con+100;  # initial value of $crit, ensures that the loop alays runs
      $oldfrac = 0.0001; # initial percentage of real/fake rate
      $iter = 0;         # counter for number of iterations where real/fake < 1%, prevents stagnated faking
      $n = 0;            # counter for number of total iterations, prevents runaway

      print "\n## Working on Tx2 = ${otx}keV, Eta = ${etaf}\n";

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
	    $norm1 = $norm1 - 0.05*$norm1;
	  }
	  elsif ($frac < 1.05) {
	    $norm1 = $norm1 - 0.025*$norm1;
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
	    $norm1 = $norm1 + 0.05*$norm1;
	  }
	  elsif ($frac > 0.95) {
	    $norm1 = $norm1 + 0.025*$norm1;
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

      # build array for psnuping ps files
      push(@ps,"${root}_fakspec.ps");

      # increment the eta counter
      $eta -= $etastep;
    }

    #increment the tx counter
    $txiter++;
  }

  # put the ps files together
  $p = join " ",@ps;
  system "cat $p > temp.123";
  system "ps2ps temp.123 temp.234";
  system "psnup -4 temp.234 junk.ps";

  system("mv -f junk.ps allfak.ps");

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


# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};
exit 0;

#######################
#######################
##   Sub-Routines    ##
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
    $moline = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & $norm1 & $tx2 & 1.0 & =4 & =5 & 0 & $norm2 /*";
    # Unknown model or error##############################################
  } else {
    die "Unknown model: $model\n";
  }

  # print the fakeit commands
  $fakline = "fakeit none & $rmf & $arf & y & \\n & $fak & $exposure /*";

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
		  "label top $fak\n",
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
