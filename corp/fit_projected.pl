#!/usr/bin/perl -w
#
# NAME:
#     fit_projected.pl
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
$quiet     = "no";
$rootdir   = "reprocessed/";                   # where to find the cluster specific data
$specdir   = "$ENV{HOME}/research/pf_clusters/pf_fits/plots/spectra/";
$sofexfile = "$ENV{HOME}/research/redux/redux_info/sofex_txfree_fefro.dat";

# fitting parameters
$dofit     = "yes";                            # if no then just creates the XCM files for xspec to run
$iter      = 10000;                            # the number of iterations XSPEC should run to 'fit'
$converge  = 0.01;                             # the convergance criterium for the 'fit statistic' used
$ntrial    = 1;                              # number of trials in the error calculation
$toler     = 0.05;                             # tolerance for the fit statistic

# details of fitting
@runname   = qw(annuli);                       # name of the region and spectra to use
@emin      = qw(0.7);                          # min and max energy ranges for fitting,
$emax      = "7.0";                            # needs to be a string so PERL don't cut off decimal pts.
$crmin     = "0.7";                            # needs to be a string so PERL don't cut off decimal pts.
$crmax     = "2.0";                            # needs to be a string so PERL don't cut off decimal pts.
$abund     = "angr";                           # angr, feld, aneb, grsa, wilm, lodd
$nhmod     = "wabs";                           # e.g., wabs,tbabs, ph
$freeze_nh = "yes";                            # fix nh to the galactic value? "yes" or "no"
$zfe       = "no";                             # if yes, then fe is frozen at $confe for z > conz
$conz      = 0.3;
$confe     = 0.3;
$freeze_fe = "no";                             # keep fe at specified level, shouldn't be "yes" often
$src       = "src1_grp";                       # extension of spectral files: sou, src1, src1_grp, ...
$bgd       = "bgd";                            # extension of bkgrnd spectral files: bgd, bgd_adj, ...
$h0        = 70;                               # cosmology h0
$q0        = 0.0;                              # norm. acceleration (ignored by Xspec)
$omegal    = 0.7;                              # cosmology imega_lambda
$timeout   = 1800;                             # seconds until kills xspec job
$syserr    = "0.00";                           # % systematic error to add
$stat      = "chi";                            # statistic to use in fitting: cstat (low count), chi (good S/N), lstat (Bayesian)
$conlevel  = "2.71";                           # compute confidence intervals:
                                               # 1.0 = 68% (1-sigma), 2.71 = 90% (1.6-sigma), 4.0 = 95.5% (2-sigma),
                                               # 6.63 = 99% (2.6-sigma), 9.0 = 99.7% (3-sigma)
$lconf     = "90";
$lmin      = "0.001";
$lmax      = "100.0";

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
use POSIX qw(strftime);
use FindBin qw($Bin);
use Cwd;

# check input params
$nargs = @ARGV;
die "Incorrect number of parameters\n" if ($nargs != 2);

