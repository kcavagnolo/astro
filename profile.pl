#! /usr/bin/perl -w
#
# NAME:
#     make_profile.pl
#
# PURPOSE:
#     Extracts a cumulative profile from reprocessed data.
#     Extracts a radial surface brightness profile from reprocessed data.
#
# EXPLANATION:
#     See also http://cxc.harvard.edu/ciao/threads/radial_profile/
#
# CALLING SEQUENCE:
#     make_profile.pl <reference list>
#
# INPUTS:
#     <reference list> = file containing information about each cluster
#     in the case of X and Y being the centroid position in pixels and Rmax in pixels
#     #Name                      ObsID      X      Y   Rmax  MinCts        z   Nh20     Tx     Fe   Lbol  Chip    E_obs  Diff   Robs   Location
#     1E0657_56                   3184   3778   4026    590    5000   0.2960   6.53  11.64   0.23  46.20    i3   1.5432     y    200   MBRANE
#     1E0657_56                   5356   4205   4267    670    5000   0.2960   6.53  11.64   0.23  46.20    i2   1.5432     y    200   MBRANE
#     1E0657_56                   5361   3788   3916    662    5000   0.2960   6.53  11.64   0.23  46.20    i3   1.5432     y    200   MBRANE
#
# OUTPUTS:
#     source region file with name:                          <obsid>_source.reg
#     cumulative profile region file with name:              <obsid>_cumprof.reg
#     cumulative profile in FITS format with name:           <obsid>_cumprof.fits
#     cumulative profile in DAT format with name:            <obsid>_cumprof.dat
#     a postscript copy of the cumulative profile with name: <obsid>_cumprof.ps
#
#     annuluar regions file with name:                       <obsid>_sbprof_<bin size and type>.reg
#     surface brightness profile in FITS foramt with name:   <obsid>_sbprof_<bin size and type>.fits
#     surface brightness profile in DAT format with name:    <obsid>_sbprof_<bin size and type>.dat
#     a postscript copy of the sbr profile with name:        <obsid>_sbprof.ps
#
# MODIFICATION HISTORY:
#     May 3, 2005 --- Ken Cavagnolo
#        added extensive header in IDL format
#        added command to copy rad profs to dir of user choice
#
#######################
#######################
##    Set Options    ##
#######################
#######################

# General options
$rootdir  = "reprocessed/";             # where to find the cluster specific data
$evtext   = "exclude";                  # name of events file to use
$dmexterr = "gaussian";                 # can be gaussian or gehrels
$notify   = "no";                       # should you be notified when the script is done?
$mailto   = "cavagnolo\@oca.eu";        # email address to send notifications
$verb     = 1;                          # how wordy the script should be whilst running
$sbprofdir  = "$ENV{'HOME'}/research/smcs/analysis/sbr";
$cumprofdir = "$ENV{'HOME'}/research/smcs/analysis/cumprof";
$syserr   = 0.0;

# Cumulative profile options
$make_cumprof = "yes";                  # should the script extract cumulative profile?
$cbin = 2;                              # size of cumprof bins
$plot_cumprof = "no";                   # do we want a plot of the cumprof?
$cprcts = 2500;                         # number of counts in each bin for cumprof plotting

# Surface brightness profile options
$make_sbprof = "yes";                    # should the script extract surface brightness profile?
$use_expmap  = "no";                    # will you be using an exp. map during extraction of the sur bri prof?
$emin = "700";                          # minimum energy to use, this is in eV
$emax = "2000";                         # maximum energy to use, this is in eV
$plot_sbprof = "no";                    # do we want a plot of the cumprof?

# One of the following must be set to "yes"
$ellbin  = "no";                        # using elliptical bins created by make_sbell.pl
$ellsize = 2;                           # size of bins
$physbin = "no";                        # if binning by physical size, then "yes" and set
$minkpc  = 10;                          # minimum size of bin in kpc
$ctsbin  = "no";                        # if binning by counts, then "yes" and set
$mincts  = 1000;                        # minimum number of counts to place in each bin
$pixbins = "yes";                       # if binning by a set pixel width, then "yes"
$binsize = 10;                           # and set size of bin in pixels

#######################
#######################
##   Main Program    ##
#######################
#######################

# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);
die "## ERROR: Wrong number of command line arguments.\n" if (@ARGV != 1);
die "## ERROR: CIAO is not loaded, type 'ciao' at the command line.\n" unless ($ENV{'ASCDS_BIN'});

