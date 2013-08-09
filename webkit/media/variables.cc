
/*
 * variables.cc
 *
 *  Created on: Aug 09, 2013
 *      Author: devasia
 */

#include "variables.h"

bool Variables::getRandomSeek(){
	return seek;
}

int Variables::getNumberFramesSeek(){
	return numFramesSeek;
}

int Variables::getSeekToLocation(){
	return seekToLocation;
}
