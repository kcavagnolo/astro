#!/usr/bin/perl -w
#
# NAME:
#     find_tx.pl
#
# PURPOSE:
#
# EXPLANATION:
#
# CALLING SEQUENCE:
#     find_tx.pl <reference list>
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

$forcetx  = "yes";
$errfile  = "err_find_tx.log";
$delta    = 200;                          # r_delta -> delta=500,200,...
$in       = 0.1;                          # inner percent of r_delta
$out      = 0.5;                          # outer percent of r_delta
$crit     = 3;                            # number of iterations before quiting
$min      = 3;                            # minimum iters to stop
$binspec  = 25;                           # cts/bin for extracted spec
$abund    = "grsa";
$dbin     = "8";                          # binning of detector WMAP
$h0       = 70;                           # norm. Hubble constant
$q0       = 0.0;                          # norm. acceleration (ignored by Xspec)
$omegal   = 0.7;                          # norm. lambda dens
$emin     = "0.5";                        # lower energy range of fit
$emax     = "8.0";                        # upper energy range of fit
$rootdir  = "reprocessed";                # location of obs specific data products
$verb     = 0;                            # level of screen output from CIAO tools
$quiet    = "no";                         # should Xspec be quiet?
$ntrial   = 1000;
$toler    = 0.05;
$conlevel = "1.00";
$lconf    = "90";
$lmin     = "0.01";
$lmax     = "100.0";

#######################
#######################
##   Main Program    ##
#######################
#######################

# Check the number of arguments given
die "## ERROR: CIAO is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "## ERROR: Wrong number of command line arguments\n" if (@ARGV != 1);

# Load useful libraries
# Store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# open and print to the log file
open(LOG,">>$Bin/find_tx.log");
printf LOG "%-25s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s\n",
    "#Name","ObsID","OldTx","OldThi","OldTlo","NewTx","NewThi","NewTlo","OldFe","NewFe","Oldz","Newz","OldL","NewL";

# open final values log
open(FIN,">>$Bin/final_tx.log");
printf FIN "# Rdelta: $delta; Inner: $in; Outer: $out; Specbin: $binspec; Fit Range: $emin-$emax keV; Lbol: 0.01-100.0 keV\n";
printf FIN "%-25s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s\n",
    "#Name","ObsID","Tx","Thi","Tlo","Fe","Fehi","Felo","z","zhi","zlo","lbol","lbhi","lblo";

# Read in the reference file
%refdata = sub_read_file($ARGV[0]);

