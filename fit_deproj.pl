#! /usr/bin/perl -w
#
# VERSION:
#
# NAME:
#
# PURPOSE:
#
# EXPLANATION:
#
# CALLING SEQUENCE:
#     fit_1tdeproj.pl <reference file> <config file>
#
# INPUTS:
#     <config file>:           file telling the script how to treat each annulus
#     the required format for the config file is as follows:
#
#     Cluster                    ObsID Ann  Model     nh20     Tx    Fe     Norm  Tx2   Norm2
#     2A_0335+096                  919  1   mekal    18.11   0.99  0.90  7.70e-4  2.0 5.20e-3
#     2A_0335+096                  919  2   mekal      =1    1.75   =1   6.70e-3  2.0 6.60e-4
#     2A_0335+096                  919  3   mekal      =1    1.02   =1   6.00e-3  2.0 1.00e-5
#     2A_0335+096                  919  4   mekal      =1    2.35  0.90  9.50e-3  0.5 1.00e-5
#
#     -Model can be mekal or mekal2t.
#     -Ann is just an enumeration of the annuli.
#     -nh20 is the column density and can be manipulated depending on type of fitting.
#     -Tx and Tx2 are fit temperatures from correlated projected fitting run,
#       Tx2 is ignored if using a single temperature model.
#     -Fe is the metallicity from correlated projected fitting run and can be tied to other annuli.
#     -Norm and Norm2 are the normalization from correlated projected fitting run,
#       Norm2 is ignored if using a single temperature model.
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

$xspeccom  = "xspec";
$datadir   = "/mnt/DROBO/";
$rootdir   = "reprocessed/";                   # where to find the cluster specific data
$makeps    = "no";                            # make gifs files of the spectrum, sort of broken now
$specdir   = "/home/cavagnolo/research/pf_clusters/pf_fits/plots/spectra/";      # where to put images of spectra

# fitting parameters
$iter      = 1000;                             # the number of iterations XSPEC should run to 'fit'
$converge  = 0.01;                             # the convergance criterium for the 'fit statistic' used
$ntrial    = 100;                              # number of trials in the error calculation
$toler     = 0.1;                              # tolerance for the fit statistic

# details of fitting
$chat      = "10";
$calcerr   = "yes";
$freeze_nh = "yes";                            # fix nh to the Galactic value? "yes" or "no"
$freeze_fe = "no";                             # fix nh to input value?
$runname   = "annuli";                         # run name of the annuli to use
$src       = "src1_grp";                       # extension of spectrum files: sou, src1, src1_grp, ...
$h0        = 70;
$q0        = 0.0;                              # norm. acceleration (ignored by Xspec)
$omegal    = 0.7;
$timeout   = 172800;                            # seconds until kills xspec job
$emin      = "0.7";                            # min and max energy ranges for fitting,
$emax      = "7.0";                            # use a string so PERL won't cut off decimal pts.
$crmin     = "0.7";                            # min for count rate reporting
$crmax     = "2.0";                            # max for count rate reporting
$nhmod     = "wabs";                           # nh model to use, e.g., wabs, tbabs, phabs
$syserr    = "0.00";
$stat      = "chi";                            # statistic to use in fitting: cstat (low count), chi (good S/N), lstat (Bayesian)
$conlevel  = "2.71";                           # compute confidence intervals:
                                               # 1.0 = 68% (1-sigma), 2.71 = 90% (1.6-sigma), 4.0 = 95.5% (2-sigma),
                                               # 6.63 = 99% (2.6-sigma), 9.0 = 99.7% (3-sigma)

#######################
#######################
##   Main Program    ##
#######################
#######################

# set some parameters
$nargs = @ARGV;
die "## ERROR: Incorrect number of parameters\n" if ($nargs != 1);
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});
use FindBin qw($Bin);
use Cwd;
$ENV{PGPLOT_TYPE}="/null";
use constant PI => 4*atan2(1,1);

# read in the reference file
%refdata = &get_data($ARGV[0]);

# read in the model config file
%configdata = &get_config($ARGV[0]);

