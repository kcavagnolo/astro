#! /usr/local/bin/perl -w

# make html page for source removed from list
# make_clusters cluster.list

# make ra sorted list, make list sorted by flag
%clusters = get_data($ARGV[0],0,1);

# define some changeable numbers
$wwwpath = "../www/";
$imagedir = "images";
#$imagedir2 = "images2";
$splitcount = 50;
$im_width = 680;
$im_height = 340;

# define messages

$headmessage = "<p>These are smoothed images of the ACIS fields (ACIS
    left, DSS right) for clusters in the sample. The green circle is
    2.5' in radius and indicates the nominal coordinates of the source
    from the literature.  A dashed green circle indicates the
    position of other (possible) clusters in the field. <p> A green
    background color means that the clusters is considered a good
    candidate for analysis while a yellow background indicates
    clusters that might be analyzed.  Red indicates clusters which
    have some issue preventing analysis.<br><hr>\n";

$mainmessage = "The tables below have been broken up into separate pages for
$splitcount clusters for convenience.";

# create hashes %alphasort,%rasort,%seqsort,%flagsort;
# key of hash begins with name, ra, obs id, or flag respectively
# value of hash is html table entry for each cluster
return_hashes();

# do main index file
print_header(\*MAINFILE,"${wwwpath}/clusters.html",
	     "Clusters Observed by Chandra ACIS");
print MAINFILE $mainmessage;

#print MAINFILE "<p>Sorted by flag:\n";
#print MAINFILE "<table><tr><td><a href=ok.html>Clusters included in the proposal sample</a></td></tr>\n",
#"<tr><td><a href=maybe.html>Clusters that might be included</a></td></tr>",
#"<tr><td><a href=other.html>Clusters excluded</a></td></tr></table>\n";

# alpha sort table
print MAINFILE "<p>Sorted by name:\n";
print MAINFILE  &do_alphasort();

# RA  sort table
print MAINFILE "<p>Sorted by RA:\n";
print MAINFILE  &do_rasort();

# Obs Id  sort table
print MAINFILE "<p>Sorted by Obs Id:\n";
print MAINFILE  &do_seqsort();


print_footer(\*MAINFILE);


# print out statistics
foreach $flag (@flags) {
    $flag =~ s/\s+$//;
    $flag =~ s/^\s+//;
    $flag = uc $flag;
    $flag{$flag}++;
}

$count = 0;
foreach $flag (sort keys %flag) {
    print "$flag: $flag{$flag}\n";
    $count += $flag{$flag};
}

print $count,"\n";
print scalar(keys %clusters),"\n";


sub print_header {
    my($fh,$infile,$title) = @_;
    
    open($fh,">$infile") || die "Can't open $infile\n";
    @headinfo = ( "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2//EN\">",
		  "<html>", "<head>", "<title>$title</title>", 
		  "<LINK REV=MADE HREF=\"mailto:horner\@milkyway.gsfc.nasa.gov\">", 
		  "</head>", 
		  "<body bgcolor=\"#FFFFFF\" text=\"#000000\" link=\"#0000FF\"
alink=\"#00FF00\" vlink=\"#FF0000\" >", "<h1>$title</h1>");
    foreach $element (@headinfo) {
	print $fh $element,"\n";
    }
}

sub print_footer {
    my $fh = shift;
    print $fh "</body>\n</html>\n";
    close $fh;
}


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

