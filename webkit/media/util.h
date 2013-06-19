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

using namespace std;

class Util{

private:
	static double timespecDiff(struct timespec *timeA_p, struct timespec *timeB_p);

public:
	static void init();
	static void log(string message);
	static double returnFramesToRandomSeek();
	static bool randomSeek();
};

#endif /* UTIL_H_ */
