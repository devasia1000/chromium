#!/bin/sh

#These variables are user-editable
bandwidth=2500
delay=50

#Load 'dummynet' kernel module
sudo insmod ./ipfw3-2012/kipfw-mod/ipfw_mod.ko

#Undo bandwidth throttling from last run
echo "y" | sudo ./ipfw3-2012/ipfw/ipfw flush

#Start bandwidth throttling
sudo ./ipfw3-2012/ipfw/ipfw add pipe 2 in proto tcp
sudo ./ipfw3-2012/ipfw/ipfw pipe 2 config bw ${bandwidth}Kbit/s delay ${delay}ms

#Delete all Chromium cache files
sudo rm -rfv ~/.cache/chromium/Default/Media\ Cache/*
sudo rm -rfv ~/.cache/chromium/Default/Cache/*

#Delete all Google Chrome cache files - just to be safe
sudo rm -rfv ~/.cache/google-chrome/Default/Media\ Cache/*
sudo rm -rfv ~/.cache/google-chrome/Default/Cache/*

#Start chromium video
./out/Release/chrome http://skype-alpha.csail.mit.edu/start.html | tee ~/Desktop/src/chromium.txt &
#Wait for video to play a while
sleep 1800
#Kill chromium
sudo killall chrome

#Start ChromiumPostProcessor
java -jar ChromiumPostProcessor/dist/ChromiumPostProcessor.jar $bandwidth $delay

#Undo bandwidth throttling
echo "y" | sudo ./ipfw3-2012/ipfw/ipfw flush
