/*
 * util.cc
 *
 *  Created on: Jun 18, 2013
 *      Author: devasia
 */

#include <string.h>
#include <iostream>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fstream>
#include "util.h"
#include "../../media/base/seekable_buffer.h"
#include "variables.h"

using namespace std;

//Variables for auto seek
bool alreadySeeked; /* we don't want chromium to seek twice */

//Variables for stall detection - don't modify or touch these variables
string previousMessage;
double previousMessageTime;

//Variables for timing
struct timespec start;
struct timespec frame;

//Variables for buffer detection
double fps; /* frames per second of the video */

//Variables for graph generation
int64_t decodedBytes; /* number of video bytes decoded */
int64_t bufferPos; /* position of the buffer */
int64_t frame_count; /* number of frames played since the start of the video */

// variables for loading time
bool alreadyLoaded; /* sometimes the loading function is called twice
 	 	 	 	 	 this ensures we only log the first call */

bool alreadyInit=false; /* sometimes the Util::init()is called twice,
 	 	 	 	 	 	 this ensures we only log the first call */

void Util::init(){
	if(alreadyInit==false){
		alreadyInit=true;
		alreadyLoaded=false;
		frame_count=0;
		previousMessage="";
		decodedBytes=0;
		bufferPos=0;
		clock_gettime(CLOCK_MONOTONIC_RAW, &start);
	}
}

void Util::log(string message){

	if(strcmp("Loading", message.c_str())==0 && alreadyLoaded==false){

		clock_gettime(CLOCK_MONOTONIC_RAW, &frame);
		double time=timespecDiff(&frame, &start);

		previousMessage="Loading";
		previousMessageTime=time;

		alreadyLoaded=true;
	}

	else if((strcmp("Loading", previousMessage.c_str())==0) && (strcmp("FrameReady", message.c_str())==0)){

		clock_gettime(CLOCK_MONOTONIC_RAW, &frame);
		double time=timespecDiff(&frame, &start);

		cout<<"#Loading Time: "<<time-previousMessageTime<<" ms\n";
		cout.flush();

		previousMessage="FrameReady";
		previousMessageTime=time;
		frame_count++;
	}

	else if((strcmp("FrameReady", previousMessage.c_str())==0) && (strcmp("FrameReady", message.c_str()))==0){
		clock_gettime(CLOCK_MONOTONIC_RAW, &frame);
		double time=timespecDiff(&frame, &start);

		double stall=time-previousMessageTime;

		if(stall>60){
			cout<<"#Stall of "<<stall<<" ms detected between Frame "<<frame_count<<" and "<<frame_count+1<<"\n";
			cout.flush();
		}

		previousMessage="FrameReady";
		previousMessageTime=time;

		frame_count++;
	}

	else{
		clock_gettime(CLOCK_MONOTONIC_RAW, &frame);
		double time=timespecDiff(&frame, &start);

		cout<<"#"<<message<<" at "<<time<<"\n";
	}
}

void Util::logWithoutTimestamp(string str){
	cout<<str<<"\n";
}

void Util::logWithoutTimestamp(double d){
	cout<<d<<"\n";
}

void Util::log(string message, int64_t value){
	clock_gettime(CLOCK_MONOTONIC_RAW, &frame);
	double time=timespecDiff(&frame, &start);
	cout<<"#"<<message<<" "<<value<<" at "<<time<<"\n";
}

double Util::returnFramesToSeek(){
	return Variables::getNumberFramesSeek();
}

bool Util::randomSeek(){
	return Variables::getRandomSeek();
}

//This is a private function of the class
double Util::timespecDiff(struct timespec *timeA_p, struct timespec *timeB_p){
	int64_t nano = ((timeA_p->tv_sec * 1000000000) + timeA_p->tv_nsec) -
           ((timeB_p->tv_sec * 1000000000) + timeB_p->tv_nsec);
	double d = static_cast<double>(nano);
	d=d/1000000; //Convert to milliseconds
	return d;
}

 bool Util::returnAlreadySeeked(){
	 return alreadySeeked;
 }

void Util::setAlreadySeeked(bool s){
	alreadySeeked=s;
}

double Util::returnSeekToLocation(){
	return Variables::getSeekToLocation();
}
