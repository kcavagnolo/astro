#! /usr/bin/perl -w
#
# NAME:
#   findbcg.pl
#
# PURPOSE:
#   to automate the by eye process of bcg/cd galaxy finding
#
# EXPLANATION:
#   this script opens an instance of ds9, queries DSS for an image,
#   and then reads the ra and dec from the crosshair
#
# CALLING SEQUENCE:
#   linux> perl findbcg.pl <input_file> <output_file>
#
# INPUTS:
#   <input_file>: this is a flat ASCII file with three columns:
#   #Name      RA   Dec
#   Yo      0:0:0 0:0:0
#   Yes, giving Ra and Dec to get Ra and Dec *seems* redundant, but if
#   you already have a list of X-ray centroids to work with...  RA and
#   Dec need to be in J2000 sexagesimal format, e.g. hh:mm:ss,
#   dd:mm:ss
#
# OUTPUTS:
#  <output_file>: this will be a file that looks exactly like the
#  input but with the addition of a notes column
#
# REQUIREMENTS:
#  DS9, XPA messaging system, the Perl modules IPA::XPA and Image::DS9
#
# NOTES:
#  Since this script invokes ds9 from the command line, *ALL* command
#  line options are available for use. Check DS9 manual for commands,
#  e.g. scaling, color, binning, etc
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$timeout = '30';        # the number of seconds before timeout, give
			# DS9 time to load images, so make long

$survey = '-dssstsci';  # the sky survey to query, check DS9 command
			# line options for more, e.g. FIRST, NVSS,
			# 2MASS...

#######################
#######################

# load useful libraries
# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);
use Image::DS9;

# open the log file
open(LOG,">$ARGV[1]");
printf LOG "%-25s %15s %15s %50s\n","#Name","RA(J2000)","Dec(J2000)","Notes";
printf LOG "%-25s %15s %15s %50s\n","#--","hms","dms","--";

# open coord file
open(REF,"$ARGV[0]");
while(<REF>) {
    chomp;
    next if (/^#/);
    next if (/^$/);
    @line = split;
    $name = $line[0];
    $fra = $line[1];
    $fdec = $line[2];
    
# load an object connected to DS9
    $dsp = new Image::DS9;
    unless ( $dsp->nservers )
    {
	system("ds9 -mode crosshair $survey coord $fra $fdec &" );
	$dsp->wait($timeout) or die( "## ERROR: unable to connect to DS9\n" );
    }
    $nservers = $dsp->nservers;
    print "## STATUS: Talking with $nservers servers\n";

# get coords
    print "## Type notes now, then press enter to continue...\n";
    $notes = <STDIN>;
    chomp($notes);
    $coords = $dsp -> crosshair( wcs => 'sexagesimal' );
    ($ra, $dec) = @$coords;

# catch bad coords
    unless ($ra =~ m/:/) {
	$ra = '0:0:0';
	$dec = '0:0:0';
	$notes = 'error';
    }

# dump to log and close object
    printf LOG "%-25s %15s %15s %50s\n",$name,$ra,$dec,$notes;
    $dsp->exit;
}
close REF;
close LOG;
exit 0;
