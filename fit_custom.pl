#!/usr/bin/perl -w
#
# NAME:
#     me_fit_projected.pl
#
# PURPOSE:
#     Fit XSPEC models to spectra extracted from Chandra data.
#     The currently accepted models are MEKAL, MEKAL2T,
#     MKCFlow, Ray, and APEC.
#
# EXPLANATION:
#     This script takes in the PI, ARF, and RMF files from
#     extract_spectra.pl and fits the specified model to the data.
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
#     fit_projected.pl <reference list> <model>
#
# INPUTS:
#     xxx.pi file = the spectral data needed for fitting
#     xxx.arf or xxx.warf = the Auxiliary Response file either weighted or not
#     xxx.rmf or xxx.wrmf = the Redistribution Matrix file either weighted or not
#     <reference list> = file containing information about each cluster
#     the assumed format for the list is as follows:
#     in the case of X and Y being the centroid position in pixels and Rmax in pixels
#     Name                           ObsID        X        Y   Rmax     MinCts         z  Nh20     Tx     Fe  Lbol
#     ABELL_0644                      2211   3908.5   4332.5  243.9       5000    0.0704  6.41   8.64   0.35 45.00
#     ABELL_1651                      4185   4222.5   4034.5  132.3       5000    0.0844  1.88   5.97   0.30 45.00
#
# OUTPUTS:
#     A data file containing values and errors for the fit parameters:
#     nh, Tx, Fe, normalization, statistic, and degrees of freedom.
#     This will be stored in the file defined by $datfile.
#
# MODIFICATION HISTORY:
#     May 3, 2005 --- Ken Cavagnolo
#        added extensive header in IDL format
#
#######################
#######################
##    Set Options    ##
#######################
#######################

# set some global parameters
$quiet     = "yes";
$datadir   = "../";                        # where to find the /acis dir
$rootdir   = "reprocessed/";                   # where to find the cluster specific data

# fitting parameters
$iter       = 1000;                            # the number of iterations XSPEC should run to 'fit'
$converge   = 0.01;                            # the convergance criterium for the 'fit statistic' used
$ntrial     = 100;                             # number of trials in the error calculation
$toler      = 0.05;                            # tolerance for the fit statistic

# details of fitting
$eming     = "0.7";                            # min and max energy ranges for fitting,
$emax      = "7.0";                            # needs to be a string so PERL don't cut off decimal pts.
$crmin     = $eming;                           # min for count rate reporting
$crmax     = $emax;                            # max for count rate reporting
$h0        = 70;                               # cosmology h0
$q0        = 0.0;                              # acceleration, ignored by Xspec
$omegal    = 0.7;                              # cosmology imega_lambda
$timeout   = 1800;                             # seconds until kills xspec job
$syserr    = "0.00";                           # % systematic error to add
$conlevel  = "2.71";                           # compute confidence intervals:
                                               # 1.0 = 68% (1-sigma), 2.71 = 90% (1.6-sigma), 4.0 = 95.5% (2-sigma),
                                               # 6.63 = 99% (2.6-sigma), 9.0 = 99.7% (3-sigma)


#######################
#######################
##   Main Program    ##
#######################
#######################

# set some parameters
$ENV{PGPLOT_TYPE}="/null";

# check input params
$nargs = @ARGV;
die "Incorrect number of parameters\n" if ($nargs != 1);

# define output filename
$en = "7-7";
$en = "2-7" if ($eming eq "2.0");
$datfile = "custom_${en}.dat";

# read in the reference file
%refdata = get_data($ARGV[0]);

# determine how many items there are to fit
open(COUNT,$ARGV[0]);
while(<COUNT>){
  next if (/^\#/);
  next if (/^$/);
  $counter++;
}

# store the script directory in $Bin
use FindBin qw($Bin);
use Cwd;

# define the state name
$statname = "redstat";

# open file to contain fit results and errors
open(FITFILE,">$Bin/${datfile}");
print_info();
close FITFILE;

# open logfile
open(LOGFILE,">fit_custom.log");

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

    # announce how much longer
    print "$counter spectra left to fit\n";

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get values
    $name      = $data[0];
    $obsid     = $data[1];
    $z         = $data[2];
    $nh        = $data[3]*1e-2;
    $tx        = $data[4];
    $fe        = $data[5];
    $emin      = $data[6] if ($eming eq "2.0");
    $nhmod     = $data[7];  # wabs, abs, ...
    $model     = $data[8];  # mekal, mekal2t, ray, apec, mekctpl
    $stat      = $data[9];  # chi, cstat, lstat
    $freeze_nh = $data[10]; # yes or no
    $freeze_fe = $data[11]; # yes or no
    $runname   = $data[12]; # r2500, r2500-50, ...
    $src       = $data[13]; # src1_grp, src1, sou, ...
    $bgd       = $data[14]; # bgd, bgd_adj, ...
    $local     = $data[15]; # yes or no
    $emin      = $eming;
    $crmin     = $emin;

    # change directory
    chdir("$datadir/$obsid/$rootdir");

    # define some names
    $data = "${name}_${obsid}_${runname}_${src}.pi";
    $databgd = "${name}_${obsid}_${runname}_${bgd}.pi";
    $databgd = "local.pi" if ($local eq "yes");
    $xcmfile = "${name}_${obsid}_${runname}.xcm";
    $sourcereg = "${obsid}_${runname}.reg";

    # write to log file
    print "## Working on $data for ${emin}-${emax}\n" if ($quiet eq "yes");

    # if the source file doesn't exist, we move on
    unless (-e $data && -e $databgd) {
      print "## No ${runname} spectrum for $obsid ($name)\n";
      print LOGFILE "${obsid}: No ${runname} spectrum\n" unless (-e $data);
      print LOGFILE "${obsid}: No ${runname} bgd spectrum\n" unless (-e $databgd);
      chdir("$Bin");
      next;
    }

    # update the data file's header for bgd selection
    $command = "punlearn dmhedit; dmhedit infile=$data operation=add key=BACKFILE value=$databgd filelist=\"\"";
    system($command);

    # print model to XCMFILE, get parameters for con limit determination
    @clpar = make_xcmfile($nhmod,$model,$data,$xcmfile);

    # run xspec (see subroutine run_xspec) with a timeout
    do_xspec($xcmfile,@clpar);

    # format output and put into results file
    format_output($data,@clpar);

    # change back to original directory
    chdir("$Bin");

    # increment counter
    $counter--;
  }

