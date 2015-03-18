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
$quiet     = "yes";                            # should Xspec vomit on the screen?
$rootdir   = "reprocessed";                    # where to find the cluster specific data

# fitting parameters
$dofit      = "yes";                           # if no then just creates the XCM files for xspec to run
$iter       = 1000;                            # the number of iterations XSPEC should run to 'fit'
$converge   = 0.01;                            # the convergance criterium for the 'fit statistic' used
$ntrial     = 100;                             # number of trials in the error calculation
$toler      = 0.05;                            # tolerance for the fit statistic

# details of fitting
$inc       = 4;                                # the number of annuli to increment !!! total annuli fit will be inc+1 !!!
$runname   = "annuli";                         # name of the region and spectra to use
$emin      = ("0.7");                          # min and max energy ranges for fitting,
$emax      = "7.0";                            # needs to be a string so PERL don't cut off decimal pts.
$crmin     = "0.7";
$crmax     = "2.0";
$nhmod     = "wabs";                           # e.g., wabs,tbabs, ph
$freeze_nh = "yes";                            # fix nh to the galactic value? "yes" or "no"
$freeze_fe = "no";                             # keep fe at specified level, shouldn't be "yes" often
$src       = "src1_grp";                       # extension of spectral files: sou, src1, src1_grp, ...
$bgd       = "bgd_adj";                        # extension of bkgrnd spectral files: bgd, bgd_adj, ...
$h0        = 70;                               # cosmology h0
$q0        = 0.0;                              # norm. acceleration (ignored by Xspec)
$omegal    = 0.7;                              # cosmology imega_lambda
$timeout   = 18000;                            # seconds until kills xspec job
$syserr    = "0.00";                           # % systematic error to add
$conlevel  = "2.71";                           # compute confidence intervals:
                                               # 1.0 = 68% (1-sigma), 2.71 = 90% (1.6-sigma), 4.0 = 95.5% (2-sigma),
                                               # 6.63 = 99% (2.6-sigma), 9.0 = 99.7% (3-sigma)

#######################
#######################
##   Main Program    ##
#######################
#######################

# check for ciao env loaded
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});

# set some parameters
$ENV{PGPLOT_TYPE}="/null";
use constant PI => 4*atan2(1,1);
use FindBin qw($Bin);
use Cwd;

# check input params
$nargs = @ARGV;
die "Incorrect number of parameters\n" if ($nargs != 2);

# define the dat file name
$datfile   = "degraded_tx.dat";

# read in the reference file
%refdata = get_data($ARGV[0]);
$model = $ARGV[1];

# open file to contain fit results and errors
if ($dofit eq "yes") {
    open(FITFILE,">$Bin/${datfile}");
    print_info();
    close FITFILE;
}

