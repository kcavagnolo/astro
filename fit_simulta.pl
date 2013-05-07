#!/usr/bin/perl -w
#
# NAME:
#     fit_simulta.pl
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
#     nh, Tx, Fe, normalization, chi-squared, and degrees of freedom.
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
$quiet     = "yes";                            # should Xspec vomit on the screen?
$rootdir   = "reprocessed";                    # where to find the cluster specific data
$specdir   = "$ENV{'HOME'}/research/iras09/data/tx_2.5K/";
$sofexfile = "$ENV{'HOME'}/research/redux/redux_info/sofex_txfree_fefro.dat";

# fitting parameters
$dofit      = "yes";                           # if no then just creates the XCM files for xspec to run
$iter       = 1000;                            # the number of iterations XSPEC should run to 'fit'
$converge   = 0.01;                            # the convergance criterium for the 'fit statistic' used
$ntrial     = 100;                             # number of trials in the error calculation
$toler      = 0.05;                            # tolerance for the fit statistic

# details of fitting
@runname   = ("annuli");                       # name of the region and spectra to use
@eming     = ("0.7");                          # min and max energy ranges for fitting,
$emax      = "7.0";                            # needs to be a string so PERL don't cut off decimal pts.
$crmin     = "0.7";
$crmax     = "2.0";
$abund     = "grsa";                           # angr, feld, aneb, grsa, wilm, lodd
$nhmod     = "wabs";                           # e.g., wabs,tbabs, ph
$freeze_nh = "yes";                            # fix nh to the galactic value? "yes" or "no"
$freeze_fe = "no";                             # keep fe at specified level, shouldn't be "yes" often
$src       = "src1_grp";                       # extension of spectral files: sou, src1, src1_grp, ...
$bgd       = "src1_bgd";                       # extension of bkgrnd spectral files: bgd, bgd_adj, ...
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

# check input params
$nargs = @ARGV;
die "Incorrect number of parameters\n" if ($nargs != 2);

