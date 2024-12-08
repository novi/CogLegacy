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
#import <unistd.h>

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

//BOOL isOutputStream(AudioStreamID streamID)
//{
//    AudioObjectPropertyAddress address;
//    address.mScope = kAudioObjectPropertyScopeGlobal;
//    address.mElement = kAudioObjectPropertyElementMaster;
//    address.mSelector = kAudioStreamPropertyDirection;
//    
//    UInt32 direction;
//    UInt32 size = sizeof(direction);
//    OSStatus status = AudioObjectGetPropertyData(streamID, &address,
//                                                 0, NULL, &size, &direction);
//    if (status != noErr) return NO;
//    return direction == 0;
//}

AudioStreamRangedDescription* getAvailableFormats2(AudioStreamID streamID, BOOL isPhysical, size_t* count)
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = isPhysical ? kAudioStreamPropertyAvailablePhysicalFormats : kAudioStreamPropertyAvailableVirtualFormats;
    
    UInt32 outDataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(streamID, &address, 0, NULL, &outDataSize);
    if (status != noErr) {
        NSLog(@"%s, AudioObjectGetPropertyDataSize error %ld", __func__, status);
        return NULL;
    }
    
    AudioStreamRangedDescription* descriptions = malloc(outDataSize);
    status = AudioObjectGetPropertyData(streamID, &address,
                                        0, NULL, &outDataSize, descriptions);
    if (status != noErr) {
        free(descriptions);
        NSLog(@"%s, AudioObjectGetPropertyData error %ld", __func__, status);
        return NULL;
    }
    *count = outDataSize/sizeof(AudioStreamRangedDescription);
    return descriptions;
}

AudioStreamRangedDescription* getAvailableFormats(AudioStreamID streamID, BOOL isPhysical, size_t* count)
{
    AudioDevicePropertyID property = isPhysical ? kAudioStreamPropertyAvailablePhysicalFormats : kAudioStreamPropertyAvailableVirtualFormats;
    UInt32 outDataSize = 0;
    OSStatus status = AudioStreamGetPropertyInfo(streamID, 0, property, &outDataSize, NULL);
    if (status != noErr) {
        NSLog(@"%s, AudioStreamGetPropertyInfo error %ld", __func__, status);
        return NULL;
    }
    
    AudioStreamRangedDescription* descriptions = malloc(outDataSize);
    status = AudioStreamGetProperty(streamID, 0, property, &outDataSize, descriptions);
    if (status != noErr) {
        NSLog(@"%s, AudioStreamGetProperty error %ld", __func__, status);
        free(descriptions);
        return NULL;
    }
    *count = outDataSize/sizeof(AudioStreamRangedDescription);
    NSLog(@"getAvailableFormats count: %ld, is physical: %d", *count, isPhysical);
    return descriptions;
}

AudioStreamID* getAllOutputStreams(AudioDeviceID deviceID, size_t* count)
{    
    UInt32 outDataSize = 0;
    OSStatus status = AudioDeviceGetPropertyInfo(deviceID, 0, false, kAudioDevicePropertyStreams, &outDataSize, NULL);
    if (status != noErr) {
        NSLog(@"%s, AudioDeviceGetPropertyInfo error %ld", __func__, status);
        return NULL;
    }
    
    AudioStreamID* streams = malloc(outDataSize);
    status = AudioDeviceGetProperty(deviceID, 0, false, kAudioDevicePropertyStreams, &outDataSize, streams);
    if (status != noErr) {
        NSLog(@"%s, AudioDeviceGetProperty error %ld", __func__, status);
        free(streams);
        return NULL;
    }
    *count = outDataSize/sizeof(AudioStreamID);
    return streams;
}

//

@interface AvailableFormats : NSObject
{
@public;
    AudioStreamRangedDescription* descriptions;
    size_t count;
    BOOL isPhysical;
    AudioDeviceID deviceID;
}
@end



@implementation AvailableFormats

//- (id)initWithDevice:(AudioDeviceID)aDeviceID isPhysical:(BOOL)anIsPhysical
//{
//    self = [super init];
//    if (self) {
//        isPhysical = anIsPhysical;
//        deviceID = aDeviceID;
//    }
//    return self;
//}

@end

static NSMutableDictionary* availablePhysicalFormats; // key is device id
static NSMutableDictionary* availableVirtualFormats; // key is device id

