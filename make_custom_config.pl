#! /usr/bin/perl -w
open(A,"../me_info/ref_loc.list");
open(B,">out");
printf B "%-25s %6s %8s %6s %6s %6s %8s %6s %6s %6s %5s %5s %10s %10s %10s %5s %10s\n",
  "#Name","ObsID","z","NH20","Tx","Fe","E_obs","nhmod","model","stat","NHfro","Fefro","apert","source","bkgrnd","local","location";
while(<A>){
  chomp;
  next if (/^\#/);
  @a = split;
  printf B "%-25s %6s %8.4f %6.2f %6.2f %6.2f %8.4f %6s %6s %6s %5s %5s %10s %10s %10s %5s %10s\n",
    $a[0],$a[1],$a[6],$a[7],$a[8],$a[9],$a[12],"wabs","mekal","cash","yes","yes","inner50","src1_grp","bgd_adj","no",$a[15];
}
close A;
close B;
