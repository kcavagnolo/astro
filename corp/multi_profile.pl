#! /usr/bin/perl -w
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

# General options
$merged   = "/merged";
$rootdir  = "reprocessed";               # where to find the cluster specific data
$dmexterr = "gaussian";                  # can be gaussian or gehrels                                                                  
$syserr   = 0.0;                         # systematic error to add
$notify   = "no";                        # should you be notified when the script is done?
$mailto   = "cavagnolo\@oca.eu";         # email address to send notifications
$verb     = 1;                           # how wordy the script should be whilst running
$cprofdir = "$ENV{'HOME'}/research/smcs/analysis/cumprof";
$sprofdir = "$ENV{'HOME'}/research/smcs/analysis/sbr";
$tempdir  = "$ENV{'HOME'}/research/redux/temp1/";

# Merging params
$merge    = "yes";
$mergeevt = "yes";
$mergebgd = "yes";
$ext      = "exclude";
$doexc    = "yes";
$energy   = 1.3;
$xygrid   = "0.5:8192.5:#4096,0.5:8192.5:#4096";

# Cumulative profile options
$make_cumprof = "no";                  # should the script extract cumulative profile?
$cbin = 2;                              # size of cumprof bins
$cprcts = 2500;                         # number of counts in each bin for cumprof plotting

# Surface brightness profile options
$make_sbprof = "no";                   # should the script extract surface brightness profile?
$emin = "700";                          # minimum energy to use, this is in eV
$emax = "2000";                         # maximum energy to use, this is in eV

# One of the following must be set to "yes"
$ellbin  = "no";                        # using elliptical bins created by make_sbell.pl
$ellsize = 2;                           # size of bins
$physbin = "no";                        # if binning by physical size, then "yes" and set
$minkpc  = 10;                          # minimum size of bin in kpc
$ctsbin  = "no";                        # if binning by counts, then "yes" and set
$mincts  = 1000;                        # minimum number of counts to place in each bin
$pixbins = "yes";                       # if binning by a set pixel width, then "yes"
$binsize = 10;                          # and set size of bin in pixels

#######################
#######################
##   Main Program    ##
#######################
#######################

# set environment
use Cwd;
use FindBin qw($Bin);

# do some checks
die "## ERROR: ciao is not loaded\n" unless ($ENV{'ASCDS_BIN'});
die "## Wrong number of command line arguments\n" if (@ARGV != 1);
if ($pixbins eq "yes") {
    $binname = "${binsize}pix";
} elsif ($ctsbin eq "yes") {
    $binname = "${mincts}cts";
} elsif ($physbin eq "yes") {
    $binname = "${minkpc}kpc";
} elsif ($ellbin eq "yes") {
    $binname = "${ellsize}pixell";
} else {
    die "## ERROR: Unknown binning designation... sinner >:)\n";
}