sub outsidelinks {
    
    my($clname) = shift;
    my($ra,$dec) = @_;
    my($nedname) = nedformat($clname);
    my($nedlink,$adslink,$w3blink);

    # link to NED entry for source
    $nedlink =  "<a href=\"http://nedwww.ipac.caltech.edu/cgi-bin/nph-objsearch?objname=${nedname}&extend=no&out_csys=Equatorial&out_equinox=J2000.0&obj_sort=RA+or+Longitude&zv_breaker=30000.0&list_limit=5&img_stamp=YES\">NED</a>\n";

    #add stuff to text= to search abstracts for keywords
    $adslink = "<a href=\"http://adsabs.harvard.edu/cgi-bin/nph-abs_connect?sim_query=YES&lpi_query=YES&ned_query=YES&iau_query=YES&aut_xct=NO&aut_logic=OR&obj_logic=OR&author=&object=${nedname}&start_mon=&start_year=&end_mon=&end_year=&ttl_logic=OR&title=&txt_logic=OR&text=&nr_to_return=50&start_nr=1&query_type=PAPERS&select_nr=50&select_start=1&start_entry_day=&start_entry_mon=&start_entry_year=&min_score=&jou_pick=ALL&ref_stems=&data_and=ALL&group_and=ALL&sort=SCORE&aut_wt=1.0&obj_wt=1.0&ttl_wt=0.3&txt_wt=3.0&aut_syn=YES&ttl_syn=YES&txt_syn=YES&aut_wgt=YES&obj_wgt=YES&ttl_wgt=YES&txt_wgt=YES&ttl_sco=YES&txt_sco=YES&obj_req=YES&txt_req=YES&db_key=AST&version=1\">ADS</a>\n";

    # querry browse for public data
    $w3blink = "<a href=\"http://heasarc.gsfc.nasa.gov/cgi-bin/W3Browse/w3query.pl?NR=NED&GIFsize=100&Entry=${ra},${dec}&Fields=Standard&Radius=Default&Equinox=2000&tablehead=name%3Dheasarc_ASCAPUBLIC&tablehead=name%3Dheasarc_ROSPUBLIC&tablehead=name%3Dheasarc_chandrapub&tablehead=name%3Dheasarc_SAXNFILOG&Coordinates=Equatorial&Action=Query%20Submittal\">W3B</a>\n";

    # query browse for A0's
    $w3blink2 = "<a href=\"http://heasarc.gsfc.nasa.gov/cgi-bin/W3Browse/w3query.pl?NR=NED&GIFsize=100&Entry=${ra},${dec}&Fields=Standard&Radius=Default&Equinox=2000&tablehead=name%3Dheasarc_ROSAO&tablehead=name%3Dheasarc_ASCAO&tablehead=name%3Dheasarc_chandrao&tablehead=name%3Dheasarc_SAXAO&Coordinates=Equatorial&Action=Query%20Submittal\">A0s</a>\n";

    return ($nedlink,$adslink,$w3blink,$w3blink2);

}


sub nedformat {
    my($name) = shift;
    $name =~ s/\_/ /g;

    $name = "IRAS 09104+4109" if ($name eq "CL 09104+4109");
    $name = "RASS1 027" if ($name eq "RX J0232.3-4420"); #$name = "" if ($name eq "");
    $name = "ZwCl 0949.6+5207" if ($name eq "RX J0949.8+1708");  
    $name = "1RXS J193818.5+540928" if ($name eq "CL 1938.3+5409");  
    $name = "NVSS J013803-215533" if ($name eq "RX J0138.0-2156");
#    $name = "" if ($name eq "RX J1354.9+7715");


    chop($name) if ($name =~ /ABELL\s\d+S$/ || $name =~ /ABELL\s\d+N$/);
    $name =~ s/\+/\%2B/g;
    $name =~ s/\s/+/g;

    $name .= "+CLUSTER" if ($name eq "CENTAURUS" || $name eq "FORNAX" || 
			    $name eq "HERCULES"  || $name eq "OPHIUCHUS");
    $name .= "+GROUP" if ($name eq "PAVO+I");
    return $name;
}


