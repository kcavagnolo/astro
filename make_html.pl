#!/usr/bin/perl -w
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

$mfile    = $ENV{'HOME'}."/research/pf_clusters/pf_fits/master.table";
$trfile   = $ENV{'HOME'}."/research/pf_clusters/pf_fits/dat/pf_temp_profs.dat";
$sfile    = $ENV{'HOME'}."/research/pf_clusters/pf_info/sample_info.dat";
$stordir  = "/mnt/DROBO/accept";
$url      = "http://www.pa.msu.edu/astro/MC2/accept";
$paperid  = "2009ApJS..182...12C";
$clpath   = "clusters";
$mainpage = "index.html";
$tabwidth = "700";
$fontfam  = "sans-serif"; # helvetica, sans-serif, monospace

# banner settings
$banner    = "${url}/fractal.jpg";
$bannertxt = "&nbsp;";
$bnheight  = "100px";
$bntxtsize = "6px";
$bncolor   = "#FFFFFF";

# navigation bar
$navbg  = "#000000";
$navhom = "${url}/nav_01.png";
$navacc = "${url}/nav_02.png";
$navent = "${url}/nav_03.png";
$navpri = "${url}/nav_04.png";
$navaut = "${url}/nav_05.png";
$navcod = "${url}/nav_06.png";
#$navbgd = "${url}/nav_07.png";

# footer settings
$email   = "kcavagno --at-- uwaterloo ~dot~ ca <parse this email address if you're not a bot>";
$myname  = "Kenneth W. Cavagnolo";
$msulogo = "${url}/msutype.gif";
$palogo  = "${url}/PAlogo.jpg";
$kmodel  = "<i>K(r) = K<sub>0</sub>+K<sub>100</sub>(r/100 kpc)<sup>\&alpha;</sup></i>";

# colors
$bgd    = "#999999";
$txt    = "#000000";
$link   = "#FFFFFF";
$alink  = "#FFFF00";
$hlink  = "#00CCFF";
$vlink  = "#FFFFFF";
$tbbgd  = "#000000";
$tb2bgd = "#999999";
$tb3bgd = "#333333";
$tbtext = "#FFFFFF";
$ulcolr = "#FFCC00";

#######################
#######################
##   Main Program    ##
#######################
#######################

# Check the number of arguments given
die "## Wrong number of command line arguments\n" if (@ARGV != 1);

# Load useful libraries
# Store the script directory in $Bin
use Cwd;
use FindBin qw($Bin);
use Math::Complex;
use File::stat;
use POSIX qw(strftime);

# Read in the reference data
%clinfo = sub_get_data($ARGV[0]);
%txann  = sub_gettx($trfile);
%obsinfo = sub_get_data($sfile);
sub_readmaster($mfile);

# make directory to store reprocessed and new files
mkdir($stordir,0777) unless (-d $stordir);
mkdir("$stordir/$clpath",0777) unless (-d "$stordir/$clpath");

# make alpha sorted table
$mainfile = "${stordir}/$mainpage";
@alphakeys = sort keys %clinfo;

# make the mainfile
sub_make_index($mainfile,@alphakeys);

# make the individual cluster/sequence files
sub_make_clfiles();
sub_make_accept();
sub_make_entropy();
sub_make_primer();
sub_make_authors();
sub_make_code();

# clean exit
exit 0;

#######################
#######################
##   Sub-Routines    ##
#######################
#######################

