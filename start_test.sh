#!/bin/sh

#These variables are user-editable
bandwidth=350 #in kilobits per second
iterations=100
videoPlayTime=300 #in seconds

#These variables are NOT user-editable
i=0

while [ $i -lt $iterations ]; do

	#Delete all Chromium cache files
	sudo rm -rfv ~/.cache/chromium/Default/Media\ Cache/*
	sudo rm -rfv ~/.cache/chromium/Default/Cache/*

	#Delete all Google Chrome cache files - just to be safe
	sudo rm -rfv ~/.cache/google-chrome/Default/Media\ Cache/*
	sudo rm -rfv ~/.cache/google-chrome/Default/Cache/*
	
	#Start bandwidth throttling and start Chromium
	trickle -d $bandwidth -u 10000 ./out/Release/chrome http://127.0.0.1/start.html | tee chromium.txt

	#Wait for video to play a while
	sleep $videoPlayTime
	#Kill chromium
	sudo killall chrome

	#Kill bandwidth throttling process
	sudo killall trickle
	sudo killall trickled

	#Start ChromiumPostProcessor
	java -jar ChromiumPostProcessor/dist/ChromiumPostProcessor.jar $bandwidth $delay

	#Increment counter 
	let i=i+1

done
