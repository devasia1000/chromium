#!/usr/bin/perl -w

sub generateLog1Filename;
sub generateLog2Filename;
sub generateLog3Filename;
sub generateLog4Filename;

$log1Filename=generateLog1Filename();
$log2Filename=generateLog2Filename();
$log3Filename=generateLog3Filename();
$log4Filename=generateLog4Filename();

open(LOG1, ">${log1Filename}");
$|=1;
open(LOG2, ">${log2Filename}");
$|=1;
open (LOG3, ">${log3Filename}");
$|=1;
open(LOG4, ">${log4Filename}");
$|=1;

print $log1Filename, " ", $log2Filename, " ", $log3Filename, "\n";

while($line=<STDIN>){
 @sp=split(" ", $line);
 
if($sp[0] eq "#VideoResolution"){
  print $sp[3], " ", $sp[1], "\n";
  print LOG1 $sp[3], " ", $sp[1], "\n";
  LOG1->autoflush(1);
 }

elsif($sp[0] eq "#Frame"){
  print $sp[3], " ", $sp[1], "\n";
  print LOG2 $sp[3], " ", $sp[1], "\n";
  LOG2->autoflush(1);
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
 $filename="/home/devasia/Desktop/log/videoResolution${i}.txt";
 while(-e $filename){
  $i=$i+1;
  $filename="/home/devasia/Desktop/log/videoResolution${i}.txt";
 }
 return $filename;
}

sub generateLog2Filename(){
 $i=0;
 $filename="/home/devasia/Desktop/log/frame${i}.txt"; 
 while(-e $filename){
  $i=$i+1;
  $filename="/home/devasia/Desktop/log/frame${i}.txt";
 }
 return $filename;
}

sub generateLog3Filename(){
 $i=0;
 $filename="/home/devasia/Desktop/log/forwardbuffered${i}.txt";
 while(-e $filename){
  $i=$i+1;
  $filename="/home/devasia/Desktop/log/forwardbuffered${i}.txt";
 }
 return $filename;
}

sub generateLog4Filename(){
 $i=0;
 $filename="/home/devasia/Desktop/log/chromium_report${i}.txt";
 while(-e $filename){
  $i=$i+1;
  $filename="/home/devasia/Desktop/log/chromium_report${i}.txt";
 }
 return $filename;
}

