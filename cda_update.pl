#! /usr/bin/perl -w
#
# NAME:
#     cda_update.pl
#
# PURPOSE:
#     This script queries the CDA and finds out which OBSIDs you are
#     not ignoring and do not have. A list of comma separated OBSIDs
#     are output which can be put into WebChaser, or you can feed the
#     one column list of obsids to query_cda.pl for auto downloading
#     (much faster than using WebChaser).
#
# EXPLANATION:
#     This script assumes you're data is stored in <obsid> dirs
#     somewhere on your computer
#
# CALLING SEQUENCE:
#     unix%> perl cda_update.pl
#
# FILES ASSUMED TO EXIST:
#     A file listing obsids to ignore (optional)
#
# INPUTS:
#     None
#
# KEY OUTPUTS:
#     cda_needed        -- a file containing info on the obsids you don't have
#     cda_query         -- the results of the CDA query
#     cda_upcoming      -- an ASCII file listing the obsids which will be released soon
#     cda_upcoming_html -- an HTML file listing the obsids which will be released soon (useful for calendars and such)
#
#######################
#######################
##    Set Options    ##
#######################
#######################

@datadir  = ("/mnt/GIDEON");                  # the location of your chandra data
$dest     = "/mnt/GIDEON/accept/";            # where to put the HTML output file
$ignore   = "$ENV{'HOME'}/research/redux/redux_info/cda_ignore"; # a file containing obsids to ignore
#$ignore   = "";
$getall   = "no";                            # this queries the ENTIRE cda
@instr    = ('ACIS-I','ACIS-S');             # instruments to check for
@grating  = ('NONE');                        # include grating data?
#@status   = ('archived','observed','scheduled','unobserved'); # status of observations to check
@status   = ('archived');
@category = ('CLUSTERS OF GALAXIES');#,'NORMAL GALAXIES');#,'ACTIVE GALAXIES AND QUASARS'); # the categories to look under
$radius   = '10';                            # isn't used in query but needs to be input
$incrdfr  = 'j2000';                         # coord sys to return ra and dec
$incrdeq  = '2000';                          # same
$outcrdfr = 'j2000';                         # same
$outcrdeq = '2000';                          # same
$sort     = 'releaseDate';                   # how obs will be sorted
$sortord  = 'ascending';                     # up or down
$url      = 'http://cda.harvard.edu/srservices/ocatList.do?'; # doesn't need to be changed
$maxresults = 'No Limit';                    # don't limit the results
$outcrdunit = 'sexagesimal';                 # format of output coords

# HTML file formatingoptions
$fontfam  = "sans-serif";
$bgd      = "#999999";
$txt      = "#000000";
$link     = "#FFFFFF";
$alink    = "#FFFF00";
$hlink    = "#00CCFF";
$vlink    = "#FFFFFF";
$tbbgd    = "#000000";
$tbtext   = "#FFFFFF";

#######################
#######################
##   Main Program    ##
#######################
#######################

no warnings('once');
use POSIX qw(strftime);

if ($getall eq "yes") {
    @instr = ('');
    @grating  = ('');
    @category = ('');
    @status  = ('archived','observed','scheduled','unobserved','canceled','discarded');
    foreach $a (@status) {
	$a =~ s/\s+/\%20/g;
	push @val, "status=$a";
    }
} else {
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
}
$radius = "radius=".$radius;
$incrdfr = "inputCoordFrame=".$incrdfr;
$incrdeq = "inputCoordEquinox=".$incrdeq;
$outcrdfr = "outputCoordFrame=".$outcrdfr;
$outcrdeq = "outputCoordEquinox=".$outcrdeq;
$outcrdunit = "outputCoordUnits=".$outcrdunit;
$sort = "sortColumn=".$sort;
$maxresults = "maxResults=".$maxresults;
$sortord = "sortOrder=".$sortord;
$format = "format=text";

@others = ($radius,$incrdfr,$incrdeq,$outcrdfr,$outcrdeq,$outcrdunit,$sort,$maxresults,$sortord,$format);
foreach $a (@others) {
  $a =~ s/\s+/\%20/g;
  push @val, $a;
}
$opts = join "&", @val;
system("curl \'$url$opts' \> cda_query\n");

# build hash of downloaded obs
system("rm -f obsids");
foreach $dir (@datadir) {
    system("ls -1d $dir/* >> obsids");
    open(A,"obsids");
    while(<A>){
	chomp;
	@a = split("/");
	$a = pop(@a);
	$ref{$a} = "yes";
    }
    close A;
    system("rm -f obsids");
}

