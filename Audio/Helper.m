/*
 *  Helper.c
 *  CogAudio
 *
 *  Created by Andre Reffhaug on 2/17/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#include <math.h>
#include "Helper.h"

//These functions are helpers for the process of converting volume from a linear to logarithmic scale.
//Numbers that goes in to audioPlayer should be logarithmic. Numbers that are displayed to the user should be linear.
//Here's why: http://www.dr-lex.34sp.com/info-stuff/volumecontrols.html
//We are using the approximation of X^4.
//Input/Output values are in percents.
double logarithmicToLinear(double logarithmic)
{
	return pow((logarithmic/MAX_VOLUME), 0.25) * 100.0;
}

double linearToLogarithmic(double linear)
{
	return (linear/100.0) * (linear/100.0) * (linear/100.0) * (linear/100.0) * MAX_VOLUME;
}
//End helper volume function thingies. ONWARDS TO GLORY!



AudioDeviceID getCurrentOutputDevice()
{
    NSDictionary *device = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"outputDevice"];
	if (device) {
        AudioDeviceID deviceID = [[device objectForKey:@"deviceID"] longValue];
        return deviceID;
    }
    return 0;
}

BOOL isOutputStream(AudioStreamID streamID)
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = kAudioStreamPropertyDirection;
    
    UInt32 direction;
    UInt32 size = sizeof(direction);
    OSStatus status = AudioObjectGetPropertyData(streamID, &address,
                                                 0, NULL, &size, &direction);
    if (status != noErr) return NO;
    return direction == 0;
}

AudioStreamRangedDescription* getAvailableFormats(AudioStreamID streamID, BOOL isPhysical, size_t* count)
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = isPhysical ? kAudioStreamPropertyAvailablePhysicalFormats : kAudioStreamPropertyAvailableVirtualFormats;
    
    UInt32 outDataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(streamID, &address, 0, NULL, &outDataSize);
    if (status != noErr) return NULL;
    
    AudioStreamRangedDescription* descriptions = malloc(sizeof(AudioStreamRangedDescription) * outDataSize);
    status = AudioObjectGetPropertyData(streamID, &address,
                                        0, NULL, &outDataSize, descriptions);
    if (status != noErr) {
        free(descriptions);
        return NULL;
    }
    *count = outDataSize/sizeof(AudioStreamRangedDescription);
    return descriptions;
}

AudioStreamID* getAllStreams(AudioDeviceID deviceID, size_t* count)
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = kAudioDevicePropertyStreams;
    
    UInt32 outDataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, NULL, &outDataSize);
    if (status != noErr) return NULL;
    
    AudioStreamID* streams = malloc(sizeof(AudioStreamID) * outDataSize);
    status = AudioObjectGetPropertyData(deviceID, &address,
                                        0, NULL, &outDataSize, streams);
    if (status != noErr) {
        free(streams);
        return NULL;
    }
    *count = outDataSize/sizeof(AudioStreamID);
    return streams;
}

AudioStreamRangedDescription* getAvailableFormatsForFirstOutput(AudioDeviceID deviceID, BOOL isPhysical, size_t* count)
{
    size_t streamCount = 0;
    AudioStreamID* streams = getAllStreams(deviceID, &streamCount);
    if (streams == NULL) {
        return NULL;
    }
    
    size_t i;
    for (i = 0; i < streamCount; i++) {
        if (isOutputStream(streams[i])) {
            AudioStreamRangedDescription* descriptions = getAvailableFormats(streams[i], isPhysical, count);
            free(streams);
            return descriptions;
        }
    }
    free(streams);
    return NULL;
}
