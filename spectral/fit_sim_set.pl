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

# set some global parameters
$quiet     = "yes";
$rootdir   = "../temp4/";              # where to find the cluster specific data

# fitting parameters
$iter       = 1000;                       # the number of iterations XSPEC should run to 'fit'
$converge   = 0.01;                       # the convergance criterium for the 'fit statistic' used
$ntrial     = 100;                        # number of trials in the error calculation
$toler      = 0.05;                       # tolerance for the fit statistic

# details of fitting
@eming     = ("0.7","2.0");              # min and max energy ranges for fitting,
$emax      = "7.0";                      # needs to be a string so PERL don't cut off decimal pts.
$nhmod     = "wabs";                     # e.g., wabs,tbabs, ph
$freeze_nh = "yes";                      # fix nh to the galactic value? "yes" or "no"
$freeze_fe = "no";                       # keep fe at specified level, shouldn't be "yes" often
$h0        = 70;                         # cosmology: H_0
$q0        = 0.0;                              # norm. acceleration (ignored by Xspec)
$omegal    = 0.7;                        # cosmology: omega_lambda
$timeout   = 18000;                      # seconds until kills xspec job
$syserr    = "0.00";                     # % systematic error to add
$stat      = "chi";                      # statistic to use in fitting: cs
$conlevel  = "2.71";                     # compute confidence intervals:
                                         # 1.0 = 68% (1-sigma), 2.71 = 90% (1.6-sigma), 4.0 = 95.5% (2-sigma),
                                         # 6.63 = 99% (2.6-sigma), 9.0 = 99.7% (3-sigma)

$name  = "fake_set";
$obsid = "0000";
$z     = 0.1;
$nh    = 0.03;
$tx    = 5.0;
$fe    = 0.3;
$txbf     = 5.0;
$txbflo   = 5.0;
$txbfhi   = 5.0;
$fe       = 0.3;
$normbf   = 0.003;
$normbflo = 0.003;
$normbfhi = 0.003;

#######################
#######################
##   Main Program    ##
#######################
#######################

# set some parameters
$ENV{PGPLOT_TYPE}="/null";

# store the script directory in $Bin
use FindBin qw($Bin);
use Cwd;

# define the state name
$statname = "chisq" if ($stat eq "chi");
$statname = "cash"  if ($stat eq "cstat");
$statname = "bayes" if ($stat eq "lstat");

foreach $eming (@eming) {
  $crmin = $eming;
  $crmax = $emax;

  # define the dat file name
  $nff = "nhfro";
  $nff = "nhfree" if ($freeze_nh eq "no");
  $fff = "fefro";
  $fff = "fefree" if ($freeze_fe eq "no");
  $en = "7-7";
  $en = "2-7" if ($eming eq "2.0");
  $datfile = "fakset_${nff}_${fff}_${en}.dat";

  # read in the reference file
  $model = "mekal";

  # open file to contain fit results and errors
  open(FITFILE,">$Bin/${datfile}");
  sub_print_info();
  close FITFILE;

  # open up a logfile
  open(LOGFILE,">fit_sim_spec.log");
  print LOGFILE "\n###### Started fitting at ",scalar(localtime)," ######\n";

  # get values from ref file
  $emin  = $eming;
  $emin  = 2/1+$z if ($eming eq "2.0");
  $crmin = $emin;

  # change directory
  chdir("$rootdir");
  print "## Started $name (ObsId $obsid) ",scalar(localtime),"\n";

  # find all fak spec matching
  undef(@glob);
  push @glob, glob("faked_*spec_grp.fak");
  
  # if the source file doesn't exist, we move on
  unless (@glob) {
      print "## No spec_grp for $obsid ($name)\n";
      print LOGFILE "${obsid}: No spec_grp\n";
      chdir("$Bin");
  }

  # loop through each spectrum
  foreach $fak (@glob) {

      print "## Working on $fak\n" if ($quiet eq "yes");

      # define some names
      $data = $fak;
      $xcmfile = "${name}_${obsid}.xcm";

      # print model to XCMFILE, get parameters for con limit determination
      @clpar = sub_make_xcmfile($nhmod,$model,$data,$xcmfile);

      # run xspec (see subroutine run_xspec) with a timeout
      sub_do_xspec($xcmfile,@clpar);

      # format output and put into results file
      unless (-e "$xcmfile.model") {
	  print "Can't open $xcmfile.model\n";
	  print LOGFILE "${obsid} : No $xcmfile.model\n";
	  next;
      }

      # format output and put into results file
      sub_format_output($data,@clpar);
    }

    # change back to original directory
    chdir("$Bin");

    # status
    print "## Finished $name (ObsId $obsid) ",scalar(localtime),"\n\n";
}