sub object_html {
    
    my($key,$clname,$seqno,$ra,$dec,$angle,$fieldname,$flag,$nedlink,$adslink,$w3blink,$w3blink2) = @_;
    my($color);

    if ($flag eq "OK") {
	$color = "#009900";
    } elsif ($flag eq "MAYBE") {
	$color = "#ffff00";
    } else {
	$color = "#FF0000";
    }


    #beginning of table
    $entry = "<p><table bgcolor=\"#000000\" BORDER=0 CELLSPACING=0 cellpadding=2>\n<tr><td><table bgcolor=\"$color\" BORDER=0  cellpadding=3 CELLSPACING=2 width=\"100%\">\n";

    # table data
    $entry .= "<tr><th>Name</th><th>Obs Id</th><th>RA</th><th>DEC</th><th>Redshift</th><th nowrap>Instr</th><th>Flag</th><th>Links</th><tr>\n";

    $entry .=   "<tr><td nowrap>$clname</td><td>$seqno</td><td>$ra</td><td>$dec</td><td>$angle</td><td nowrap>$fieldname</td><td>$flag</td><td nowrap>$nedlink $adslink $w3blink $w3blink2</td>\n";
    
    $entry .= "<tr><td colspan=8><img src=\"${imagedir}/${key}.png\" width=$im_width height=$im_height alt=\"$key X-ray and DSS images\"></td>\n</tr>\n";

#    $entry .= "<tr><td colspan=8><img src=\"../${imagedir2}/${key}.png\" width=$im_width height=$im_height alt=\"$key X-ray and DSS images\"></td>\n</tr>\n";

    # end of table
    $entry .= "</table></td></tr></table>\n";


    return $entry;
    
}

sub return_hashes {

    @flags = ();
    foreach $key (sort keys %clusters) {

	unless (-e "${wwwpath}/${imagedir}/${key}.png") {
	    print "No image for ${wwwpath}/${imagedir}/${key}.png\n" ;
	    next ; 
	}

	@data = split(" ",$clusters{$key});
	($name,$seqno,$ra,$dec,$angle) = splice(@data,0,5);
	
	# format flags
	$flag = pop @data;
	push @flags,$flag;
	
	# skip ones that are "OK" (ie. clusters)
#	next unless ($flag eq "MAYBE");
#	next if ($flag eq "OK" || $flag eq "MAYBE");
	
	#format field name
	$fieldname = join(" ",@data);
	
	$clname = uc $name;
	$clname =~ s/\_/ /g;
	
	# get NED, ADS, etc links
	($nedlink,$adslink,$w3blink,$w3blink2) = 
	    outsidelinks($clname,$ra,$dec);
	
	# make html table for each object
	$entry = object_html($key,$clname,$seqno,$ra,$dec,$angle,$fieldname,$flag,$nedlink,$adslink,$w3blink,$w3blink2);
	
	$alphasort{$key} = $entry;
	$rasort{"${ra}_${dec}_${seqno}"} = $entry;
	$seqsort{"${seqno}_${ra}_${dec}"} = $entry;
#$flagsort{"${flag}_${key}"} = $entry;
    }

#    return, %alphasort,%rasort,%seqsort,%flagsort;

}

sub do_alphasort {

    unlink <$wwwpath/alphasort?.html>;
    unlink <$wwwpath/alphasort??.html>;

    # print html file
    print_header(\*OUTFILE,"${wwwpath}/alphasort1.html",
		 "Image of Clusters");
    print OUTFILE $headmessage;

    $count = 0;
    $truecount = 0;
    $fileno = 1;
    @firsts = ();
    @lasts = ();

    %entry = %alphasort;
    foreach $key (sort keys %entry) {
	
	@data = split(/_/,$key);
	pop @data;
	$clname = join(" ",@data);
	
	push @firsts,$clname if ($count == 0);
	
	# print out the table
	print OUTFILE $entry{$key};
	
	# check the count
	$count++;
	$truecount++;
	if ($count == $splitcount) {
	    push @lasts,$clname;
	    print_footer(\*OUTFILE);
	    $count = 0;
	    $fileno++;
	    print_header(\*OUTFILE,"${wwwpath}/alphasort${fileno}.html","ACIS Field Images");
	    print OUTFILE $headmessage;
	}
	
    }
    
    # go through each cluster and make the table
    # break at $splitcount clusters so that file isn't huge

    push @lasts,$clname;
    print_footer(\*OUTFILE);
    

    $count = 1;
    $alphatable =  "<p><table><tr><th>Section</th><th align=left>From:</th>
<th align=left>To:</th><tr>\n";
    
    foreach $first (@firsts) {
	$last = shift @lasts;
	$alphatable .= "<tr><td><a href=\"alphasort$count.html\">Table 1.${count}</a></td><td>$first</td><td>$last</td></tr>\n";
	$count++;
    }
    $alphatable .= "</table>\n";
    
    return  $alphatable;


}


