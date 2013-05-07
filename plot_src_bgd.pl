#! /usr/bin/perl -w
use Cwd;
$Bin = cwd();
use IPC::Open3;
while (<>) {
  chomp;
  next if (/^\#/); # skip comment lines
  next if (/^$/);  # skip blank lines
  s/^\s+//;        # trim leading whitespace
  s/\s+$//;        # trim trailing whitespace
  @data = split;
  $name = join "_", $data[0],$data[1];
  $ref{$name} = $_;
}
$num=0;
{
  foreach $key (sort keys %ref) {
    @data = split(/\s+/,$ref{$key});
    $name = $data[0];
    $obsid = $data[1];
    $src = "${obsid}_addex_src_grp.pi";
    $bgd = "${obsid}_addex_bgd_grp_adj.pi";
    $dir = "/Volumes/MBRANE/${obsid}/reprocessed" if ($data[15] eq "MBRANE");
    $dir = "../acis/${obsid}/reprocessed" if ($data[15] eq "NAZGUL");;
    chdir("$dir");
    unless (-e $src && -e $bgd) {
      print "No $src or $bgd\n";
      chdir("$Bin");
      next;
    }
    open(XCM,">temp.xcm");
    print XCM "query yes\n";
    print XCM "data 1:1 $src\n";
    print XCM "data 2:2 $bgd\n";
    print XCM "response 1:1 ${name}_${obsid}_r2500_src1.wrmf\n";
    print XCM "response 2:2 ${name}_${obsid}_r2500_src1.wrmf\n";
    print XCM "setplot energy\n";
    print XCM "ignore bad\n";
    print XCM "ignore 1-2:**-0.2 12.0-**\n";
    close XCM;
    $pid = open3(*XSPEC_INPUT,*XSPEC_OUTPUT,*XSPEC_ERR,"xspec11") || die "Can't run xspec\n";
    print XSPEC_INPUT "\@temp.xcm\n";
    print XSPEC_INPUT "query no\n";
    while (<XSPEC_OUTPUT>) {
      chomp($xout = $_);
      print "xspec: $xout\n";
      print XSPEC_INPUT "iplot ldata\n";
      print XSPEC_INPUT "label top ${name} ${obsid}\n";
      print XSPEC_INPUT "time off\n";
      print XSPEC_INPUT "cpd temp_${num}.ps/cps\n";
      print XSPEC_INPUT "plot\n";
      print XSPEC_INPUT "cpd /null\n";
      print XSPEC_INPUT "exit\n\n";
      print XSPEC_INPUT "exit\n\n";
    }
    close XSPEC_INPUT;
    close XSPEC_OUTPUT;
    close XSPEC_ERR;
    waitpid($pid,0);
    system("mv -f temp_${num}.ps $Bin/../temp/");
    unlink("temp.xcm");
    $num++;
    chdir("$Bin");
  }
}
#chdir("../temp");
#system("ls -1ct > list");
#system("cat list | perl pscat.pl 6 all.ps");
#unlink("list");
#unlink(temp*.ps);
#chdir("$Bin");