sub sub_get_data {

    my($infile) = @_;
    my(@data,$name,%info);
    open(INFILE,$infile) || die "\n## ERROR: Can't open $infile\n";
    while (<INFILE>) {
	chomp;
	next if (/^\#/);
	next if (/^$/);
	s/^\s+//;
	s/\s+$//;
	@data = split;
	$name = join("_", $data[0],$data[1]);
	$info{$name} = $_;
    }
    close INFILE;
    return %info;
}

#######################
#######################

sub sub_read {

  my($infile) = @_;
  my(@a,%info);
  open(INFILE,$infile) || die "\n## ERROR: Can't open $infile\n";
  while(<INFILE>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    s/^\s+//;
    s/\s+$//;
    @a = split;
    $info{$a[0]} = $_;
  }
  close INFILE;
  return %info;
}

#######################
#######################

sub sub_make_index {

  my($file) = shift;
  my(@keys) = @_;
  my($lx,$lha,$lrad,$ra,$dec,$var,$ara,$adec,$type,@data,@a,@b,@k,$k0);

  # print main file header
  sub_print_header(\*MAINFILE,
		   $file,
		   "ACCEPT: Archive of Chandra Cluster Entropy Profile Tables");

  # insert introduction
  $hscell = "<tr>\n<td><font size=4><b><u>";
  $hecell = "</u></b></font></td>\n</tr>\n";
  $scell = "<tr>\n<td><font size=2>";
  $ecell = "</font></td>\n</tr>\n";
  $blank = "<tr>\n<td>\&nbsp\;</td>\n</tr>\n"; 
  print MAINFILE
      "<br><table border=0 cellpadding=0 cellspacing=0 width=\"50%\">\n",
      "${scell}",
      "Welcome to the home of ACCEPT, a project at Michigan State \n",
      "University by Kenneth Cavagnolo, Megan Donahue, Mark \n",
      "Voit, and Ming Sun. The purpose of this web site is to distribute the \n",
      "science-ready data products and finalized analysis results to \n",
      "you -- the interested researcher.\n",
      "${ecell}";

  # update link
  print MAINFILE "${blank}";
  print MAINFILE "${hscell}Updates and RSS Feed</u><a href=\"${url}/rss.xml\" target=\"_blank\"><img src=\"rss.png\" alt=\"RSS png\" border=\"0\" align=\"BOTTOM\"></a><u>${hecell}";
  print MAINFILE
      "${scell}",
      "This site will be updated as new cluster observations become \n",
      "available in the CDA and as the project expands to include \n",
      "analysis of XMM-Newton data. Stay up-to-date by subscribing to \n",
      "our <a href=\"${url}/rss.xml\" ",
      "target=\"_blank\">RSS feed</a>. A schedule of upcoming \'Clusters \n",
      "of Galaxies\' Chandra observations to be made public is \n",
      "<a href=\"${url}/cda_upcoming_html\" \n",
      "target=\"_blank\">provided here</a>. The typical timeline for new \n",
      "observations to be processed and added to this page is 1 day.\n",
      "${ecell}";

  # request for citation
  print MAINFILE "${blank}";
  print MAINFILE "${hscell}Citation Request${hecell}";
  print MAINFILE
      "${scell}",
      "If you find a use in your work for the data or results of ACCEPT, \n",
      "please cite our paper:<br>\n",
      "\&nbsp\;&nbsp\;\&nbsp\;\&nbsp\;<b><i>\"Intracluster Medium Entropy Profiles for a Chandra Archival Sample of Galaxy Clusters\"</i><br>\n",
      "\&nbsp\;&nbsp\;\&nbsp\;\&nbsp\;Cavagnolo, Kenneth W.; Donahue, Megan; Voit, G. Mark; Sun, Ming<br></b>\n",
      "\&nbsp\;&nbsp\;\&nbsp\;\&nbsp\;<a href=\"http://adsabs.harvard.edu/abs/${paperid}\">ADS Listing</a><br>\n",
      "\&nbsp\;&nbsp\;\&nbsp\;\&nbsp\;<a href=\"http://adsabs.harvard.edu/cgi-bin/nph-bib_query?bibcode=${paperid}&data_type=BIBTEX&db_key=PRE&nocookieset=1\">BibTeX Entry</a><br>\n",
      "${ecell}";

  # figure of merit
  print MAINFILE "${blank}";
  print MAINFILE "${hscell}Useful Data and Figures${hecell}";
  print MAINFILE
      "${scell}",
      "0) <a href=\"${url}/accept_main.tab\" target=\"_blank\">Download an ASCII version of</a> the main table.<br>\n",
      "1) <a href=\"${url}/data/all_profiles.dat\" target=\"_blank\">Download an ASCII file</a> containing all of the data for ACCEPT.<br>\n",
      "2) <a href=\"${url}/data/acceptdb.fits\" target=\"_blank\">Download a FITS file</a> containing all of the data for ACCEPT (coming soon).<br>\n",
      "3) <a href=\"${url}/data/hiflugcsdb.fits\" target=\"_blank\">Download a FITS file</a> for the HIFLUGCS subsample (coming soon).<br>\n",
      "4) <a href=\"${url}/images/montage.jpg\" target=\"_blank\">Download a montage image</a> of the ACCEPT clusters ordered by ascending core entropy (WARNING: 18Mb file).<br>\n",
      "${ecell}";

  # add bold title
  print MAINFILE "${blank}";
  print MAINFILE "${hscell}Explanation of Main Table${hecell}";
  print MAINFILE
      "${scell}",
      "Below is the main table which lists all the clusters in ACCEPT. ",
      "To view an individual cluster click on the ObsID and a new tab will ",
      "open with that cluster/ObsID's page. Each page contains:<br>\n",
      "<ul>\n",
      "<li>Wide-field <i>Chandra</i> image of cluster.</li>\n",
      "<li>Image of the cluster core.</li>\n",
      "<li>SDSS/DSS image of the cluster core.</li>\n",
      "<li>Light curve for the observation.</li>\n",
      "<li>Surface brightness profile.</li>\n",
      "<li>Image of temperature bins plus temperature profile.</li>\n",
      "<li>Density profile.</li>\n",
      "<li>Metal abundance profile.</li>\n",
      "<li>Pressure profile.</li>\n",
      "<li>Entropy profile.</li>\n",
      "<li>Cooling time profile.</li>\n",
      "<li>Gravitating mass profile <b>(NOT THE CRUX OF THIS WORK, USE AT OWN RISK!)</b>.</li>\n",
      "</ul>\n",
      "${ecell}";
  
  # end the table
  print MAINFILE "</table>\n";

  # print a row of units
  $astyle = "style=\"border-top-width\:1px \; border-top-style\:solid \; border-color\:white\"";
  $aform = "$astyle align=center bgcolor=\"$tbbgd\" valign=middle";
  $sfont = "<font size=2 color=\"$tbtext\">";
  $efont = "</font>";

  # print table header
  print MAINFILE
      "<hr>\n",
      "<center><font size=6><b><u>ACCEPT Main Table</u></b></font></center>\n",
      "<table id=\"maintable\" class=\"tablesorter\" border=0 cellpadding=4 cellspacing=0 width=\"100%\">\n",
      "<caption>\n",
      "<b><font color=\"$hlink\">The table below is sortable by column, just click the column head to sort.</font></b><br>",
      "<b><font color=\"$ulcolr\">Listed upper limits are 3&sigma;.</font></b><br>",
      "<b><font color=red>Our NVSS and SUMSS search criteria miss large, amorphous sources like WATs.<br>Hence, low-redshift objects with upper limits may have a WAT radio source.</font></b><br>",
      "<b><font color=green>Values listed for <i>K<sub>0</sub></i> , <i>K<sub>100</sub></i> , and <i>\&alpha;</i> are best-fit values of the model $kmodel.</font></b><br>",
      "<b>Bolometric luminosities are taken from a hetergeneous set of apertures; new values for homogeneous apertures are being generated.</b><br>",
      "<font size=2><b>Notes --</b> Col. <b>(1)</b> index number; ",
      "col. <b>(2)</b> name of cluster; ",
      "col. <b>(3)</b> observation identification number; ",
      "col. <b>(4)</b> exposure time; ",
      "col. <b>(5)</b> right ascension of cluster center; ",
      "col. <b>(6)</b> declination of cluster center; ",
      "col. <b>(7)</b> redshift; ",
      "col. <b>(8)</b> best-fit central entropy; ",
      "col. <b>(9)</b> best-fit entropy profile normalization at 100 kpc; ",
      "col. <b>(10)</b> best-fit entropy profile power-law index; ",
      "col. <b>(11)</b> cluster temperature; ",
      "col. <b>(12)</b> bolometric luminosity; ",
      "col. <b>(13)</b> upper limit indicator; ",
      "col. <b>(14)</b> H\&alpha; luminosity; ",
      "col. <b>(15)</b> upper limit indicator; ",
      "col. <b>(16)</b> integrated radio luminosity; ",
      "col. <b>(17)</b> link to Chandra Data Archive (CDA); ",
      "col. <b>(18)</b> link to National Virtual Observatory (NVO); ",
      "col. <b>(19)</b> link to NASA/IPAC Extragalactic Database (NED); ",
      "and col. <b>(20)</b> link to Smithsonian/NASA Astrophysics Data System (ADS).</font>",
      "</caption>\n",
      "<thead>\n",
      "<tr bgcolor=\"$tbbgd\">\n",
      "<th class=\"{sorter: \'integer\'}\" align=center>${sfont}#${efont}</th>\n",
      "<th class=\"{sorter: \'text\'}\" align=center>${sfont}Cluster Name${efont}</th>\n",
      "<th class=\"{sorter: \'integer\'}\" align=center>${sfont}ObsID${efont}</th>\n",
      "<th class=\"{sorter: \'float\'}\" align=center>${sfont}Exp.<br>Time${efont}</th>\n",
      "<th class=\"{sorter: \'text\'}\" align=center>${sfont}R.A.${efont}</th>\n",
      "<th class=\"{sorter: \'text\'}\" align=center>${sfont}Decl.${efont}</th>\n",
      "<th class=\"{sorter: \'float\'}\" align=center>${sfont}<i>z</i>${efont}</th>\n",
      "<th class=\"{sorter: \'float\'}\" align=center>${sfont}<i>K<sub>0</sub></i>${efont}</th>\n",
      "<th class=\"{sorter: \'float\'}\" align=center>${sfont}<i>K<sub>100</sub></i>${efont}</th>\n",
      "<th class=\"{sorter: \'float\'}\" align=center>${sfont}<i>\&alpha;</i>${efont}</th>\n",
      "<th class=\"{sorter: \'float\'}\" align=center>${sfont}<i>T<sub>X</sub></i>${efont}</th>\n",
      "<th class=\"{sorter: \'float\'}\" align=center>${sfont}<i>L<sub>bol</sub></i>${efont}</th>\n",
      "<th class=\"{sorter: \'text\'}\" align=center>${sfont}UL?${efont}</th>\n",
      "<th class=\"{sorter: \'float\'}\" align=center>${sfont}<i>L<sub>H\&alpha;</sub></i>${efont}</th>\n",
      "<th class=\"{sorter: \'text\'}\" align=center>${sfont}UL?${efont}</th>\n",
      "<th class=\"{sorter: \'float\'}\" align=center>${sfont}<i>L<sub>radio</sub></i>${efont}</th>\n",
      "<th class=\"{sorter: false}\" colspan=4>${sfont}External&nbsp;Links${efont}</th>\n",
      "</tr>\n",
      "<tr>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "<td $aform>${sfont}ksec${efont}</td>\n",
      "<td $aform>${sfont}hr\:min\:sec${efont}</td>\n",
      "<td $aform>${sfont}deg\:min\:sec${efont}</td>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "<td $aform>${sfont}keV cm<sup>2</sup>${efont}</td>\n",
      "<td $aform>${sfont}keV cm<sup>2</sup>${efont}</td>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "<td $aform>${sfont}keV${efont}</td>\n",
      "<td $aform>${sfont}10<sup>44</sup>ergs s<sup>-1</sup>${efont}</td>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "<td $aform>${sfont}10<sup>40</sup>ergs s<sup>-1</sup>${efont}</td>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "<td $aform>${sfont}10<sup>40</sup>ergs s<sup>-1</sup>${efont}</td>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "<td $aform>${sfont}---${efont}</td>\n",
      "</tr>\n",
      "<tr>\n",
      "<td $aform>${sfont}(1)${efont}</td>\n",
      "<td $aform>${sfont}(2)${efont}</td>\n",
      "<td $aform>${sfont}(3)${efont}</td>\n",
      "<td $aform>${sfont}(4)${efont}</td>\n",
      "<td $aform>${sfont}(5)${efont}</td>\n",
      "<td $aform>${sfont}(6)${efont}</td>\n",
      "<td $aform>${sfont}(7)${efont}</td>\n",
      "<td $aform>${sfont}(8)${efont}</td>\n",
      "<td $aform>${sfont}(9)${efont}</td>\n",
      "<td $aform>${sfont}(10)${efont}</td>\n",
      "<td $aform>${sfont}(11)${efont}</td>\n",
      "<td $aform>${sfont}(12)${efont}</td>\n",
      "<td $aform>${sfont}(13)${efont}</td>\n",
      "<td $aform>${sfont}(14)${efont}</td>\n",
      "<td $aform>${sfont}(15)${efont}</td>\n",
      "<td $aform>${sfont}(16)${efont}</td>\n",
      "<td $aform>${sfont}(17)${efont}</td>\n",
      "<td $aform>${sfont}(18)${efont}</td>\n",
      "<td $aform>${sfont}(19)${efont}</td>\n",
      "<td $aform>${sfont}(20)${efont}</td>\n",
      "</tr>\n",
      "</thead>\n",
      "<tbody>\n";

  # open an ascii log
  open(ASCTAB,">${stordir}/accept_main.tab");
  printf ASCTAB "%-25s %20s %20s %10s %10s %10s %10s %10s %10s %6s %10s %6s %10s\n","#Name","RA","Dec","z","K0","K100","alpha","Tcl","Lbol","UL?","LHa","UL?","Lrad";
  printf ASCTAB "%-25s %20s %20s %10s %10s %10s %10s %10s %10s %6s %10s %6s %10s\n","#--","h:m:s","d:m:s","--","keV.cm^2","keV.cm^2","--","keV","erg/sec","--","erg/sec","--","erg/sec";

  # go through each cluster and make the table
  my $count   = 0;
  my $obscount = 0;
  my $oldname = "";
  foreach $key (@keys) {
    next unless defined ($clinfo{$key});
    my @refdata = split(/\s+/,$clinfo{$key});

    # get data values
    my $name  = $refdata[0];
    my $obsid = $refdata[1];
    my $z     = $refdata[6];
    my $nh    = $refdata[7];
    my $tx    = $refdata[8];
    my $fe    = $refdata[9];

    # format names
    my $cname = $name;
    $cname =~ s/BELL_00/BELL /;
    $cname =~ s/BELL_0/BELL /;
    $cname =~ s/_/ /;
    $count++ unless ($cname eq $oldname);
    $obscount++;

#    # insert header for looks
#    if ((($count%20)==0) && ($cname ne $oldname)) {
#      $aform = "align=center bgcolor=\"$tbbgd\" valign=middle";
#      $sfont = "${sfont}<b>";
#      $efont = "</b></font>";
#      print MAINFILE "<tr>\n",
#      "<td $aform>${sfont}#${efont}</td>\n",
#      "<td bgcolor=\"$tbbgd\" valign=middle align=center colspan=4>${sfont}External&nbsp;Links${efont}</td>\n",
#      "</tr>\n";
#    }

    # get values for individ cluster
    if (exists $obsinfo{$key}) {
	@data = split(/\s+/,$obsinfo{$key});
	$expt = sprintf("%.1f",$data[19]);
    } else {
	$expt = 0.00;
    }
    if (exists $mlbol{$name}) {
	$lx = $mlbol{$name};
	if ($lx > 0.0) {
	    $lx = $lx;
	    $lx   = sprintf("%.3f",$lx);
	} else {
	    $lx = 0.00;
	}
	$havar = "";
	$sfont = "";
	$efont = "";
	$type = $mhatype{$name};
	if ($type eq "NF") {
	    $havar = "<";
#	    $sfont = "<font color=\"$ulcolr\">";
#	    $efont = "</font>";
	}
	$rawlha = $mha{$name};
	if ($rawlha > 0.0) {
	    $rawlha = $rawlha;
	    $rawlha = sprintf("%.3f",$rawlha);
	} else {
	    $rawlha = 0.00;
	}
	$lha = $sfont.$rawlha.$efont;
	$radvar = "";
	$sfont = "";
	$efont = "";
	$type = $mradtype{$name};
	if ($type eq "NF") {
	    $radvar = "<";
#	    $sfont = "<font color=\"$ulcolr\">";
#	    $efont = "</font>";
	}
	$rawlrad = $mradio{$name};
	if ($rawlrad > 0.0) {
	    $rawlrad = $rawlrad;
	    $rawlrad = sprintf("%.3f",$rawlrad);
	} else {
	    $rawlrad = 0.00;
	}
	$lrad = $sfont.$rawlrad.$efont;
	$k0 = $mk0{$name};
	$k0 = sprintf("%.2f",$k0);
	$k0err = $mk0err{$name};
	$k0err = sprintf("%.2f",$k0err);
	$k100 = $mk100{$name};
	$k100 = sprintf("%.2f",$k100);
	$k100err = $mk100err{$name};
	$k100err = sprintf("%.2f",$k100err);
	$alpha = $malpha{$name};
	$alpha = sprintf("%.2f",$alpha);
	$alphaerr = $maerr{$name};
	$alphaerr = sprintf("%.2f",$alphaerr);
	$ra = $mra{$name};
	$dec = $mdec{$name};
    } else {
	$lx   = "---";
	$lha = "---";
	$lrad = "---";
	$k0 = "---";
	$k100 = "---";
	$alpha = "---";
	$k0err = "---";
	$k100err = "---";
	$alphaerr = "---";
	$ra = "---";
	$dec = "---";
    }

    # store all this data for another subroutine
    my $edat = join(" ",$expt,$ra,$dec,$k0,$lx,$rawlha,$rawlrad,$k100,$alpha,$k0err,$k100err,$alphaerr);
    $extra{$obsid} = $edat;

    # add a line to the top of row
#    if ($cname ne $oldname && $count != 1) {
	$style = "style=\"border-top-width\:1px\;border-top-style\:solid\"";
#    } else {
#	$style = "";
#    }

    # print the html
    print MAINFILE 
	"<tr>\n<td $style align=center><font size=\"2\">$count</font></td>\n",
	"<td $style align=center><font size=\"2\">$cname</font></td>\n";

    # put everything into rows
    $tbalign = "center";
    print MAINFILE
	"<td $style align=$tbalign><font size=\"2\"><a href=\"${url}/${clpath}/${obsid}.html\" target=\"_blank\">$obsid</a></font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$expt</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$ra</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$dec</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$z</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$k0</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$k100</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$alpha</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$tx</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$lx</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$havar</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$lha</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$radvar</font></td>\n",
	"<td $style align=$tbalign><font size=\"2\">$lrad</font></td>\n";
    my($ned,$ads,$w3b,$w3b2,$nvo,$cda) = sub_extlinks($cname,$ra,$dec,$obsid);
    print MAINFILE $cda,$nvo,$ned,$ads;
    print MAINFILE "</tr>\n";

    # print to an ascii file
    unless ($cname eq $oldname) {
	$oname = $cname;
	$oname =~ s/\s+/_/;
	$havar = '=' if ($havar !~ /^\</);
	$radvar = '=' if ($radvar !~ /^\</);
	$havar = '?' if ($lha == 0);
	$radvar = '?' if ($lrad == 0);
	printf ASCTAB "%-25s %20s %20s %10.4f %10.2f %10.2f %10.2f %10.2f %10.3f %6s %10.3f %6s %10.3f\n",$oname,$ra,$dec,$z,$k0,$k100,$alpha,$tx,$lx,$havar,$lha,$radvar,$lrad;
    }

    # iter name
    $oldname = $cname;
  }
  close ASCTAB;
  print MAINFILE "</tbody>\n";
  print MAINFILE "</table>\n";
  print_footer(\*MAINFILE);
  print "## Processed $obscount observations for $count cluster\n";
}

#######################
#######################

sub sub_print_header {

  my($fh,$infile,$title) = @_;

  open($fh,">$infile") || die "Can't open $infile\n";
  @headinfo = ("<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/tr/html4/loose.dtd\">",
	       "<html>",
	       "<head>",
	       "<title>$title</title>",
	       "<meta name=\"AUTHOR\" content=\"Kenneth W. Cavagnolo\">",
	       "<meta name=\"KEYWORDS\" content=\"chandra x-ray galaxy cluster cavagnolo entropy michigan state university cosmology astrophysics astronomy\">",
	       "<meta name=\"ROBOTS\" content=\"ALL,INDEX,FOLLOW\">",
	       "<meta name=\"DESCRIPTION\" content=\"ACCEPT: Archive of Chandra Cluster Entropy Profile Tables\">",
	       "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS Feed for ACCEPT\" href=\"${url}/rss.xml\">",
	       "<meta http-equiv=\"CACHE-CONTROL\" content=\"NO-CACHE\">",
	       "<meta http-equiv=\"CONTENT-LANGUAGE\" content=\"en-US\">",
	       "<meta http-equiv=\"CONTENT-TYPE\" content=\"text/html; charset=UTF-8\">",
	       "<style type=\"text/css\">",
	       "  body,tb   {text-decoration: none;      color: $txt; font-family: ${fontfam}; color: ${txt}; background:${bgd}}",
	       "  a:link    {text-decoration: none;      color: $link;}",
	       "  a:visited {text-decoration: none;      color: $vlink;}",
	       "  a:hover   {text-decoration: underline; color: $hlink;}",
	       "  a:active  {text-decoration: none;      color: $alink;}",
	       "</style>",
	       "<script type=\"text/javascript\" src=\"jquery-latest.js\"></script>",
	       "<script type=\"text/javascript\" src=\"jquery.tablesorter.js\"></script>",
	       "<script type=\"text/javascript\" src=\"jquery.tablesorter.pager.js\"></script>",
	       "<script type=\"text/javascript\" src=\"jquery.metadata.js\"></script>",
	       '<script type="text/javascript">',
	       '$(document).ready(function()',
	       '{',
	       '$.tablesorter.defaults.sortList = [[0,0]];',
	       '$("#maintable").tablesorter({ sortMultisortKey: "shiftKey" } );',
	       '}',
	       ');',
	       '</script>',
	       "</head>",
	       "<body>");
  foreach $element (@headinfo) {
    print $fh $element,"\n";
  }

  # page banner
  print $fh "<a name=\"top\"></a>\n";
  print $fh "<table cellSpacing=0 cellPadding=0 width=\"100%\" border=0 style=\"background: #fff url(${banner});\">\n";
  print $fh "<tr style='height:$bnheight'>\n";
  print $fh "<td>&nbsp;&nbsp;&nbsp;</td>\n";
  print $fh "<td align=left valign=middle><font size=$bntxtsize color=\"$bncolor\"><b>$bannertxt</b></font></td>\n";
  print $fh "</tr>\n";
  print $fh "</table>\n";

  # navigation bar
  print $fh "<table cellSpacing=0 cellPadding=0 width=\"100%\" bgColor=\"$navbg\" border=0>\n";
  print $fh "<tr>\n";
  print $fh "<td><a href=\"${url}\"><img name=\"\" src=\"${navhom}\" alt=\"Home\" border=\"0\" width=\"\" height=\"\"></a></td>\n";
  print $fh "<td><a href=\"${url}/accept.html\"><img name=\"\" src=\"${navacc}\" alt=\"What is ACCEPT\" border=\"0\" width=\"\" height=\"\"></a></td>\n";
  print $fh "<td><a href=\"${url}/entropy.html\"><img name=\"\" src=\"${navent}\" alt=\"Entropy?\" border=\"0\" width=\"\" height=\"\"></a></td>\n";
  print $fh "<td><a href=\"${url}/primer.html\"><img name=\"\" src=\"${navpri}\" alt=\"Cluster Primer\" border=\"0\" width=\"\" height=\"\"></a></td>\n";
  print $fh "<td><a href=\"${url}/authors.html\"><img name=\"\" src=\"${navaut}\" alt=\"Authors\" border=\"0\" width=\"\" height=\"\"></a></td>\n";
  print $fh "<td><a href=\"${url}/code.html\"><img name=\"\" src=\"${navcod}\" alt=\"Reduction Code\" border=\"0\" width=\"\" height=\"\"></a></td>\n";
#  print $fh "<td><img name=\"\" src=\"${navbgd}\" alt=\"navbgd\" border=\"0\" width=\"\" height=\"\"></a></td>\n";
  print $fh "<td width=\"100%\" align=right>&nbsp;</td>\n";
  print $fh "</tr>\n";
  print $fh "</table>\n";
}

#######################
#######################

sub print_footer {
  my $fh = shift;
  $mytime = strftime("%Y-%m-%d %X", localtime);
  print $fh
      "<hr>\n<br><table bgcolor=\"$tb3bgd\" border=0 cellspacing=0 cellpadding=2>\n",
      "<tr>\n<td><table bgcolor=\"$tb2bgd\" border=1 cellspacing=3 cellpadding=2>\n",
      "<tr>\n<td align=center><a href=\"${url}\"><font size=2>Main Page</font></a></td>\n",
      "<td align=center><a href=\"\#top\"><font size=2>Top of Page</font></a></td>\n",
      "</tr>\n</table>\n</td>\n</tr>\n</table>\n",
      "<br><font size=2>Email the PI/webmaster: <a href=\"mailto:${email}\">${myname}</a>\n",
      "<br>This page was last updated: $mytime\n";
  print $fh
      "<br>Click map below to see locations of last 100 visitors\n",
      "<br>\n",
      '<!-- ### BEGIN NIFTYMAPS.COM CODE ### -->'."\n",
      '<!-- # WARNING: Do not edit the code below # -->'."\n",
      '<!-- # or your free map will be terminated # -->'."\n",
      '<!-- # as per our Terms and Conditions # -->'."\n",
      '<a href=\'http://www.niftymaps.com/visitor-map.php?id=103478\'><img src=\'http://i.niftymaps.com/103478.png\' alt=\'Click to zoom in on my visitor map!\' border=\'0\'></a><br>Create your free world <a href=\'http://www.niftymaps.com/\' target=\'_blank\'>visitor maps</a>'."\n",
      '<!-- ### END NIFTYMAPS.COM CODE ### -->'."\n",
      "<br>Unique hits to this page:</font>\n",
      '<a href="http://www.easycounter.com/">'."\n",
      '<img src="http://www.easycounter.com/counter.php?kcavagnolo"'."\n",
      'border="0" alt="Hit Counter"></a>'."\n";
  print $fh
      "<p>\n",
      '<a href="http://validator.w3.org/check?uri=referer"> ',
      '<img src="http://www.w3.org/Icons/valid-html401-blue" ',
      'alt="Valid HTML 4.01 Transitional" border=0 height="31" width="88"></a>'."\n",
      "<a href=\"http://www.w3.org/WAI/WCAG1A-Conformance/check?uri=referer\" ",
      "title=\"Explanation of Level A Conformance\"> ",
      "<img border=0 height=\"32\" width=\"88\" ",
      "src=\"http://www.w3.org/WAI/wcag1A-blue\" ",
      "alt=\"Level A conformance icon, ",
      "W3C-WAI Web Content Accessibility Guidelines 1.0\"></a>\n",
      "<a href=\"http://jigsaw.w3.org/css-validator/check?uri=referer\"> ",
      "<img style=\"border:0;width:88px;height:31px\" ",
      "src=\"http://jigsaw.w3.org/css-validator/images/vcss-blue\" ",
      "alt=\"Valid CSS!\"></a>\n",
      "<a href=\"http://feedvalidator.org/check.cgi?url=http%3A//www.pa.msu.edu/astro/MC2/accept/rss.xml\"> ",
      "<img style=\"border:0;width:88px;height:31px\" src=\"${url}/valid-rss.png\" alt=\"[Valid RSS]\" title=\"Validate my RSS feed\"></a>\n",
      "</p>\n";
  print $fh
      "<hr>\n",
      "<p><center>\n",
      "<a href=\"http://www.pa.msu.edu\" target=\"_blank\"><img src=\"$palogo\" width=86 height=86 alt=\"Department of Physics and Astronomy\" border=0></a>\n",
      "<a href=\"http://www.msu.edu\" target=\"_blank\"><img src=\"$msulogo\" width=250 height=86 alt=\"Michigan State University\" border=0></a>\n",
      "<br><font size=2>\&copy; Copyright 2009 Michigan State University Board of Trustees. East Lansing MI 48824<br>\n",
      "MSU is an affirmative-action, equal-opportunity employer.</font><br></center>\n",
      "<p><center>\n",
      "<a href=\"http://www.kiva.org\" target=\"_blank\">\n",
      "<img src=\"http://www.kiva.org/images/bannerlong.png\" width=\"460\" height=\"60\" alt=\"Kiva - loans that change lives\" border=\"0\" align=\"BOTTOM\"></a>\n",
      "<br><font size=2>Our research group proudly supports the microlending efforts of the non-profit organization Kiva.</font>\n";
  print $fh
      "<p><font size=1>\&copy; Copyright 2007-2009 Kenneth W. Cavagnolo<br>\n",
      "Except where explicitly stated, all rights are reserved and <br>\n",
      "content should not be copied, adapted, redistributed, or <br>\n",
      "otherwise used without the prior written permission of Kenneth <br>\n",
      "W. Cavagnolo. Any unauthorized publication, copying, hiring, <br>\n",
      "lending or reproduction is strictly prohibited and constitutes a <br>\n",
      "breach of copyright.</font><br></center>\n";
  print $fh
      '<script type="text/javascript">'."\n",
      'var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");'."\n",
      'document.write(unescape("%3Cscript src=\'" + gaJsHost + "google-analytics.com/ga.js\' type=\'text/javascript\'%3E%3C/script%3E"));'."\n",
      '</script>'."\n",
      '<script type="text/javascript">'."\n",
      'try {'."\n",
      'var pageTracker = _gat._getTracker("UA-8034516-2");'."\n",
      'pageTracker._trackPageview();'."\n",
      '} catch(err) {}</script>'."\n";
  print $fh
      "</body>\n",
      "</html>\n";
  close $fh;
}

#######################
#######################

sub sub_extlinks {

  my($nedlink,$adslink,$w3blink,$w3blink2,$nvolink,@ra,@dec);
  my($clname,$ra,$dec,$obsid) = @_;
  my($nedname) = nedformat($clname);

  # format ra and dec to NED standards
  $ra =~ s/\:/\+/g;
  $dec =~ s/\+/\%2B/g;
  $dec =~ s/\:/\+/g;
  # link to NED entry for source
  $nedlink =
      "<td $style align=center><font size=\"2\"><a href=\"http://nedwww.ipac.caltech.edu/cgi-bin/nph-objsearch?search_type=Near+Position+Search&amp;"
      ."in_csys=Equatorial&amp;"
      ."in_equinox=J2000.0&amp;"
      ."lon=$ra&amp;"
      ."lat=$dec&amp;"
      ."radius=2.0&amp;"
      ."out_csys=Equatorial&amp;"
      ."out_equinox=J2000.0&amp;"
      ."obj_sort=Distance+to+search+center&amp;"
      ."of=pre_text&amp;"
      ."zv_breaker=30000.0&amp;"
      ."list_limit=5&amp;"
      ."img_stamp=YES&amp;"
      ."z_constraint=Unconstrained&amp;"
      ."z_value1=&amp;"
      ."z_value2=&amp;"
      ."z_unit=z&amp;"
      ."ot_include=ANY&amp;"
      ."nmp_op=ANY\" target=\"_blank\">NED</a></font></td>\n";
  
# NED search by name
#  $nedlink =
#    "<td $style align=center><font size=\"2\"><a href=\"http://nedwww.ipac.caltech.edu/cgi-bin/nph-objsearch?objname=${nedname}&amp;"
#      ."extend=no&amp;"
#	."out_csys=Equatorial&amp;"
#	  ."out_equinox=J2000.0&amp;"
#	    ."obj_sort=RA+or+Longitude&amp;"
#	      ."zv_breaker=30000.0&amp;"
#		."list_limit=5&amp;"
#		  ."img_stamp=YES\" target=\"_blank\">NED</a></font></td>\n";

  # querry browse for public data
  $w3blink =
      "<td $style align=center><font size=\"2\"><a href=\"http://heasarc.gsfc.nasa.gov/cgi-bin/W3Browse/w3query.pl?NR=NED&amp;"
      ."GIFsize=100&amp;"
      ."Entry=${ra},${dec}&amp;"
      ."Fields=Standard&amp;"
      ."Radius=Default&amp;"
      ."Equinox=2000&amp;"
      ."tablehead=name%3Dheasarc_ASCAPUBLIC&amp;"
      ."tablehead=name%3Dheasarc_ROSPUBLIC&amp;"
      ."tablehead=name%3Dheasarc_chandrapub&amp;"
      ."tablehead=name%3Dheasarc_SAXNFILOG&amp;"
      ."Coordinates=Equatorial&amp;"
      ."Action=Query%20Submittal\" target=\"_blank\">W3B</a></font></td>\n";

  # query browse for A0's
  $w3blink2 =
      "<td $style align=center><font size=\"2\"><a href=\"http://heasarc.gsfc.nasa.gov/cgi-bin/W3Browse/w3query.pl?NR=NED&amp;"
      ."GIFsize=100&amp;"
      ."Entry=${ra},${dec}&amp;"
      ."Fields=Standard&amp;"
      ."Radius=Default&amp;"
      ."Equinox=2000&amp;"
      ."tablehead=name%3Dheasarc_ROSAO&amp;"
      ."tablehead=name%3Dheasarc_ASCAO&amp;"
      ."tablehead=name%3Dheasarc_chandrao&amp;"
      ."tablehead=name%3Dheasarc_SAXAO&amp;"
      ."Coordinates=Equatorial&amp;"
      ."Action=Query%20Submittal\" target=\"_blank\">A0s</a></font></td>\n";

  # add stuff to text= to search abstracts for keywords
  $adslink =
      "<td $style align=center><font size=\"2\"><a href=\"http://adsabs.harvard.edu/cgi-bin/nph-abs_connect?sim_query=YES&amp;"
      ."lpi_query=YES&amp;ned_query=YES&amp;iau_query=YES&amp;"
      ."aut_xct=NO&amp;aut_logic=OR&amp;obj_logic=OR&amp;"
      ."author=&amp;object=${nedname}&amp;start_mon=&amp;"
      ."start_year=&amp;end_mon=&amp;end_year=&amp;"
      ."ttl_logic=ORtitle=&amp;txt_logic=OR&amp;"
      ."text=&amp;nr_to_return=100&amp;start_nr=1&amp;"
      ."query_type=PAPERS&amp;select_nr=100&amp;select_start=1&amp;"
      ."start_entry_day=&amp;start_entry_mon=&amp;start_entry_year=&amp;"
      ."min_score=&amp;jou_pick=ALL&amp;ref_stems=&amp;"
      ."data_and=ALL&amp;group_and=ALL&amp;sort=SCORE&amp;"
      ."aut_wt=1.0&amp;obj_wt=1.0&amp;ttl_wt=0.3&amp;"
      ."txt_wt=3.0&amp;aut_syn=YES&amp;ttl_syn=YES&amp;"
      ."txt_syn=YES&amp;aut_wgt=YES&amp;obj_wgt=YES&amp;"
      ."ttl_wgt=YES&amp;txt_wgt=YES&amp;ttl_sco=YES&amp;"
      ."txt_sco=YES&amp;obj_req=YES&amp;txt_req=YES&amp;"
      ."db_key=AST&amp;version=1\" target=\"_blank\">ADS</a></font></td>\n";

  # add nvo query
  $nvolink =
      "<td $style align=center><font size=\"2\"><a href=\"http://heasarc.gsfc.nasa.gov/cgi-bin/vo/datascope/jds.pl?"
      ."position=${ra}%20%20${dec}&amp;size=0.25&amp;skipcache=on&amp;skipregsave=on&amp;skiplog=on\" target=\"_blank\">NVO</a></font></td>\n";

  # cda query
  $cdalink = "<td $style align=center><font size=\"2\">"
      ."<a href=\"http://cda.harvard.edu/chaser/viewerContents.do?obsid=${obsid}&amp;operation=summary\" "
      ."target=\"_blank\">CDA</a></font></td>\n";

#  $cdalink =
#      "<td $style align=center><font size=\"2\"><a href=\"http://cfa-www.harvard.edu/archive/chandra/search?red=&amp;"
#      ."obs=${obsid}&amp;name=&amp;resol=Simbad%40CfA&amp;ins=Any&amp;ra=&amp;gra=Any&amp;dec=&amp;key=&amp;wid=&amp;pi=&amp;Search=Search\" target=\"_blank\">CDA</a></font></td>\n";

  return ($nedlink,$adslink,$w3blink,$w3blink2,$nvolink,$cdalink);
}

#######################
#######################

sub nedformat {

  my($name) = shift;
  $name =~ s/\_/ /g;

  $name = "IRAS 09104+4109" if ($name eq "CL 09104+4109");
  chop($name) if ($name =~ /aBELL\s\d+S$/ || $name =~ /aBELL\s\d+N$/);
  $name =~ s/\+/\%2B/g;
  $name =~ s/\s/+/g;
  $name .= "+CLUSTER" if ($name eq "CENTAURUS" || $name eq "FORNAX" ||
			  $name eq "HERCULES"  || $name eq "OPHIUCHUS");
  return $name;
}

#######################
#######################

sub sub_make_clfiles {

  foreach $key (sort keys %clinfo) {
    @refdata = split(/\s+/,$clinfo{$key});
    $name  = $refdata[0];
    $cname = $name;
    $cname =~ s/_/ /;
    $obsid = $refdata[1];
    $rmax  = $refdata[4];
    $mincts= $refdata[5];
    $z     = $refdata[6];
    $nh    = $refdata[7];
    $tx    = $refdata[8];
    $fe    = $refdata[9];
    $loc   = $refdata[15];

    # get extra data from previous routine
    @edat = split(/\s+/,$extra{$obsid});
    my $expt   = $edat[0];
    my $ra     = $edat[1];
    my $dec    = $edat[2];
    my $k0     = $edat[3];
    my $lx     = $edat[4];
    my $lha    = $edat[5];
    my $lrad   = $edat[6];
    my $k100   = $edat[7];
    my $alpha  = $edat[8];
    my $k0err    = $edat[9];
    my $k100err  = $edat[10];
    my $alphaerr = $edat[11];

    # print header
    sub_print_header(\*OUTFILE,
		     "${stordir}/${clpath}/${obsid}.html",
		     "$cname -- $obsid");

    # insert links to download data
    print OUTFILE
	"<br><font size=2><b>Cluster: $cname</b></font><br>\n",
	"<font size=2><b>ObsID: $obsid</b></font><br><br>\n";

    # insert anchor links
    print OUTFILE
	"<table bgcolor=\"$tb3bgd\" border=1 cellspacing=0 cellpadding=2>\n",
	"<tr>\n",
	"<td>\n",
	"<table bgcolor=\"$tb2bgd\" border=1 cellspacing=3 cellpadding=2>\n",
	"<tr>\n",
	"<th colspan=3><font size=2>Page Navigation Links</font></th>\n</tr>\n";
    $scell = "<td align=left><font size=2>";
    $ecell = "</font></td>\n";
    print OUTFILE
	"<tr>\n",
	"${scell}<a href=\"\#coreimg\">Cluster Core Image</a>${ecell}",
	"${scell}<a href=\"\#cool\">Cooling Time Profile</a>${ecell}",
	"${scell}<a href=\"\#dens\">Density Profile</a>${ecell}",
	"</tr>\n",
	"<tr>\n",
	"${scell}<a href=\"\#ent\">Entropy Profile</a>${ecell}",
	"${scell}<a href=\"\#gmas\">Gravitating Mass Profile</a>${ecell}",
	"${scell}<a href=\"\#lc\">Light Curve</a>${ecell}",
	"</tr>\n",
	"<tr>\n",
	"${scell}<a href=\"\#fe\">Metal abundance profile</a>${ecell}",
	"${scell}<a href=\"\#p\">Pressure Profile</a>${ecell}",
	"${scell}<a href=\"\#multiimg\">SDSS/DSS Image</a>${ecell}",
	"</tr>\n",
	"<tr>\n",
	"${scell}<a href=\"\#spec\">Spectral Analysis</a>${ecell}",
	"${scell}<a href=\"\#sbr\">Surface Brightness Profile</a>${ecell}",
	"${scell}<a href=\"\#tx\">Temperature Profile</a>${ecell}",
	"</tr>\n",
	"<tr>\n",
	"${scell}<a href=\"\#wfimg\">Wide-Field Image</a>${ecell}",
	"</tr>\n",
	"</table>\n",
	"</td>\n",
	"</tr>\n",
	"</table>\n";

    # print some info to the body
    $scell = "<th><font color=\"$tbtext\" size=2>";
    $ecell = "</font></th>\n";
    print OUTFILE
	"<p><table border=0 cellspacing=2 width=$tabwidth>\n",
	"<caption>\n",
	"<font size=2>",
	"Col. <b>(1)</b> Exposure time; ",
	"col. <b>(2)</b> right ascension of cluster center; ",
	"col. <b>(3)</b> declination of cluster center; ",
	"col. <b>(4)</b> Galactic absorbing column density, N<sub>H</sub>; ",
	"col. <b>(5)</b> redshift; ",
	"col. <b>(6)</b> maximum radius from cluster center, R<sub>max</sub>; ",
	"col. <b>(7)</b> minimum counts used per T<sub>X</sub> annulus; ",
	"col. <b>(8)</b> average cluster temperature; ",
	"col. <b>(9)</b> average cluster metal abundance; ",
	"and col. <b>(10)</b> bolometric luminosity; ",
	"</font>",
	"</caption>\n",
	"<tr bgcolor=\"$tbbgd\">\n",
	"${scell}Exp<br>Time${ecell}",
	"${scell}R.A.${ecell}",
	"${scell}Decl.${ecell}",
	"${scell}<i>N<sub>H</sub></i>${ecell}",
	"${scell}<i>z</i>${ecell}",
	"${scell}R<sub>max</sub>${ecell}",
	"${scell}Min. cts.${ecell}",
	"${scell}<i>T<sub>X</sub></i>${ecell}",
	"${scell}Abund.${ecell}",
	"${scell}<i>L<sub>bol</sub></i>${ecell}",
	"</tr>\n";
    $scell = "<td align=center><font color=\"$tbtext\" size=2>";
    $ecell = "</font></td>\n";
    print OUTFILE
	"<tr bgcolor=\"$tbbgd\">\n",
	"${scell}ksec${ecell}",
	"${scell}hr:min:sec${ecell}",
	"${scell}deg:min:sec${ecell}",
	"${scell}10<sup>20</sup> cm<sup>-2</sup>${ecell}",
	"${scell}---${ecell}",
	"${scell}pixels${ecell}",
	"${scell}counts${ecell}",
	"${scell}keV${ecell}",
	"${scell}Solar${ecell}",
	"${scell}10<sup>44</sup> ergs/s${ecell}",
	"</tr>\n",
	"<tr bgcolor=\"$tbbgd\">\n",
	"${scell}(1)${ecell}",
	"${scell}(2)${ecell}",
	"${scell}(3)${ecell}",
	"${scell}(4)${ecell}",
	"${scell}(5)${ecell}",
	"${scell}(6)${ecell}",
	"${scell}(7)${ecell}",
	"${scell}(8)${ecell}",
	"${scell}(9)${ecell}",
	"${scell}(10)${ecell}",
	"</tr>\n";

    # print cluster data
    $scell = "<td align=center><font size=2>";
    $ecell = "</font></td>\n";
    print OUTFILE
	"<tr>\n",
	"${scell}$expt${ecell}",
	"${scell}$ra${ecell}",
	"${scell}$dec${ecell}",
	"${scell}$nh${ecell}",
	"${scell}$z${ecell}",
	"${scell}$rmax${ecell}",
	"${scell}$mincts${ecell}",
	"${scell}$tx${ecell}",
	"${scell}$fe${ecell}",
	"${scell}$lx${ecell}",
	"</tr>\n",
	"</table>\n",
	"<br><font size=2><a href=\"${url}/data/${name}_profiles.dat\">Click here to download a master table of profiles for this cluster.</a></font>\n",
	"<br><font size=2>All images generated using <a href=\"http://hea-www.harvard.edu/RD/ds9/\" target=\"_blank\">SAOImage DS9</a>, ",
	"developed by the <a href=\"http://cfa-www.harvard.edu/sao/\" target=\"_blank\">Smithsonian Astrophysical Observatory</a></font>.";

    # insert wide-field GIF image of cluster
    $imgfile = "${url}/images/${obsid}_wide.png";
    $title   = "Smoothed and binnd wide-field Chandra X-ray image of cluster";
    $text    = "A gaussian smoothing kernel with size 2 was applied to the flare-cleaned, level-2 "
	."events file binned with a factor of 8 to produce this image. Point sources have not been "
	."excluded and no exposure correction has been applied to this image.";
    $alt     = "$cname";
    $anchor  = "wfimg";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert image of cluster core
    $imgfile = "${url}/images/${obsid}_core.png";
    $title   = "Smoothed and binned Chandra X-ray image of the cluster \"core\"";
    $text    = "Same as the wide-field image above but the binning factor used here was 2.";
    $alt     = "$cname";
    $anchor  = "coreimg";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert image of cluster in SDSS
    $imgfile = "${url}/images/${obsid}_multi.png";
    $title   = "SDSS/DSS footprint overlaid on cluster core";
    $text    = "The SDSS/DSS footprint (white box) is centered on the cluster core.";
    $alt     = "$cname";
    $anchor  = "multiimg";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # decide which file to use SDSS or DSS
    my $file = "${loc}/${obsid}/reprocessed/${obsid}_sdss.png";
    if (-e $file) {
	my $filesize = stat("$file")->size;
	if ($filesize < 10000) {
	    $imgfile = "${url}/images/${obsid}_dss.png";
	    $survey = "Digitized Sky Survey (DSS)";
	    $slink = "http://archive.stsci.edu/dss/";
	} else {
	    $imgfile = "${url}/images/${obsid}_sdss.png";
	    $survey = "Sloan Digital Sky Survey (SDSS)";
	    $slink = "http://www.sdss.org/";
	}
    } else {
	print "## ERROR: Missing $file\n";
    }
    $title  = "$survey image of cluster core";
    $text   = "Image taken from <a href=\"${slink}\" target=\"_blank\">${survey}</a>";
    $text   .= " via <a href=\"http://skyview.gsfc.nasa.gov/ target=\"_blank\">SkyView</a>." if ($survey eq "DSS");
    $alt    = "$cname";
    $anchor = "sdss";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert light curve
    $imgfile = "${url}/lc/${obsid}_lc.png";
    $title   = "Background light curve";
    $text    = "To check for contamination from background flares or periods of "
	."excessively high background, light curve analysis was performed using "
	."Maxim Markevitch's contributed CIAO script <a href=\"http://cxc.harvard.edu"
	."/contrib/maxim/acisbg/\" target=\"_blank\">lc_clean.sl</a>. "
	."Periods with count rates >= 3sigma and/or a factor >= 1.2 of "
	."the mean background level of the observation were removed from the GTI file.\n";
    $alt     = "light curve";
    $anchor  = "lc";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert sur bri prof
    $imgfile = "${url}/surbri/${obsid}_surbri.png";
    $title   = "Surface brightness profile";
    $text    = "We began by extracting surface brightness profiles "
	."from the 0.7-2.0 keV energy range using concentric "
	."annular bins of size 5\" (~10 ACIS pixels) originating from "
	."the X-ray center. To remove the effects of vignetting and exposure "
	."time fluctuations we corrected each surface brightness profile by an "
	."observation specific normalized radial exposure profile.";
    $alt    = "surface brightness profile";
    $anchor = "sbr";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert picture of spectral bins
    $imgfile = "${url}/images/${obsid}_tx.png";
    $title   = "Annuli used for generating temperature profile";
    $text    = "Each annulus is centered at RA: ${ra}, Decl: ${dec} and contains ${mincts} counts. "
	."Links to an image of each spectrum and the corresponding best-fit MeKaL model (solid-line) are "
	."provided below the image.";
    $alt     = "temperature bins";
    $anchor  = "spec";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert a table linking to images of annuli spectra
    if (exists $txann{$name}) {
	print OUTFILE "<p>\n<table bgcolor=\"$tb3bgd\" border=3 cellspacing=4 cellpadding=4 width=$tabwidth>\n";
	my $twid = 0.8*$tabwidth;
	print OUTFILE "<tr>\n<td><table bgcolor=\"$tb2bgd\" align=center border=1 cellspacing=2 cellpadding=2 width=$twid>\n";
	print OUTFILE "<tr>\n<th colspan=5 align=center><font size=2>Links to images of spectra</font></th>\n</tr>\n";
	print OUTFILE "<tr>\n";
	$numann = $txann{$name};
	my $ctr = 0;
	for (my $i=1; $i<=$numann; $i++) {
	    if ((($ctr%5)==0) && ($ctr != 0)){
		$ctr = 0;
		print OUTFILE "</tr>\n<tr>\n";
	    }
	    print OUTFILE "<td><font size=2><a href=\"${url}/spectra/${obsid}_annuli${i}.png\">Annulus ${i}</a></font></td>\n";
	    $ctr++;
	}
	print OUTFILE "</tr>\n</table>\n</td>\n</tr>\n</table>\n";
    } else {
	print "## ERROR: no annuli spectra for $name\n";
    }

    # insert tx prof
    $imgfile = "${url}/tx/${obsid}_tx.png";
    $title   = "Temperature profile";
    $text    = "The temperature profile corresponding to the image and annuli shown above. Uncertainties are 90% confidence.";
    $alt     = "temperature profile";
    $anchor  = "tx";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert fe prof
    $imgfile = "${url}/fe/${obsid}_fe.png";
    $title   = "Metal abundance profile";
    $text    = "The abundance profile corresponding to the image and annuli shown above. Uncertainties are 90% confidence.";
    $alt     = "abundance profile";
    $anchor  = "fe";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert ne prof
    $imgfile = "${url}/density/${obsid}_density.png";
    $title   = "Density profile";
    $text    = "Electron gas density profile derived from deprojecting the surface brightness with spectral information.";
    $alt     = "density profile";
    $anchor  = "dens";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert pressure prof
    $imgfile = "${url}/pressure/${obsid}_pressure.png";
    $title   = "Pressure profile";
    $text    = "Electron gas pressure profile derived from the density and temperature profiles.";
    $alt     = "pressure profile";
    $anchor  = "p";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert entropy prof
    $imgfile = "${url}/entropy/${obsid}_entropy.png";
    $title   = "Entropy profile";
    $text    = "Entropy profile derived from density and temperature as <i>K=Tn<sub>e</sub><sup>-2/3</sup></i>. "
	."The dashed line is the best-fit for the model $kmodel "
	."with fit values:<br>"
	."<i>K<sub>0</sub></i> = $k0 &plusmn; $k0err keV cm<sup>2</sup><br>"
	."<i>K<sub>100</sub></i> = $k100 &plusmn; $k100err keV cm<sup>2</sup><br>"
	."<i>\&alpha;</i> = $alpha &plusmn; $alphaerr.<br>"
	."The dashed-dotted line is the best-fit for the model <i>K=K<sub>100</sub>(r/100 kpc)<sup>\&alpha;</sup></i>.";
    $alt     = "entropy profile";
    $anchor  = "ent";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert fc prof
    $imgfile = "${url}/fc/${obsid}_fc.png";
    $title   = "Conduction suppresion profile";
    $text    = "Conduction suppression factor, <i>f<sub>c</sub></i> profile derived from the entropy profile assuming Spitzer conduction.";
    $alt     = "fc profile";
    $anchor  = "fc";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert tcool prof
    $imgfile = "${url}/tcool/${obsid}_tcool.png";
    $title   = "Cooling time profile";
    $text    = "Gas cooling time profile using the formulation <i>t<sub>cool</sub>=(3/2 nkT)/(n<sub>e</sub>n<sub>p</sub>&Lambda;(T,Z))</i> for isochoric cooling. "
	."The dashed horizontal line represents the age of the Universe at the redshift of the cluster.";
    $alt     = "cooling profile";
    $anchor  = "cool";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # insert grav mass prof
    $imgfile = "${url}/mgrav/${obsid}_mgrav.png";
    $title   = "Gravitating mass profile";
    $text = "Gravitating mass profile derived from assuming
    hydrostatic equilibrium and differentiating the log-space electron
    density profile with a piecewise method. The d(ln T)/dr term has
    been assumed to be negligible (a terrible assumption). **CAUTION**
    THIS WAS NOT THE FOCUS OF OUR WORK, USE AT YOUR OWN RISK!";
    $alt     = "grav mass profile";
    $anchor  = "mgrav";
    sub_insert_img($obsid,$imgfile,$title,$text,$alt,$anchor);

    # close the file
    print_footer(\*OUTFILE);
  }
}

#######################
#######################

sub sub_insert_img {

  my($key,$file,$title,$text,$alt,$anchor) = @_;
  my $twid = 0.8*$tabwidth;
  print OUTFILE
      "<a name=\"$anchor\"></a>\n",
      "<p>\n<table bgcolor=\"$tb3bgd\" border=3 cellspacing=4 cellpadding=4 width=$tabwidth>\n",
      "<tr>\n<td><table bgcolor=\"$tb2bgd\" align=center border=1 cellspacing=2 cellpadding=2 width=$twid>\n",
      "<tr>\n<th align=center><font size=2>$title</font></th>\n</tr>\n",
      "<tr>\n<td bgcolor=\"\#FFFFFF\" align=center><img align=middle src=\"$file\" alt=\"$key $alt\"></td>\n</tr>\n",
      "<tr>\n<td><font size=2>$text</font></td>\n</tr>\n",
      "</table>\n</td>\n</tr>\n</table>\n";
}

#######################
#######################

sub sub_gettx {

  my($in) = @_;
  my(%out);
  print "## Reading in temperature information.\n";
  my $iter = 1;
  my $oldname = "fdfd";
  open(A,$in);
  while(<A>){
      chomp;
      next if (/^\#/);
      next if (/^$/);
      s/^\s+//;
      s/\s+$//;
      my @a = split;
      my $name = $a[0];
      if (($iter == 1) || ($name eq $oldname)) {
	  $iter++;
	  $oldname = $name;
      } else {
	  $out{$oldname} = $iter;
	  $iter = 1;
      }
  }
  $out{$oldname} = $iter;
  return %out;
}

#######################
#######################

sub sub_readmaster {

    my($in) = @_;
    open(A,$in);
    while(<A>){
	chomp;
	next if (/^\#/);
	next if (/^$/);
	s/^\s+//;
	s/\s+$//;
	my @a = split;
	$mra{$a[0]} = $a[1];
	$mdec{$a[0]} = $a[2];
#	$mz{$a[0]} = $a[3];
#	$mtx{$a[0]} = $a[4];
	$mk0{$a[0]} = $a[5];
	$mk0err{$a[0]} = $a[6];
	$mk100{$a[0]} = $a[7];
	$mk100err{$a[0]} = $a[8];
	$malpha{$a[0]} = $a[9];
	$maerr{$a[0]} = $a[10];
	$mlbol{$a[0]} = $a[11]/1.0e44;
	$mha{$a[0]} = $a[12]/1.0e40;
	$mhatype{$a[0]} = $a[13];
	$mradio{$a[0]} = $a[14]/1.0e40;
	$mradtype{$a[0]} = $a[15];
    }
}

#######################
#######################

sub sub_make_accept {

    # print header
    sub_print_header(\*OUTFILE,
                     "${stordir}/accept.html",
                     "What is ACCEPT?");

    # insert introduction
    $hscell = "<tr>\n<td><font size=4><b><u>";
    $hecell = "</u></b></font></td>\n</tr>\n";
    $scell = "<tr>\n<td><font size=2>";
    $ecell = "</font></td>\n</tr>\n";
    print OUTFILE "<br><table border=0 cellpadding=0 cellspacing=0 width=\"50%\">\n";
    print OUTFILE "${hscell}What is ACCEPT?${hecell}";
    print OUTFILE "${blank}";
    print OUTFILE
	"${scell}",
	"<b>The simple explanation:</b><br>\n",
	"ACCEPT is a research tool for astrophysicists interested in galaxy clusters.<br>\n",
	"What makes ACCEPT unique is that it is a large, uniformly analyzed database of<br>\n",
	"many cluster properties. Such a database is useful for many research areas, for example,<br>\n",
	"when making comparisons between simulations and observations.<br>\n",
	"${ecell}";
    
    # add blank line
    print OUTFILE "${blank}

";

    # add explanation #2
    print OUTFILE
	"${scell}",
	"<b>The involved explanation:</b><br>\n",
	"Thorough details of this project are presented in two papers:<br>\n",
	"<br>(1) Donahue, Megan; Horner, Donald J.; Cavagnolo, Kenneth W.; Voit, G. Mark<br>",
	"<a href=\"http://adsabs.harvard.edu/abs/2006ApJ...643..730D\" target=\"_blank\">",
	"<i>\"Entropy Profiles in the Cores of Cooling Flow Clusters of Galaxies\"</i></a><br>\n",
	"<br>(2) Cavagnolo, Kenneth W.; Donahue, Megan; Voit, G. Mark; Sun, Ming<br>",
	"<a href=\"http://adsabs.harvard.edu/abs/${paperid}\" target=\"_blank\">",
	"<i>\"Intracluster Medium Entropy Profiles for a Chandra Archival Sample of Galaxy Clusters\"</i></a><br>\n",
	"${ecell}";

    # end the table
    print OUTFILE "</table>\n";

    # close the file
    print_footer(\*OUTFILE);
}

#######################
#######################

sub sub_make_entropy {

    # print header
    sub_print_header(\*OUTFILE,
                     "${stordir}/entropy.html",
                     "An explanation of entropy");

    # insert introduction
    $hscell = "<tr>\n<td><font size=4><b><u>";
    $hecell = "</u></b></font></td>\n</tr>\n";
    $scell = "<tr>\n<td><font size=2>";
    $ecell = "</font></td>\n</tr>\n";
    print OUTFILE "<br><table border=0 cellpadding=0 cellspacing=0 width=\"50%\">\n";
    print OUTFILE "${hscell}An Explanation of Entropy${hecell}";
    print OUTFILE "${blank}";
    print OUTFILE
	"${scell}",
	"Coming soon...\n",
	"<br>In the meantime, read:\n",
	"<br>(A) <a href=\"http://adsabs.harvard.edu/abs/2000MNRAS.315..689L\" target=\"_blank\">The entropy and energy of intergalactic gas in galaxy clusters</a>\n",
	"<br>(B) <a href=\"http://adsabs.harvard.edu/abs/2002ApJ...576..601V\" target=\"_blank\">Modified Entropy Models for the Intracluster Medium</a>\n",
	"<br>(C) <a href=\"http://adsabs.harvard.edu/abs/2006A%26A...446..429P\" target=\"_blank\">Structure and scaling of the entropy in nearby galaxy clusters</a>\n",
	"${ecell}",
#	"${blank}",
#	"${scell}",
#	"${ecell}",
	"</table>\n";

    # close the file
    print_footer(\*OUTFILE);
}

#######################
#######################

sub sub_make_primer {

    # print header
    sub_print_header(\*OUTFILE,
                     "${stordir}/primer.html",
                     "Galaxy Clusters 101");

    # insert introduction
    $hscell = "<tr>\n<td><font size=4><b><u>";
    $hecell = "</u></b></font></td>\n</tr>\n";
    $scell = "<tr>\n<td><font size=2>";
    $ecell = "</font></td>\n</tr>\n";
    print OUTFILE "<br><table border=0 cellpadding=0 cellspacing=0 width=\"50%\">\n";
    print OUTFILE "${hscell}Galaxy Clusters 101${hecell}";
    print OUTFILE "${blank}";
    print OUTFILE
	"${scell}",
	"Coming soon...\n",
	"${ecell}",
#	"${blank}",
#	"${scell}",
#	"${ecell}",
	"</table>\n";

    # close the file
    print_footer(\*OUTFILE);
}

#######################
#######################

sub sub_make_code {

    # print header
    sub_print_header(\*OUTFILE,
                     "${stordir}/code.html",
                     "Reduction and Analysis Code");

    # insert introduction
    $hscell = "<tr>\n<td><font size=4><b><u>";
    $hecell = "</u></b></font></td>\n</tr>\n";
    $scell = "<tr>\n<td><font size=2>";
    $ecell = "</font></td>\n</tr>\n";
    print OUTFILE "<br><table border=0 cellpadding=0 cellspacing=0 width=\"50%\">\n";
    print OUTFILE "${hscell}Reduction and Analysis Code${hecell}";
    print OUTFILE "${blank}";
    print OUTFILE
	"${scell}",
	"Sometime in ____ I (Ken) will upload a tarball containing most\n ",
	"of the data reduction and analysis scripts used in creating\n ",
	"ACCEPT. There will also be a \"Cookbook\" which guides the\n ",
	"user in how to use the scripts (this will be Appendix A from\n ",
	"my dissertation). The suite of scripts is named <i>CORP</i>\n ",
	"for Chandra Observation Reduction Pipeline (I love\n ",
	"acronyms). <i>CORP</i> is written using PERL and IDL mostly\n ",
	"with some TCL for good measure. In time you can also\n ",
	"expect to see <i>XORP</i> join the party... the XMM\n ",
	"Observation Reduction Pipeline.<br>\n",
	"${ecell}",
	"</table>\n";

    # close the file
    print_footer(\*OUTFILE);
}

#######################
#######################

sub sub_make_authors {

    # print header
    sub_print_header(\*OUTFILE,
                     "${stordir}/authors.html",
                     "About the authors");

    # insert introduction
    $hscell = "<tr>\n<td><font size=4><b><u>";
    $hecell = "</u></b></font></td>\n</tr>\n";
    $scell = "<tr>\n<td><font size=2>";
    $ecell = "</font></td>\n</tr>\n";
    print OUTFILE
	"<br><table border=0 cellpadding=0 cellspacing=0 width=\"50%\">\n",
	"${hscell}About the Authors${hecell}",
	"${scell}",
	"Click photos to be transferred to author's personal site.\n",
	"${ecell}",
	"${blank}";
    print OUTFILE
	"${scell}",
	"<a href=\"http://www.pa.msu.edu/people/cavagnolo\" target=\"_blank\"><img src=\"Cavagnolo.jpg\" alt=\"Ken Cavagnolo\"></a> \n",
	"<br><b><u>Dr. Ken Cavagnolo</u></b><br>\n\n",
        "Ken received a bachelor's degree in physics \n",
	"from the <a href=\"http://www.gatech.edu/\" target=\"_blank\">\n",
	"Georgia Institute of Technology</a>, and a \n",
	"Ph.D. in astrophysics from <a \n",
	"href=\"http://www.colorado.edu/\" target=\"_blank\">Michigan State University</a> \n",
	"under the guidance of Dr. Megan Donahue. Ken is now a \n",
	"post-doctoral fellow with <a href=\"http://www.physics.uwaterloo.ca/people/mcnamara/index.html\" \n",
        "target=\"_blank\">Dr. Brian McNamara</a> in the <a \n",
        "href=\"http://astro.uwaterloo.ca/\" \n",
        "target=\"_blank\">Astrophysics and Gravitation</a> group at \n",
        "the <a href=\"http://www.uwaterloo.ca/\" \n",
        "target=\"_blank\">University of Waterloo</a> in <a href=\"http://maps.google.com/maps?f=q&amp;hl=en&amp;geocode=&amp;q=University+of+Waterloo+Waterloo,\n",
	"+ON+N2L+3G1,+Canada&amp;sll=43.46888,-80.53948&amp;sspn=0.045535,0.076647&amp;ie=UTF8&amp;ll=43.466812,-80.540171&amp;spn=0.045537,0.076647&amp;z=14\" \n",
        "target=\"_blank\">Waterloo, Ontario Canada</a>. \n",
	"<br><a href=\"mailto:kcavagno ~at~ IM.NOT.A.BOT scimail -dot- uwaterloo -dot- ca\">Email Ken</a>\n",
	"${ecell}";
    print OUTFILE "${blank}";
    print OUTFILE
	"${scell}",
	"<a href=\"http://www.pa.msu.edu/people/donahue\" target=\"_blank\"><img src=\"Donahue.jpg\" alt=\"Megan Donahue\"></a> ",
	"<br><b><u>Dr. Megan Donahue</u></b><br>\n",
	"Megan is a tenured associate professor at Michigan State \n",
	"University. She earned a bachelor\'s degree in physics from <a \n",
	"href=\"http://web.mit.edu/\" target=\"_blank\">MIT</a>, and a \n",
	"Ph.D. in astrophysics from the <a \n",
	"href=\"http://www.colorado.edu/\" target=\"_blank\">University \n",
	"of Colorado at Boulder</a> under the guidance of <a \n",
	"href=\"http://casa.colorado.edu/~mshull/\" \n",
	"target=\"_blank\">Dr. J. Michael Shull</a>. Megan has been a <a \n",
	"href=\"http://www.ociw.edu/fellowships/recentfellows.html\" \n",
	"target=\"_blank\">Carnegie Fellow</a> at <a href=\"http://www.ociw.edu/\" \n",
	"target=\"_blank\">Carnegie Observatories</a> and a fellow at <a href=\"http://www.stsci.edu\" \n",
	"target=\"_blank\">STScI</a>.\n",
	"<br><a href=\"mailto:donahue ~at~ IM.NOT.A.BOT pa -dot- msu -dot- edu\">Email Megan</a>\n",
	"${ecell}";
    print OUTFILE "${blank}";
    print OUTFILE
	"${scell}",
	"<a href=\"http://www.pa.msu.edu/people/voit\" target=\"_blank\"><img src=\"Voit.jpg\" alt=\"Mark Voit\"></a> ",
	"<br><b><u>Dr. G. Mark Voit</u></b><br>\n",
	"Mark is a tenured associate professor at Michigan State \n",
	"University. He earned a bachelor\'s degree in astrophysical \n",
	"sciences from <a href=\"http://www.princeton.edu/main/\" target=\"_blank\">\n",
	"Princeton University</a>, and a Ph.D. in \n",
	"astrophysics from the <a href=\"http://www.colorado.edu/\" \n",
	"target=\"_blank\">University of Colorado at Boulder</a> under \n",
	"the guidance of <a href=\"http://casa.colorado.edu/~mshull/\" \n",
	"target=\"_blank\">Dr. J. Michael Shull</a>. Mark was a \n",
	"research fellow at <a href=\"http://www.caltech.edu/\" \n",
	"target=\"_blank\">Cal Tech</a> and a <a \n",
	"href=\"http://www.stsci.edu/institute/org/spd/hubble-fellowship/fellows-list\" \n",
	"target=\"_blank\">Hubble Fellow</a> at <a \n",
	"href=\"http://www.jhu.edu/\" target=\"_blank\">Johns Hopkins \n",
	"University</a>.\n",
	"<br><a href=\"mailto:voit ~at~ IM.NOT.A.BOT pa -dot- msu -dot- edu\">Email Mark</a>\n",
	"${ecell}";
    print OUTFILE "${blank}";
    print OUTFILE
	"${scell}",
	"<a href=\"http://hea-www.harvard.edu/~msun\" target=\"_blank\"><img src=\"Sun.jpg\" alt=\"Ming Sun\"></a> ",
	"<br><b><u>Dr. Ming Sun</u></b><br>\n",
	"Ming is a post-doc working with Craig Sarazin at the University of Virigina. \n",
	"Ming was a post-doc at Michigan State University during ACCEPT's creation.\n",
	"<br><a href=\"mailto:ms4ar ~at~ IM.NOT.A.BOT virginia -dot- edu\">Email Ming</a>\n",
	"${ecell}";
    print OUTFILE "</table>\n";

    # close the file
    print_footer(\*OUTFILE);
}

#######################
#######################