# close files and exit
print "\n###### Finished fitting ",scalar(localtime)," ######\n\n";
close LOGFILE;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub get_data {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## Can't open $infile!\n";
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

sub print_info {

  print FITFILE "# Custom: see config file for specs; E/Cts Range = $eming - $emax keV\n";
  print FITFILE "# See config for Nh-fro/free, Fe-fro/free, Confidence Levels = $conlevel; Sys err = $syserr\n";

  printf FITFILE "%-25s %6s %6s %6s %5s %5s %5s %5s %5s %5s %5s %5s %5s %10s %10s %10s %5s %5s %5s %10s %10s %10s %7s %6s %6s %6s %6s\n",
    "# Cluster","ObsID","Rin","Rout","nh20","nlo","nhi","Tx","Tlo","Thi","Fe","Felo","Fehi",
      "Norm","Normlo","Normhi","Tx2","Tlo2","Thi2","Norm2","Normlo2","Normhi2","z","Cr","Src\%",$statname,"dof";
}

#######################
#######################

sub make_xcmfile {

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
  # MEKAL+MEKAL model###################################################
  elsif ($model eq "mekal2t") {
    ($nhpar,$txpar,$fepar,$normpar,$txpar2,$normpar2) = (1,2,4,7,8,13);
    $modstring = "${nhmod}(mekal + mekal)";
    $line      = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1 & 0.1 & 1.0 & =4 & =5 & 0 & 0.01";
  }
  # MEKAL+CUTOFFPL/b model##############################################
  elsif ($model eq "mekctpl") {
    ($nhpar,$txpar,$fepar,$normpar) = (1,2,4,7);
    $modstring = "${nhmod}(mekal)+cutoffpl/b";
    $line      = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1 & -0.15,0 & 5.6,0 & 0.1";
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
  push @clpar,$txpar2 if ($model eq "mekal2t");
  push @clpar,$normpar2 if ($model eq "mekal2t");

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

    # stat to high can't calculate errors
    if ($line =~ /maximum/) {
      print "## $obsid: $statname too large to estimate confidence intervals\n";
      print LOGFILE "$obsid: $statname too large to estimate confidence intervals\n";
	
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
      print "## $obsid: no fit, confidence intervals unreal\n";
      print LOGFILE "## $obsid: no fit, confidence intervals unreal\n";
	
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
    if ($line =~ m/^XSPEC.*?\s+Parameter\s+Confidence/) {
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

      # make a gif image of the spectrum
      unlink "${obsid}_custom_spectrum.ps";
      myprint
	"setplot energy\n",
	  "iplot ldata resid\n",
	    "label top $name $obsid\n",
	      "time off\n",
		"cpd ${obsid}_custom_spectrum.ps/vcps\n",
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
    if ($model eq "mekal2t") {
      $tx2  = $moddata[0] if ($mcount == $txpar2);
      $norm2 = $moddata[0] if ($mcount == $normpar2);
    }
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

  # handle the mekal2t models params
  if ($model eq "mekal2t") {
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
    if (/Net count rate/) {
      @data = split("/",$_);
      $ptot = $data[2];
      $ptot =~ s/^.*\(//;
      $ptot =~ s/\%.*//;
      chomp $ptot;
    }
  }
	
  # get Rout and Rin in arcmin (print later as part of output)
  open(INFILE,$sourcereg);
  while (<INFILE>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    if (/^circle/) {
      $rin = sprintf("%.2f",0);
      next;
    }
    @rin = (split/\,/,$_);
    $rin = $rin[2];
    chop $rin;
    $rin = ($rin*0.492)/60;
    chomp $rin;
    $rin = sprintf("%.2f",$rin);
  }
  close INFILE;

  $rout = `punlearn dmkeypar; dmkeypar ${file}+1 XFLT0001; pget dmkeypar value`;
  chomp $rout;
  $rout = sprintf("%.2f",$rout);

  # make a note in the logfile
  print LOGFILE "${obsid}: Fitting complete with Tx=$tx ; Fe=$fe ; stat=$stats[0]\n";

  # print out the info
  open(FITFILE,">>$Bin/${datfile}");
  printf FITFILE "%-25s %6s %6s %6s %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %10.2e %10.2e %10.2e %5.2f %5.2f %5.2f %10.2e %10.2e %10.2e %7.4f %6.3f %6s %6.2f %6i\n",$name,$obsid,$rin,$rout,$nh*1e2,$nlo*1e2,$nhi*1e2,$tx,$tlo,$thi,$fe,$felo,$fehi,$norm,$normlo,$normhi,$tx2,$tlo2,$thi2,$norm2,$normlo2,$normhi2,$z,$cr,$ptot,$stats[0],$dof[0];
  close FITFILE
}

#######################
#######################
