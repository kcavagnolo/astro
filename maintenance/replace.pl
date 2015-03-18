#! /usr/bin/perl -w
# perl replace.pl <replacements> <file1> <output>

$byname = "no";
$doapp = "yes";

open(A,"$ARGV[0]");
while(<A>){
  chomp;
  next if (/^\#/);
  next if (/^$/);
  @line=split;
  if ($byname eq "yes") {
      $get = $line[0];
  } else {
      $get = $line[1];
  }
  $ref{$get} = $_;
}
close A;

open(B,"$ARGV[1]");
open(C,">$ARGV[2]");
while(<B>){
  chomp;
  @line = split;
  if ($byname eq "yes") {
      $get = $line[0];
  } else {
      $get = $line[1];
  }
  if (/^\#/) {
    if (exists $ref{$get}) {
      print "## Replacing $line[0] ; $line[1] **COMMENTED OUT**\n";
      print C "#"."$ref{$get}\n";
      $replace++;
      next;
    } else {
      print C "$_\n";
      next;
    }
  }
  if (exists $ref{$get}) {
    print "## Replacing $line[0] $line[1]\n";
    print C "$ref{$get}\n";
    $replace++;
    next;
  } else {
    print C "$_\n";
    next;
  }
}
close B;
close C;
print "## $replace replacements performed on $ARGV[1] into $ARGV[2]\n";

$append = 0;
if ($doapp eq "yes") {
  undef %ref;
  open(A,"$ARGV[2]");
  while(<A>){
    chomp;
    next if (/^\#/);
    next if (/^$/);
    @line=split;
    if ($byname eq "yes") {
      $get = $line[0];
    } else {
      $get = $line[1];
    }
    $ref{$get} = $_;
  }
  close A;

  open(B,"$ARGV[0]");
  open(C,">>$ARGV[2]");
  while(<B>){
    chomp;
    @line = split;
    next if (/^\#/);
    next if (/^$/);
    if ($byname eq "yes") {
      $get = $line[0];
    } else {
      $get = $line[1];
    }
    next if (exists $ref{$get});
    print "## $line[0] $line[1] not present, ammending...\n";
    print C "$_\n";
    $append++;
  }
  close B;
  close C;
  print "## $append ammendments performed on $ARGV[2]\n";
}

