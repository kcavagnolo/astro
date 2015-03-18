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
$onlynew   = "yes";
$rootdir   = "reprocessed/";       # where to find the cluster specific data
$verb      = 1;                    # how wordy the script should be whilst running
$evtext    = "exclude";            # extension of events file to use for sbr prof extraction
$emin      = "700";                # minimum energy to use, this is in eV
$emax      = "2000";               # maximum energy to use, this is in eV
$binsize   = 10;                   # and set size of bin in pixels
$sbprofdir = "~/research/pf_clusters/pf_fits/plots/sbr";
@newz      = (0.10, 0.12, 0.14, 0.16, 0.18,
	      0.20, 0.22, 0.24, 0.26, 0.28,
	      0.30, 0.32, 0.34, 0.36, 0.38);

#######################
#######################
##   Main Program    ##
#######################
#######################

# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
delete $ENV{'DYLD_BIND_AT_LAUNCH'};

# read in the reference file
%refdata = sub_read_file($ARGV[0]);

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

  # split up the data line
  @data = split(/\s+/,$refdata{$key});
  $name    = $data[0];
  $obsid   = $data[1];
  $x       = $data[2];
  $y       = $data[3];
  $rmax    = $data[4];
  $realz   = $data[6];
  $datadir = $data[15];
  chdir("$datadir/$obsid/$rootdir/");

  # set general names
  $evtfile = "${obsid}_${evtext}.fits";
  $bgfile  = "${obsid}_bgevt.fits";

  # catch error and move-on
  unless (-e $evtfile && -e $bgfile) {
    $offender = "no $evtfile" unless (-e $evtfile);
    $offender = "no $bgfile" unless (-e $bgfile);
    chdir($Bin);
    sub_logerror($offender);
    next;
  };

  # extract prof for each art. z
  foreach $artz (@newz) {

    # only use altz which is > realz
    if ($artz < $realz) {
      $offender = "$artz less than $realz";
      sub_logerror($offender);
      next;
    }

    # define some names
    $sbreg  = "${obsid}_sbprof_${artz}deg.reg";
    $sbfits = "${obsid}_sbprof_${artz}deg.fits";
    $sbdat  = "${obsid}_sbprof_${artz}deg.dat";
    $sbps   = "${obsid}_sbprof_${artz}deg.ps";

    # make only new files
    if ($onlynew eq "yes") {
        if (-e $sbfits) {
	    print "## Already have $sbfits, moving on...\n";
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

    # plot the sb prof
    sub_plot_sbprof($sbfits,$sbps);

    # delete temp files
    unlink "sb.sl";
    unlink "tempevt.fits";
    unlink "tempbgd.fits";

    # take care of postscript file
    mkdir("$sbprofdir",0777) unless (-d "$sbprofdir");
    system("cp -f ${sbps} $sbprofdir");
  }

  # write to log file
  print "\n## STATUS: Finished $name (ObsId $obsid) ",scalar(localtime),"\n";

  # change back to original directory
  chdir("$Bin");
}

# email user that the task is complete
print "## STATUS: Done.\n";

# CIAO and IDL use the DYLD_BIND_AT_LAUNCH environment variable.
delete $ENV{'DYLD_BIND_AT_LAUNCH'};

# exit cleanly
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_read_file {

  my($infile) = @_;
  my(@data,$name,%info);
  open(INFILE,$infile) || die "\n## ERROR: Can't open $infile\n";
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

sub sub_sbreg {

  my($sbreg) = @_;
  my($line,$pixel);

  # calculate annuli to use
  my @lines = ();
  my $rin = 0;
  my $rold = 0;
  my $totcts = 0;

  # convert binsize to physical size
  open(PROFILE,">temp.pro");
  print PROFILE "\!quiet=1\n";
  print PROFILE "cosmology,'$artz',result,/silent\n";
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
    s/^\s+//;
    s/\s+$//;
    @line = split;
    $conv = $line[0];
  }
  close FILE;
  unlink("temp.log","temp.pro");
  delete $ENV{'DYLD_BIND_AT_LAUNCH'};
  my $physical = $binsize*$conv*0.492;

  # convert physical size back to bin size
  open(PROFILE,">temp.pro");
  print PROFILE "\!quiet=1\n";
  print PROFILE "cosmology,'$realz',result,/silent\n";
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
    s/^\s+//;
    s/\s+$//;
    @line = split;
    $conv = $line[0];
  }
  close FILE;
  unlink("temp.log","temp.pro");
  delete $ENV{'DYLD_BIND_AT_LAUNCH'};
  my $newbin = sprintf("%i",$physical/($conv*0.492));

  # make regions
  while ($rin < $rmax) {
    $rout = $rin+$newbin;
    $line = "annulus($x,$y,$rin,$rout)\n";
    push @lines,$line;
    $rold = $rin;
    $rin = $rout;
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
  $command = "punlearn dmextract; dmextract infile=\"tempevt.fits\[bin sky=\@${sbreg}]\" "
    ."outfile=rprofile.fits bkg=\"tempbgd.fits\[bin sky=\@${sbreg}]\" clobber=yes verbose=$verb";
  system($command);

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
  open(CHFILE,">sb.sl");
  print CHFILE
    "plot  \"$sbfits\[cols rmid,sur_bri,sur_bri_err]\" 1 2 3\n",
      "c 1 symbol point\n",
	"c 1 symbol blue\n",
	  "plot \"$sbfits\[cols rmid,bg_sur_bri,bg_sur_bri_err]\" 1 2 3\n",
	    "c 2 symbol point\n",
	      "c 2 symbol red\n",
		"title \"$name (Obs. ${obsid})\"\n",
		  "xlabel \"R_{mid} [Pixels]\"\n",
		    "ylabel \"Surface Brightness (counts/pixel^2)\"\n",
		      "log\n",
			"print postfile $sbps\n",
			  "exit\n";
  close CHFILE;
  system("chips --batch sb.sl");
}

#######################
#######################

sub sub_logerror {

  my($offender) = @_;

  open  ERRFILE,">>${Bin}/errors_makeprof.log";
  print "${obsid} # failure in make_profile.pl, $offender ",scalar(localtime),"\n";
  print ERRFILE "${obsid} # failure in make_profile.pl, $offender ",scalar(localtime),"\n";
  close ERRFILE;
}

#######################
#######################