# read in the reference file
%refdata = sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get obsid
    $name    = $data[0];
    $obsid   = $data[1];
    $x       = $data[2];
    $y       = $data[3];
    $rmax    = $data[4];
    $z       = $data[6];
    $datadir = $data[15];

    # change directory
    print "## STATUS: Starting $obsid, $name at ",scalar(localtime),"\n";
    chdir("$datadir/$obsid/$rootdir/");

    # binning naming
    if ($pixbins eq "yes") {
	$binname = "${binsize}pix";
    } elsif ($ctsbin eq "yes") {
	$binname = "${mincts}cts";
    } elsif ($physbin eq "yes") {
	$binname = "${minkpc}kpc";
    } elsif ($ellbin eq "yes") {
	$binname = "${ellsize}pixell";
    } else {
	die print "## ERROR: Unknown binning designation... sinner >:)\n";
    }

    # set general names
    $evtfile = "${obsid}_${evtext}.fits";
    $bgfile  = "${obsid}_bgevt.fits";
    $cumdat  = "${obsid}_cumprof.dat";
    $cumsrc  = "${obsid}_source.reg";
    $cumreg  = "${obsid}_cumprof.reg";
    $cumfits = "${obsid}_cumprof.fits";
    $cumps   = "${obsid}_cumprof.ps";
    if ($use_expmap eq "yes") {
	$expfile = "${obsid}_expmap.fits";
	$sbreg   = "${obsid}_sbprof_${binname}_norm.reg";
	$sbfits  = "${obsid}_sbprof_${binname}_norm.fits";
	$sbdat   = "${obsid}_sbprof_${binname}_norm.dat";
	$sbps    = "${obsid}_sbprof_${binname}_norm.ps";
    } else {
	$sbreg   = "${obsid}_sbprof_${binname}.reg";
	$sbfits  = "${obsid}_sbprof_${binname}.fits";
	$sbdat   = "${obsid}_sbprof_${binname}.dat";
	$sbps    = "${obsid}_sbprof_${binname}.ps";
    }

    # catch error and move-on
    unless (-e $evtfile && -e $bgfile) {
	$offender = "no $evtfile" unless (-e $evtfile);
	$offender = "no $bgfile" unless (-e $bgfile);
	chdir($Bin);
	sub_logerror($offender);
	sub_send_mail("error",$offender);
	next;
    };

    # create cumulative profile
    if ($make_cumprof eq "yes") {
	sub_cumreg($cumsrc,$cumreg);
	if ($fail eq "yes") {
	    $offender = "sub_cumreg";
	    sub_logerror($offender);
	    next;
	}

	# create cum. prof.
	sub_make_cumprof($evtfile,$cumreg,$bgfile,$cumfits,$cumdat);
	if ($fail eq "yes") {
	    $offender = "sub_make_cumprof";
	    sub_logerror($offender);
	    next;
	}
    }
    if ($plot_cumprof eq "yes") {
	sub_plot_cumprof($cumdat,$cumfits,$cumps);
	mkdir("$cumprofdir",0777) unless (-d "$cumprofdir");
	system("cp -f ${cumps} $cumprofdir");
    }

    # create surface brightness profile
    if ($make_sbprof eq "yes") {
	if ($ctsbin eq "yes") {
	    unless (-e $cumdat) {
		$offender = "no $cumdat";
		chdir($Bin);
		sub_logerror($offender);
		sub_send_mail("error",$offender);
		next;
	    }
	}
	if ($use_expmap eq "yes") {
	    unless (-e $expfile) {
		$offender = "no $expfile";
		chdir($Bin);
		sub_logerror($offender);
		sub_send_mail("error",$offender);
		next;
	    }
	}

	# create region files for sb prof
	sub_sbreg($sbreg);
	if ($fail eq "yes") {
	    $offender = "sub_sbreg";
	    sub_logerror($offender);
	    next;
	}

	# create sb prof
	sub_make_sbprof($evtfile,$sbreg,$bgfile,$sbfits,$sbdat);
	if ($fail eq "yes") {
	    $offender = "sub_make_sbprof";
	    sub_logerror($offender);
	    next;
	}
    }
    if ($plot_sbprof eq "yes") {
	sub_plot_sbprof($sbfits,$sbps);
	mkdir("$sbprofdir",0777) unless (-d "$sbprofdir");
	system("cp -f ${sbps} $sbprofdir");
    }

    # write to log file
    print "## STATUS: Finished $obsid $name ",scalar(localtime),"\n";
    chdir("$Bin");
}