# loop through each cluster
open(REF,$ARGV[0]);
while (<REF>) {
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;
    s/\s+$//;
    @data = split;
    $fail = "no";
    undef(@output);
    
    # change directory
    if (-d "$tempdir") {
	chdir("$tempdir");
	system('rm -rf *fits* *lis*');
    } else {
	die "## ERROR: No dir named $tempdir. Set \$tempdir to a real dir.\n";
    }

    # get all obsids associated with name
    $name    = $data[0];
    @obsid   = split(/\_/,$data[1]);
    $fidx    = $data[2];
    $fidy    = $data[3];
    $rmax    = $data[4];
    $z       = $data[6];
    $id      = $data[11];
    $datadir = $data[15];

    # remove the ardlib
    print "## Starting $name (ObsId $name) ",scalar(localtime),"\n";
    system("punlearn ardlib");

    # define some names
    if ($merge eq "yes") {
	$fail = &sub_get_files();
	if ($fail eq "yes") {
	    &sub_logerror($offender);
	    next;
	}
	$mergedevt = "${name}_merged.fits";
	$mergedbgd = "${name}_bgevt.fits";
	$mergedreg = "${name}_exclude.reg";
	$mergedexc = "${name}_exclude.fits";
	$cumdat    = "${name}_cumprof.dat";
	$cumsrc    = "${name}_source.reg";
	$cumreg    = "${name}_cumprof.reg";
	$cumfits   = "${name}_cumprof.fits";
	$cumps     = "${name}_cumprof.ps";
	$sbreg     = "${name}_sbprof_${binname}.reg";
	$sbfits    = "${name}_sbprof_${binname}.fits";
	$sbdat     = "${name}_sbprof_${binname}.dat";
	$sbps      = "${name}_sbprof_${binname}.ps";
	$domove    = "yes";
    } else {
	$tdir      = "$datadir/$merged/$name";
	$mergedevt = "$tdir/${name}_merged.fits";
	$mergedbgd = "$tdir/${name}_bgevt.fits";
	$mergedreg = "$tdir/${name}_exclude.reg";
	$mergedexc = "$tdir/${name}_exclude.fits";
	$cumdat    = "$tdir/${name}_cumprof.dat";
	$cumsrc    = "$tdir/${name}_source.reg";
	$cumreg    = "$tdir/${name}_cumprof.reg";
	$cumfits   = "$tdir/${name}_cumprof.fits";
	$cumps     = "$tdir/${name}_cumprof.ps";
	$sbreg     = "$tdir/${name}_sbprof_${binname}.reg";
	$sbfits    = "$tdir/${name}_sbprof_${binname}.fits";
	$sbdat     = "$tdir/${name}_sbprof_${binname}.dat";
	$sbps      = "$tdir/${name}_sbprof_${binname}.ps";
	$domove    = "no";
    }

    # merge evt files
    if ($mergeevt eq "yes") {
	$fail = &sub_merge($mergedevt,@evt);
        if ($fail eq "yes") {
	    $offender = "sub_merge evt";
            &sub_logerror($offender);
            next;
	}
    }
    if ($mergebgd eq "yes") {
	$fail = &sub_merge($mergedbgd,@bgd);
	if ($fail eq "yes") {
	    $offender = "sub_merge bgd";
	    &sub_logerror($offender);
	    next;
	}
    }
    if ($doexc eq "yes") {
	sub_conv_radec($mergedreg);
	if ($fail eq "yes") {
	    $offender = "sub_centroid";
	    logerror($offender);
	    next;
	}
	sub_exclude($mergedevt,$mergedreg,$mergedexc);
	if ($fail eq "yes") {
	    $offender = "sub_exclude";
	    sub_logerror($offender);
	    next;
	}
    }
    
    # create cumulative profile
    if ($make_cumprof eq "yes") {
	sub_cumreg($cumsrc,$cumreg);
	if ($fail eq "yes") {
	    $offender = "sub_cumreg";
	    sub_logerror($offender);
	    next;
	}
	sub_make_cumprof($mergedexc,$cumreg,$mergedbgd,$cumfits,$cumdat);
	if ($fail eq "yes") {
	    $offender = "sub_make_cumprof";
	    sub_logerror($offender);
	    next;
	}
#	sub_plot_cumprof($cumdat,$cumfits,$cumps);
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
	sub_sbreg($sbreg);
	if ($fail eq "yes") {
	    $offender = "sub_sbreg";
	    sub_logerror($offender);
	    next;
	}
	sub_make_sbprof($mergedexc,$sbreg,$mergedbgd,$sbfits,$sbdat);
	if ($fail eq "yes") {
	    $offender = "sub_make_sbprof";
	    sub_logerror($offender);
	    next;
	}
#	sub_plot_sbprof($sbfits,$sbps);
    }

    # take care of output files
    if (@output && $domove eq "yes") {
	mkdir("$datadir/merged",0777) unless (-d "$datadir/merged");
	mkdir("$datadir/merged/$name",0777) unless (-d "$datadir/merged/$name");
	print "## STATUS: Moving files\n";
	foreach $fizile (@output) {
	    system("mv -f $fizile $datadir/merged/$name/");
	}
    }

    # clean-up any remaining mess
    unlink <*.lis>;
    unlink <*_asol*>;
    unlink <*_reproj_*>;
    unlink ("*$ext*");
    unlink <*bgevt*>;
    unlink <*.ps>;

    # write to log file
    print "## Finished $name (ObsId $name) ",scalar(localtime),"\n";
    chdir("$Bin");
}
close REF;