# define the dat file name
$nff = "nhfro";
$nff = "nhfree" if ($freeze_nh eq "no");
$fff = "fefro";
$fff = "fefree" if ($freeze_fe eq "no");
$datfile = "deproj_${runname}_${nff}_${fff}.dat";

# determine how many items there are
$counter = scalar(keys %refdata);

# define the state name
$statname = "chisq" if ($stat eq "chi");
$statname = "cash"  if ($stat eq "cstat");
$statname = "bayes" if ($stat eq "lstat");

# if actually doing the fit print some information
open(FITFILE,">$Bin/${datfile}");
&print_info();

# go through each cluster in reference list
foreach $key (sort keys %refdata) {

    # announce how much longer
    print "$counter clusters left to fit\n";

    # split up the data line
    @data = split(" ",$refdata{$key});
    $name  = $data[0];
    $obsid = $data[1];
    $z     = $data[2];

    # change directory
    chdir("$datadir/$obsid/$rootdir");

    # define file name
    $xcmfile = "${name}_${obsid}_config_1tdeproj.xcm" ;

    # return hash of file names corresponding to annuli
    %annuli = &get_annuli("*_${runname}*${src}.pi");

    # make sure we have files to work with
    unless (%annuli) {
	print "## No ${runname} spectra for $obsid ($name)\n";
	chdir("$Bin");
	next;
    }
    
    # print model to XCMFILE, get parms for confidence limits calc
    &make_model($xcmfile,$name,$obsid,$z);

    # run xspec (dump results to model.dat)
    &run_xspec($xcmfile);

    # format output (in model.dat) and put into results file
    &format_output(sort {$a <=> $b} keys %annuli);
    
    # take care of spectral image
    system("cp -f ${obsid}_deproj.ps $specdir") if ($makeps eq "yes");

    # return home
    chdir("$Bin");
}