AudioStreamRangedDescription* getAvailableFormatsForFirstOutput(AudioDeviceID deviceID, BOOL isPhysical, size_t* count)
{
    AvailableFormats* format;
    if (isPhysical) {
        format = [availablePhysicalFormats objectForKey:[NSNumber numberWithUnsignedLong:deviceID]];
    } else {
        format = [availableVirtualFormats objectForKey:[NSNumber numberWithUnsignedLong:deviceID]];
    }
    if (!format) return NULL;
    *count = format->count;
    return format->descriptions;
}

//

void saveAvailableFormatsForFirstOutput(AudioDeviceID deviceID, BOOL isPhysical)
{
    size_t streamCount = 0;
    AudioStreamID* streams = getAllOutputStreams(deviceID, &streamCount);
    if (streams == NULL) {
        return;
    }
    
    if (streamCount == 0) {
        return;
    }
    
    size_t count = 0;
    AudioStreamRangedDescription* descriptions = getAvailableFormats2(streams[0], isPhysical, &count);
    free(streams);
    
    AvailableFormats* format = [[[AvailableFormats alloc] init] autorelease];
    format->deviceID = deviceID;
    format->descriptions = descriptions;
    format->count = count;
    format->isPhysical = isPhysical;
    
    if (isPhysical) {
        if (!availablePhysicalFormats) {
            availablePhysicalFormats = [[NSMutableDictionary alloc] init];
        }
        [availablePhysicalFormats setObject:format forKey:[NSNumber numberWithUnsignedLong:deviceID]];
    } else {
        if (!availableVirtualFormats) {
            availableVirtualFormats = [[NSMutableDictionary alloc] init];
        }
        [availableVirtualFormats setObject:format forKey:[NSNumber numberWithUnsignedLong:deviceID]];
    }
    
    return;
}

BOOL setHogMode(AudioDeviceID deviceID)
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = kAudioDevicePropertyHogMode;
    
    UInt32 size = sizeof(pid_t);
    pid_t data = getpid();
    OSStatus status = AudioObjectSetPropertyData(deviceID, &address,
                                                 0, nil,
                                                 size, &data);
    
    if (status != noErr) {
        NSLog(@"set hog mode error %ld, for device %ld", status, deviceID);
        return NO;
    } else {
        
        status = AudioObjectGetPropertyData(deviceID, &address, 0, NULL, &size, &data);
        if (status != noErr) {
            NSLog(@"set hog mode error (2) %ld, for device %ld", status, deviceID);
            return NO;
        }
        BOOL isSuccess = data == getpid();
        if (isSuccess) {
            NSLog(@"set hog mode success for device %ld", deviceID);
        } else {
            NSLog(@"set hog mode error, current pid %d, got pid %d, for device %ld", getpid(), data, deviceID);
        }
        return isSuccess;
    }
}

BOOL unsetHogMode(AudioDeviceID deviceID)
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = kAudioDevicePropertyHogMode;
    
    UInt32 size = sizeof(pid_t);
    pid_t data = -1;
    OSStatus status = AudioObjectSetPropertyData(deviceID, &address,
                                                 0, nil,
                                                 size, &data);
    
    if (status != noErr) {
        NSLog(@"unset hog mode error %ld, for device %ld", status, deviceID);
        return NO;
    } else {
        
        status = AudioObjectGetPropertyData(deviceID, &address, 0, NULL, &size, &data);
        if (status != noErr) {
            NSLog(@"unset hog mode error (2) %ld, for device %ld", status, deviceID);
            return NO;
        }
        BOOL isSuccess = data == -1;
        if (isSuccess) {
            NSLog(@"unset hog mode success for device %ld", deviceID);
        } else {
            NSLog(@"unset hog mode error, current pid %d, got pid %d, for device %ld", getpid(), data, deviceID);
        }
        return isSuccess;
    }
}
//
//BOOL setHogModeAlt(BOOL hogMode, AudioDeviceID deviceID)
//{
//    UInt32 size = sizeof(pid_t);
//    pid_t data = -1;
//    OSStatus status = AudioDeviceSetProperty(deviceID, NULL, 0, false, kAudioDevicePropertyHogMode, size, &data);
//    
//    if (status != noErr) {
//        NSLog(@"set hog mode error %ld, for device %ld", status, deviceID);
//    } else {
//        pid_t newData = 0;
//        status = AudioDeviceGetProperty(deviceID, 0, false, kAudioDevicePropertyHogMode, &size, &newData);
//        NSLog(@"set hog mode success, new mode: %d, for device %ld, %d %d", hogMode, deviceID, data, newData);
//    }
//}
