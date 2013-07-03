#!/usr/bin/perl -w

sub generateDecodedFileName;
sub generateTotalBufferedFileName;
sub generateForwardBufferFileName;
sub generateStallFileName;

$decodedFilename=generateDecodedFileName();
$totalbufferedFilename=generateTotalBufferedFileName();
$forwardbufferedFilename=generateForwardBufferedFileName();
$stallFilename=generateStallFileName();

open(DECODED, ">${decodedFilename}");
$|=1;
open(BUFFERED, ">${totalbufferedFilename}");
$|=1;
open (STALLED, ">${stallFilename}");
$|=1;
open(FORWARDBUFFERED, ">${forwardbufferedFilename}");
$|=1;

print $decodedFilename, " ", $totalbufferedFilename, " ", $forwardbufferedFilename, "\n";

while($line=<STDIN>){
 @sp=split(" ", $line);
 
if($sp[0] eq "#VideoResolution"){
  #print $sp[3], " ", $sp[1], "\n";
  print DECODED $sp[3], " ", $sp[1], "\n";
  DECODED->autoflush(1);
 }

elsif($sp[0] eq "#PlayTime"){
  #print $sp[3], " ", $sp[1], "\n";
  print BUFFERED $sp[3], " ", $sp[1], "\n";
  BUFFERED->autoflush(1);
 }

elsif($sp[0] eq "#ForwardBuffer"){
 print FORWARDBUFFERED $sp[3], " ", $sp[1], "\n";
 FORWARDBUFFERED->autoflush(1);
}

elsif($sp[0] eq "#Stall" || $sp[0] eq "#Loading"){
  print STALLED $line;
  STALLED->autoflush(1);
 }

else{
  print $line;
 }
}


sub generateDecodedFileName(){
 $i=0;
 $filename="/home/devasia/Desktop/log/decoded${i}.txt";
 while(-e $filename){
  $i=$i+1;
  $filename="/home/devasia/Desktop/log/decoded${i}.txt";
 }
 return $filename;
}

sub generateTotalBufferedFileName(){
 $i=0;
 $filename="/home/devasia/Desktop/log/totalbuffered${i}.txt"; 
 while(-e $filename){
  $i=$i+1;
  $filename="/home/devasia/Desktop/log/totalbuffered${i}.txt";
 }
 return $filename;
}

sub generateForwardBufferedFileName(){
 $i=0;
 $filename="/home/devasia/Desktop/log/forwardbuffered${i}.txt";
 while(-e $filename){
  $i=$i+1;
  $filename="/home/devasia/Desktop/log/forwardbuffered${i}.txt";
 }
 return $filename;
}

sub generateStallFileName(){
 $i=0;
 $filename="/home/devasia/Desktop/log/chromium_report${i}.txt";
 while(-e $filename){
  $i=$i+1;
  $filename="/home/devasia/Desktop/log/chromium_report${i}.txt";
 }
 return $filename;
}