# open up a logfile
open(LOGFILE,">fit_simulta.log") || die "## ERROR: Can't open log\n";
print LOGFILE "\n###### Started fitting at ",scalar(localtime)," ######\n";

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});
    $name    = $data[0];
    $obsid   = $data[1];
    $z       = $data[6];
    $nh      = $data[7]*1e-2;
    $tx      = $data[8];
    $fe      = $data[9];
    $datadir = $data[15];
    chdir("$datadir/$obsid/$rootdir/");

    # write to log file
    print "## STATUS: Working on $obsid for ${emin}-${emax}\n" if ($quiet eq "yes");

    # get all annuli to work with
    %annuli = get_annuli("*_${runname}*${src}.pi");

    # make sure we have files to work with
    unless (%annuli) {
	print "## No ${runname} spectra for $obsid ($name)\n";
	print LOGFILE "${obsid} :: No ${runname} spectra\n";
	chdir("$Bin");
	next;
    }

    # go through each annulus and fit
    undef @anns;
    foreach $anum (sort {$a <=> $b} keys %annuli) {
	$data = $annuli{$anum};
	$bgfile = $annuli{$anum};
	$bgfile =~ s/\_${src}.pi/\_${bgd}.pi/;
	$command = "punlearn dmhedit; dmhedit infile=$data operation=add key=BACKFILE value=$bgfile filelist=\"\"";
	system($command);
	push @anns, $data;
    }
    $i = 0;
    while ($i+$inc <= $#anns) {
	$reg = "$anns[$i]";
	$reg =~ s/\_${src}.pi/\.reg/;
	open(IN,$reg);
	while (<IN>) {
	    chomp;
	    next if (/^\#/); # skip comment lines
	    next if (/^$/);  # skip blank lines
	    @rin = split(",");
	    $rin = $rin[2];
	    $rin = ($rin*0.492)/60;
	    chomp $rin;
	    $rin = sprintf("%.2f",$rin);
	}
	close IN;
	$reg = "$anns[$i+$inc]";
	$reg =~ s/\_${src}.pi/\.reg/;
	open(IN,$reg);
	while (<IN>) {
	    chomp;
	    next if (/^\#/); # skip comment lines
	    next if (/^$/);  # skip blank lines
	    $_ =~ s/\)//;
	    @rout = split(",");
	    $rout = $rout[3];
	    $rout = ($rout*0.492)/60;
	    chomp $rout;
	    $rout = sprintf("%.2f",$rout);
	}
	close IN;
	$j = $i;
	$ac = 1;
	undef @indata;
	while ($j <= $i+$inc) {
	    push @indata, "data ${ac}:${ac} $anns[$j]";
	    $j++;
	    $ac++;
	}
	$indata = join " ", @indata;
	print "## STATUS: Fitting $indata\n" if ($quiet eq "yes");
	$xcmfile = "temp.xcm";
	@clpar = make_xcmfile($nhmod,$model,$xcmfile,$indata);
	do_xspec($xcmfile,@clpar) if ($dofit eq "yes");
	format_output($rin,$rout,@clpar) if ($dofit eq "yes");
	unlink("${xcmfile}");
	unlink("${xcmfile}.model");
	unlink("${xcmfile}.log");
	$i = $i+($inc+1);
    }
    chdir("$Bin");
}
# close files and exit
print LOGFILE "###### Finished fitting ",scalar(localtime)," ######\n\n";
print "\n###### Finished fitting ",scalar(localtime)," ######\n\n";
close LOGFILE;
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub get_data {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile);
  while (<INFILE>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    s/^\s+//;        # trim leading whitespace
    s/\s+$//;        # trim trailing whitespace
    @data = split;
    $name = join "_", $data[0],$data[1],$data[2],$data[3],$data[4];
    $info{$name} = $_;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub get_annuli {

    # get input arg
    my($searchstring) = @_;

    # localize some variables
    my(@annuli,%annuli,$file,$anum);

    # search for annuli file in current directory
    @annuli = glob($searchstring);

    # want to make sure end up sorted numerically
    # create hash where key is number and value is file name
    undef %annuli;
    foreach $file (@annuli) {
	$anum = $file;
	if (scalar(@annuli) == 1) {
	    $anum = 1;
	} else {
	    $anum =~ s/.*${runname}(\d+)\_${src}.pi/$1/;
        }
    $annuli{$anum} = $file;
    }
    return %annuli;
}

#######################
#######################

sub print_info {

    print FITFILE "# Model: $nhmod($ARGV[1]) for $runname spectra; Fit Range = $emin - $emax; Count Rates = $crmin - $crmax keV\n";
    print FITFILE "# Nh frozen = $freeze_nh; Fe frozen = $freeze_fe; Confidence Levels = $conlevel; Systematic error = $syserr\n";

    	printf FITFILE "%-16s %20s %6s %6s %5s %5s %5s %5s %5s %5s %5s %5s %5s %10s %10s %10s %5s %5s %5s %10s %10s %10s %7s %6s %6s %6s %6s\n",
    "# Cluster","ObsID","Rin","Rout","nh20","nlo","nhi","Tx","Tlo","Thi","Fe","Felo","Fehi",
    "Norm","Normlo","Normhi","Tx2","Tlo2","Thi2","Norm2","Normlo2","Normhi2","z","Cr","Src\%","chisq","dof";
}

#######################
#######################

sub make_xcmfile {

  # input vaules
  my($nhmod,$model,$xcmfile,$indata) = @_;

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
  print XCMFILE "$indata\n";
  print XCMFILE "ignore 1-2:**-${emin} ${emax}-**\n";
  if ($model eq "mekal") {
      ($nhpar,$txpar,$fepar,$normpar) = (1,2,4,7);
      $modstring = "${nhmod}(mekal)";
      $line = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1 & =1 & =2 & =3 & =4 & =5 & =6 & 0.1\n";
  }
  else {
      die "Unknown model: $model\n";
  }
  print XCMFILE "model $modstring $line\n" ;
  print XCMFILE "freeze $nhpar\n" if ($freeze_nh eq "yes");
  print XCMFILE "thaw $nhpar\n" if ($freeze_nh eq "no");
  print XCMFILE "freeze $fepar\n" if ($freeze_fe eq "yes");
  print XCMFILE "thaw $fepar\n" if ($freeze_fe eq "no");
  print XCMFILE "systematic $syserr\n" unless ($syserr == 0);
  close XCMFILE;

  # get the parameters to get con limits for
  undef @clpar;
  push @clpar,$nhpar if ($freeze_nh eq "no");
  push @clpar,$txpar;
  push @clpar,$normpar;
  push @clpar,$fepar if ($freeze_fe eq "no");
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

sub do_xspec {

  $SIG{ALRM} = sub { die "timeout" };
  eval {
    alarm($timeout);
    run_xspec(@_);
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

sub run_xspec {

  my ($xcmfile,@parameters) = @_;
  my ($i,$parameters,$line,$done,$conlim,$params,$xline,$diff,$par,$dum);
  undef %low;
  undef %high;

  # starts xspec (perl and read and write from/to it)
  # $pid is a global variable that can be used to kill xspec
  use IPC::Open3;
  $pid = open3(*XSPEC_INPUT,*XSPEC_OUTPUT,*XSPEC_ERR,"xspec11") || die "## ERROR: Can't run xspec\n";

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
    if ($line =~ /^.*?\s+\> maximum/) {
      print "## $obsid: Chi squared too large to estimate confidence intervals\n";
      print LOGFILE "$obsid: Chi squared too large to estimate confidence intervals\n";
	
      # set errors to zero
      foreach $parameter (@parameters) {
	$low{$parameter} = 0;
	$high{$parameter} = 0;
      };
		
      # write things to a log file
      $diff = 0;
      for ($i=0; $i <= 1; $i++) {
	  $dum = $i+1;
	  $par = 7+($diff*$i);
	  $par = sprintf("%i",$par);
	  $xline .= "tclout rate $dum\n";
	  $xline .= "puts \"Rate${dum} $xspec_tclout\"\n";
	  $xline .= "tclout param ${par}\n";
	  $xline .= "puts \"Norm${dum} $xspec_tclout\"\n";
      }
      myprint
	"save model ${xcmfile}.model\n",
	  "log $xcmfile.log\n",
	    "show fit\n",
	      "notice 1-2:**-**\n",
		"ignore 1-2:**-$crmin $crmax-**\n",
	          "$xline\n",
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
	if ($line =~ m/Chi-Squared when model parameter/) {
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
      $diff = 0;
      for ($i=0; $i <= 1; $i++) {
          $dum = $i+1;
          $par = 7+($diff*$i);
          $par = sprintf("%i",$par);
          $xline .= "tclout rate $dum\n";
          $xline .= "puts \"Rate${dum} \$xspec_tclout\"\n";
          $xline .= "tclout param ${par}\n";
          $xline .= "puts \"Norm${dum} \$xspec_tclout\"\n";
      }

      # save model
      myprint
	"save model ${xcmfile}.model\n",
	  "log $xcmfile.log\n",
	    "show fit\n",
	      "notice 1-2:**-**\n",
		"ignore 1-2:**-$crmin $crmax-**\n",
	          "$xline\n",
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

sub format_output {

  my($rin,$rout,@parameters) = @_;
  my($nh,$tx,$fe,$norm,$normlo,$normhi,$cr,$nlo,$nhi,$felo,$fehi,$tlo,$thi,
     $tx2,$norm2,$normlo2,$normhi2,$tlo2,$thi2,@data,$ptot,$tt,$t);

  # get model parameter values
  # go through model file produced by xspec sub
  open(MODFILE,("$xcmfile.model")) || die "## ERROR: Can't open $xcmfile.model\n";
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
  ($tx2,$tlo2,$thi2) = (0,0,0);
  ($norm2,$normlo2,$normhi2) = (0,0,0);

  # go through log file produced by xspec sub
  open(MODFILE,"$xcmfile.log") || die "## ERROR: Can't open $xcmfile.log\n";
  my(@dof) = ();
  my(@chisq) = ();
  $cr = 0;
  $norm = 0;
  $ptot = 0;
  $tt = 0;
  $nn = 0;
  $rr = 0;
  while (<MODFILE>) {
    if (/Reduced chi-squared/) {
      @data = split(" ",$_);
      push @chisq,sprintf("%7.2f",$data[3]);
      push @dof,$data[5];
    }
    if (/^Rate/) {
      $rr++;
      @data = split(" ",$_);
      $cr = $cr+$data[1];
    }
    if (/^Norm/) {
      $nn++;
      @data = split(" ",$_);
      $norm = $norm+$data[1];
    }
    if (/Net count rate/) {
      $tt++;
      @data = split("/",$_);
      $t = $data[2];
      $t =~ s/^.*\(//;
      $t =~ s/\%.*//;
      chomp $t;
      $ptot = $ptot+$t;
    }
  }
  $cr = $cr/$rr;
  $norm = $norm/$nn;
  $ptot = $ptot/$tt;

  # print out the info
  open(FITFILE,">>$Bin/${datfile}");
  printf FITFILE "%-16s %20s %6s %6s %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f "
      ."%5.2f %10.2e %10.2e %10.2e %5.2f %5.2f %5.2f %10.2e %10.2e %10.2e %7.4f %6.3f "
      ."%6.1f %6.2f %6i\n",$name,$obsid,$rin,$rout,$nh*1e2,$nlo*1e2,$nhi*1e2,$tx,$tlo,$thi,
      $fe,$felo,$fehi,$norm,$normlo,$normhi,$tx2,$tlo2,$thi2,$norm2,$normlo2,$normhi2,$z,$cr,
      $ptot,$chisq[0],$dof[0];
  close FITFILE
}

#######################
#######################
