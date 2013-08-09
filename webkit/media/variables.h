/*
 * variables.h
 *
 *  Created on: Aug 09, 2013
 *      Author: devasia
 */

#ifndef VARIABLES_H_
#define VARIABLES_H_

class Variables{

private:
	/* All private variables are user-editable */

	static const bool seek=false; /* If 'seek' is set to 'true', player will seek to 'seekToLocation' seconds
									after playing 'numFramesSeek' frames.
									If 'seek' is set to false, player plays video normally */

	static const int numFramesSeek=50; /* seeks to frame number 'numFrame' if 'seek' if set to true
									If 'seek' is set to false, has no effect. */

	static const int seekToLocation=500; /* If seek is 'true', player will seek to 'seekToLocation' seconds
										after playing 'numFramesSeek' frames. If 'seek' is false, has no effect */

public:

	static bool getRandomSeek();
	static int getNumberFramesSeek();
	static int getSeekToLocation();
};

#endif /* VARIABLES_H_ */
