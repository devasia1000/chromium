/*
 * util.cc
 *
 *  Created on: Jun 18, 2013
 *      Author: devasia
 */

#include "util.h"

using namespace std;

//TODO: Make these variables private
struct timespec start, frame;
bool loading=false;

//These variables are user editable
double numFramesRandomSeek=100;
bool seek=false;

void Util::init(){
	clock_gettime(CLOCK_MONOTONIC_RAW, &start);
}

void Util::log(string message){
	clock_gettime(CLOCK_MONOTONIC_RAW, &frame);
	double time=timespecDiff(&frame, &start);
	//TODO: Write to file instead of 'cout'
	cout<<"#"<<message<<" at "<<time<<"\n";
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
