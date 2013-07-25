#!/usr/bin/perl

$videolink=$ARGV[0];
print $videolink;

for($i=0;$i<100;$i++){
#Delete all Chromium cache files
`sudo rm -rfv ~/.cache/chromium/Default/Media\ Cache/*`;
`sudo rm -rfv ~/.cache/chromium/Default/Cache/*`;

#Delete all Google Chrome cache files - just to be safe
`sudo rm -rfv ~/.cache/google-chrome/Default/Media\ Cache/*`;
`sudo rm -rfv ~/.cache/google-chrome/Default/Cache/*`;

#Start Chromium
system("~/Desktop/src/out/Release/chrome ${videolink} &");
# wait for video to play a while
sleep(25);
#send SIGTERM to chromium
print `sudo killall chrome`;
}
