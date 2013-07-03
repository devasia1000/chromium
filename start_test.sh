#!/bin/sh

#These variables are user-editable

iterations=100
videoPlayTime=30 #in seconds

#These variables are NOT user-editable
i=0

	#Delete all Chromium cache files
	sudo rm -rfv ~/.cache/chromium/Default/Media\ Cache/*
	sudo rm -rfv ~/.cache/chromium/Default/Cache/*

	#Delete all Google Chrome cache files - just to be safe
	sudo rm -rfv ~/.cache/google-chrome/Default/Media\ Cache/*
	sudo rm -rfv ~/.cache/google-chrome/Default/Cache/*

	#Start Chromium
	trickle -d 300 -u 1000 ~/Desktop/src/out/Release/chrome http://dash-mse-test.appspot.com/dash-player.html 

	#Wait for video to play a while
        sleep $videoPlayTime
	
	let i=i+1;
