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

// return value must be freed
AudioStreamID* getAllOutputStreams(AudioDeviceID deviceID, size_t* count);
AudioStreamRangedDescription* getAvailableFormats(AudioStreamID streamID, BOOL isPhysical, size_t* count);
AudioStreamRangedDescription* getAvailableFormatsForFirstOutput(AudioDeviceID deviceID, BOOL isPhysical, size_t* count);


AudioStreamRangedDescription* getAvailableFormats2(AudioStreamID streamID, BOOL isPhysical, size_t* count);

//AudioStreamRangedDescription* getAvailablePhysicalFormatsForFirstOutput(AudioDeviceID deviceID, size_t* count);
void saveAvailableFormatsForFirstOutput(AudioDeviceID deviceID, BOOL isPhysical);

BOOL setHogMode(AudioDeviceID deviceID);
BOOL unsetHogMode(AudioDeviceID deviceID);

@protocol DirectModeDecoder <NSObject>

- (void)setAvailableVirtualFormats:(AudioStreamRangedDescription*)descriptions descriptionCount:(size_t)count;
-(NSValue*)outputFormatForDirectMode;

@end