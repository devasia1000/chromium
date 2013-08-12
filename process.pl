#!/usr/bin/perl -w

# set this variable to '0' if you don't want real time graphs
$realTimeGraph=1;

sub generateLog1Filename;
sub generateLog2Filename;
sub generateLog3Filename;
sub generateLog4Filename;

$log1Filename=generateLog1Filename();
$log2Filename=generateLog2Filename();
$log3Filename=generateLog3Filename();
$log4Filename=generateLog4Filename();

$plotFrequency1=50;
$plotFrequency2=50;

open(LOG1, ">${log1Filename}");
$|=1;
open(LOG2, ">${log2Filename}");
$|=1;
open (LOG3, ">${log3Filename}");
$|=1;
open(LOG4, ">${log4Filename}");
$|=1;

#print $log1Filename, " ", $log2Filename, " ", $log3Filename, "\n";

$pid1=open(PLOT1, "| '/usr/bin/gnuplot' 2>&1 ");
$pid2=open(PLOT2, "| '/usr/bin/gnuplot' 2>&1 ");
$pid3=open(PLOT3, "| '/usr/bin/gnuplot' 2>&1 ");
$pid4=open(PLOT4, "| '/usr/bin/gnuplot' 2>&1 ");

while($line=<STDIN>){
 @sp=split(" ", $line);
 
if($sp[0] eq "#VideoResolution"){
  #print $sp[3], " ", $sp[1], "\n";
  print LOG1 $sp[3], " ", $sp[1], "\n";
  LOG1->autoflush(1);

if($realTimeGraph==1){
 if($plotFrequency1<0){
   syswrite(PLOT1, "plot \"${log1Filename}\" using 1:2 with line title \"${log1Filename}\"; set xlabel \"Time (ms)\"; set ylabel \"Video Resolution\"\n");
   $plotFrequency1=50
 }
$plotFrequency1=$plotFrequency1-1;
}
}

elsif($sp[0] eq "#Frame"){
  #print $sp[3], " ", $sp[1], "\n";
  print LOG2 $sp[3], " ", $sp[1], "\n";
  LOG2->autoflush(1);

if($realTimeGraph==1){
  if($plotFrequency2<0){
   syswrite(PLOT2, "plot \"${log2Filename}\" using 1:2 with line title \"${log2Filename}\"; set xlabel \"Time (ms)\"; set ylabel \"Frame Number\"\n");
   $plotFrequency2=50
  }
  $plotFrequency2=$plotFrequency2-1;
 }
}

elsif($sp[0] eq "#ForwardBuffer"){
 print LOG3 $sp[3], " ", $sp[1], "\n";
 LOG3->autoflush(1);
}

elsif($sp[0] eq "#Stall" || $sp[0] eq "#Loading"){
  print LOG4 $line;
  LOG4->autoflush(1);
 }

else{
  print $line;
 }
}


sub generateLog1Filename(){
 $i=0;
 $filename="~/log/videoResolution${i}.txt";
 while(-e $filename){
  $i=$i+1;
  $filename="~/log/videoResolution${i}.txt";
 }
 return $filename;
}

sub generateLog2Filename(){
 $i=0;
 $filename="~/log/frame${i}.txt"; 
 while(-e $filename){
  $i=$i+1;
  $filename="~/log/frame${i}.txt";
 }
 return $filename;
}

sub generateLog3Filename(){
 $i=0;
 $filename="~/log/forwardbuffered${i}.txt";
 while(-e $filename){
  $i=$i+1;
  $filename="~/log/forwardbuffered${i}.txt";
 }
 return $filename;
}

sub generateLog4Filename(){
 $i=0;
 $filename="~/log/chromium_report${i}.txt";
 while(-e $filename){
  $i=$i+1;
  $filename="~/log/chromium_report${i}.txt";
 }
 return $filename;
}

