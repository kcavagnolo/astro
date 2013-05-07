#! /usr//bin/perl -w

# make Latex cluster table for paper
%data = get_data($ARGV[0],0,1);
 

open(OUTFILE,">clustertable.tex") || die "Cannot open clustertable.tex\n";
print_header();

    foreach $key (sort keys %data) {
    
    @data   = split(" ",$data{$key});
	
    $name = $data[0];
    $name =~ s/\_/ /g;
  
    $line = join(" & ",$name,$data[1],$data[2],$data[2],$data[4],$data[5],$data[6]);
    print OUTFILE  $line,'\\\\',"\n";

}	

print_footer();


sub print_colhead {
    my ($line,$out);
    @out = @_;
    foreach $out (@out) {
	$out = '\colhead{' . $out . '}';
   }
    $line = join(' & ',@out);
    return $line;
}

sub print_header{

     $line0 = '\begin{deluxetable}{lrrrccc}';
     $line1 = print_colhead("Name", 'ObsID',' $\alpha$ ',' $\delta$ ','$R_{max}$ ',
			    'MinCts', '$z$ ');
    $line2 = print_colhead(" ","[deg.]","[deg.]",' [$\arcmin$] ',
			   " "," ");
    $line3 = print_colhead(map { '(' . $_ . ')'} (1..7));
   

    # print head for stat sample table
    print OUTFILE

	$line0,"\n",
#	'\rotate',"\n",
	'\tablewidth{0pt}',"\n",
	'\tabletypesize{\scriptsize}',"\n",
	'\tablecaption{Cluster Include in Entropy Library\label{tab:cluster}}',"\n",
	'\tablehead{',$line1,,'\\\\',"\n",$line2,'\\\\',"\n",$line3,'}',"\n",
	'\startdata',"\n";

}

sub print_footer {
    print OUTFILE
	'\enddata',"\n",
	'\end{deluxetable}',"\n";
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
