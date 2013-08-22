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
	static void init(); /* initialize the class, must be called before using the logger */
	static void log(string message); /* log loading times and stall times */
	static void log(string message, int64_t value); /* log a string and a value with a timestamp */
	static double returnFramesToSeek(); /* return the number of frames before starting random seek */
	static bool randomSeek(); /* getter function for seek data member */
	static double timespecDiff(struct timespec *timeA_p, struct timespec *timeB_p); /* returnd the difference
	 	 	 	 	 	 	 	 	 	 	 	 	 	 	 	 	 	 	 	 	 	 between two timespecs */
	static bool returnAlreadySeeked(); /* getter function for alreadySeeked */
	static void setAlreadySeeked(bool s); /* setter function for alreadySeeked */
	static double returnSeekToLocation(); /* getter function for numFramesToRandomSeek */
	static void logWithoutTimestamp(string str); /* log a string without a timestamp */
	static void logWithoutTimestamp(double d); /* log a double without a timestamp */
        static void logWithoutTimestamp(string str, double d);
};

#endif /* UTIL_H_ */