foreach $eming (@eming) {
  foreach $runname (@runname) {

    # define the dat file name
    $ad = "";
    $ad = "adj_" if ($bgd =~ /.*adj.*/);
    $nff = "nhfro";
    $nff = "nhfree" if ($freeze_nh eq "no");
    $fff = "fefro";
    $fff = "fefree" if ($freeze_fe eq "no");
    $en = "7-7";
    $en = "2-7" if ($eming eq "2.0");
    $datfile   = "simulta_${ad}${runname}_${nff}_${fff}_${en}.dat";

    # read in the reference file
    %refdata = get_data($ARGV[0]);
    $model = $ARGV[1];
    if ($model =~ /apec\/b/ || $model =~ /mekal\/b/) {
      %sofexdata = get_sofex($sofexfile);
    }

    # determine how many items there are
    open(COUNT,$ARGV[0]);
    while(<COUNT>){
      next if (/^\#/);
      next if (/^$/);
      $counter++;
    }
    close COUNT;

    # store the script directory in $Bin
    use FindBin qw($Bin);
    use Cwd;

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

      # announce how much longer
      print "## STAUTS: $counter spectra left to fit\n";

      # split up the data line
      @data = split(/\s+/,$refdata{$key});

      #get values
      $name   = $data[0];
      @obsid  = ($data[1],$data[2],$data[3],$data[4]);
      $obsstr = join "+", @obsid;
      $obsstr =~ s/\+0000//g;
      $z      = $data[9];
      $nh     = $data[10]*1e-2;
      $tx     = $data[11];
      $fe     = $data[12];
      $emin   = $eming;
      $emin   = $data[15] if ($eming eq "2.0");
      $crmin  = $emin;
      $datadir= $data[18];

      # write to log file
      print "## STATUS: Working on $obsstr for ${emin}-${emax}\n" if ($quiet eq "yes");

      # get all annuli to work with
      %annuli = get_annuli("$datadir/$obsid[0]/$rootdir/*_${runname}*${src}.pi");

      # make sure we have files to work with
      unless (%annuli) {
	  print "## No ${runname} spectra for $obsstr ($name)\n";
	  print LOGFILE "${obsstr}: No ${runname} spectra\n";
	  chdir("$Bin");
	  next;
      }

      # go through each annulus and fit
      $todo = scalar(keys %annuli);
      foreach $anum (sort {$a <=> $b} keys %annuli) {
	  print "\n## STATUS: $todo annuli left to fit for ${name}.\n";

	  # define some names
	  @files = ();
	  @srcreg = ();
	  foreach $iobs (@obsid) {
	    next if ($iobs eq "0000");
	    $dir = "$datadir/$iobs/$rootdir";
	    my $data = "${name}_${iobs}_${runname}${anum}_${src}.pi";
	    my $databgd = "${name}_${iobs}_${runname}${anum}_${bgd}.pi";
	    my $sourcereg = "${name}_${iobs}_${runname}${anum}.reg";
	    unless (-e "$dir/$data") {
	      print "## ERROR: No spectrum for $iobs ($name)\n";
	      print LOGFILE "${iobs}: No ${runname}${anum} spectrum\n";
	      chdir("$Bin");
	      next;
	    }
	    push @files, $data;
	    push @srcreg, $sourcereg;
	    system("cp $dir/$data /tmp/");
	    system("cp $dir/$databgd /tmp/");
	    system("cp $dir/$sourcereg /tmp/");
	    system("cp $dir/${name}_${iobs}_${runname}${anum}_src1.wrmf /tmp/");
	    system("cp $dir/${name}_${iobs}_${runname}${anum}_src1.warf /tmp/");
	  }
	  next unless (@files);
	  $len = $#files;
	  $flen = $len+1;

	  # change directory
	  chdir("/tmp");

	  # add soft excess bgd component
	  if ($model =~ /apec\/b/ || $model =~ /mekal\/b/) {
	    sub_add_sofex();
	  }

	  # define filename
	  $xcmfile = "temp.xcm";

	  # update the data file's header for bgd selection
	  foreach $iobs (@obsid) {
	    next if ($iobs eq "0000");
	    my $data = "${name}_${iobs}_${runname}${anum}_${src}.pi";
	    my $databgd = "${name}_${iobs}_${runname}${anum}_${bgd}.pi";
	    if (-e $data && -e $databgd) {
		$command = "punlearn dmhedit; dmhedit infile=$data operation=add key=BACKFILE value=$databgd filelist=\"\"";
	    } else {
		next;
	    }
	    system($command);
	  }

	  # print model to XCMFILE, get parameters for con limit determination
	  @clpar = make_xcmfile($nhmod,$model,$xcmfile);

	  # run xspec (see subroutine run_xspec) with a timeout
	  do_xspec($xcmfile,@clpar) if ($dofit eq "yes");

	  # format output and put into results file
	  $sourcereg = $srcreg[0];
	  $file1 = $files[0];
	  format_output($file1,@clpar) if ($dofit eq "yes");

	  # clean-up
	  unlink <*pi>;
	  unlink <*wrmf>;
	  unlink <*warf>;
	  unlink <*reg>;
	  unlink("${xcmfile}");
	  unlink("${xcmfile}.model");
	  unlink("${xcmfile}.log");

	  # change back to original directory
	  chdir("$Bin");
	  $todo--;
	}

      # increment counter
      $counter--;
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

sub get_sofex {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## Can't open $infile\n";
  while (<INFILE>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;
    s/\s+$//;
    @data = split;
    $name = join "_", $data[0],$data[1];
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

    print FITFILE "# Model: $nhmod($ARGV[1]) for $runname spectra using Abund $abund; Fit Range = $eming - $emax; Count Rates = $crmin - $crmax keV\n";
    print FITFILE "# Nh frozen = $freeze_nh; Fe frozen = $freeze_fe; Confidence Levels = $conlevel; Systematic error = $syserr\n";

    	printf FITFILE "%-16s %20s %6s %6s %5s %5s %5s %5s %5s %5s %5s %5s %5s %10s %10s %10s %5s %5s %5s %10s %10s %10s %7s %6s %6s %6s %6s\n",
    "# Cluster","ObsID","Rin","Rout","nh20","nlo","nhi","Tx","Tlo","Thi","Fe","Felo","Fehi",
    "Norm","Normlo","Normhi","Tx2","Tlo2","Thi2","Norm2","Normlo2","Normhi2","z","Cr","Src\%","chisq","dof";
}

#######################
#######################

sub sub_add_sofex {

  my $i = 0;
  @softx = ();
  @soffe = ();
  @snorm = ();
  foreach $iobs (@obsid) {
    if ($iobs eq "0000") {
      push @softx, 0;
      push @soffe, 0;
      push @snorm, 0;
      next;
    }
    $key = $name."_".$iobs;
    if (exists $sofexdata{$key}) {
      @sofex = split(/\s+/,$sofexdata{$key});
      push @softx, $sofex[2];
      push @soffe, $sofex[5];
      $sofnorm = $sofex[10];
      $sofarea = $sofex[17];
      $scale = 0;
      open(REG,"$srcreg[$i]");
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
      push @snorm, $scale*$sofnorm;
    } else {
      push @softx, 0;
      push @soffe, 0;
      push @snorm, 0;
      next;
    }
    $i++;
  }
}

#######################
#######################


sub make_xcmfile {

  # input vaules
  my($nhmod,$model,$xcmfile) = @_;

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
  print XCMFILE "data ";
  for ($i=0; $i <= $len; $i++) {
    $dum = $i+1;
    print XCMFILE "${dum}:${dum} ".$files[$i]." ";
    print "## Loaded $files[$i]\n" if ($quiet eq "yes");
  }
  print XCMFILE "\n";
  $dum = $len+1;
  print XCMFILE "ignore bad\n";
  print XCMFILE "ignore 1-$dum:**-${emin} ${emax}-**\n";

  # set the abundance model
  print XCMFILE "abund $abund\n";

  # MEKAL model#########################################################
  if ($model eq "mekal") {
    ($nhpar,$txpar,$fepar,$normpar) = (1,2,4,7);
    $modstring = "${nhmod}(mekal)";
    $line = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1";
    for ($i=0; $i <= $len-1; $i++) {
      $line .= " & =1 & =2 & =3 & =4 & =5 & =6 & 0.1";
    }
    $line .= "\n";
  }
  # MEKAL2T model#########################################################
  elsif ($model eq "mekal2t") {
    ($nhpar,$txpar,$fepar,$normpar,$txpar2,$normpar2) = (1,2,4,7,8,13);
    $modstring = "${nhmod}(mekal+mekal)";
    $line = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1 & 1.0 & 1.0 & =4 & =5 & 0 & 0.1";
    for ($i=0; $i <= $len-1; $i++) {
      $line .= " & =1 & =2 & =3 & =4 & =5 & =6 & 0.1 & =8 & =9 & =10 & =11 & =12 & 0.1";
    }
    $line .= "\n";
  }
  # MEKAL+APEC/b model##################################################
  elsif ($model eq "mekal+apec/b") {
    ($nhpar,$txpar,$fepar,$normpar) = (1,2,4,7);
    $modstring = "${nhmod}(mekal)+apec/b";
    $line = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1 & $softx[0],0 & $soffe[0] & 0 & $snorm[0],0";
    for ($i=0; $i <= $len-1; $i++) {
      $dum = $i+1;
      $line .= " & =1 & =2 & =3 & =4 & =5 & =6 & 0.1 & $softx[$dum],0 & $soffe[$dum] & 0 & $snorm[$dum],0";
    }
    $line .= "\n";
  }
  # MEKAL+MEKAL/b model##################################################
  elsif ($model eq "mekal+mekal/b") {
    ($nhpar,$txpar,$fepar,$normpar) = (1,2,4,7);
    $modstring = "${nhmod}(mekal)+mekal/b";
    $line = "& $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.1 & $softx[0],0 & 1.0 & $soffe[0] & 0 & 0 & $snorm[0],0";
    for ($i=0; $i <= $len-1; $i++) {
      $dum = $i+1;
      $line .= " & =1 & =2 & =3 & =4 & =5 & =6 & 0.1 & $softx[$dum],0 & 1.0 & $soffe[$dum] & 0 & 0 & $snorm[$dum],0";
    }
    $line .= "\n";
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
      $snum = 0;
      foreach $s (@snorm) {
	  if ($s < 0.00) {
	      if ($model =~ /apec\/b/) {
		  $parnum = 11+(11*$snum);
		  $parnum = sprintf("%i",$parnum);
		  print XCMFILE "newpar $parnum 1 $s $s $s $s $s\n";
	      } elsif ($model =~ /mekal\/b/) {
		  $parnum = 13+(13*$snum);
		  $parnum = sprintf("%i",$parnum);
		  print XCMFILE "newpar $parnum 1 $s $s $s $s $s\n";
	      } else {
		  die "## ERROR: what in the $s is this!\n";
	      }
	  }
	  $snum++;
      }
  }

  # done with the xcm file, close
  close XCMFILE;

  # get the parameters to get con limits for
  @clpar = ();
  push @clpar,$nhpar if ($freeze_nh eq "no");
  push @clpar,$txpar;
  push @clpar,$normpar;
  push @clpar,$fepar if ($freeze_fe eq "no");
  if ($model eq "mekal2t") {
      push @clpar,$txpar2;
      push @clpar,$normpar2;
  }

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
      print(LOGFILE "$name $obsstr:  timed out\n");
      kill 15, $pid;  # relies of $pid being a global variable
      next;
    }
    else { # something else happended
      print LOGFILE "$name $obsstr exited early\n";
      next;
    }
  }
}

#######################
#######################

sub run_xspec {

  my ($xcmfile,@parameters) = @_;
  my ($parameters,$line,$done,$conlim,$params,$xline,$diff,$par,$dum);
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
      print "## $obsstr: Chi squared too large to estimate confidence intervals\n";
      print LOGFILE "$obsstr: Chi squared too large to estimate confidence intervals\n";
	
      # set errors to zero
      foreach $parameter (@parameters) {
	$low{$parameter} = 0;
	$high{$parameter} = 0;
      };
		
      # write things to a log file
      if ($model =~ /apec\/b/) {
	  $diff = 11;
      } elsif ($model =~ /mekal\/b/) {
	  $diff = 13;
      } else {
	  $diff = 0;
      }
      for ($i=0; $i <= $len; $i++) {
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
	  "notice 1-${flen}:**-**\n",
	  "ignore bad\n",
	  "ignore 1-${flen}:**-$crmin $crmax-**\n",
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
	  print LOGFILE "$obsstr: Check fit\n";
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
      if ($model =~ /apec\/b/) {
          $diff = 11;
      } elsif ($model =~ /mekal\/b/) {
          $diff = 13;
      } else {
	  $diff = 0;
      }
      for ($i=0; $i <= $len; $i++) {
          $dum = $i+1;
          $par = 7+($diff*$i);
          $par = sprintf("%i",$par);
          $xline .= "tclout rate $dum\n";
          $xline .= "puts \"Rate${dum} \$xspec_tclout\"\n";
          $xline .= "tclout param ${par}\n";
          $xline .= "puts \"Norm${dum} \$xspec_tclout\"\n";
      }

      # make a gif image of the spectrum
      $tobs = $obsstr;
      $tobs =~ s/\+/\_/g;
      unlink "${tobs}_${runname}${anum}_spec.ps";
      myprint
	  "setplot energy\n",
	  "iplot ldata resid\n",
	  "label top $name $obsstr\n",
	  "time off\n",
	  "cpd ${tobs}_${runname}${anum}_spec.ps/vcps\n",
	  "plot\n",
	  "cpd /null\n",
	  "exit\n";

      # save model
      myprint
	  "save model ${xcmfile}.model\n",
	  "log $xcmfile.log\n",
	  "show fit\n",
	  "notice 1-${flen}:**-**\n",
	  "ignore bad\n",
	  "ignore 1-${flen}:**-$crmin $crmax-**\n",
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

  # take care of spectral image
  mkdir("$specdir",0777) unless (-d "$specdir");
  $tobs = $obsstr;
  $tobs =~ s/\+/\_/g;
  system("mv -f ${tobs}_${runname}${anum}_spec.ps $specdir");
}

#######################
#######################

sub format_output {

  my($file,@parameters) = @_;
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
    if ($model eq "mekal2t") {
      $tx2   = $moddata[0] if ($mcount == $txpar2);
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

  # get Rout and Rin in arcmin (print later as part of output)
  open(INFILE,$sourcereg);
  while (<INFILE>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    @rin = (split/\,/,$_);
    $rin = $rin[2];
    $rin = ($rin*0.492)/60;
    $rin = 0.00 if ($runname eq "r2500" || $runname eq "r5000");
    chomp $rin;
    $rin = sprintf("%.2f",$rin);
  }
  close INFILE;

  $rout = `punlearn dmkeypar; dmkeypar ${file}+1 XFLT0001; pget dmkeypar value`;
  chomp $rout;
  $rout = sprintf("%.2f",$rout);

  # make a note in the logfile
  $obsid = join "+",@obsid;

  # print out the info
  open(FITFILE,">>$Bin/${datfile}");
  printf FITFILE "%-16s %20s %6s %6s %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f "
      ."%5.2f %10.2e %10.2e %10.2e %5.2f %5.2f %5.2f %10.2e %10.2e %10.2e %7.4f %6.3f "
      ."%6.1f %6.2f %6i\n",$name,$obsstr,$rin,$rout,$nh*1e2,$nlo*1e2,$nhi*1e2,$tx,$tlo,$thi,
      $fe,$felo,$fehi,$norm,$normlo,$normhi,$tx2,$tlo2,$thi2,$norm2,$normlo2,$normhi2,$z,$cr,
      $ptot,$chisq[0],$dof[0];
  close FITFILE
}

#######################
#######################