sub do_rasort {

    unlink <$wwwpath/rasort?.html>;
    unlink <$wwwpath/rasort??.html>;

    # print html file
    print_header(\*OUTFILE,"${wwwpath}/rasort1.html",
		 "Image of Clusters");
    print OUTFILE $headmessage;

    $count = 0;
    $truecount = 0;
    $fileno = 1;
    @firsts = ();
    @lasts = ();

    # make ra,dec,seqno sorted list of keys 
    foreach $key (keys %rasort) {
	@fields = split(/_/,$key);
	$primary{$key} = $fields[0];
	$secondary{$key} = $fields[1];
	$tertiary{$key} = $fields[2];
    }

    @sortedkeys = sort sortbyfields (keys %rasort);

    foreach $key (@sortedkeys) {
	
	@data = split(/_/,$key);
	$clname = $data[0];
	
	push @firsts,$clname if ($count == 0);
	
	# print out the table
	print OUTFILE $rasort{$key};
	
	# check the count
	$count++;
	$truecount++;
	if ($count == $splitcount) {
	    push @lasts,$clname;
	    print_footer(\*OUTFILE);
	    $count = 0;
	    $fileno++;
	    print_header(\*OUTFILE,"${wwwpath}/rasort${fileno}.html","ACIS Field Images");
	    print OUTFILE $headmessage;
	}
	
    }
    
    # go through each cluster and make the table
    # break at $splitcount clusters so that file isn't huge

    push @lasts,$clname;
    print_footer(\*OUTFILE);
    

    $count = 1;
    $ratable =  "<p><table><tr><th>Section</th><th align=left>From:</th>
<th align=left>To:</th><tr>\n";
    
    foreach $first (@firsts) {
	$last = shift @lasts;
	$ratable .= "<tr><td><a href=\"rasort$count.html\">Table 1.${count}</a></td><td align=right>$first</td><td align=right>$last</td></tr>\n";
	$count++;
    }
    $ratable .= "</table>\n";
    
    return  $ratable;


}

sub sortbyfields {
    
    ($primary{$a} <=> $primary{$b}) || 
	($secondary{$a} <=> $secondary{$b}) || 
	    ($tertiary{$a} <=> $tertiary{$b});
    
}


sub do_seqsort {

    unlink <$wwwpath/seqsort?.html>;
    unlink <$wwwpath/seqsort??.html>;

    # print html file
    print_header(\*OUTFILE,"${wwwpath}/seqsort1.html",
		 "Image of Clusters");
    print OUTFILE $headmessage;

    $count = 0;
    $truecount = 0;
    $fileno = 1;
    @firsts = ();
    @lasts = ();

    # make ra,dec,seqno sorted list of keys 
    foreach $key (keys %seqsort) {
	@fields = split(/_/,$key);
	$primary{$key} = $fields[0];
	$secondary{$key} = $fields[1];
	$tertiary{$key} = $fields[2];
    }

    @sortedkeys = sort sortbyfields (keys %seqsort);

    foreach $key (@sortedkeys) {
	
	@data = split(/_/,$key);
	$clname = $data[0];
	
	push @firsts,$clname if ($count == 0);
	
	# print out the table
	print OUTFILE $seqsort{$key};
	
	# check the count
	$count++;
	$truecount++;
	if ($count == $splitcount) {
	    push @lasts,$clname;
	    print_footer(\*OUTFILE);
	    $count = 0;
	    $fileno++;
	    print_header(\*OUTFILE,"${wwwpath}/seqsort${fileno}.html","ACIS Field Images");
	    print OUTFILE $headmessage;
	}
	
    }
    
    # go through each cluster and make the table
    # break at $splitcount clusters so that file isn't huge

    push @lasts,$clname;
    print_footer(\*OUTFILE);
    

    $count = 1;
    $ratable =  "<p><table><tr><th>Section</th><th align=left>From:</th>
<th align=left>To:</th><tr>\n";
    
    foreach $first (@firsts) {
	$last = shift @lasts;
	$ratable .= "<tr><td><a href=\"seqsort$count.html\">Table 1.${count}</a></td><td align=right>$first</td><td align=right>$last</td></tr>\n";
	$count++;
    }
    $ratable .= "</table>\n";
    
    return  $ratable;


}
