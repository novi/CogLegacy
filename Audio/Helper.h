/*
 *  Helper.h
 *  CogAudio
 *
 *  Created by Andre Reffhaug on 2/17/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>
#import <CoreAudio/AudioHardware.h>


#define MAX_VOLUME 400.0

double logarithmicToLinear(double logarithmic);
double linearToLogarithmic(double linear);


AudioDeviceID getCurrentOutputDevice();
BOOL isOutputStream(AudioStreamID streamID);

// return value must be freed
AudioStreamID* getAllStreams(AudioDeviceID deviceID, size_t* count);
AudioStreamRangedDescription* getAvailableFormats(AudioStreamID streamID, BOOL isPhysical, size_t* count);
AudioStreamRangedDescription* getAvailableFormatsForFirstOutput(AudioDeviceID deviceID, BOOL isPhysical, size_t* count);
