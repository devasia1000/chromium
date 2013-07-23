#!/usr/bin/perl

$videolink=$ARGV[0];

#Delete all Chromium cache files
print `sudo rm -rfv ~/.cache/chromium/Default/Media\ Cache/*`;
print `sudo rm -rfv ~/.cache/chromium/Default/Cache/*`;

#Delete all Google Chrome cache files - just to be safe
print `sudo rm -rfv ~/.cache/google-chrome/Default/Media\ Cache/*`;
print `sudo rm -rfv ~/.cache/google-chrome/Default/Cache/*`;

#Start Chromium
print `~/Desktop/src/out/Release/chrome ${videolink} | perl process.pl`;