foreach $emin (@emin) {
  foreach $runname (@runname) {

    # define the dat file name
    $ad = "";
    $ad = "adj_" if ($bgd =~ /.*adj.*/);
    $nff = "nhfro";
    $nff = "nhfree" if ($freeze_nh eq "no");
    $fff = "fefro";
    $fff = "fefree" if ($freeze_fe eq "no");
    $en = "7-7";
    $en = "2-7" if ($emin eq "2.0");
    $datfile = "${ad}${runname}_${nff}_${fff}_${en}.dat";

    # read in the reference file
    %refdata = get_data($ARGV[0]);
    $model = $ARGV[1];
    if ($model =~ /apec\/b/ || $model =~ /mekal\/b/) {
      %sofexdata = get_data($sofexfile);
    }

    # determine how many items there are
    open(COUNT,$ARGV[0]);
    while(<COUNT>){
      next if (/^\#/);
      next if (/^$/);
      $counter++;
    }

    # define the state name
    $statname = "chisq" if ($stat eq "chi");
    $statname = "cash"  if ($stat eq "cstat");
    $statname = "bayes" if ($stat eq "lstat");

    # open file to contain fit results and errors
    if ($dofit eq "yes") {
      open(FITFILE,">$Bin/${datfile}");
      print_info();
      close FITFILE;
    }

    # open up a logfile
    open(LOGFILE,">fit_spectra.log") || die "Can't open fit_spectra.log\n";
    print LOGFILE "\n###### Started fitting at ",scalar(localtime)," ######\n";

    # go through each cluster
    foreach $key (sort keys %refdata) {

      # announce how much longer
      print "## STATUS: $counter cluster(s) left to fit\n";

      # split up the data line
      @data = split(/\s+/,$refdata{$key});

      # get values
      $name    = $data[0];

      # check for multiple obs
      if (exists $check{$name}){
          print "## WARNING: $name has multiple entries skipping.\n";
          next;
      }
      $num = check_obs($name,$ARGV[0]);
      %check = ();
      if ($num > 1) {
          print "## WARNING: There are multiple entries for $name, skipping.\n";
          unless (exists $check{$name}) {
              open(ERR,">>err_multi");
              print ERR "$name\n";
              close ERR;
          }
          $check{$name} = $name;
          next;
      }

      # read rest of data
      $obsid   = $data[1];
      $z       = $data[6];
      $nh      = $data[7]*1e-2;
      $tx      = $data[8];
      $fe      = $data[9];
      $datadir = $data[15];
      $fail    = "no";

      # determine fe freeze based on redshift
      if ($zfe eq "yes") {
	  if ($z >= $conz) {
	      $freeze_fe = "yes";
	      $fe = $confe;
	  } else {
	      $freeze_fe = "no";
	      $fe = $data[9];
	  }
      }

      # change directory
      chdir("$datadir/$obsid/$rootdir");

      # get all regions to work with
      %annuli = get_annuli("*_${runname}*${src}.pi");

      # make sure we have files to work with
      unless (%annuli) {
	print "## No ${runname} spectra for $obsid ($name)\n";
        print LOGFILE "${obsid}: No ${runname} spectra\n";
        chdir("$Bin");
        next;
      }

      $todo = scalar(keys %annuli);
      print "## STATUS: $todo annuli to fit for ${name}.\n";

      # fit each annulus
      foreach $anum (sort {$a <=> $b} keys %annuli) {

	# define some names
#	$bgfile = $annuli{$anum};
#	$bgfile =~ s/\_${src}.pi/\_${bgd}.pi/;
	$xcmfile = "${name}_${obsid}_${runname}${anum}.xcm";
	$annreg  = "${name}_${obsid}_${runname}${anum}.reg";

#	# update the data file's header for bgd selection
#	$command = "punlearn dmhedit; dmhedit infile=$annuli{$anum} operation=add key=BACKFILE value=$bgfile filelist=\"\"";
#	system($command);

	print "## Working on $annuli{$anum}\n" if ($quiet eq "yes");

	# add soft excess bgd component
	if ($model =~ /apec\/b/ || $model =~ /mekal\/b/) {
	  unless (exists $sofexdata{$key}) {
	    print "## No sofex fit for $obsid ($name)\n";
	    print LOGFILE "${obsid}: No sofex fit\n";
	    chdir("$Bin");
	    $fail = "yes";
	  } else {
	    sub_add_sofex();
	    $fail = "no";
	  }
	}
	next if ($fail eq "yes");

	# print model to XCMFILE, get parameters for con limit determination
	@clpar = make_xcmfile($nhmod,$model,$annuli{$anum},$xcmfile);

	# run xspec (see subroutine run_xspec) with a timeout
	do_xspec($xcmfile,@clpar) if ($dofit eq "yes");

	# format output and put into results file
	format_output($annuli{$anum},@clpar) if ($dofit eq "yes");
      }

      # change back to original directory
      chdir("$Bin");

      # increment counter
      $counter--;

      # write to log file
      print LOGFILE "###### Finished $name (ObsId $obsid) ",scalar(localtime),"\n";
    }

    # close files and exit
    print LOGFILE "###### Finished fitting ",scalar(localtime)," ######\n\n";
    print "\n###### Finished fitting ",scalar(localtime)," ######\n\n";
    close LOGFILE;
  }
}

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

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

sub check_obs {

    my($name,$infile) = @_;
    my(@a,$num);
    $num = 0;
    open(A,$infile);
    while(<A>){
        chomp;
        next if (/^\#/); # skip comment lines
        next if (/^$/);  # skip blank lines
        s/^\s+//;        # trim leading whitespace
        s/\s+$//;        # trim trailing whitespace
        @a = split;
        $num++ if ($a[0] eq $name);
    }
    close A;
    return $num;
}

#######################
#######################

sub print_info {

  print FITFILE "# Model: $nhmod($ARGV[1]) for $runname spectra using Abund $abund; Fit Range = $emin - $emax; Count Rates = $crmin - $crmax keV\n";
  print FITFILE "# Nh frozen = $freeze_nh; Fe frozen = $freeze_fe; Confidence Levels = $conlevel; Systematic error = $syserr\n";

  printf FITFILE "%-25s %6s %6s %6s %5s %5s %5s %5s %5s %5s %5s %5s %5s %10s %10s %10s %5s %5s %5s %10s %10s %10s %7s %6s %6s %6s %6s\n",
    "# Cluster","ObsID","Rin","Rout","nh20","nlo","nhi","Tx","Tlo","Thi","Fe","Felo","Fehi",
      "Norm","Normlo","Normhi","Tx2","Tlo2","Thi2","Norm2","Normlo2","Normhi2","z","Cr","Src\%",$statname,"dof";
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

sub sub_add_sofex {

  @sofex = split(/\s+/,$sofexdata{$key});
  $softx = $sofex[2];
  $soffe = $sofex[5];
  $sofnorm = $sofex[10];
  $sofarea = $sofex[17];
  $scale = 0;
  open(REG,"$annreg");
  while(<REG>){
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
      $scale = (PI*(($out**2)-($in**2)))/$sofarea;
    }
    if (/^circle/) {
      my @vals = split(",",$_);
      my $r = $vals[2];
      $r =~ s/\)//g;
      $scale = (PI*$r**2)/$sofarea;
    }
    if (/^ellipse/) {
      my @vals = split(",",$_);
      my $b = $vals[3];
      $b =~ s/\)//g;
      my $a = $vals[2];
      $a =~ s/\)//g;
      $scale = (PI*$b*$a)/$sofarea;
    }
  }
  close REG;
  $snorm = $scale*$sofnorm;
  $snorm = sprintf("%7.2E",$snorm);
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

  # set the abundance model
  print XCMFILE "abund $abund\n";

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
  # MKCFLOW model#########################################################
  elsif ($model eq "mkcflow") {
    ($nhpar,$txpar,$txpar2,$fepar,$normpar) = (1,2,3,4,7);
    $modstring = "${nhmod}(mkcflow)";
    $line      = "& $nh & 0.1 & $tx & $fe,0 & $z & 0 & 0.1";
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
  elsif ($model eq "mekal+cutoffpl/b") {
    ($nhpar,$txpar,$fepar,$normpar) = (1,2,4,7);
    $modstring = "${nhmod}(mekal)+cutoffpl/b";
    $line      = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1 & -0.15,0 & 5.6,0 & 0.1";
  }
  # MEKAL+APEC/b model##################################################
  elsif ($model eq "mekal+apec/b") {
    ($nhpar,$txpar,$fepar,$normpar) = (1,2,4,7);
    $modstring = "${nhmod}(mekal)+apec/b";
    $line      = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1 & $softx,0 & $soffe & 0 & $snorm,0";
  }
  # MEKAL+MEKAL/b model##################################################
  elsif ($model eq "mekal+mekal/b") {
    ($nhpar,$txpar,$fepar,$normpar) = (1,2,4,7);
    $modstring = "${nhmod}(mekal)+mekal/b";
    $line = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1 & $softx,0 & 1.0 & $soffe & 0 & 0 & $snorm,0";
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

  # xspec no understand neg. norm
  if ($model =~ /apec\/b/ || $model =~ /mekal\/b/) {
      if ($snorm < 0.00) {
	  if ($model =~ /apec\/b/) {
	      print XCMFILE "newpar 11 1 $snorm $snorm $snorm $snorm $snorm\n";
	  } elsif ($model =~ /mekal\/b/) {
	      print XCMFILE "newpar 13 1 $snorm $snorm $snorm $snorm $snorm\n";
	  } else {
	      die "## ERROR: what in the $snorm is this!\n";
	  }
      }
  }

  # remove unnecessary component... just in case
  if ($model =~ /apec\/b/ || $model =~ /mekal\/b/) {
      print XCMFILE "delcomp 3\n" if ($softx == 0);
  }

  # done with the xcm file, close
  close XCMFILE;

  # get the parameters to get con limits for
  @clpar = ();
  push @clpar,$nhpar if ($freeze_nh eq "no");
  push @clpar,$txpar;
  push @clpar,$normpar;
  push @clpar,$fepar if ($freeze_fe eq "no");
  push @clpar,$txpar2 if ($model eq "mekal2t" || $model eq "mkcflow");
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
  $nconv = $converge;

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
    if ($line =~ m/^.*?\s+Parameter\s+Confidence/) {
      $done = 0;
      # what to do in various cases
      while ($done < @parameters) {
	chomp ($line=<XSPEC_OUTPUT>);
	print "xspec: $line\n" if ($quiet eq "no");

	# error found a new minimum
	if ($line =~ m/when model parameter/) {
	  print LOGFILE "$obsid: Check fit for $runname $anum\n";
	  $nconv = 0.1*$converge;
	  myprint "fit $iter $nconv\n" ;
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
      unlink "${obsid}_${runname}${anum}_spec.ps";
      myprint
	  "setplot energy\n",
	  "iplot ldata resid\n",
	  "label top $name $obsid\n",
	  "time off\n",
	  "cpd ${obsid}_${runname}${anum}_spec.ps/vcps\n",
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

      # open an output file
      $mytime = strftime("%Y-%m-%d %X", localtime);
      $filler = 'eval puts \$fileid \"-------------------------"'."\n";
      myprint 'set fileid [open '.${runname}.'_lumin.dat a]'."\n";
      unless (-e "${runname}_lumin.dat") {
	  myprint 'eval puts \$fileid \"'."Created: $mytime\"\n";
	  myprint 'eval puts \$fileid \"'."Runname: $runname\"\n";
	  myprint 'eval puts \$fileid \"'."Fit confidence: $conlevel\"\n";
	  myprint 'eval puts \$fileid \"'."Fit emin-emax: $emin-$emax keV\"\n";
	  myprint 'eval puts \$fileid \"'."Flux/Lum confidence: $lconf\"\n";
	  myprint 'eval puts \$fileid \"'."Flux/Lum emin-emax: $lmin-$lmax keV\"\n";
	  myprint 'eval puts \$fileid \"Flux units: ergs/cm2/sec"'."\n";
	  myprint 'eval puts \$fileid \"Lum units: ergs/sec"'."\n";
	  myprint $filler;
      }

      # make diagonal response
      myprint "dummyrsp $lmin $lmax 3000\n";

      # get flux
      myprint "flux $lmin $lmax $z err 1000 $lconf\n";
      myprint "tclout flux\n";
      myprint 'scan $xspec_tclout "%f %f %f" fl fllo flhi'."\n";
      myprint 'eval puts \$fileid \"Flux $fl $fllo $flhi"'."\n";
      myprint $filler;

      # get lumin
      myprint "lumin $lmin $lmax $z err 100 $lconf\n";
      myprint "tclout lumin\n";
      myprint 'scan $xspec_tclout "%f %f %f" lum lumlo lumhi'."\n";
      myprint 'eval puts \$fileid \"Lumin $lum $lumlo $lumhi"'."\n";
      myprint $filler;

      # all done quit XSPEC
      myprint "exit\n\n";
    }
  }

  close XSPEC_INPUT;
  close XSPEC_OUTPUT;
  close XSPEC_ERR;
  waitpid($pid,0);

  # take care of spectral image
  mkdir("$specdir",0777) unless (-d "$specdir");
  system("mv -f ${obsid}_${runname}${anum}_spec.ps $specdir");
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
    if ($model eq "mekal2t" || $model eq "mkcflow") {
      $tx2  = $moddata[0] if ($mcount == $txpar2);
    }
    if ($model eq "mekal2t") {
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
  if ($model eq "mekal2t" || $model eq "mkcflow") {
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
  open(INFILE,$annreg);
  while (<INFILE>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    if (/^circle/) {
      $rin = sprintf("%.2f",0);
      last;
    }
    @rin = split(/\,/,$_);
    $rin = ($rin[2]*0.492)/60;
  }
  close INFILE;
  $rout = `punlearn dmkeypar; dmkeypar ${file}+1 XFLT0001; pget dmkeypar value`;
  chomp $rout;
  $rout = sprintf("%.2f",$rout);

  # print out the info
  open(FITFILE,">>$Bin/${datfile}");
  printf FITFILE "%-25s %6s %6.3f %6.3f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %10.2e %10.2e %10.2e %5.2f %5.2f %5.2f %10.2e %10.2e %10.2e %7.4f %6.3f %6s %6.2f %6i\n",$name,$obsid,$rin,$rout,$nh*1e2,$nlo*1e2,$nhi*1e2,$tx,$tlo,$thi,$fe,$felo,$fehi,$norm,$normlo,$normhi,$tx2,$tlo2,$thi2,$norm2,$normlo2,$normhi2,$z,$cr,$ptot,$stats[0],$dof[0];
  close FITFILE
}

#######################
#######################
