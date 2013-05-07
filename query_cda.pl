#! /usr/bin/perl -w
no warnings('once');

######################
######################
##   Set Options    ##
######################
######################

# usage:
# perl query_cda.pl <my-one-column-list-of-obsids_file>

$dest     = '/mnt/GIDEON/';
$out      = 'crap';
$get_data = 'yes';
$ftpdat   = $ENV{'HOME'}."/research/redux/redux_info/cdaftp.dat";
$get_nh   = 'no';
$get_z    = 'no';
$get_tx   = 'no';
$deg_rad  = 0.5;
@instr    = ('ACIS-I','ACIS-S');
@grating  = ('NONE');
@status   = ('archived');
$radius   = '10';
$incrdfr  = 'j2000';
$incrdeq  = '2000';
$outcrdfr = 'j2000';
$outcrdeq = '2000';
$outcrdunit = 'decimal';
$sort     = 'target';
$maxresults = 'No Limit';
$sortord  = 'ascending';
$url      = 'http://cda.harvard.edu/srservices/ocatList.do?';
$ftpadd   = 'ftp://cdaftp.harvard.edu/pub/science/';
$baxadd   = 'http://bax.ast.obs-mip.fr/servlets/omp.servlet.ClusterQueryByName?nextSequence=result&clustername=';

#######################
#######################
##   Main Program    ##
#######################
#######################

# check the number of arguments given
die "## ERROR: Wrong number of command line arguments.\n" if (@ARGV != 1);
die "## ERROR: $out exists! Will not clobber file.\n" if (-e $out);
die "## ERROR: CIAO is not loaded, type 'ciao' at the command line.\n" unless ($ENV{'ASCDS_BIN'});
use Cwd;
use FindBin qw($Bin);

# check for required progs
print "## STATUS: Checking for required programs, ignore output...\n";
print "## wget...?\n";
system("wget -V");
if ($? == -1) {
    die "## ERROR: Program \'wget\' not on system.\n";
}
print "## FOUND!\n";
print "## curl...?\n";
system("curl -V");
if ($? == -1) {
    die "## ERROR: Program \'curl\' not on system.\n";
}
print "## FOUND!\n";
if ($get_nh eq "yes") {
    print "## nh...?\n";
    system("nh -v");
    if ($? == -1) {
	print "## WARNING: Program \'nh\' not on system.\n";
	print "## WARNING: All NH values will be set as -1.00\n";
	$get_nh = "no";
    }
    print "## FOUND!\n";
}
print "## STATUS: Required programs exist, let's go...\n";

