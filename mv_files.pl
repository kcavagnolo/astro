#! /usr/bin/perl -w

# read in the reference file
%refdata = get_data($ARGV[0]);

# store the script directory in $Bin
use FindBin qw($Bin);
use Cwd;

# go through each cluster and extract events, images
MAIN: foreach $key (sort keys %refdata) {

    # split up the data line
    @data = split(/\s+/,$refdata{$key});

    # get obsid
    $name  = $data[0];
    $obsid = $data[1];

    $orig = "../temp/";
    $file = "${name}_${obsid}_*";
    $dest = "../acis/$obsid/reprocessed/";

    # remove files
    @globlist = glob("${orig}/${file}");
    print "${obsid}: moving @globlist\n";
    system(`mv ${orig}/${file} ${dest}`);

  }

################
# Sub routines #
################

sub get_data {
    my($infile,@params) = @_;
    my(%info,@data,$name);
    open(INFILE,$infile) || die "Can't open $infile\n";
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