# build hash of obsids to ignore
open(A,"$ignore");
while(<A>){
  chomp;
  next if (/^\#/);
  next if (/^$/);
  s/^\s+//;
  s/\s+$//;
  @a = split;
  $ign{$a[0]} = "yes";
}
close A;

# create local date
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
  localtime(time);
$year += 1900;

$mytime = strftime("%Y-%m-%d %X", localtime);
open(CDA,"cda_query");

open(MISSING,">cda_needed");
print MISSING "# missing obsids for archived clusters of galaxies\n";

open(UPCOMING,">cda_upcoming");
print UPCOMING "# This list last updated: $mytime\n";
print UPCOMING "# Upcoming release of ObsIDs:\n";
printf UPCOMING "%-30s %8s %8s %15s %20s %30s\n","# Cluster","Obsid","Exp","ArcDate","PI","Category";

open(HTMLUPCOMING,">cda_upcoming_html");
print HTMLUPCOMING
    "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/tr/html4/loose.dtd\">\n",
    "<html>\n",
    "<head>\n",
    "<title>Upcoming CDA archived observations</title>\n\n",
    "<meta name=\"AUTHOR\" content=\"Kenneth W. Cavagnolo\">\n",
    "<meta name=\"KEYWORDS\" content=\"chandra x-ray galaxy cluster cavagnolo entropy michigan state university cosmology astrophysics astronomy\">\n",
    "<meta name=\"ROBOTS\" content=\"ALL,INDEX,FOLLOW\">\n",
    "<meta name=\"DESCRIPTION\" content=\"ACCEPT: Archive of Chandra Cluster Entropy Profile Tables\">\n",
    "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS Feed for ACCEPT\" href=\"http://www.pa.msu.edu/astro/MC2/accept/rss.xml\">\n",
    "<meta http-equiv=\"CACHE-CONTROL\" content=\"NO-CACHE\">\n",
    "<meta http-equiv=\"CONTENT-LANGUAGE\" content=\"en-US\">\n",
    "<meta http-equiv=\"CONTENT-TYPE\" content=\"text/html; charset=UTF-8\">\n",
    "<style type=\"text/css\">\n",
    "  body,tb   {text-decoration: none;      color: $txt; font-family: ${fontfam}; font-size: small; background:${bgd}}\n",
    "  a:link    {text-decoration: none;      color: $link;}\n",
    "  a:visited {text-decoration: none;      color: $vlink;}\n",
    "  a:hover   {text-decoration: underline; color: $hlink;}\n",
    "  a:active  {text-decoration: none;      color: $alink;}\n",
    "</style>\n",
    "</head>\n",
    "<body>\n\n",
    "<p><b># This list last updated: $mytime\n\n",
    "<br># Upcoming release of ObsIDs:</b><br>\n";
print HTMLUPCOMING
    "<table border cellpadding=0 cellspacing=0>\n",
    "<tr bgcolor=\"$tbbgd\">\n",
    "<th align=left><font color=\"$tbtext\"># Target</font></th>\n",
    "<th align=center><font color=\"$tbtext\">Obsid</font></th>\n",
    "<th align=center><font color=\"$tbtext\">Exp</font></th>\n",
    "<th align=center><font color=\"$tbtext\">ArcDate</font></th>\n",
    "<th align=center><font color=\"$tbtext\">PI</font></th>\n",
    "<th align=center><font color=\"$tbtext\">Category</font></th>\n",
    "</tr>\n";
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
  $target =~ s/\s+/_/g;
  $cat =~ s/^\s+//;
  $cat =~ s/\s+$//;
  next if ($seq eq "10");
  $num++;
  $texp += $exp;
  next if ($stat eq "unobserved" || $stat eq "scheduled");
  next if (exists $ref{$obsid});
  next if (exists $ign{$obsid});
  if ($stat eq "archived") {
    push @nobs, $obsid;
    print MISSING "# Do not have $obsid for $target\n";
    next;
  }
  if ($stat eq "observed") {
      if ($prdate eq '') {
	  $prdate = "none";
      } else {
	  @prdate  = split(" ",$prdate);
	  $prdate  = $prdate[0];
	  @prdate  = split("-",$prdate);
      }
#    $prday   = pop(@prdate);
#    $prmon   = pop(@prdate);
#    $pryrs   = pop(@prdate);
#     if ($pryrs lt $year) {
#       printf "%-20s %10s %15s\n",$target,$obsid,$prdate;
#       next;
#     }
#     if ($pryrs eq $year && $prmon lt $mon) {
#       printf "%-20s %10s %15s\n",$target,$obsid,$prdate;
#       next;
#     }
#     if ($pryrs eq $year && $prmon eq $mon && $prday le $mday) {
#       printf "%-20s %10s %15s\n",$target,$obsid,$prdate;
#       next;
#     }
      printf UPCOMING "%-30s %8s %8s %15s %20s %30s\n",$target,$obsid,$exp,$prdate,$pi,$cat;
      if ($cat eq "CLUSTERS OF GALAXIES") {
	  print HTMLUPCOMING
	      "<tr bgcolor=\"#CCCCCC\">\n",
	      "<td align=left><b>${target}</b></td>\n",
	      "<td align=center><b><a href=\"http://cda.harvard.edu/chaser/viewerContents.do?obsid=${obsid}&amp;operation=propAbstract\" target=\"_blank\">${obsid}</a></b></td>\n",
	      "<td align=center><b>${exp}</b></td>\n",
	      "<td align=center><b>${prdate}</b></td>\n",
	      "<td align=center><b>${pi}</b></td>\n",
	      "<td align=center><b>${cat}</b></td>\n";
      } else {
	  print HTMLUPCOMING
	      "<tr>\n",
	      "<td align=left>${target}</td>\n",
	      "<td align=center><a href=\"http://cda.harvard.edu/chaser/viewerContents.do?obsid=${obsid}&amp;operation=propAbstract\" target=\"_blank\">${obsid}</a></td>\n",
	      "<td align=center>${exp}</td>\n",
	      "<td align=center>${prdate}</td>\n",
	      "<td align=center>${pi}</td>\n",
	      "<td align=center>${cat}</td>\n";
      }
      print HTMLUPCOMING "<tr>\n";
  }
}

print HTMLUPCOMING
    "</table>\n",
    "</body>\n",
    "</html>\n";
$texp = sprintf("%.2f",$texp/1e3);
print "\n## WOW, there are $num observations in this query.\n";
print "\n## For a total of $texp Msec.\n";
$nnobs = join ",",@nobs;
print MISSING "$nnobs\n\n";
foreach $a (@nobs) {
    print MISSING "$a\n";
}
close MISSING;
close UPCOMING;
close HTMLUPCOMING;
system("mv -f cda_upcoming_html ${dest}");
close CDA;
exit 0;
