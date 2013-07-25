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

using namespace std;

//TODO: Make these variables private

//Variables for random seek
double numFramesRandomSeek;
bool seek;
bool alreadySeeked; /* we don't want chromium to seek twice */
double seekToLocation; /* where should chromium seek to? (in seconds) */

//Variables for stall detection
string previousMessage;
double previousMessageTime;

//Variables for timing
struct timespec start;
struct timespec frame;

//Variables for buffer detection
double fps;

//Variables for graph generation
int64_t decodedBytes;
int64_t bufferPos;
int64_t frame_count;

// variables for loading time
bool alreadyLoaded;

void Util::init(){
	alreadyLoaded=false;
	numFramesRandomSeek=200;
	seekToLocation=300; /* in seconds */
	seek=true;
	frame_count=0;
	previousMessage="";

	decodedBytes=0;
	bufferPos=0;

	clock_gettime(CLOCK_MONOTONIC_RAW, &start);
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

void Util::log(string message, int64_t value){
	clock_gettime(CLOCK_MONOTONIC_RAW, &frame);
	double time=timespecDiff(&frame, &start);
	cout<<"#"<<message<<" "<<value<<" at "<<time<<"\n";
}

double Util::returnFramesToRandomSeek(){
	return numFramesRandomSeek;
}

bool Util::randomSeek(){
	return seek;
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
	return seekToLocation;
}
