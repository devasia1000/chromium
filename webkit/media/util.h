/*
 * util.h
 *
 *  Created on: Jun 18, 2013
 *      Author: devasia
 */

#ifndef UTIL_H_
#define UTIL_H_

#include <string>
#include <iostream>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fstream>
#include <sstream>

using namespace std;

class Util {

public:
	static void init();
	static void log(string message);
	static void log(string message, int64_t value);
	static double returnFramesToRandomSeek();
	static bool randomSeek();
	static double timespecDiff(struct timespec *timeA_p, struct timespec *timeB_p);
	static bool returnAlreadySeeked();
	static void setAlreadySeeked(bool s);
	static double returnSeekToLocation();
};

#endif /* UTIL_H_ */