# build hash of obs to download
open(A,$ARGV[0]);
while(<A>){
    chomp;
    next if (/^\#/);
    @z = split;
    push(@obsids,$z[0]);
}
close A;
$innum = $#obsids+1;
$obsids = join(",",@obsids);

# download data
if ($get_data eq "yes") {
    open(A,"$ftpdat");
    while(<A>){
	chomp;
	next if (/^\#/);
	next if (/^$/);
	s/^\s+//;
	s/\s+$//;
	@line = split;
	$obsloc{$line[0]} = "$line[1]$line[2]";
    }
    close A;
    foreach $obs (@obsids) {
	unless (exists $obsloc{$obs}) {
	    print "## ERROR: No $obs found in existing CDAFTP structure...\n",
	    "## ERROR: Consider running build_cdaftp.pl again.\n";
	    next;
	}
	$loc = $obsloc{$obs};
	chdir("$dest") || die "## ERROR: Can't change to $dest\n";
	@args = ("wget","-nv","-r","-nH","--cut-dirs=4","${ftpadd}${loc}${obs}/");
	system(@args);
	chdir("$Bin");
    }
}

# build options
foreach $a (@instr) {
    $a =~ s/\s+/\%20/g;
    push @val, "instrument=$a";
}
foreach $a (@grating) {
    $a =~ s/\s+/\%20/g;
    push @val, "grating=$a";
}
foreach $a (@status) {
    $a =~ s/\s+/\%20/g;
    push @val, "status=$a";
}
foreach $a (@category) {
    $a =~ s/\s+/\%20/g;
    push @val, "category=$a";
}

# format the options
$obsids = "obsid=".$obsids;
$radius = "radius=".$radius;
$incrdfr = "inputCoordFrame=".$incrdfr;
$raweq = $incrdeq;
$incrdeq = "inputCoordEquinox=".$incrdeq;
$outcrdfr = "outputCoordFrame=".$outcrdfr;
$outcrdeq = "outputCoordEquinox=".$outcrdeq;
$outunit = $outcrdunit;
$outcrdunit = "outputCoordUnits=".$outcrdunit;
$sort = "sortColumn=".$sort;
$maxresults = "maxResults=".$maxresults;
$sortord = "sortOrder=".$sortord;
$format = "format=text";

@others = ($obsids,$radius,$incrdfr,$incrdeq,$outcrdfr,$outcrdeq,$outcrdunit,$sort,$maxresults,$sortord,$format);
foreach $a (@others) {
    $a =~ s/\s+/\%20/g;
    push @val, $a;
}
$opts = join "&", @val;
print "Querying CDA...\n";
system("curl --silent \'$url$opts' \> cda_query\n");
die "## ERROR: Could not contact CDA\n" unless (-e "cda_query");
print "Query successful.\n";

# open the query list and make a reference file
open(CDA,"cda_query");
open(OUT,">${out}");
if ($outunit eq "sexagesimal") {
    printf OUT "%-25s %6s %15s %15s %6s %7s %8s %6s %6s %6s %6s %5s %8s %5s %6s %20s %25s\n",
    "#Name","ObsID","RA","Dec","Rmax","MinCts","z","Nh20","Tx","Fe","Lbax","Chip","E_obs","Diff","Robs","Location","Txref";
    printf OUT "%-25s %6s %15s %15s %6s %7s %8s %6s %6s %6s %6s %5s %8s %5s %6s %20s %25s\n",
    "#--","--","hms","dms","pix","cts","--","cm^-2","keV","solar","1d44es","--","keV","--","pix","--","--";
} elsif ($outunit eq "decimal") {
    printf OUT "%-25s %6s %8s %8s %6s %7s %8s %6s %6s %6s %6s %5s %8s %5s %6s %20s %25s\n",
    "#Name","ObsID","RA","Dec","Rmax","MinCts","z","Nh20","Tx","Fe","Lbax","Chip","E_obs","Diff","Robs","Location","Txref";
    printf OUT "%-25s %6s %8s %8s %6s %7s %8s %6s %6s %6s %6s %5s %8s %5s %6s %20s %25s\n",
    "#--","--","deg","deg","pix","cts","--","cm^-2","keV","solar","1d44es","--","keV","--","pix","--","--";
} else {
    die "## ERROR: What kind of output coordinate format is ${outunit}?\n";
}
$num = 0;
$texp = 0;
$pline = '';
while(<CDA>){
    chomp;
    next if (/\#/);
    next if (/^Seq/);
    ($seq,$obsid,$instr,$grat,$aexp,$exp,$target,
     $pi,$ra,$dec,$stat,$mode,$sdate,$prdate,
     $propnum,$cat,$type,$ao,$joint,$grid)
	= split("\t",$_);
    next if ($seq eq "10");
    $num++;
    $texp += $exp;
    next if ($stat eq "unobserved" || $stat eq "scheduled" || $stat eq "observed");
    $target =~ s/\s+/\_/g;
    $rawra = $ra;
    $rawdec = $dec;
    if ($outcrdunit eq "sexagesimal") {
	$ra =~ s/\s+/\:/g;
	$dec =~ s/\s+/\:/g; 
    }
    $ra =~ s/\s+//g;
    $dec =~ s/\s+//g; 
    $instr =~ s/ACIS-//;
    $instr =~ s/S/s3/;
    $instr =~ s/I/i3/;
    $nh = sub_nh($ra,$dec) if ($get_nh eq "yes");
    $z  = sub_z($rawra,$rawdec) if ($get_z eq "yes");
    ($tx,$txref,$lx) = sub_qbax() if ($get_tx eq "yes");
    if ($outunit eq "sexagesimal") {
	printf OUT "%-25s %6s %15s %15s %6.0f %7.0f %8.4f %6.2f %6.2f %6.2f %6.2f %5s %8.4f %5s %6i %20s %25s\n",
	$target,$obsid,$ra,$dec,0,2500,$z,$nh,$tx,0.30,$lx,$instr,0.0000,"y",000,$dest,$txref;
    } elsif ($outunit eq "decimal") {
	printf OUT "%-25s %6s %8.2f %8.2f %6.0f %7.0f %8.4f %6.2f %6.2f %6.2f %6.2f %5s %8.4f %5s %6i %20s %25s\n",
	$target,$obsid,$ra,$dec,0,2500,$z,$nh,$tx,0.30,$lx,$instr,0.0000,"y",000,$dest,$txref;
    }
}
$texp = sprintf("%.2f",$texp/1e3);
print "## $num of $innum obsids were retrieved in this query.\n";
print "## Total exposure time: $texp Msec.\n";
close CDA;
close OUT;
system("rm -f cda_query");
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_nh {

    my($ra,$dec) = @_;
    my(@data,$value);

    # invoke prop_nh
    # output is formatted as:
    # LAB >> Weighted average nH (cm**-2)  1.43E+20
    open(NH, "nh equinox=$raweq ra=$ra dec=$dec disio=$deg_rad tchat=4 |");
    while (<NH>) {
	chomp;
	$line = $_;
	if ($line =~ /Weighted/) {
	    @data = split;
	    $value = $data[6]/1e20;
	    print "\n## Found N_HI = $value 10**20 cm**-2 for $target ($obsid)\n";
	}
    }
    close(NH);
    return $value;
}

#######################
#######################

sub sub_z {

    my($ra,$dec) = @_;
    my(@a,$z,$url,$opts,$first,$gcl);

    if ($outunit eq "decimal") {
	$ra .= "d";
	$dec .= "d";
    }
    $url = "http://nedwww.ipac.caltech.edu/cgi-bin/nph-objsearch?";
    $opts = "in_csys=Equatorial&in_equinox=J2000.0&lon=${ra}&lat=${dec}&radius=2.0&"
	."out_csys=Equatorial&out_equinox=J2000.0&obj_sort=Distance+to+search+center&"
	."of=ascii_tab&zv_breaker=30000.0&list_limit=0&img_stamp=NO&search_type=Near+Position+Search&"
	."z_constraint=Unconstrained&z_value1=&z_value2=&z_unit=z&ot_include=ANY&ex_objtypes1=GravLens&"
	."ex_objtypes1=DLA&ex_objtypes1=AbsLineSys&ex_objtypes1=EmissnLine&ex_objtypes3=Supernovae&"
	."ex_objtypes3=HIIregion&ex_objtypes3=PN&ex_objtypes3=SNR&ex_objtypes3=StarAssoc&ex_objtypes3=StarClust&"
	."ex_objtypes3=MolCloud&ex_objtypes3=Nova&ex_objtypes3=VarStar&ex_objtypes3=WolfRayet&ex_objtypes3=CarbonStar&"
	."ex_objtypes3=PofG&ex_objtypes3=Other&ex_objtypes3=Star&ex_objtypes3=BlueStar&ex_objtypes3=RedStar&"
	."ex_objtypes3=Pulsar&ex_objtypes3=ReflNeb&ex_objtypes3=DblStar&ex_objtypes3=FlareStar&"
	."ex_objtypes3=EmissnObj&ex_objtypes3=EmissnNeb&ex_objtypes3=WhiteDwarf&nmp_op=ANY";
    system("curl --silent \'$url$opts' \> ned_query\n");
    open(NED,"ned_query");
    $first = "yes";
    $gcl = "no";
    while(<NED>){
	chomp;
	next unless (/^\d/);
	@a = split("\t",$_);
	if ((/^1/) && ($first eq "yes")) {
	    if ($a[6] eq "") {
		$z = -9.999;
	    } else {
		$z = $a[6]
	    }
	    $first = "no";
	}
	if (($a[4] eq "GClstr") && ($gcl eq "no")) {
	    if ($a[6] eq "") {
		$z = -9.999;
	    } else {
		$z = $a[6]
	    }
	    $gcl = "yes";
	}
    }
    $z = sprintf("%.4f",$z);
    print "## Found redshift of $z for $a[1] :: $target\n\n";
    close NED;
    system("rm -f ned_query");
    return $z;
}

#######################
#######################

sub sub_qbax {

    my($name, @args, $command, $getdat, $good, @data, $a, @info, @tx, $tx, $txref, $lx);
    $name = $target;
    $name =~ s/\_000/ /g;
    $name =~ s/\_00/ /g;
    $name =~ s/\_0/ /g;
    $name =~ s/\_/\+/g;
    $name =~ s/ /\+/g;
    $name .= '#';
    @args = ("wget","-nv","\'${baxadd}$name\'","-Otemp.dat");
    $command = join(" ",@args);
    system($command);
    open(B,"temp.dat");
    $getdat = "n";
    $good = "y";
    undef(@data);
    while(<B>){
        chomp;
        if (/does not exist/) {
            $good = "n";
	    @tx = (-99,-99,-99);
	    $txref = 'NA';
	    $lx = -99;
            last;
        }
        if (/\<\/table\>/) {
            $getdat = "n";
            last;
        }
        if (/External/) {
            $getdat = "y";
            next;
        }
        if ($getdat eq "y") {
            push @data, $_;
        }
    }
    if ($good ne "n") {
        $a = join("",@data);
        $a =~ s/<a.*?>//g;
        $a =~ s/<\/a>//g;
        $a =~ s/<input.*?>//g;
        $a =~ s/<font.*?>//g;
        $a =~ s/<sub>\(/,/g;
        $a =~ s/\)<\/sub>//g;
        $a =~ s/<\/font>//g;
        $a =~ s/ width.*?>/>/g;
        $a =~ s/<\/tr>//g;
        $a =~ s/<td>//g;
        $a =~ s/<tr>//g;
        $a =~ s/References:/References/g;
        $a =~ s/<\/td>/\n/g;
        @info = split(/\n/,$a);
        $lx = $info[5];
        if ($lx eq '&nbsp;') {
            $lx = -99.0;
        }
        $tx = $info[6];
        $tx =~ s/\-//g;
        $tx =~ s/\+//g;
        $txref = $info[14];
        if ($tx eq '&nbsp;') {
            $tx = '-99.0,-99.0,-99.0';
            $txref = 'NA';
        }
        @tx = split(/,/,$tx);
    }
    close B;
    system("rm -f temp.dat");
    return($tx[0],$txref,$lx);
}

#######################
#######################