# clean-up
print "## STATUS: Finished making profiles at ",scalar(localtime),"\n";
sub_send_mail("complete","") if ($notify eq "yes");
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
    open(INFILE,$infile) || die "## ERROR: Cannot open $infile\n";
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

sub sub_get_profile {

    my($infile) = @_;
    my(%info,@data);
    open(INFILE,$infile) ||
	(sub_send_mail("error","open $infile") &&
	 die "Can't open $infile\n");
    while (<INFILE>) {
	chomp;
	s/^\s+//;  # trim leading whitespace
	s/\s+$//;  # trim trailing whitespace
	next if (/^\#/); # skip comment lines
	next if (/^$/);  # skip blank lines
	next unless (/^\d/);
	@data = split;
	$info{$data[2]} = $data[3];
    }
    close INFILE;
    return %info;
}

#######################
#######################

sub sub_send_mail {

  my($status,$offender) = @_;
  if ($status eq "complete") {
      open (MAIL,"|mail -s \"\[Pipeline\] make_profile.pl is finished\" $mailto,");
      print MAIL
	  "Greetings User,\n\n",
	  "HOORAY! :\)\n",
	  "The perl script for making cumulative\n",
	  "profiles and surface brightness profiles\n",
	  "has finished. Check the errors_makeprof.log\n",
	  "file for any errors. If no errors have occurred\n",
	  "then proceed to the next step in data reduction.\n\n",
	  "Cheers,\n",
	  "Apocalypse\n";
      close MAIL;
  }

  if ($status eq "error") {
      open (MAIL,"|mail -s \"\[Pipeline\] make_profile.pl has erred\" $mailto,");
      print MAIL
	  "Greetings User,\n\n",
	  "I have bad news :\(\n",
	  "The perl script make_profile.pl has erred.\n",
	  "The script has either died or moved on to another cluster.\n",
	  "This error is for ${obsid} created by ${offender}.\n",
	  "Check errors_makeprof.log for more detail.\n\n",
	  "Cheers,\n",
	  "Apocalypse\n";
      close MAIL;
  }
  return 0;
}

#######################
#######################

sub sub_cumreg {

    my($srcreg,$cumreg) = @_;
    my($line,$rin,$rout);

    # create region file for entire source
    open(SRCREG,">$srcreg");
    $line = "circle($x,$y,$rmax)";
    $line =~ s/\s+//g;
    print SRCREG $line,"\n";
    close SRCREG;

    # write region file for annuli extraction
    open(ANNREG,">$cumreg");
    $rin = 0;
    while ($rin < $rmax) {
	$rout = $rin+$cbin;
	$line = "circle($x,$y,$rout)";
	print ANNREG $line,"\n";
	$rin = $rout;
    }
    close ANNREG;

    # check that it worked or return an error
    if (-e $srcreg && -e $cumreg) {
	print "\n## Created region files $srcreg and $cumreg\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_make_cumprof {

    my($evtfile,$cumreg,$bgfile,$cumfits,$cumdat) = @_;

    # extract profile from events, using blank sky background
    print "## Extracting radial profile\n";
    $command = "punlearn dmextract; dmextract infile=\"${evtfile}\[bin sky=\@${cumreg}]\" "
	."outfile=rprofile.fits bkg=\"${bgfile}\[bin sky=\@${cumreg}]\" error=$dmexterr "
	."bkgerror=$dmexterr opt=generic sys_err=$syserr clobber=yes verbose=$verb";
    system($command);
    
    # add a column for r
    print "## Adding Rmid column\n";
    $command = "punlearn dmtcalc; dmtcalc infile=rprofile.fits outfile=$cumfits "
	."expression=\"rmid=0.5*(R[0]+R[1])\" clobber=yes verbose=$verb";
    system($command);
    unlink "rprofile.fits";
    
    # dump to a text file
    print "## Creating cumulative profile DAT file\n";
    $command = "dmlist \"$cumfits\[cols rmid,net_counts,net_err]\" opt=array > $cumdat";
    system($command);

    # check that it worked or return an error
    if (-e $cumdat && -e $cumfits) {
	print "\n## Created cumulative profile resulting in $cumfits and $cumdat\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_plot_cumprof {

    my($cumdat,$cumfits,$cumps) = @_;
    my(%cumprof,@lines,$rin,$rold,@rvals,$totcts,$pixel);

    # read in file and figure out annuli
    %cumprof = sub_get_profile($cumdat);
    @rvals = ();
    $rin = 0;
    $rold = 0;
    $totcts = 0;
    foreach $pixel (sort {$a <=> $b} keys %cumprof) {
	next unless ($cumprof{$pixel} > $totcts + $cprcts);
	push @rvals,$pixel;
	$totcts = $cumprof{$pixel};
	$rold = $rin;
	$rin = $pixel;
    }

    # plot region boundaries
    open(CHFILE,">cumpr.sl");
    print CHFILE
	"plot  \"$cumfits\[cols rmid,net_counts]\" x 1 y 2\n",
	"symbol soliduptri\n",
	"symbol red\n",
	"symbol size 1.0\n",
	"title \"$name (Obs. ${obsid})\"\n",
	"xlabel \"R_{mid} [Pixels]\"\n",
	"ylabel \"Cumulative Counts\"\n";
    foreach $rval (@rvals) {
	print CHFILE "line $rval 0 $rval 2e8\n";
	print CHFILE "line dash\n";
    }
    print CHFILE
	"print postfile $cumps\n",
	"exit\n";
    close CHFILE;
    system("chips -b cumpr.sl");
    unlink("cumpr.sl");
}

#######################
#######################

sub sub_sbreg {

    my($sbreg) = @_;
    my(%cumprof,@lines,$rin,$rold,$totcts,$line,$pixel);

    # calculate annuli to use
    @lines = ();
    $rin = 0;
    $rold = 0;
    $totcts = 0;
    if ($pixbins eq "yes") {
	while ($rin < $rmax) {
	    $rout = $rin+$binsize;
	    $line = "annulus($x,$y,$rin,$rout)\n";
	    push @lines,$line;
	    $rold = $rin;
	    $rin = $rout;
	}
    } elsif ($ctsbin eq "yes") {
	%cumprof = sub_get_profile($cumdat);
	foreach $pixel (sort {$a <=> $b} keys %cumprof) {
	    last unless ($pixel < $rmax);
	    next unless ($cumprof{$pixel} > $totcts + $mincts);
	    $line = "annulus($x,$y,$rin,$pixel)\n";
	    push @lines,$line;
	    $totcts = $cumprof{$pixel};
	    $rold = $rin;
	    $rin = $pixel;
	}
    } elsif ($physbin eq "yes") {
	open(PRO,">junk.pro");
	print PRO "\!quiet=1\n";
	print PRO "cosmology,'$z',result,/silent\n";
	print PRO "openw,1,'temp.log'\n";
	print PRO "printf,1,strcompress(result[4],/remove_all)\n";
	print PRO "close,1\n";
	close PRO;
	$idldir = $ENV{'IDL_DIR'};
	$pid = open3(\*IDL_INPUT, \*IDL_OUTPUT, \*IDL_ERR, "${idldir}/bin/idl") ||
	    die "## ERROR: Cannot start IDL\n";
	print IDL_INPUT "print, '--Now in IDL--'\n";
	print IDL_INPUT "\@junk.pro\n";
	while (<IDL_OUTPUT>) {
	    chomp;
	    print "idl: $_\n";
	    print IDL_INPUT "exit\n";
	}
	print "idl: --Exiting IDL--\n";
	close IDL_INPUT;
	close IDL_OUTPUT;
	close IDL_ERR;
	waitpid($pid,0);
	delete $ENV{'DYLD_BIND_AT_LAUNCH'};

	# get info
	open(FILE,"temp.log");
	while(<FILE>) {
	    chomp;
	    next if (/^\#/);
	    next if (/^$/);
	    s/^\s+//;
	    s/\s+$//;
	    @line = split;
	    $conv = $line[0];
	}
	close FILE;
	system("rm -f temp.log junk.pro");
	delete $ENV{'DYLD_BIND_AT_LAUNCH'};
	$pbin = $minkpc/($conv*0.492);
	while ($rin < $rmax) {
	    $rout = $rin+$pbin;
	    $line = "annulus($x,$y,$rin,$rout)\n";
	    push @lines,$line;
	    $rold = $rin;
	    $rin = $rout;
	}
    } else {
	print "## WARNING: Do not understand binning designation, have region already?\n";
    }

    # reset final outer bin to rmax
    pop @lines;
    push @lines,"annulus($x,$y,$rold,$rmax)\n";

    # write region file for annuli extraction
    open(SBREG,">$sbreg");
    print SBREG @lines;
    close SBREG;

    # check that it worked or return an error
    if (-e $sbreg) {
	print "\n## Created region file $sbreg\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_make_sbprof {

    my($evtfile,$sbreg,$bgfile,$sbfits,$sbdat) = @_;

    # make temporary events files in given energy range
    print "## Creating temporary images\n";
    $command = "dmcopy \"${evtfile}\[energy=${emin}:${emax}]\" tempevt.fits clobber=yes verbose=$verb";
    system($command);
    $command = "dmcopy \"${bgfile}\[energy=${emin}:${emax}]\" tempbgd.fits clobber=yes verbose=$verb";
    system $command;

    # extract profile from events, using blank sky background
    print "## Extracting sbr profile\n";
    if ($use_expmap eq "yes") {
	$command = "punlearn dmextract; dmextract infile=\"tempevt.fits\[bin sky=\@${sbreg}]\" "
	    ."outfile=rprofile.fits bkg=\"tempbgd.fits\[bin sky=\@${sbreg}]\" exp=\"$expfile\" error=$dmexterr "
	    ."bkgerror=$dmexterr opt=generic sys_err=$syserr bkgexp=\"$expfile\" clobber=yes verbose=$verb";
	system($command);
    } else {
	$command = "punlearn dmextract; dmextract infile=\"tempevt.fits\[bin sky=\@${sbreg}]\" "
	    ."outfile=rprofile.fits bkg=\"tempbgd.fits\[bin sky=\@${sbreg}]\" sys_err=$syserr opt=generic "
	    ."clobber=yes verbose=$verb";
	system($command);
    }

    # add a column for rmid, rin, rout
    print "## Adding Rin, Rout, and Rmid columns to FITS file\n";
    $command = "punlearn dmtcalc; dmtcalc infile=rprofile.fits outfile=$sbfits "
	."expression=\"rmid=(0.5*(R[0]+R[1]))\" clobber=yes verbose=$verb";
    system($command);
    $command = "punlearn dmtcalc; dmtcalc infile=$sbfits outfile=$sbfits "
	."expression=\"rin=(R[0])\" clobber=yes verbose=$verb";
    system($command);
    $command = "punlearn dmtcalc; dmtcalc infile=$sbfits outfile=$sbfits "
	."expression=\"rout=(R[1])\" clobber=yes verbose=$verb";
    system($command);

    # dump to a text file
    print "## Dumping results to $sbdat file\n";
    $command = "punlearn dmlist; dmlist \"$sbfits\[cols rin,rout,rmid,sur_bri,sur_bri_err,"
	."bg_sur_bri,bg_sur_bri_err,bg_rate,bg_area,exposure]\" opt=array > $sbdat";
    system($command);
    unlink "tempevt.fits";
    unlink "tempbgd.fits";
    unlink "rprofile.fits";

    # check that it worked or return an error
    if (-e $sbdat && -e $sbfits) {
	print "\n## Created sbr profile resulting in $sbfits and $sbdat\n";
	$fail = "no";
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_plot_sbprof {

    my($sbfits,$sbps) = @_;

    # plot surface brightness profiles
    `rm -f $sbps`;
    open(CHFILE,">sb.sl");
    print CHFILE
	"make_figure (\"$sbfits\[cols rmid,sur_bri,sur_bri_err]\",\"histogram\")\n",
	"make_figure (\"$sbfits\[cols rmid,bg_sur_bri,bg_sur_bri_err]\",\"histogram\")\n",
	"set_plot_title (\"$name (Obs. ${obsid})\")\n",
	"set_plot_xlabel (\"R_{mid} [Pixels]\")\n",
	"set_plot_ylabel (\"Surface Brightness (counts/pixel^2)\")\n",
	"log_scale(X_AXIS)\n",
	"print_window (\"$sbps\",\[\"pagesize\",\"letter\",\"fittopage\",True\]) \n",
	"exit\n";
    close CHFILE;
    system("chips -b sb.sl");
    unlink("sb.sl");
}

#######################
#######################

sub sub_logerror {
    my($offender) = @_;
    chdir("$Bin");
    open  ERRFILE,">>err_makeprof.log";
    print "## ERROR: ${obsid} failure in make_profile.pl, $offender ",scalar(localtime),"\n";
    print ERRFILE "${obsid} # failure in make_profile.pl, $offender ",scalar(localtime),"\n";
    close ERRFILE;
}

#######################
#######################
