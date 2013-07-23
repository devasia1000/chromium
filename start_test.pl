#!/usr/bin/perl

$videolink=$ARGV[0];
print $videolink;

#Delete all Chromium cache files
`sudo rm -rfv ~/.cache/chromium/Default/Media\ Cache/*`;
`sudo rm -rfv ~/.cache/chromium/Default/Cache/*`;

#Delete all Google Chrome cache files - just to be safe
`sudo rm -rfv ~/.cache/google-chrome/Default/Media\ Cache/*`;
`sudo rm -rfv ~/.cache/google-chrome/Default/Cache/*`;

#Start Chromium
print `~/Desktop/src/out/Release/chrome ${videolink} | perl ~/Desktop/src/process.pl`;