# Go through each cluster
{
    foreach $key (sort keys %refdata) {

	# split up the data line
	@data = split(/\s+/,$refdata{$key});

	# get values specific to each cluster
	$name  = $data[0];
	$obsid = $data[1];
	$x     = $data[2];
	$y     = $data[3];
	$rmax  = $data[4];
	$z     = $data[6];
	$nh    = $data[7]*1e-2;
	$tx    = $data[8];
	$fe    = $data[9];
	$lbol  = $data[10];
	$datadir = $data[15];
	$fail  = "no";
	$doz   = "no";

	# only work on cluster with no tx
	if (($tx <= 0) || ($forcetx eq "yes")) {
	    $tx = 5.0 if ($tx <= 0);
	    $thi = $tx+0.5;
	    $tlo = $tx-0.5;
	    $fe = 0.3 if ($fe <= 0);
	    if ($z <= 0) {
		$doz = "yes";
		$z = 0.1;
	    }

	    # change directory
	    chdir("$datadir/$obsid/$rootdir");

	    # define file names
	    $evtfile = "${obsid}_exclude.fits";
	    $bgfile  = "${obsid}_bgevt.fits";
	    $root    = "${obsid}_findtx";
	    $xcmfile = "${root}.xcm";
	    $source  = "${root}.reg";
	    $spec    = "${root}_grp.pi";
	    $newrsp  = "yes";

	    # get the asol file or files
	    ($asol,$pbk) = &get_asolfile();

	    # catch error and move-on
	    unless (-e $evtfile && -e $bgfile) {
		$offender = "no $evtfile" unless (-e $evtfile);
		$offender = "no $bgfile" unless (-e $bgfile);
		chdir($Bin);
		sub_logerror($offender);
		next;
	    };
	    
	    # initialize some values
	    $iter = 0;
	    $rat = 0;
	    
	    # begin the fitting loop
	    while (($iter <= $crit) && ($rat < $min)) {
		
		# calculate rdelta
		if ($thi-$tx > $tx-$tlo) {
		    $terr = $thi-$tx;
		} else {
		    $terr = $tx-$tlo;
		}
		undef @radius;
		@radius = sub_rdelta($delta,$z,$tx);
		if ($fail eq "yes") {
		    $offender = "sub_rdelta";
		    sub_logerror($offender);
		    $newtx=$newthi=$newtlo=$newfe=$newfehi=$newfelo=$newz=$newzhi=$newzlo=$newlbol=$newlbhi=$newlblo=-1.0;
		    $iter = 1000;
		    next;
		}
		$rin = $radius[0];    # inner fraction of Rdelta in pixels
		$rout = $radius[1];   # outer fraction of Rdelta in pixels
		$scale = $radius[2];  # scale factor in kpc/pix
		$tx = $radius[3];     # new randomized Tx
		$rin = sprintf "%d",$rin;
		$rout = sprintf "%d",$rout;
		$drin = sprintf "%d",($rin*$scale);
		$drout = sprintf "%d",($rout*$scale); 
		print "## Using Tx of $tx keV and redshift $z\n";
		print "## Found inner radius of ${in}*R_$delta: $drin kpc, ${rin} pixels\n";
		print "## Found inner radius of ${out}*R_$delta: $drout kpc, ${rout} pixels\n";
		if ($rout > $rmax) {
		    $offender = "$name $obsid R_out ($rout pix) > R_max ($rmax pix)";
		    sub_logerror($offender);
		    $newtx=$newthi=$newtlo=$newfe=$newfehi=$newfelo=$newz=$newzhi=$newzlo=$newlbol=$newlbhi=$newlblo=-1.0;
		    $iter = 1000;
		    next;
		}
		if ($rin > 0.5*$rout) {
		    $offender = "$name $obsid R_in ($rin pix) > 0.5*R_out ($rout pix)";
		    sub_logerror($offender);
		    $newtx=$newthi=$newtlo=$newfe=$newfehi=$newfelo=$newz=$newzhi=$newzlo=$newlbol=$newlbhi=$newlblo=-1.0;
		    $iter = 1000;
		    next;
		}

		# build the extraction region
		open(REGFILE,">$source");
		print REGFILE "# Region file format: CIAO version 1.0\n";
		print REGFILE "annulus(${x},${y},${rin},${rout})\n";
		close REGFILE;
		
		# set badpix file
		sub_set_ardlib();
		
		# extract spectrum for entire cluster
		print "## Extracting source spectrum\n";
		sub_extract_src($evtfile,$source,$root);
		if ($fail eq "yes") {
		    $offender = "sub_extract_src";
		    sub_logerror($offender);
		    $newtx=$newthi=$newtlo=$newfe=$newfehi=$newfelo=$newz=$newzhi=$newzlo=$newlbol=$newlbhi=$newlblo=-1.0;
		    $iter = 1000;
		    next;
		}
		print "## Source spectrum extraction complete\n";
		print "## Extracting background spectrum\n";
		sub_extract_bgd($bgfile,$source,$root);
		if ($fail eq "yes") {
		    $offender = "sub_extract_bgd";
		    sub_logerror($offender);
		    $newtx=$newthi=$newtlo=$newfe=$newfehi=$newfelo=$newz=$newzhi=$newzlo=$newlbol=$newlbhi=$newlblo=-1.0;
		    $iter = 1000;
		    next;
		}
		print "## Background spectrum extraction complete\n";
		
		# print model to XCMFILE
		@clpar = sub_make_xcmfile($spec,$xcmfile);
		
		# run xspec (see subroutine run_xspec) with a timeout
		print "## Running Xspec\n";
		sub_run_xspec($xcmfile,@clpar);
		if ($fail eq "yes") {
		    $offender = "sub_run_xspec";
		    sub_logerror($offender);
		    $newtx=$newthi=$newtlo=$newfe=$newfehi=$newfelo=$newz=$newzhi=$newzlo=$newlbol=$newlbhi=$newlblo=-1.0;
		    $iter = 1000;
		    next;
		}
		
		# watch for bad z
		if ($newz <= 0.0) {
		    $newz = 0.2;
		}
		
		# get model parameter errors
		if (defined $low{$txpar}) {
		    ($newtlo,$newthi) = ($low{$txpar}, $high{$txpar});
		} else {
		    ($newtlo,$newthi) = (0,0);
		}
		if (defined $low{$fepar}) {
		    ($newfelo,$newfehi) = ($low{$fepar}, $high{$fepar});
		} else {
		    ($newfelo,$newfehi) = (0,0);
		}
		if (defined $low{$zpar}) {
		    ($newzlo,$newzhi) = ($low{$zpar}, $high{$zpar});
		} else {
		    ($newzlo,$newzhi) = (0,0);
		}
		
		# setup the exit criterion
		print "## New temperature of ${newtx} kev found\n";
		if (($newthi <= $thi && $newthi >= $tlo) ||
		    ($newtlo <= $thi && $newtlo >= $tlo)) {
		    print "## Errors overlap, iterating...\n";
#		    $newrsp = "no";
		    $newrsp = "yes";
		    $rat++;
		} else {
		    print "## Temperature is significantly different from last iteration, restarting.\n";
		    $newrsp = "yes";
		    $rat = 0;
#		    $iter = 0;
		}
		$dof = 1 if ($dof == 0);
		$rat = 0 if ($stat/$dof > 2);

		# print the results to a file
		printf LOG "%-25s %8s %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %8.4f %8.4f %8.4f %8.4f\n",
		$name,$obsid,$tx,$thi-$tx,$tx-$tlo,$newtx,$newthi-$newtx,$newtx-$newtlo,$fe,$newfe,$z,$newz,$lbol,$newlbol;
		
		# increment counter
		$tx = $newtx;
		$tlo = $newtlo;
		$thi = $newthi;
		$fe = $newfe;
		$z = $newz;
		$lbol = $newlbol;
		$iter++;
	    }
	    
	    # clean-up
	    unlink ("rdel.pro");
	    unlink ("temp.log");
	    
	    # change back to original directory
	    chdir("$Bin");
	    printf FIN  "%-25s %8s %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f\n",
	    $name,$obsid,$newtx,$newthi,$newtlo,$newfe,$newfehi,$newfelo,$newz,$newzhi,$newzlo,$newlbol,$newlbhi,$newlblo;
	}
    }
}