# email user that the task is complete
print "## Finished making profiles at ",scalar(localtime),"\n";
sub_send_mail("complete","") if ($notify eq "yes");
delete $ENV{'DYLD_BIND_AT_LAUNCH'};
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_get_profile {
    
    my($infile) = @_;
    my(%info,@data);
    open(INFILE,$infile) ||
	die "## ERROR: Cannot open $infile\n";
    while (<INFILE>) {
	chomp;
	s/^\s+//;
	s/\s+$//;
	next if (/^\#/);
	next if (/^$/);
	next unless (/^\d/);
	@data = split;
	$info{$data[2]} = $data[3];
    }
    close INFILE;
    return %info;
}

#######################
#######################

sub sub_get_files {

    undef @evt;
    undef @bgd;
    undef @a;
    undef @asol;
    print "## Copying files...\n";
    foreach $iobs (@obsid) {
	next if ($iobs eq "");
	my $dir = "$datadir/$iobs/$rootdir";
	my $evtfile = "${iobs}_${ext}.fits";
	my $bgfile = "${iobs}_bgevt.fits";
	if (-e "$dir/$evtfile" && -e "$dir/$bgfile") {
	    push @evt, $evtfile;
	    push @bgd, $bgfile;
	    
	    # [cols <columns list>] DM filter is necessary to remove
	    # the different event file structures
	    unless (-e "$tempdir/$evtfile" && -e "$tempdir/$bgfile") {
		$command = "punlearn dmcopy; dmcopy \"$dir/$evtfile\[cols -phas]\" "
		    ."$tempdir/$evtfile clobber=yes";
		system($command);
		$command = "punlearn dmcopy; dmcopy \"$dir/$bgfile\[cols ccd_id,"
		    ."chip,energy,fltgrade,det,sky]\" $tempdir/$bgfile clobber=yes";
		system($command);
	    } else {
		print "## STATUS: Files exist at dest. Well, that saves some time.\n";
	    }
	} else {
	    $offender = "no $evtfile" unless (-e "$dir/$evtfile");
	    $offender = "no $bgfile" unless (-e "$dir/$bgfile");
	    return "yes";
	}

	# retrieve aspect solutions if building exp map
	$adir = "$datadir/$iobs/primary";
	@a = glob("$adir/*asol*fits*");
	if (@a) {
	    foreach $as (@a) {
		system("cp -f $as $tempdir");
		$as =~ s/$adir\///g;
		push @asol, $as;
	    }
	} else {
	    $offender = "no asol for $iobs";
	    return "yes";
	}
    }
    print "## Done\n";
    return "no";
}

#######################
#######################

sub sub_merge {
    
    my($out,@data) = @_;
    my($chip,$data,$ref,$command,$asol,$exp);
    $data = join ",",@data;
    $ref = $data[0];
    if ($id =~ /^s$/) {
	$chip = "4:9";
    } elsif ($id =~ /^i$/) {
	$chip = "0:3";
    } elsif ($id =~ /^si$/) {
	$chip = "0:9";
    } else {
	print "## ERROR: bad ccd id\n";
	return "yes";
    }
    @asol = sort(@asol); # sort asol to get them in time sequence
    $asol = join ",",@asol;

    # execute the commands
    $command = "punlearn merge_all; "
	."merge_all evtfile=\"$data\" asol=\"$asol\" chip=$chip "
	."dtffile=\"\" xygrid=\"$xygrid\" energy=$energy intdir=$tempdir "
	."expmap=\"\" expcorr=\"\" refcoord=\"$ref\" merged=\"$out\" clobber=yes";
    system($command);
    push @output,$out;
    
    # check for errors
    if (-e $out) {
	print "## STATUS: Merging complete\n";
	return "no";
    } else {
	return "yes";
    }
}

#######################
#######################

sub sub_conv_radec {

    my($reg) = @_;
    my($obs,$evt,$excl,@a,$x,$y,$indir,$curdir,@infile,$asol,@dir,@globlist,$ra,$dec,$file);
    $indir = cwd();

    # merge lists
    open(EXCL,">$reg");
    print EXCL "# Region file format: CIAO version 1.0\n";
    foreach $obs (@obsid) {
	next if ($obs eq "0000");
	chdir("$datadir/$obs/reprocessed");
	undef @infile;
	undef @excl;
	@infile = glob("${obs}_*evt2*.fits");
	die "\n## ERROR: No $obs evt file\n" unless (@infile);
	$evt = shift @infile;
	undef @infile;
	@infile = glob("../primary/pcad*asol*.fits*");
	die "\n## ERROR: No $obs asol file\n" unless (@infile);
	$asol = shift @infile;
	undef @infile;
	@infile = glob("${obs}_exclude.reg*");
	die "\n## ERROR: No $obs excl file\n" unless (@infile);
	my $val = shift(@infile);
	push @excl, $val;

	# run dmcoords
	foreach $file (@excl) {
	    print "## STATUS: Converting $file to (RA,Dec)...\n";
	    print "##         be patient, I am bad at math :\\\n";
	    open(B,"$file");
	    while(<B>) {
		chomp;
		next if (/\#/);
		next if (/^$/);
		next if (/\,0\.00/ || /NAN/ || /nan/ || /global/ || /color/ || /font/ || /physical/);
		if (/ellipse/) {
		    $type = "ell";
		    $_ =~ s/ellipse\(//;
		    $_ =~ s/\)//;
		    @a = split(",",$_);
		    $x = $a[0];
		    $y = $a[1];
		}
		if (/circle/) {
		    $type = "cir";
		    $_ =~ s/circle\(//;
		    $_ =~ s/\)//;
		    @a = split(",",$_);
		    $x = $a[0];
		    $y = $a[1];
		}
		if (/annulus/) {
		    $type = "ann";
		    $_ =~ s/annulus\(//;
		    $_ =~ s/\)//;
		    @a = split(",",$_);
		    $x = $a[0];
		    $y = $a[1];
		}
		$command = "punlearn dmcoords; dmcoords $evt $asol x=$x y=$y opt=sky";
		system($command);
		
		# get output ra and dec
		$ra = `pget dmcoords ra`;
		$dec = `pget dmcoords dec`;
		$ra =~ s/^\s+//;
		$ra =~ s/\s+$//;
		$dec =~ s/^\s+//;
		$dec =~ s/\s+$//;

		# print out new values
		if ($type eq "ell") {
		    print EXCL "ellipse($ra,$dec,$a[2],$a[3],$a[4])\n";
		} elsif ($type eq "cir") {
		    print EXCL "circle($ra,$dec,$a[2])\n";
		} elsif ($type eq "ann") {
		    print EXCL "annulus($ra,$dec,$a[2],$a[3])\n";
		}
	    }
	    close B;
	}
	chdir("$indir");
    }
    close EXCL;
}

#######################
#######################

sub sub_exclude {

    my($mrg,$reg,$mrgexc) = @_;

    # remove regions from merged file
    $command = "dmcopy \"$mrg\[exclude sky=region($reg)]\" $mrgexc clobber=yes verbose=$verb\n";
    system($command);
    
    # check that it worked or return an error
    if (-e $mrgexc && -e $reg) {
	print "## STATUS: Created $mrgexc\n";
	$fail = "no";
	push @output,$mrgexc,$reg;
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_cumreg {

    my($srcreg,$cumreg) = @_;
    my($line,$rin,$rout);

    # create region file for entire source
    open(SRCREG,">$srcreg");
    $line = "circle($fidx,$fidy,$rmax)";
    $line =~ s/\s+//g;
    print SRCREG $line,"\n";
    close SRCREG;

    # write region file for annuli extraction
    open(ANNREG,">$cumreg");
    $rin = 0;
    while ($rin < $rmax) {
	$rout = $rin+$cbin;
	$line = "circle($fidx,$fidy,$rout)";
	print ANNREG $line,"\n";
	$rin = $rout;
    }
    close ANNREG;

    # check that it worked or return an error
    if (-e $srcreg && -e $cumreg) {
	print "## STATUS: Created region files $srcreg and $cumreg\n";
	$fail = "no";
	push @output,$srcreg,$cumreg;
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_make_cumprof {

    my($evtfile,$cumreg,$bgfile,$cumfits,$cumdat) = @_;

    # extract profile from events, using blank sky background
    print "## STATUS: Extracting radial profile\n";
    $command = "punlearn dmextract; dmextract infile=\"${evtfile}\[bin sky=\@${cumreg}]\" "
        ."outfile=rprofile.fits bkg=\"${bgfile}\[bin sky=\@${cumreg}]\" error=$dmexterr "
        ."bkgerror=$dmexterr opt=generic sys_err=$syserr clobber=yes verbose=$verb";
    system($command);

    # add a column for r
    $command = "punlearn dmtcalc; dmtcalc infile=rprofile.fits outfile=$cumfits "
	."expression=\"rmid=R[0]\" clobber=yes verbose=0";
    system($command);
    unlink("rprofile.fits");

    # dump to a text file
    $command = "dmlist \"$cumfits\[cols rmid,net_counts,net_err]\" opt=array > $cumdat";
    system($command);

    # check that it worked or return an error
    if (-e $cumdat && -e $cumfits) {
	print "## STATUS: Created cumulative profile created\n";
	$fail = "no";
	push @output,$cumfits,$cumdat;
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
    undef @rvals;
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
    open(CHFILE,">chips.sl");
    print CHFILE
	"plot  \"$cumfits\[cols rmid,net_counts]\" x 1 y 2\n",
	"symbol soliduptri\n",
	"symbol red\n",
	"symbol size 1.0\n",
	"title \"$name (Obs. ${name})\"\n",
	"xlabel \"R_{out} [Pixels]\"\n",
	"ylabel \"Cumulative Counts\"\n";
    foreach $rval (@rvals) {
	print CHFILE "line $rval 0 $rval 2e8\n";
	print CHFILE "line dash\n";
    }
    print CHFILE
	"print postfile $cumps\n",
	"exit\n";
    close CHFILE;
    system("chips -b chips.sl");
    unlink "chips.sl";
    mkdir("$cprofdir",0777) unless (-d "$cprofdir");
    system("cp -f ${cumps} $cprofdir");
}

#######################
#######################

sub sub_sbreg {

    my($sbreg) = @_;
    my(%cumprof,@lines,$line,$pixel);

    # calculate annuli to use
    undef @lines;
    my $rin = 0;
    my $rold = 0;
    my $totcts = 0;
    my $finish = 'n';
    if ($pixbins eq "yes") {
	while ($rin < $rmax) {
	    $rout = $rin+$binsize;
	    $line = "annulus($fidx,$fidy,$rin,$rout)\n";
	    push @lines,$line;
	    $rold = $rin;
	    $rin = $rout;
	}
	$finish = 'y';
    } elsif ($ctsbin eq "yes") {
	%cumprof = sub_get_profile($cumdat);
	foreach $pixel (sort {$a <=> $b} keys %cumprof) {
	    last if ($pixel >= $rmax);
	    next unless ($cumprof{$pixel} > $totcts + $mincts);
	    $line = "annulus($fidx,$fidy,$rin,$pixel)\n";
	    push @lines,$line;
	    $totcts = $cumprof{$pixel};
	    $rold = $rin;
	    $rin = $pixel;
	}
	$finish = 'y';
    } elsif ($physbin eq "yes") {
	open(PROFILE,">temp.pro");
	print PROFILE "\!quiet=1\n";
	print PROFILE "cosmology,'$z',result,/silent\n";
	print PROFILE "openw,1,'temp.log'\n";
	print PROFILE "printf,1,strcompress(result[4],/remove_all)\n";
	print PROFILE "close,1\n";
	print PROFILE "exit \n";
	close PROFILE;
	system("\$IDL_DIR/bin/idl temp.pro");
	open(FILE,"temp.log");
	while(<FILE>) {
	    chomp;
	    next if (/^\#/);
	    next if (/^$/);
	    s/^\s+//;  # trim leading whitespace
	    s/\s+$//;  # trim trailing whitespace
	    @line = split;
	    $conv = $line[0];
	}
	close FILE;
	system("rm -f temp.log temp.pro");
	delete $ENV{'DYLD_BIND_AT_LAUNCH'};
	$pbin = $minkpc/($conv*0.492);
	while ($rin < $rmax) {
	    $rout = $rin+$pbin;
	    $line = "annulus($fidx,$fidy,$rin,$rout)\n";
	    push @lines,$line;
	    $rold = $rin;
	    $rin = $rout;
	}
	$finish = 'y';
    } else {
	print "\n## WARNING: Do not understand binning designation, have region already?\n";
    }

    if ($finish eq 'y') {
	# reset final outer bin to rmax
	pop @lines;
	push @lines,"annulus($fidx,$fidy,$rold,$rmax)\n";
	open(SBREG,">$sbreg");
	print SBREG @lines;
	close SBREG;
    }

    # check that it worked or return an error
    if (-e $sbreg) {
	print "## STATUS: Created region file $sbreg\n";
	$fail = "no";
	push @output,$sbreg;
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
    $command = "punlearn dmextract; dmextract infile=\"tempevt.fits\[bin sky=\@${sbreg}]\" "
	."outfile=rprofile.fits bkg=\"tempbgd.fits\[bin sky=\@${sbreg}]\" sys_err=$syserr opt=generic "
	."clobber=yes verbose=$verb";
    system($command);
    unlink "tempevt.fits";
    unlink "tempbgd.fits";

    # add a column for rmid, rin, rout
    $command = "punlearn dmtcalc; dmtcalc infile=rprofile.fits outfile=$sbfits "
	."expression=\"rmid=(0.5*(R[0]+R[1]))\" clobber=yes verbose=0";
    system($command);
    $command = "punlearn dmtcalc; dmtcalc infile=$sbfits outfile=$sbfits "
	."expression=\"rin=(R[0])\" clobber=yes verbose=0";
    system($command);
    $command = "punlearn dmtcalc; dmtcalc infile=$sbfits outfile=$sbfits "
	."expression=\"rout=(R[1])\" clobber=yes verbose=0";
    system($command);
    unlink("rprofile.fits");

    # dump to a text file
    $command = "punlearn dmlist; dmlist \"$sbfits\[cols rin,rout,rmid,sur_bri,sur_bri_err,"
	."bg_sur_bri,bg_sur_bri_err,bg_rate,bg_area,exposure]\" opt=array > $sbdat";
    system($command);

    # check that it worked or return an error
    if (-e $sbdat && -e $sbfits) {
	print "## STATUS: Created sbr profile\n";
	$fail = "no";
	push @output,$sbfits,$sbdat;
    } else {
	$fail = "yes";
    }
}

#######################
#######################

sub sub_plot_sbprof {

    my($sbfits,$sbps) = @_;

    # plot surface brightness profiles
    open(CHFILE,">sb.sl");
    print CHFILE
	"plot  \"$sbfits\[cols rmid,sur_bri,sur_bri_err]\" 1 2 3\n",
	"c 1 symbol point\n",
	"c 1 symbol blue\n",
	"plot \"$sbfits\[cols rmid,bg_sur_bri,bg_sur_bri_err]\" 1 2 3\n",
	"c 2 symbol point\n",
	"c 2 symbol red\n",
	"title \"$name (Obs. ${name})\"\n",
	"xlabel \"R_{mid} [Pixels]\"\n",
	"ylabel \"Surface Brightness (counts/pixel^2)\"\n",
	"log\n",
	"print postfile $sbps\n",
	"exit\n";
    close CHFILE;
    system("chips -b sb.sl");
    unlink "sb.sl";
    mkdir("$sprofdir",0777) unless (-d "$sprofdir");
    system("cp -f ${sbps} $sprofdir");
}

#######################
#######################

sub sub_logerror {
    my($offender) = @_;
    chdir("$Bin");
    open ERRFILE,">>err_multi_profile.log";
    print "## ERROR: ${name} failure in make_multiprof.pl, $offender ",scalar(localtime),"\n";
    print ERRFILE "${name} # failure in make_multiprof.pl, $offender ",scalar(localtime),"\n";
    close ERRFILE;
    &sub_send_mail("error",$offender) if $notify eq "yes";
}

#######################
#######################

sub sub_send_mail {
    my($status,$offender) = @_;
    if ($status eq "complete") {
	open (MAIL,"|mail -s \"\[Pipeline\] make_profile.pl is finished\" $mailto,");
	print MAIL
	    "Greetings User,\n\n",
	    "HOORAY!\n",
	    "The perl script for making cumulative\n",
	    "profiles and surface brightness profiles\n",
	    "has finished. Check the errors_makeprof.log\n",
	    "file for any errors. If no errors have occurred\n",
	    "then proceed to the next step in data reduction.\n\n",
	    "Cheers\n",
	    "Ken Cavagnolo\n";
	close MAIL;
    }
    if ($status eq "error") {
	open (MAIL,"|mail -s \"\[Pipeline\]make_profile.pl has erred\" $mailto,");
	print MAIL
	    "Greetings User,\n\n",
	    "I have bad news :\(\n",
	    "The perl script make_profile.pl has erred.\n",
	    "The script has either died or moved on to another cluster.\n",
	    "This error is for ${name} created by ${offender}.\n",
	    "Check errors_makeprof.log for more detail.\n\n",
	    "Cheers,\n",
	    "Ken Cavagnolo\n";
	close MAIL;
    }
    return 0;
}

#######################
#######################