# close files and exit
print LOGFILE "## Finished fitting ",scalar(localtime)," ##\n\n";
print "## Finished fitting ",scalar(localtime)," ##\n\n";
close LOGFILE;

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_print_info {

    print FITFILE "# Model: $nhmod($model) for spectra; Fit Range = $eming - $emax; Count Rates = $crmin - $crmax keV\n";
    print FITFILE "# Nh frozen = $freeze_nh; Fe frozen = $freeze_fe; Confidence Levels = $conlevel; Systematic error = $syserr\n";

    printf FITFILE "%-25s %6s %6s %6s %5s %5s %5s %5s %5s %5s %5s %5s %5s %10s %10s %10s %5s %5s %5s %6s %6s %6s %7s %6s %6s %6s %6s\n",
      "# Cluster","ObsID","AddTx","Eta","nh20","nlo","nhi","Tx","Tlo","Thi","Fe","Felo","Fehi",
	"Norm","Normlo","Normhi","T/TBF","lo","hi","N/NBF","lo","hi","z","Cr","Junk",
	  $statname,"dof";
}

#######################
#######################

sub sub_make_xcmfile {

  # input vaules
  my($nhmod,$model,$file,$xcmfile) = @_;

  # other local variables 
  my(@clpar,$modstring,$line,@conpar);

  # clean up any files left over from previous runs
  unlink "$xcmfile";
  unlink <*.fit> ;
  unlink "model.dat";

  # print to XCM file
  open(XCMFILE,">$xcmfile");
  print XCMFILE "query yes\n";
  print XCMFILE "cosmo ${h0} ${q0} ${omegal}\n";
  print XCMFILE "data $file\n";
  print XCMFILE "statistic ${stat}\n";
  print XCMFILE "ignore **-${emin} ${emax}-**\n";
  print XCMFILE "ignore bad\n";

  # Model information
  # Raymond-Smith #######################################################
  if ($model eq "ray") {
    ($nhpar,$txpar,$fepar,$normpar) = (1,2,3,5);
    $modstring = "${nhmod}(ray)";
    $line      = "& $nh & $tx & $fe,0 & $z & 0.1";
  }
  # MEKAL model#########################################################
  elsif ($model eq "mekal") {
    ($nhpar,$txpar,$fepar,$normpar) = (1,2,4,7);
    $modstring = "${nhmod}(mekal)";
    $line      = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1";
  }
  # APEC model##########################################################
  elsif ($model eq "apec") {
    ($nhpar,$txpar,$fepar,$normpar) = (1,2,3,5);
    $modstring = "${nhmod}(apec)";
    $line      = "& $nh & $tx & $fe,0 & $z & 0.1";
  }
  else {
    die "Unknown model: $model\n";
  }

  # print out model
  print XCMFILE "model $modstring $line\n" ;

  # freeze nh if desired
  print XCMFILE "freeze $nhpar\n" if ($freeze_nh eq "yes");
  print XCMFILE "thaw $nhpar\n" if ($freeze_nh eq "no");

  # freeze fe if desired
  print XCMFILE "freeze $fepar\n" if ($freeze_fe eq "yes");
  print XCMFILE "thaw $fepar\n" if ($freeze_fe eq "no");

  # add in systematic error
  print XCMFILE "systematic $syserr\n" unless ($syserr == 0);

  # done with the xcm file, close
  close XCMFILE;

  # get the parameters to get con limits for
  @clpar = ();
  push @clpar,$nhpar if ($freeze_nh eq "no");
  push @clpar,$txpar;
  push @clpar,$normpar;
  push @clpar,$fepar if ($freeze_fe eq "no");

  # return the parameters you want confidence limits for
  return @clpar;
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

sub sub_do_xspec {

  $SIG{ALRM} = sub { die "timeout" };
  eval {
    alarm($timeout);
    sub_run_xspec(@_);
    alarm(0);
  };
  if ($@) { # trap the timeout
    if ($@ =~ /timeout/) {
      print(LOGFILE "$name $obsid:  timed out\n");
      kill 15, $pid;  # relies of $pid being a global variable
      next;
    }
    else { # something else happended
      print LOGFILE "$name $obsid exited early\n";
      next;
    }
  }
}

#######################
#######################

sub sub_run_xspec {

  my ($xcmfile,@parameters) = @_;
  my ($parameters,$line,$done,$conlim,$params);
  undef %low;
  undef %high;

  # starts xspec (perl and read and write from/to it)
  # $pid is a global variable that can be used to kill xspec
  use IPC::Open3;
  $pid = open3(*XSPEC_INPUT,*XSPEC_OUTPUT,*XSPEC_ERR,"xspec11") || die "Can't run xspec\n";

  # open the xcmfile written earlier and feed to xspec
  myprint "\@${xcmfile}\n";

  # delete files
  unlink("${xcmfile}.model");
  unlink("${xcmfile}.log");

  # fit the data
  myprint "fit $iter $converge\n" ;

  # get the confidence limits for interesting parameters
  $parameters = join " ", @parameters;
  myprint "query no\n";
  myprint "error stopat $ntrial $toler maximum 10.0 $conlevel $parameters\n";

 MAIN: while (<XSPEC_OUTPUT>) {
    chomp($line = $_);
    print "xspec: $line\n" if ($quiet eq "no");

    # chisq to high can't calculate errors
    if ($line =~ /^.*?\s+No error determination/) {
	print "## $obsid: no data\n";
	print LOGFILE "$obsid: no data\n";

      # set errors to zero
	foreach $parameter (@parameters) {
	    $low{$parameter} = 0;
	    $high{$parameter} = 0;
	};

      # write things to a log file
      myprint
        "save model ${xcmfile}.model\n",
          "log $xcmfile.log\n",
            "show fit\n",
              "notice **-**\n",
                "ignore **-$crmin $crmax-**\n",
                  "tclout rate\n",
                    'puts  "Rate $xspec_tclout"',"\n",
	  "log none\n";

      # all done quit XSPEC
	myprint "exit\n\n";
    }

    if ($line =~ /^.*?\s+\> maximum/) {
      print "## $obsid: $statname squared too large to estimate confidence intervals\n";
      print LOGFILE "$obsid: $statname squared too large to estimate confidence intervals\n";
	
      # set errors to zero
      foreach $parameter (@parameters) {
	$low{$parameter} = 0;
	$high{$parameter} = 0;
      };
		
      # write things to a log file
      myprint
	"save model ${xcmfile}.model\n",
	  "log $xcmfile.log\n",
	    "show fit\n",
	      "notice **-**\n",
		"ignore **-$crmin $crmax-**\n",
		  "tclout rate\n",
		    'puts  "Rate $xspec_tclout"',"\n",
		      "log none\n";
	
      # all done quit XSPEC
      myprint "exit\n\n";
    }

    # error calculation actually works
    if ($line =~ m/^.*?\s+Parameter\s+Confidence/) {
      $done = 0;
      # what to do in various cases
      while ($done < @parameters) {
	chomp ($line=<XSPEC_OUTPUT>);
	print "xspec: $line\n" if ($quiet eq "no");

	# error found a new minimum
	if ($line =~ m/when model parameter/) {
	  print LOGFILE "$obsid: Check fit\n";
	  myprint "fit $iter .001\n" ;
	  myprint "error stopat $ntrial $toler maximum 10.0 $conlevel $parameters\n";
	  next MAIN;
	}
	# error worked, get output
	if ($line =~ m/^\s+\d+\s+/) {
	  ($parameter, $low, $high) = split(" ",$line);
	  $done++;
	  # put into a hash
	  $low{$parameter} = $low;
	  $high{$parameter} = $high;
	}
      }

      # write things to a log file
      myprint
        "save model ${xcmfile}.model\n",
          "log $xcmfile.log\n",
            "show fit\n",
              "notice **-**\n",
                "ignore **-$crmin $crmax-**\n",
                  "tclout rate\n",
                    'puts  "Rate $xspec_tclout"',"\n",
                      "log none\n";

      # all done quit XSPEC
      myprint "exit\n\n";
    }
  }

  close XSPEC_INPUT;
  close XSPEC_OUTPUT;
  close XSPEC_ERR;
  waitpid($pid,0);

}

#######################
#######################

sub sub_format_output {

  my($file,@parameters) = @_;
  my($nh,$tx,$fe,$norm,$normlo,$normhi,$cr,$nlo,$nhi,$felo,$fehi,$tlo,$thi,$tx2,$norm2,$normlo2,$normhi2,$tlo2,$thi2,@data);

  # get model parameter values
  # go through model file produced by xspec sub
  open(MODFILE,("$xcmfile.model")) || die "Can't open $xcmfile.model\n";
  @model = <MODFILE>;
  @model = splice(@model,6);
  $mcount = 1;
  foreach $modparam (@model) {	
    @moddata = split(" ",$modparam);
    $nh   = $moddata[0] if ($mcount == $nhpar);
    $tx   = $moddata[0] if ($mcount == $txpar);
    $fe   = $moddata[0] if ($mcount == $fepar);
    $norm = $moddata[0] if ($mcount == $normpar);
    $mcount++;
  }

  # get model parameter errors
  # go through parameters variable input from run_xspec
  if (defined $low{$nhpar}) {
    ($nlo,$nhi) = ($low{$nhpar}, $high{$nhpar});
  } else {
    ($nlo,$nhi) = (0,0);
  }
  if (defined $low{$txpar}) {
    ($tlo,$thi) = ($low{$txpar}, $high{$txpar});
  } else {
    ($tlo,$thi) = (0,0);
  }
  if (defined $low{$normpar}) {
    ($normlo,$normhi) = ($low{$normpar}, $high{$normpar});
  } else {
    ($normlo,$normhi) = (0,0);
  }
  if (defined $low{$fepar}) {
    ($felo,$fehi) = ($low{$fepar}, $high{$fepar});
  } else {
    ($felo,$fehi) = ($fe,$fe);
  }

  # go through log file produced by xspec sub
  open(MODFILE,"$xcmfile.log") || die "Can't open $xcmfile.log\n";
  my(@dof) = ();
  my(@stats) = ();

  if ($stat eq "chi") {
      $phrase = "Reduced chi-squared";
      $ind1 = 3;
      $ind2 = 5;
  } elsif ($stat eq "cstat") {
      $phrase = "C-statistic";
      $ind1 = 2;
      $ind2 = 4;
  } elsif ($stat eq "lstat") {
      $phrase = "L-statistic";
      $ind1 = 2;
      $ind2 = 4;
  }
  while (<MODFILE>) {
    if (/$phrase/) {
      @data = split(" ",$_);
      push @stats,sprintf("%7.2f",$data[${ind1}]);
      push @dof,$data[${ind2}];
    }
    if (/^Rate/) {
      @data = split(" ",$_);
      $cr = $data[1];
    }
  }
	
  # compute T/TBF, Norm/NormBF, etc
  if ($txbf <= 0) {
      $txbf = -1;
  } elsif ($txbflo <= 0) {
      $txbflo = -1;
  } elsif ($txbfhi <= 0) {
      $txbfhi = -1;
  } elsif ($normbf <= 0) {
      $normbf = -1;
  } elsif ($normbflo <= 0) {
      $normbflo = -1;
  } elsif ($normbfhi <= 0) {
      $normbfhi = -1;
  }
  $tx2     = $tx/$txbf;
  $tlo2    = $tx2-($tx2*sqrt((($tx-$tlo)/$tx)**2.+(($txbf-$txbflo)/$txbf)**2));
  $thi2    = $tx2+($tx2*sqrt((($thi-$tx)/$tx)**2.+(($txbfhi-$txbf)/$txbf)**2));
  $norm2   = $norm/$normbf;
  $normlo2 = $norm2-($norm2*sqrt((($norm-$normlo)/$norm)**2.+(($normbf-$normbflo)/$normbf)**2));
  $normhi2 = $norm2+($norm2*sqrt((($normhi-$norm)/$norm)**2.+(($normbfhi-$normbf)/$normbf)**2));

  # fill the src % column with junk
  $ptot = 0.00;

  # get the fidtx and eta values from the file name
  @temp = split("_",$file);
  $fidtx = $temp[1];
  $eta = $temp[2];

  # make a note in the logfile
  print LOGFILE "${obsid}: Fitting complete with Tx=$tx ; Fe=$fe ; stat=$stats[0]\n";

  # print out the info
  open(FITFILE,">>$Bin/${datfile}");
  printf FITFILE "%-25s %6s %6s %6s %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %10.2e %10.2e "
    ."%10.2e %5.2f %5.2f %5.2f %6.3f %6.3f %6.3f %7.4f %6.3f %6s %6.2f %6i\n",
      $name,$obsid,$fidtx,$eta,$nh*1e2,$nlo*1e2,$nhi*1e2,$tx,$tlo,$thi,$fe,$felo,$fehi,$norm,$normlo,$normhi,
	$tx2,$tlo2,$thi2,$norm2,$normlo2,$normhi2,$z,$cr,$ptot,$stats[0],$dof[0];
  close FITFILE
}

#######################
#######################
