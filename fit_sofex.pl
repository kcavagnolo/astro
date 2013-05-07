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

$quiet    = "yes";
$rootdir  = "reprocessed";

# fitting parameters
$iter       = 1000;                            # the number of iterations XSPEC should run to 'fit'
$converge   = 0.01;                            # the convergance criterium for the 'fit statistic' used
$ntrial     = 100;                             # number of trials in the error calculation
$toler      = 0.05;                            # tolerance for the fit statistic

# details of fitting
$emin      = "0.2";                            # min and max energy ranges for fitting,
$emax      = "1.5";                            # needs to be a string so PERL don't cut off decimal pts.
$crmin     = $emin;                            # min for count rate reporting
$crmax     = $emax;                            # max for count rate reporting
$freeze_fe = "yes";                            # keep fe at specified level, shouldn't be "yes" often
$fidfe     = 1.0;
$freeze_tx = "no";                             # keep tx at specified level, shouldn't be "yes" ever
$fidtx     = 0.2;
$h0        = 70;                               # cosmology h0
$q0        = 0.0;                              # norm. acceleration (ignored by Xspec)
$omegal    = 0.7;                              # cosmology imega_lambda
$timeout   = 1800;                             # seconds until kills xspec job
$syserr    = "0.00";                           # % systematic error to add
$stat      = "chisq";                          # fit statistic to use: cstat, chisq, lstat
$conlevel  = "1.0";                            # compute confidence intervals:
                                               # 1.0 = 68% (1-sigma), 2.71 = 90% (1.6-sigma), 4.0 = 95.5% (2-sigma),
                                               # 6.63 = 99% (2.6-sigma), 9.0 = 99.7% (3-sigma)
#######################
#######################
##   Main Program    ##
#######################
#######################

# Check the number of arguments given
die "## Wrong number of command line arguments\n" if (@ARGV != 2);

# Load useful libraries
# Store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);
use constant PI => 4*atan2(1,1);

# Read in the reference file
%refdata  = sub_read_file($ARGV[0]);
$model = $ARGV[1];
print "## $counter observations to fit\n";

# open file to new reference
$ttt = "txfro";
$ttt = "txfree" if ($freeze_tx eq "no");
$fff = "fefro";
$fff = "fefree" if ($freeze_fe eq "no");
$outfile = "sofex_${ttt}_${fff}.dat";
sub_print_info();

