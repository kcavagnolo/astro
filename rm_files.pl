#! /usr/bin/perl -w

#######################
#######################
##    Set Options    ##
#######################
#######################

$dryrun  = "no";
@file    = qw(*annuli*.busy);
$rootdir = "reprocessed";

#######################
#######################
##   Main Program    ##
#######################
#######################

# make sure we want to do this
if ($dryrun eq "no") {
    $abort = "no";
    print "WARNING! You are about to delete the files @file. Continue? (yes/no)\n";
    print "Enter response: ";
    $abort = <STDIN>;
    chomp($abort);
    die "## ABORTED." unless ($abort eq "yes");
}

# read in the reference file
%refdata = get_data($ARGV[0]);

# store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);

# go through each cluster and extract events, images
foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get obsid
    $obsid   = $data[1];
    $datadir = $data[15];

    # change directory
    chdir("$datadir/$obsid/$rootdir/");

    # create a list of files
    foreach $ext (@file) {
	@globlist = glob("${ext}");
	
	# remove files
	foreach $a (@globlist) {
	    unless ($dryrun eq "yes") {
		system(`rm -rf ${a}`);
		print "${obsid}: removing $a\n";
	    } else {
		print "**DRYRUN** ${obsid}: removing $a\n";
	    }
	}
    }

    # change back to original directory
    chdir("$Bin");
}
exit 0;

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