# close the log file
close LOG;

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
# By unsetting this variable, it is possible to get IDL to run
delete $ENV{'DYLD_BIND_AT_LAUNCH'};
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_file {

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
	$name = join "_", $data[0],$data[1];
	$info{$name} = $_;
    }
    close INFILE;
    return %info;
}

#######################
#######################

sub sub_rdelta {

    my($delta,$z,$tx) = @_;
    my(@value,@line);

    # CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
    # By unsetting this variable, it is possible to get IDL to run
    delete $ENV{'DYLD_BIND_AT_LAUNCH'};

    # write all IDL commands to a file and then run
    open(PROFILE,">rdel.pro");

    # perturb the aperture size slightly
    print PROFILE "\!quiet=1\n";
    print PROFILE "tx = '$tx'+'$terr'*(randomn(seed,1)/2.)\n";
    print PROFILE "IF (tx LE 0) THEN tx = $tx+$terr*(randomn(seed,1)/2.)\n";
    print PROFILE "IF (tx LE 0) THEN tx = $tx+$terr*(randomn(seed,1)/2.)\n";
    print PROFILE "IF (tx LE 0) THEN tx = $tx+$terr*(randomn(seed,1)/2.)\n";
    print PROFILE "IF (tx LE 0) THEN tx = $tx+$terr*(randomn(seed,1)/2.)\n";
    print PROFILE "IF (tx LE 0) THEN tx = $tx+$terr*(randomn(seed,1)/2.)\n";
    print PROFILE "print,'## Randomized Tx from $tx keV to ',num2str(tx[0]),' keV\n";
    print PROFILE "a = (rdelta($delta,$z,tx[0],/silent))*1000.\n";
    print PROFILE "cosmology,$z,result,/silent\n";
    print PROFILE "radius1 = a*$in/result[4]/0.492\n";
    print PROFILE "radius2 = a*$out/result[4]/0.492\n";
    print PROFILE "conv = result[4]*0.492\n";
    print PROFILE "openw,1,'temp.log'\n";
    print PROFILE "printf,1,strcompress(radius1,/remove_all)\n";
    print PROFILE "printf,1,strcompress(radius2,/remove_all)\n";
    print PROFILE "printf,1,strcompress(conv,/remove_all)\n";
    print PROFILE "printf,1,strcompress(tx[0],/remove_all)\n";
    print PROFILE "close,1\n";
    print PROFILE "exit \n";
    close PROFILE;
    system("\$IDL_DIR/bin/idl rdel.pro");
    open(FILE,"temp.log");
    while(<FILE>) {
	chomp;
	next if (/^\#/);
	next if (/^$/);
	s/^\s+//;  # trim leading whitespace
	s/\s+$//;  # trim trailing whitespace
	@line = split;
	push @value, $line[0];
    }
    close FILE;

    # check that it worked or return an error
    if ($value[0] >= 0 && $value[1] > 0 && $value[2] > 0) {
	$fail = "no";
    } else {
	$fail = "yes";
    }
    return @value;
}

#######################
#######################

sub sub_set_ardlib {

    my($chips,@chips,$evtfile,$d,$curdir,$bpix);
    $curdir = cwd();

    # reset the ardlib parameter file
    system("punlearn ardlib.par");

    # glob for matching file names
    @dir = qw(reprocessed primary secondary);
    foreach $dir (@dir) {
	chdir("../$dir");
	@globlist = <*bpix*.fits*>;
	@globlist = map { "../$dir/" . $_} @globlist if (@globlist);
	last if (@globlist);
	chdir $curdir;
    }
    die "## ERROR: No bpix file for $obsid\n" unless (@globlist);
    $bpix = $globlist[0];

    # unzip if necesary
    if ($bpix =~ /gz$/) {
	system("gunzip -f $bpix");
	$bpix =~ s/\.gz$//;
    }

    # get the chips to use
    $chips = `dmkeypar $bpix DETNAM ; pget dmkeypar value`;
    chomp($chips);
    $chips =~ s/ACIS\-//;
    @chips = split('', $chips);
    foreach $d (@chips) {
	$command = "pset ardlib AXAF_ACIS${d}_BADPIX_FILE=${curdir}/$bpix\[BADPIX${d}]";
	system($command);
    }
    chdir($curdir);
}

#######################
#######################

sub sub_extract_src {

    my($command);
    my($evtfile,$source,$root) = @_;

    # because of custom specextract
    $command = "punlearn mkwarf; pset mkwarf asolfile=$asol";
    system($command);

    # make responses or not?
    if ($newrsp eq "yes") {
	$command = "punlearn specextract; specextract infile=\"$evtfile\[sky=region($source)]\" "
	    ."outroot=$root bkgfile=\"\" pbkfile=$pbk grouptype=\"NUM_CTS\" binspec=$binspec ptype=PI clobber=yes verbose=$verb";
	system($command);
    } elsif ($newrsp eq "no") {
	$command = "punlearn dmextract; dmextract infile=\"${evtfile}\[sky=region($source)\]\[bin pi\]\" "
	    ."outfile=${root}.pi wmap=\"[energy=300:2000][bin det=$dbin]\" clobber=yes verbose=$verb";
	system($command);
	$command = "punlearn grppha ; grppha infile=\"${root}.pi\" outfile=\"\!${root}_grp.pi\" chatter=0 comm=\"group min 25 & exit\"";
	system($command);
    } else {
	die "## ERROR: something is wrong\n";
    }

    # delete grouping keyword which confuses XSPEC
    $command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=del key=GROUPING file=\"\"";
    system($command);

    # delete quality keyword which confuses XSPEC
    $command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=del key=QUALITY file=\"\"";
    system($command);

    # check that it worked or return an error
    unless (-e "${root}_grp.pi") {
	$fail = "yes";
    } else {
	$fail = "no";
    }
}

#######################
#######################

sub sub_extract_bgd {

    my($command,@headers,$key);
    my($bgfile,$source,$root) = @_;

    # extract the background spectrum
    $command = "punlearn dmextract; dmextract infile=\"${bgfile}\[sky=region($source)\]\[bin pi\]\" "
	."outfile=${root}_bgd.pi wmap=\"[energy=300:2000][bin det=$dbin]\" clobber=yes verbose=$verb";
    system($command);

    # add BACKFILE keyword to spectrum header
    if ($newrsp eq "no") {
	%headers = ("RESPFILE"=>"${root}.wrmf",
		    "ANCRFILE"=>"${root}.warf",
		    "BACKFILE"=>"${root}_bgd.pi");
    } else {
	%headers = ("BACKFILE"=>"${root}_bgd.pi");
    }
    foreach $key (sort keys %headers) {
	$command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=del key=$key file=\"\"";
	system($command);
	$command = "punlearn dmhedit; dmhedit infile=${root}_grp.pi operation=add key=$key "
	    ."value=$headers{$key} filelist=\"\"";
	system($command);
    }

    # check that it worked or return an error
    unless (-e "${root}_bgd.pi") {
	$fail = "yes";
    } else {
	$fail = "no";
    }
}

#######################
#######################

sub sub_make_xcmfile {

    # input vaules
    my($spec,$xcmfile) = @_;

    # other local variables
    my($modstring,$line);
    ($txpar,$fepar,$zpar) = (2,4,5);

    # print to XCM file
    open(XCMFILE,">$xcmfile");
    print XCMFILE "query yes\n";
    print XCMFILE "cosmo ${h0} ${q0} ${omegal}\n";
    print XCMFILE "data $spec\n";
    print XCMFILE "ignore bad\n";
    print XCMFILE "ignore **-${emin} ${emax}-**\n";
    print XCMFILE "abund $abund\n";
    print XCMFILE "model wabs(mekal) & $nh & $tx & 1.0 & $fe,0 & $z & 0 & 0.01\n";
    print XCMFILE "freeze 1\n";
    print XCMFILE "thaw $fepar\n";
    print XCMFILE "thaw $zpar\n" if ($doz eq "yes");
    print XCMFILE "fit 10000 0.001\n";
    print XCMFILE "tclout param $txpar\n";
    print XCMFILE "puts \"Hey tx \$xspec_tclout\"\n";
    print XCMFILE "tclout param $fepar\n";
    print XCMFILE "puts \"Hey fe \$xspec_tclout\"\n";
    print XCMFILE "tclout param $zpar\n";
    print XCMFILE "puts \"Hey z \$xspec_tclout\"\n";
    print XCMFILE "tclout statistic\n";
    print XCMFILE "puts \"Hey stat \$xspec_tclout\"\n";
    print XCMFILE "tclout dof\n";
    print XCMFILE "puts \"Hey dof \$xspec_tclout\"\n";
    close XCMFILE;

    # get the parameters to get con limits for
    @clpar = ();
    push @clpar,$txpar;
    push @clpar,$fepar;
    push @clpar,$zpar if ($doz eq "yes");

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

sub sub_run_xspec {

    my ($xcmfile,@parameters) = @_;
    my ($line,$parameters,$done,$params);
    undef %low;
    undef %high;

    # start xspec
    use IPC::Open3;
    $pid = open3(*XSPEC_INPUT,*XSPEC_OUTPUT,*XSPEC_ERR,"xspec11") || die "## ERROR: Cannot start xspec\n";

    # open the xcmfile written earlier and feed to xspec
    myprint "\@$xcmfile\n";

    # get the confidence limits for interesting parameters
    $parameters = join(" ",@parameters);
    myprint "query no\n";
    myprint "error stopat $ntrial $toler maximum 10.0 $conlevel $parameters\n";
    
    while (<XSPEC_OUTPUT>) {
	chomp;
	$line = $_;
	print "xspec: $line\n" if ($quiet eq "no");
	if ($line =~ m/^Hey tx/) {
	    @line = split(" ",$line);
	    $newtx = $line[2];
	    $fail = "yes" if ($newtx < 0);
	}
	if ($line =~ m/^Hey fe/) {
	    @line = split(" ",$line);
	    $newfe = $line[2];
	    $fail = "yes" if ($newfe < 0);
	}
	if ($line =~ m/^Hey z/) {
	    @line = split(" ",$line);
	    $newz = $line[2];
	    $fail = "yes" if ($newz < 0);
	}
	if ($line =~ m/^Hey stat/) {
	    @line = split(" ",$line);
	    $stat = $line[2];
	    $fail = "yes" if ($stat < 0);
	}
	if ($line =~ m/^Hey dof/) {
	    @line = split(" ",$line);
	    $dof = $line[2];
	    $fail = "yes" if ($dof < 0);
	}
	if ($line =~ /^.*?\s+\> maximum/ ||
	    $line =~ /sigma indicates possible error/) {
	    open  ERR,">>$Bin/$errfile";
	    print ERR "$obsid : no error calculated\n";
	    close ERR;
	    foreach $parameter (@parameters) {
		$low{$parameter} = 0;
		$high{$parameter} = 0;
	    };
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
		    open  ERR,">>$Bin/$errfile";
		    print ERR "$obsid : Check fit\n";
		    close ERR;
		    myprint "fit 10000 0.001\n" ;
		    myprint "error stopat $ntrial $toler maximum 10.0 $conlevel $parameters\n";
		    next;
		}

		# error worked, get output
		if ($line =~ m/^\s+\d+\s+/) {
		    ($parameter, $low, $high) = split(" ",$line);
		    $done++;
		    $low{$parameter} = $low;
		    $high{$parameter} = $high;
		}
	    }

	    # open an output file
	    system("rm -f ${root}_lumin.dat");
	    $filler = 'eval puts \$fileid \"-------------------------"'."\n";
	    myprint 'set fileid [open '.${root}.'_lumin.dat w]'."\n";
	    myprint 'eval outs \$fileid \"'."Rdelta: $delta\"\n";
	    myprint 'eval outs \$fileid \"'."Inner: $in\"\n";
	    myprint 'eval outs \$fileid \"'."Outer: $out\"\n";
	    myprint 'eval outs \$fileid \"'."Specbin: $binspec\"\n";
	    myprint 'eval outs \$fileid \"'."Fit Range: $emin-$emax keV\"\n";
	    myprint 'eval puts \$fileid \"'."Fit confidence: $conlevel\"\n";
	    myprint 'eval puts \$fileid \"'."Flux/Lum confidence: $lconf\"\n";
	    myprint 'eval puts \$fileid \"'."Bolo emin-emax: $lmin-$lmax keV\"\n";
	    myprint 'eval puts \$fileid \"Flux units: ergs/cm2/sec"'."\n";
	    myprint 'eval puts \$fileid \"Lum units: ergs/sec"'."\n";
	    myprint $filler;
	    
	    # get lx for emin-emax
	    myprint "flux $emin $emax $z err 100 $lconf\n";
	    myprint "tclout flux\n";
	    myprint 'scan $xspec_tclout "%f %f %f" fl fllo flhi'."\n";
	    myprint 'eval puts \$fileid \"F('."${emin}-${emax}".') $fl $fllo $flhi"'."\n";
	    myprint "lumin $emin $emax $z err 100 $lconf\n";
	    myprint "tclout lumin\n";
	    myprint 'scan $xspec_tclout "%f %f %f" lum lumlo lumhi'."\n";
	    myprint 'eval puts \$fileid \"L('."${emin}-${emax}".') $lum $lumlo $lumhi"'."\n";
	    myprint $filler;
	    
	    # get lx for 0.2-2.0 keV
	    myprint "flux 0.5 2.0 $z err 100 $lconf\n";
	    myprint "tclout flux\n";
	    myprint 'scan $xspec_tclout "%f %f %f" fl fllo flhi'."\n";
	    myprint 'eval puts \$fileid \"F(0.5-2.0) $fl $fllo $flhi"'."\n";
	    myprint "lumin 0.5 2.0 $z err 100 $lconf\n";
	    myprint "tclout lumin\n";
	    myprint 'scan $xspec_tclout "%f %f %f" lum lumlo lumhi'."\n";
	    myprint 'eval puts \$fileid \"L(0.5-2.0) $lum $lumlo $lumhi"'."\n";
	    myprint $filler;

	    # get lx for 2-10 keV
	    myprint "flux 2.0 10.0 $z err 100 $lconf\n";
	    myprint "tclout flux\n";
	    myprint 'scan $xspec_tclout "%f %f %f" fl fllo flhi'."\n";
	    myprint 'eval puts \$fileid \"F(2.0-10.0) $fl $fllo $flhi"'."\n";
	    myprint "lumin 2.0 10.0 $z err 100 $lconf\n";
	    myprint "tclout lumin\n";
	    myprint 'scan $xspec_tclout "%f %f %f" lum lumlo lumhi'."\n";
	    myprint 'eval puts \$fileid \"L(2.0-10.0) $lum $lumlo $lumhi"'."\n";
	    myprint $filler;

	    # make dummy rsp
	    myprint "dummyrsp $lmin $lmax 3000\n";

	    # get lbol
	    myprint "flux $lmin $lmax $z err 100 $lconf\n";
	    myprint "tclout flux\n";
	    myprint 'scan $xspec_tclout "%f %f %f" fl fllo flhi'."\n";
	    myprint 'eval puts \$fileid \"Fbol $fl $fllo $flhi"'."\n";
	    myprint "lumin $lmin $lmax $z err 100 $lconf\n";
	    myprint "tclout lumin\n";
	    myprint 'scan $xspec_tclout "%f %f %f" lum lumlo lumhi'."\n";
	    myprint 'eval puts \$fileid \"Lbol $lum $lumlo $lumhi"'."\n";
	    myprint $filler;

	    # all done quit XSPEC
	    myprint "exit\n\n";
	}
    }
    
    # parse lumin file for lbol
    open(A,"${root}_lumin.dat");
    while(<A>) {
	chomp;
	next unless (/^Lbol/);
	my @data = split;
	$newlbol = $data[1];
	$newlblo = $data[2];
	$newlbhi = $data[3];
    }
    close A;
    close XSPEC_INPUT;
    close XSPEC_OUTPUT;
    close XSPEC_ERR;
    waitpid($pid,0);
}