# close files and exit
close FITFILE;
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub get_data {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "## ERROR: Cannot open $infile.\n";
  my $nann = 1;
  my $prevname = "nihil";
  while (<INFILE>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    s/^\s+//;        # trim leading whitespace
    s/\s+$//;        # trim trailing whitespace
    @data = split;
    if ($data[0] eq $prevname) {
	$nann++;
    } else {
	$nann = 1;
    }
    $name = join "_", $data[0], $data[1];
    $info{$name} = $_;
    $prevname = $data[0];
    $numann{$data[0]} = $nann unless ($nann == 1);
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub get_config {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "## ERROR: Cannot open $infile.\n";
  while (<INFILE>) {
    chomp;
    next if (/^\#/); # skip comment lines
    next if (/^$/);  # skip blank lines
    s/^\s+//;        # trim leading whitespace
    s/\s+$//;        # trim trailing whitespace
    @data = split;
    $name = join "_", $data[0],$data[1],$data[3];
    $info{$name} = $_;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub print_info {

    print FITFILE "# Model: proj($nhmod(mekal+mekal)) for $runname spectra; Fit Range = $emin - $emax; Count Rates = $crmin - $crmax keV\n";
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
  my(@annuli,%annuli,$file,$anum);

  # search for annuli file in current directory
  @annuli = glob($searchstring);

  # want to make sure end up with hash sorted numerically
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

sub make_model {

    # get the input values
    my($xcmfile,$name,$obsid,$z) = @_;

    # set some local variables
    my($modelpars,$fepar,@clpar,$modstring,$line,@conpar,@zeroes,$amodel,$nh,
       $tx,$fe,$norm,$tx2,$norm2,$nhpar,%txpar,%fepar,%txpar2,%normpar2);

    # clean up any files left over from previous runs
    undef @zeroes;
    unlink <*.fit> ;
    system("rm -f ${xcmfile} ${xcmfile}.log ${xcmfile}.model model.dat");

    # print to XCM file
    open(XCMFILE,">$xcmfile");
    print XCMFILE
	"query yes\n",
	"chatter $chat\n",
	"cosmo ${h0} ${q0} ${omegal}\n",
	"statistic ${stat}\n";

    # print commands to XCM file to read in data
    foreach $datano (sort {$a <=> $b} keys %annuli) {
	last if ($datano > $numann{$name});
	print XCMFILE
	    "data $datano:$datano $annuli{$datano}\n";
    }
    $modstring = "${nhmod}(mekal+mekal)";
    print XCMFILE "model $modstring ";
    foreach $datano (sort {$a <=> $b} keys %annuli) {
	last if ($datano > $numann{$name});

	# check that the annulus file exists and max ann not exceeded
	die "## ERROR: Mismatch between annuli and config file: ${name}_${obsid}_${runname}${datano} doesn't exist.\n"
	    unless ("${name}_${obsid}_${runname}${datano}");

	# get the config data for this annulus
	@cdata = split(" ",$configdata{"${name}_${obsid}_${datano}"});
	($amodel,$nh,$tx,$fe,$norm,$tx2,$norm2) = splice(@cdata,4);
	$modelpars = 13;
	($nhpar,$txpar,$fepar,$normpar,$txpar2,$normpar2) = (1,2,4,7,8,13);
	
	# create arrays for each parameter type to hold all the numbers
	%nhpar  = return_numbers($nhpar,$modelpars,0);
	%txpar  = return_numbers($txpar,$modelpars,0);
	%fepar  = return_numbers($fepar,$modelpars,0);
	%txpar2 = return_numbers($txpar2,$modelpars,0);
	%normpar2 = return_numbers($normpar2,$modelpars,0);

	# setup the model string for the first annulus
	if ($datano == 1) {
	    $nh = $nh*1e-2;
	    $line  =  " & $nh & $tx & 1.0 & $fe,1 & $z & 0 & $norm & $tx2 & 1.0 & =4 & =5 & 0 & $norm2" if ($amodel eq "mekal2t");
	    $line  =  " & $nh & $tx & 1.0 & $fe,1 & $z & 0 & $norm & 1,0 & 1 & 1 & 1 & 1 & 1,0" if ($amodel eq "mekal");
	    push @zeroes, $txpar2{$datano} if ($amodel eq "mekal");
	    push @zeroes, $normpar2{$datano} if ($amodel eq "mekal");
	} else {
	    if ($nh =~ /^=/) {
		$anno = substr($nh,1);
		$nhput = "=" . $nhpar{$anno};
	    } else {
		$nhput = $nh*1e-2;
	    }
	    if ($fe =~ /^=/) {
		$anno  = substr($fe,1);
		$feput = "=" . $fepar{$anno};
	    } else {
		$feput = $fe;
	    }
	    if ($tx =~ /^=/) {
		$anno  = substr($tx,1);
		$txput = "=" . $txpar{$anno};
	    } else {
		$txput = $tx;
	    }
	    # do tx2
	    if ($tx2 =~ /^=/) {
		$anno  = substr($tx2,1);
		$txput2 = "=" . $txpar2{$anno};
	    } else {
		$txput2 = $tx2;
		push @zeroes, $txpar2{$datano} if ($amodel eq "mekal");
		push @zeroes, $normpar2{$datano} if ($amodel eq "mekal");
	    }
	    # setup model string
	    $line  = " & $nhput & $txput & 1.0 & $feput,1 & =5 & 0 & $norm & $txput2 & 1.0 & = $fepar{$datano} & =5 & 0 & $norm2" if ($amodel eq "mekal2t");
	    $line  = " & $nhput & $txput & 1.0 & $feput,1 & =5 & 0 & $norm & 1,0 & 1 & 1 & 1 & 1 & 1,0" if ($amodel eq "mekal");
	}
	
	# print out the model paramters for this annulus
	print XCMFILE $line;
    }

    # done with loop now print carriage return to finish model line
    print XCMFILE "\n";

    # zero out second comp
    foreach $par (@zeroes) {
	print XCMFILE "newpar $par 0 0 -1 -1 1 1\n";
	print XCMFILE "freeze $par\n";
    }

    # freeze nh and fe if desired
    print XCMFILE "freeze " . join(" ",values %nhpar) . "\n"
	if ($freeze_nh eq "yes");
    print XCMFILE "freeze " . join(" ",values %fepar) . "\n"
	if ($freeze_fe eq "yes");

    # fix energy ranges
    print XCMFILE
	"ignore **:**-${emin} ${emax}-**\n";

    # fit the annuli first then do deprojected fit via editmod
    print XCMFILE "fit $iter $converge\n";
    print XCMFILE "editmod proj*${modstring} & \*\n";
    print XCMFILE "fit $iter $converge\n";

    # figure out parameter number for new model (offset by 3)
    %nhpar    = return_numbers($nhpar,$modelpars,3);
    %txpar    = return_numbers($txpar,$modelpars,3);
    %fepar    = return_numbers($fepar,$modelpars,3);
    %normpar  = return_numbers($normpar,$modelpars,3);
    %txpar2   = return_numbers($txpar2,$modelpars,3);
    %normpar2 = return_numbers($normpar2,$modelpars,3);

    # get the confidence limits for interesting parameters
    @conpar = values %txpar;
    push @conpar, values %nhpar;
    push @conpar, values %fepar if ($freeze_fe eq "no");
    push @conpar, values %normpar;
    push @conpar, values %txpar2 ;
    push @conpar, values %normpar2;
    @conpar = sort {$a <=> $b} @conpar;

    # save model information
    print XCMFILE
	"save model ${xcmfile}.model\n",
	"log ${xcmfile}.log\n",
	"show fit\n",
	"log none\n";

    # print appropriate error calc line
    print XCMFILE "error stopat $ntrial $toler maximum 10.0 $conlevel @conpar\n" if ($calcerr eq "yes");

    # print out information about the fit
    print XCMFILE
	'set xs_return_result 1',"\n",
	'set fileid [open model.dat w]',"\n",
	'tclout dof',"\n",
	'scan $xspec_tclout "%f" dof',"\n",
	'tclout stat',"\n",
	'set totchi $xspec_tclout',"\n",
	'set chisq [expr $totchi/$dof]',"\n",
	"set z $z\n",
	"set name $name\n",
	"set obsid $obsid\n";
    print XCMFILE 'puts $fileid "$name $obsid $chisq $dof"',"\n";

    # print out information about the fit for each annulus
    # use XSPEC TCL commands
    foreach $datano (sort {$a <=> $b} keys %annuli) {
	last if ($datano > $numann{$name});

	# get the config data for this annulus
	@cdata = split(" ",$configdata{"${name}_${obsid}_${datano}"});
	print XCMFILE
	    "set datano $datano\n",
	    # NH
	    "tclout param $nhpar{$datano}\n",
	    'scan $xspec_tclout "%f" nh',"\n",
	    # TX
	    "tclout param $txpar{$datano}\n",
	    'scan $xspec_tclout "%f" tx',"\n",
	    # FE
	    "tclout param $fepar{$datano}\n",
	    'scan $xspec_tclout "%f" fe',"\n",
	    # NORM
	    "tclout param $normpar{$datano}\n",
	    'scan $xspec_tclout "%f" norm',"\n";

	# get errors
	print XCMFILE
	    # NH
	    "tclout error $nhpar{$datano}\n",
	    'scan $xspec_tclout "%f %f" nlo nhi',"\n",
	    # TX
	    "tclout error $txpar{$datano}\n",
	    'scan $xspec_tclout "%f %f" tlo thi',"\n",
	    # NORM
	    "tclout error $normpar{$datano}\n",
	    'scan $xspec_tclout "%f %f" normlo normhi',"\n";
	# FE
	if ($freeze_fe eq "no") {
	    print XCMFILE
		"tclout error $fepar{$datano}\n",
		'scan $xspec_tclout "%f %f" felo fehi',"\n";
	} else {
	    print XCMFILE
		'set felo $fe',"\n",
		'set fehi $fe',"\n";
	}
	
	# TX2 & Norm2
	print XCMFILE
	    "tclout param $txpar2{$datano}\n",
	    'scan $xspec_tclout "%f" tx2',"\n",
	    "tclout param $normpar2{$datano}\n",
	    'scan $xspec_tclout "%f" norm2',"\n",
	    "tclout error $txpar2{$datano}\n",
	    'scan $xspec_tclout "%f %f" tlo2 thi2',"\n",
	    "tclout error $normpar2{$datano}\n",
	    'scan $xspec_tclout "%f %f" normlo2 normhi2',"\n";

	# get 0.7-2.0 keV count rate and model norm
	print XCMFILE
	    "notice **:**-**\n",
	    "ignore **:**-$crmin $crmax-**\n",
	    "tclout rate $datano\n",
	    'scan $xspec_tclout "%f" cr',"\n";

	print XCMFILE 'puts $fileid "$datano $nh $nlo $nhi $tx $tlo $thi $fe $felo $fehi $norm $normlo $normhi $tx2 $tlo2 $thi2 $norm2 $normlo2 $normhi2 $cr"',"\n";
    }
    print XCMFILE 'close $fileid',"\n";

    # make a gif image of the spectrum
    if ($makeps eq "yes") {
	print XCMFILE
	    "notice **:**-**\n",
	    "ignore **:**-${emin} ${emax}-**\n",
	    "setplot energy\n",
	    "setplot rebin 3,3\n",
	    "cpd ${obsid}_deproj.ps/vcps\n",
	    "plot ldata resid\n",
	    "cpd /null\n";
    }

    # all done quit XSPEC
    print XCMFILE "quit\n\n";

    # done with the xcm file, close
    close XCMFILE;
}

#######################
#######################

sub run_xspec {

  # runs xspec, kills xspec if takes longer than $timeout
  my($xcmfile) = shift;

  # delete files
  unless (defined ($pid = fork)) { die "## ERROR: Cannot fork $!"; }
  unless ($pid) {
    alarm $timeout;
    exec $xspeccom,$xcmfile;
  };
  wait;
  if ($? & 255) {
    next;
  }
}

#######################
#######################

sub format_output {

  my(@datano) = @_;
  my(@lines,$name,$obsid,$chisq,$dof,$header,@info,$group,$temp,@temp);

  open(MODEL,"model.dat") || die "## ERROR: Can't open model.dat";
  chomp(@lines = <MODEL>);
  $header = shift @lines;
  ($name,$obsid,$chisq,$dof) = split(" ",$header);

  foreach $line (@lines) {
    ($ann,$nh,$nlo,$nhi,$tx,$tlo,$thi,$fe,$felo,$fehi,$norm,$normlo,$normhi,$tx2,$tlo2,$thi2,$norm2,$normlo2,$normhi2,$cr) = split(" ",$line);
	
    # get the outer annuli radius
    $file = $annuli{$ann};
    $rin = 0.00 if ($ann == 1);
    $rout = `punlearn dmkeypar; dmkeypar ${file}+1 XFLT0001; pget dmkeypar value`;
    chomp $rout;
    $rout = sprintf("%.2f",$rout);
    $ptot = "0.00";

    # print line to FITFILE
    printf FITFILE "%-25s %6s %6.2f %6.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %10.2e %10.2e "
      ."%10.2e %5.2f %5.2f %5.2f %10.2e %10.2e %10.2e %7.4f %6.3f %6s %6.2f %6i\n",
	$name,$obsid,$rin,$rout,$nh*1e2,$nlo*1e2,$nhi*1e2,$tx,$tlo,$thi,$fe,$felo,$fehi,$norm,$normlo,$normhi,
	  $tx2,$tlo2,$thi2,$norm2,$normlo2,$normhi2,$z,$cr,$ptot,$chisq,$dof;
    $rin = $rout;
  }
}

#######################
#######################

sub return_numbers {

    # returns list of parameter numbers for given paramter and model
    my($param,$modelpars,$offset) = @_;
    my(%params);
    foreach $datano (sort {$a <=> $b} keys %annuli) {
	last if ($datano > $numann{$name});
	$params{$datano} = $param + ($modelpars) * ($datano-1) + $offset * $datano;
    }
    return %params;
}

#######################
#######################
