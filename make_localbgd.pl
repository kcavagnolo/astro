#! /usr/local/bin/perl -w
#
# NAME:
#     make_localbgd.pl
#
# PURPOSE:
#     construct a local background region for an obsid
#     based upon location of central cluster emission
#
# EXPLANATION:
#     this script reads in the X and Y coords for the
#     central emission of a cluster from a <reference> file
#     it then determines the chip physical dimensions using
#     get_sky_limits, and constructs a local background region
#     based upon a pre-defined edge buffer and region radius.
#
# CALLING SEQUENCE:
#     make_localbgd.pl <reference file>
#     i.e.: perl make_localbgd.pl noncf_reference.list
#
# INPUTS:
#     <reference list> = file containing information about each cluster
#     in the case of X and Y being the centroid position in pixels and Rmax in pixels
#     Name                           ObsID        X        Y   Rmax     MinCts         z  Nh20     Tx     Fe  Lbol ChipID
#     ABELL_0644                      2211   3908.5   4332.5  243.9       5000    0.0704  6.41   8.64   0.35 45.00     s3
#     ABELL_1651                      4185   4222.5   4034.5  132.3       5000    0.0844  1.88   5.97   0.30 45.00     i2
#
# OUTPUTS:
#     local background region file with name:    <obsid>_localbgd.reg
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$datadir = "../";             # location of data in relation to location of this script
$rootdir = "reprocessed";     # name of directory containing event files
$verb    = 1;                 # how wordy the script should be whilst running
$buffer  = "50";               # size of buffer region between chip edge and region edge
$radius  = "100";              # size of local background region

#######################
#######################

# read in the reference file
%refdata  = read_file($ARGV[0],0,1);

# store the script directory in $Bin
use FindBin qw($Bin);

# go through each cluster and perform tasks
 MAIN: foreach $key (sort keys %refdata) {

     # split up the data line
     @data = split(" ",$refdata{$key});

     # get obsid
     $obsid     = $data[1];
     $xcl       = $data[2];
     $ycl       = $data[3];
     $id        = $data[11];
     $id        = "i0123" if ($id =~ /^i/);

     # change directory
     chdir("$datadir/acis/$obsid/$rootdir/");

     # define and check for file names
     $bgreg        = "${obsid}_localbgd.reg";
     $excldfile    = "${obsid}_exclude.fits";

     # figure out which detector to use
     $instr = "s" if ($id =~ /^s/);
     $instr = "i" if ($id =~ /^i/);

     # intialize the fail var
     $fail = "";

     # make the bgd region
     $fail = make_reg($excldfile,$bgreg);
     if ($fail eq "yes") {
	 $offender = "make_reg";
	 logerror($offender);
	 next;
     }
     unlink<temp.reg>;

     # change back to original directory
     chdir("$Bin");

 }

#######################
#######################
##   SUB-ROUTINES    ##
#######################
#######################

sub read_file {
    my($infile,@params) = @_;
    my(%info,@data,$name);
    open(INFILE,$infile) ||
        (send_mail("error","open $infile") &&
         die "Can't open $infile\n");
    while (<INFILE>) {
        chomp;
        next if (/^\#/); # skip comment lines
        next if (/^$/);  # skip blank lines
        s/^\s+//;  # trim leading whitespace
        s/\s+$//;  # trim trailing whitespace
        @data = split;
        $name = "";
        foreach $param (@params) {
            $name .= "$data[$param]_";
        }
        chop $name;
        $info{$name} = $_;
    }
    close INFILE;
    return %info;
}

#######################
#######################

sub logerror {
    my($offender) = @_;

    chdir("$Bin");
    open  ERRFILE,">>errors.log";
    print "${obsid} # failure in make_localbgd, $offender ",scalar(localtime),"\n";
    print ERRFILE "${obsid} # failure in make_localbgd, $offender ",scalar(localtime),"\n";
    close ERRFILE;

}

#######################
#######################

sub make_reg {
    my($evt,$bgreg) = @_;
    my(@arr,@xarr,@yarr,$xsum,$ysum,$elem,@vertices,$xfid,$yfid,$prevdiff);

    # make region files for all chips in obs
    $command = "punlearn skyfov; skyfov infile=$evt outfile=temp.reg kernel=ascii verbose=$verb clobber=yes";
    system($command);

    # for ACIS-S, find the vertices which are closest to the cluster center
    $prevsum = 999999999999999;
    open(INFILE,"temp.reg");
    while (<INFILE>) {
        chomp;
        next if (/^\#/); # skip comment lines
        next if (/^\s*$/);  # skip blank lines
        next if (/^global/);  # skip blank lines
	s/^physical\;Polygon\(//;  # trim leading formatting
        s/\) \#//;  # trim trailing formatting
	@arr = split(",",$_);
	@xarr = ($arr[0],$arr[2],$arr[4],$arr[6]);
	@yarr = ($arr[1],$arr[3],$arr[5],$arr[7]);
	$xsum = 0;
	$ysum = 0;
	foreach $elem (@xarr) {
	    $xsum += abs($elem-$xcl);
	}
	foreach $elem (@yarr) {
            $ysum += abs($elem-$ycl);
        }
	$sum = $xsum+$ysum;
	@vertices = @arr if ($sum < $prevsum && $instr eq "s");
	@vertices = @arr if ($sum > $prevsum && $instr eq "i");
	$prevsum = $sum;
    }

    # define new arrays with the vertices wanted
    @xarr = ($vertices[0],$vertices[2],$vertices[4],$vertices[6]);
    @yarr = ($vertices[1],$vertices[3],$vertices[5],$vertices[7]);

    # determine which vertice is furthest from
    # central cluster emission

    $prevdist = 0;
    $i=0;
    foreach $elem (@xarr) {
	$dist = sqrt(abs($elem-$xcl)**2+abs($yarr[$i]-$ycl)**2);
	if($dist > $prevdist) {
	    $xfid = $elem;
	    $yfid = $yarr[$i];
	    $prevdist = $dist;
	}
	$i=$i+1;
    }

    # determine which edge the cluster is furthest from in both x and y
    # and save the region's center coord (xL,yL)
    if ($xcl-$xfid > 0) {
        $xL = $xfid + $buffer + $radius;
    } else {
        $xL = $xfid - $buffer - $radius;
    }

    if ($ycl-$yfid > 0) {
        $yL = $yfid + $buffer + $radius;
    } else {
        $yL = $yfid - $buffer - $radius;
    }

    # write region file for local background
    $xL = sprintf("%.0f",$xL);
    $yL = sprintf("%.0f",$yL);
    open(REGFILE,">". $bgreg) || die "Can't open region file\n";
    print REGFILE "# Region file format: CIAO version 1.0\n";
    print REGFILE "circle($xL,$yL,$radius)\n";
    close REGFILE;
}

#######################
#######################