# Go through each cluster
{
  foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get values
    $name = $data[0];
    $obsid = $data[1];
    $datadir = $data[15];
    $tx = $fidtx;
    $fe = $fidfe;
    if ($stat ne "cstat") {
	$src = "${obsid}_addex_src1_grp.pi";
    } else {
	$src = "${obsid}_addex_src1.pi";
    }
    $bgd = "${obsid}_addex_bgd_adj.pi";
    $reg = "${obsid}_addex.reg";
    $rmf = "${obsid}_addex_src1.wrmf";
    $arf = "${obsid}_addex_src1.warf";
    $xcmfile = "${obsid}_sofex.xcm";
    $fail = "no";

    # change directory
    chdir("$datadir/$obsid/$rootdir");

    # make sure we have events files to work with
    unless (-e $src && -e $bgd && -e $reg && -e $rmf && -e $arf) {
      $offender = "No ".$src unless (-e $src);
      $offender = "No ".$bgd unless (-e $bgd);
      $offender = "No ".$reg unless (-e $reg);
      $offender = "No ".$rmf unless (-e $rmf);
      $offender = "No ".$arf unless (-e $arf);
      logerror($offender);
      $counter--;
      next;
    }

    # print model to XCMFILE, get parameters for con limit determination
    @clpar = make_xcmfile($src,$bgd,$rmf,$arf,$xcmfile);
    if ($fail eq "yes") {
      $offender = "make_xcmfile";
      logerror($offender);
      $counter--;
      next;
    }

    # run xspec (see subroutine run_xspec) with a timeout
    do_xspec($xcmfile,@clpar);

    # format output and put into results file
    format_output($reg,@clpar);

    # change back to original directory
    $counter--;
    print "## $counter observations left to go...\n";
    chdir("$Bin");
  }
}

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_file {

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
    $counter++;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub logerror {

    my($offender) = @_;

    chdir("$Bin");
    open  ERR,">>err_fit_sofex.log";
    print "\n## ${obsid}: failure in fit_sofex.pl, $offender ",scalar(localtime),"\n";
    print ERR  "${obsid}: failure in fit_sofex.pl, $offender ",scalar(localtime),"\n";
    close ERR;
}

#######################
#######################

sub sub_print_info {

  open(OUT,">$Bin/${outfile}");
  printf OUT "#Model: $model; Energy band: $emin keV --> $emax keV; Fe-frozen? $freeze_fe; Tx-frozen? $freeze_tx\n";
  printf OUT "#Confidence Level: $conlevel; Systematic error: $syserr; Cosmo: $h0, $q0, $omegal\n";
  printf OUT "%-25s %6s %6s %6s %6s %6s %6s %6s %10s %10s %10s %6s %6s %6s %10s %10s %10s %10s %10s %6s %6s\n",
      "#Name","ObsID","Tx","Tlo","Thi","Fe","Felo","Fehi","norm","normlo","normhi",
	"Tx2","Tlo2","Thi2","norm2","normlo2","normhi2","area","ctr","chisq","dof";
  close OUT;
}

#######################
#######################

sub make_xcmfile {

  # input vaules
  my($src,$bgd,$rmf,$arf,$xcmfile) = @_;

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
  print XCMFILE "data $src\n";
  print XCMFILE "backgrnd $bgd\n";
  print XCMFILE "statistic ${stat}\n";
  print XCMFILE "ignore **-${emin} ${emax}-**\n";
  print XCMFILE "ignore bad\n";

  # MEKAL model#########################################################
  if ($model eq "mekal") {
    ($txpar,$fepar,$normpar) = (1,3,6);
    $modstring = "mekal";
    $line      = "& $tx & 1.0 & $fe,0 & 0 & 0 & 0.1";
  }
  # APEC model##########################################################
  elsif ($model eq "apec") {
    ($txpar,$fepar,$normpar) = (1,2,4);
    $modstring = "apec";
    $line      = "& $tx & $fe,0 & 0 & 0.1";
  }
  # MEKAL+MEKAL model###################################################
  elsif ($model eq "mekal2t") {
    ($txpar,$fepar,$normpar,$txpar2,$normpar2) = (1,3,6,7,12);
    $modstring = "mekal + mekal";
    $line      = "& $tx & 1.0 & $fe,0 & 0 & 0 & 0.1 & 0.2 & 1.0 & =4 & =5 & 0 & 0.1";
  }
  # APEC+APEC model###################################################
  elsif ($model eq "apec2t") {
    ($txpar,$fepar,$normpar,$txpar2,$normpar2) = (1,2,4,5,8);
    $modstring = "apec + apec";
    $line      = "& $tx & $fe,0 & 0 & 0.1 & 0.2 & $fe,0 & 0 & 0.1";
  }
  else {
    die "Unknown model: $model\n";
  }

  # print out model
  print XCMFILE "model $modstring $line\n" ;

  # freeze fe if desired
  print XCMFILE "freeze $txpar\n" if ($freeze_tx eq "yes");
  print XCMFILE "freeze $fepar\n" if ($freeze_fe eq "yes");
  print XCMFILE "thaw $fepar\n" if ($freeze_fe eq "no");
  
  # reset norm to be negative
  if ($model eq "mekal") {
      print XCMFILE "newpar 6 1 0.01 -1E24 -1E24 1E+24 1E+24\n";
  } elsif ($model eq "apec") {
      print XCMFILE "newpar 4 1 0.01 -1E24 -1E24 1E+24 1E+24\n";
  } elsif ($model eq "mekal2t") {
      print XCMFILE "newpar 6 1 0.01 -1E24 -1E24 1E+24 1E+24\n";
      print XCMFILE "newpar 12 1 0.01 -1E24 -1E24 1E+24 1E+24\n";
  } elsif ($model eq "apec2t") {
      print XCMFILE "newpar 4 1 0.01 -1E24 -1E24 1E+24 1E+24\n";
      print XCMFILE "newpar 8 1 0.01 -1E24 -1E24 1E+24 1E+24\n";
  } else {
      die "Unknown newpar\n";
  }

  # add in systematic error
  print XCMFILE "systematic $syserr\n" unless ($syserr == 0);

  # done with the xcm file, close
  close XCMFILE;

  unless (-e $xcmfile) {
    $fail = "yes";
    return;
  } else {
    # get the parameters to get con limits for
    @clpar = ();
    push @clpar,$txpar if ($freeze_tx eq "no");
    push @clpar,$normpar;
    push @clpar,$fepar if ($freeze_fe eq "no");
    push @clpar,$txpar2 if ($model eq "mekal2t" || $model eq "apec2t");
    push @clpar,$normpar2 if ($model eq "mekal2t" || $model eq "apec2t");

    # return the parameters you want confidence limits for
    return @clpar;
  }
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

  $SIG{ALRM} = sub {die "timeout"};
  eval {
    alarm($timeout);
    run_xspec(@_);
    alarm(0);
  };
  if ($@) { # trap the timeout
    if ($@ =~ /timeout/) {
      print("## $obsid timed out\n");
      kill 15, $pid;
      next;
    }
    else { # something else happended
      open  ERR,">>$Bin/err_fit_sofex.log";
      print "## $obsid exited early\n";
      print ERR "$obsid: exited early\n";
      close ERR;

      next;
    }
  }
}

#######################
#######################

sub run_xspec {

  my ($xcmfile,@parameters) = @_;
  my ($parameters,$line,$done,$conlim,$params);
  undef %low;
  undef %high;
  $errconv = $converge;

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

    # stat to high can't calculate errors
    if ($line =~ /^.*?\s+\> maximum/) {
      open  ERR,">>$Bin/err_fit_sofex.log";
      print "## $obsid: $stat too large to estimate confidence intervals\n";
      print ERR "$obsid: $stat too large to estimate confidence intervals\n";
      close ERR;

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

    # err in fitting, can't calculate errors
    if ($line =~ /sigma indicates possible error/) {
      open  ERR,">>$Bin/err_fit_sofex.log";
      print "## $obsid: no fit, confidence intervals unreal\n";
      print ERR "$obsid: no fit, confidence intervals unreal\n";
      close ERR;

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

    # error calculation works
    if ($line =~ m/^.*?\s+Parameter\s+Confidence/) {
      $done = 0;
      # what to do in various cases
      while ($done < @parameters) {
        chomp ($line=<XSPEC_OUTPUT>);
        print "xspec: $line\n" if ($quiet eq "no");

        # error found a new minimum
        if ($line =~ m/when model parameter/) {
          print "## $obsid: Check fit\n";
	  $errconv = $errconv-0.5*$errconv;
          myprint "fit $iter $errconv\n" ;
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

      # make a gif image of the spectrum
      unlink "${obsid}_sofex.ps";
      myprint
	  "setplot energy\n",
          "iplot data resid\n",
	  "label top $name $obsid\n",
	  "time off\n",
	  "rescale y -0.02 0.02\n",
	  "cpd ${obsid}_sofex.ps/vcps\n",
	  "plot\n",
	  "cpd /null\n",
	  "exit\n";

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

sub format_output {

  my($reg,@parameters) = @_;
  my($tx,$fe,$norm,$snorm,$area,$cr,$chi,$dof,
     $tlo,$thi,$felo,$fehi,$normlo,$normhi,
     $tx2,$tlo2,$thi2,$norm2,$normlo2,$normhi2,@data);

  # get model parameter values
  # go through model file produced by xspec sub
  open(MODFILE,("$xcmfile.model")) || die "Can't open $xcmfile.model\n";
  @model = <MODFILE>;
  @model = splice(@model,6);
  $mcount = 1;
  foreach $modparam (@model) {
    @moddata = split(" ",$modparam);
    $tx   = $moddata[0] if ($mcount == $txpar);
    $fe   = $moddata[0] if ($mcount == $fepar);
    $norm = $moddata[0] if ($mcount == $normpar);
    if ($model eq "mekal2t" || $model eq "apec2t") {
      $tx2  = $moddata[0] if ($mcount == $txpar2);
      $norm2 = $moddata[0] if ($mcount == $normpar2);
    }
    $mcount++;
  }

  # get model parameter errors
  # go through parameters variable input from run_xspec
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

  # handle the mekal2t models params
  if ($model eq "mekal2t" || $model eq "apec2t") {
    if (defined $low{$txpar2}) {
      ($tlo2,$thi2) = ($low{$txpar2}, $high{$txpar2});
    } else {
      ($tlo2,$thi2) = (0,0);
    }
    if (defined $low{$normpar2}) {
      ($normlo2,$normhi2) = ($low{$normpar2}, $high{$normpar2});
    } else {
      ($normlo2,$normhi2) = (0,0);
    }
  } else {
    ($tx2,$tlo2,$thi2) = (0,0,0);
    ($norm2,$normlo2,$normhi2) = (0,0,0);
  }

  # go through log file produced by xspec sub
  open(MODFILE,"$xcmfile.log") || die "Can't open $xcmfile.log\n";
  my(@dof) = ();
  my(@stats) = ();

  if ($stat eq "chisq") {
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
    if (/Net count rate/) {
      @data = split("/",$_);
      $ptot = $data[2];
      $ptot =~ s/^.*\(//;
      $ptot =~ s/\%.*//;
      chomp $ptot;
    }
  }

  # Get the detector area used
  open(REGFILE,"$reg") || die "Can't open $reg\n";
  $area = 0;
  while(<REGFILE>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;
    s/\s+$//;
    if (/^annulus/) {
      my @vals = split(",",$_);
      my $in = $vals[2];
      $in =~ s/\)//g;
      my $out = $vals[3];
      $out =~ s/\)//g;
      $area = $area + (PI*(($out**2)-($in**2)));
    }
    if (/^circle/) {
      my @vals = split(",",$_);
      my $r = $vals[2];
      $r =~ s/\)//g;
      $area = $area + (PI*$r**2);
    }
    if (/^ellipse/) {
      my @vals = split(",",$_);
      my $b = $vals[3];
      $b =~ s/\)//g;
      my $a = $vals[2];
      $a =~ s/\)//g;
      $area = $area + (PI*$b*$a);
    }
    if (/^rotbox/) {
      my @vals = split(",",$_);
      my $l = $vals[3];
      $l =~ s/\)//g;
      my $w = $vals[2];
      $w =~ s/\)//g;
      $area = $area + ($w*$l);
    }
  }
  $area = (1024**2)-$area;

  # print out the info
  open(OUT,">>$Bin/${outfile}");
  printf OUT "%-25s %6s %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %10.2e %10.2e %10.2e "
    ."%6.2f %6.2f %6.2f %10.2e %10.2e %10.2e %10.3e %10.2e %6.2f %6i\n",
      $name,$obsid,$tx,$tlo,$thi,$fe,$felo,$fehi,$norm,$normlo,$normhi,
	$tx2,$tlo2,$thi2,$norm2,$normlo2,$normhi2,$area,$cr,$stats[0],$dof[0];
  close OUT
}

#######################
#######################