#######################
#######################

sub sub_logerror {

    my($offender) = @_;
    chdir("$Bin");
    open  ERRFILE,">>$Bin/$errfile";
    print "${obsid} # failure in find_tx.pl, $offender ",scalar(localtime),"\n";
    print ERRFILE "${obsid} # failure in find_tx.pl, $offender ",scalar(localtime),"\n";
    close ERRFILE;
}

#######################
#######################

sub get_asolfile {

    # get the asol file or files
    my($curdir,@infile,$asol,$pbk,@dir,@globlist);
    $curdir = cwd();

    # change to appropriate dir (they sometimes change the locations)
    @dir = qw(primary secondary);
    @infile = ();
    foreach $dir (@dir) {
	chdir "../$dir";
	@globlist =  <pcad*asol*.fits*>;
	@globlist = map { "../$dir/" . $_} @globlist if (@globlist);
	push @infile, @globlist;
	chdir $curdir;
    }
    die "## ERROR: No asol files found. Exiting.\n" unless (@infile);
    $asol = join(",",@infile);
    chdir($curdir);

    # change to appropriate dir (they sometimes change the locations)
    @dir = qw(primary secondary);
    @infile = ();
    foreach $dir (@dir) {
	chdir "../$dir";
	@globlist =  <*pbk*.fits*>;
	@globlist = map { "../$dir/" . $_} @globlist if (@globlist);
	push @infile, @globlist;
	chdir $curdir;
    }
    die "## ERROR: $obsid no pbk files found. Exiting.\n" unless (@infile);
    $pbk = join(",",@infile);
    chdir($curdir);
    return ($asol,$pbk);
}

#######################
#######################
