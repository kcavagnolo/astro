#!/usr/bin/perl -w
#
# NAME:
#     download.pl
#
# PURPOSE:
#     Retrieve specified Chandra data from the archive using the python
#     script CDA.py and store in the directory acis/ by OBSID
#
# EXPLANATION:
#     This script queries the archive by using the python script cda.py
#     written by Andrew Ptak and available at:
#     http://xassist.pha.jhu.edu/xassist/cda/index.html
#
#     "cda.py is a script to query and download data from the Chandra Data
#     Archive (CDA). It is a stop-gap measure to allow for non-interactive
#     usage of the CDA. To use it, a working Python installation is required
#     (probably version >= 1.5) although a Solaris binary is also available."
#
#     All requested Chandra data files are will be placed in a dir labeled with
#     the obsid, which is then in a dir labeled acis/. The location
#     of acis/ relative to the dir from which this script is run is
#     set with the variable $datadir below.
#
#     e.g.: for Abell 644 obsid 2211, this script will place
#     all files downloaded from the CDA into the directory
#     $datadir/acis/2211/
#
# CALLING SEQUENCE:
#     download.pl <download list>
#
# INPUTS:
#     <reference list> = file containing target names and obsids, e.g.:
#     #Name                           ObsID
#     ABELL_0644                      2211
#     ABELL_1651                      4185
#
# OUTPUTS:
#     none
#
# MODIFICATION HISTORY:
#
#######################
#######################
##    Set Options    ##
#######################
#######################

$datadir = "../acis";

# type of files to retrieve (used by CDA.py), e.g.: "evt2","evt1","asol","flt1","bpix1","aoff","msk1"
@download = ("evt1","evt2","asol","flt1","bpix1","aoff","msk1","bias0","pbk0");

#######################
#######################
##   Main Program    ##
#######################
#######################

# get unique observation (based on obsid)
%cldata = get_data($ARGV[0]);

# store the script directory in $Bin
use FindBin qw($Bin);
use File::Copy;

open(LOG,">download.log") || die "Can't open download.log\n";
print LOG "###### Starting field retrieval ",scalar(localtime),"######\n";

MAIN: foreach $key (sort keys %cldata) {

    @cldata = split(" ",$cldata{$key});
    $clname = $cldata[0];
    $obsid  = $cldata[1];

    # make directories and links
    mkdir("$datadir/$obsid",0777)  unless (-d "$datadir/$obsid");

    # skip if data has already been downloaded
    # first check if primary directory exists
    @getfiles = ();
    if (-d "$datadir/$obsid/primary") {
	# if primary dir exists, check if download files exist in it
	foreach $ftype (@download) {
	    if ($ftype eq "evt1" || $ftype eq "evt2") {
		@ftypes = glob("$datadir/$obsid/primary/acis*${ftype}*");
	    } else {
		@ftypes = glob("$datadir/$obsid/primary/*${ftype}*");
	    }

	    push @getfiles,$ftype unless (@ftypes);
	}
    } else {
	    @getfiles = @download;
	}

    # go to next source if all files already downloaded
    next MAIN unless (@getfiles);

    # now write the files.dat that CDA expects
    specify_download(@getfiles);

    # use cda.py to get tar file
    print "## Retrieving $clname $obsid\n" ;
    system("cda.py $obsid");

    # move tar file to right directory
    $obsid2 = $obsid;
    $obsid2 =~ s/^0//;
    @files = glob("retrieve_${obsid2}*.tar");
    unless (@files) {
	print LOG "$obsid: CDA did not work for $clname\n";
	print "## $obsid: CDA did not work for $clname\n";
	next;
    }
    print LOG "$obsid: CDA download worked\n";
    copy($files[0],"$datadir/$obsid/data.tar");
    unlink $files[0];

    # untar file
    chdir("$datadir/$obsid");
    system("tar -xvf data.tar");
    unlink "data.tar";
    chdir $Bin;
}

print LOG "###### Finished field retrieval ",scalar(localtime),"######\n\n";
close LOG;

unlink "$Bin/files.dat";

#######################
#######################
##   Sub-routines    ##
#######################
#######################

sub specify_download {

    my(@lines) = @_;
    open(FILES,">files.dat") || die "Can't open files.dat\n";
    foreach $line (@lines) {
	print FILES $line,"\n";
    }
    close FILES;
}

#######################
#######################

sub get_data {
    my($infile,@params) = @_;
    my(%info,@data,$name);
    open(INFILE,$infile) || die "Can't open $infile\n";
    while (<INFILE>) {
        chomp;
        next if (/^\#/); # skip comment lines
        next if (/^$/);  # skip blank lines
        s/^\s+//;  # trim leading whitespace
        s/\s+$//;  # trim trailing whitespace
        @data = split /\s+/;
	$name = "$data[0]_$data[1]";
        $info{$name} = $_;
    }
    close INFILE;
    return %info;
}

#######################
#######################
