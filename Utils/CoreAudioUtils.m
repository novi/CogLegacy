//
//  CoreAudioUtils.m
//  Cog
//
//  Created by ito on 12/6/24.
//
//

#import "CoreAudioUtils.h"
#import <CoreAudio/AudioHardware.h>
#import "CogAudio/AudioPlayer.h"
#import "CogAudio/Helper.h"

@implementation CoreAudioUtils

+ (void)printStreamAvailableFormats:(AudioStreamID)streamID isPhysical:(BOOL)isPhysical
{
    size_t count = 0;
    AudioStreamRangedDescription* descriptions = getAvailableFormats(streamID, isPhysical, &count);
    if (descriptions == NULL) {
        return;
    }
    size_t i;
    for (i = 0; i < count; i++) {
        AudioStreamRangedDescription desc = descriptions[i];
        PrintStreamDesc(&desc.mFormat);        
    }
    free(descriptions);
    
}


+ (NSString*)getDeviceName:(AudioDeviceID)deviceID
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = kAudioDevicePropertyDeviceNameCFString;
    
    CFStringRef name = NULL;
    UInt32 size = sizeof(name);
    OSStatus status = AudioObjectGetPropertyData(deviceID, &address,
                                        0, NULL, &size, &name);
    if (status != noErr) return nil;
    return [(NSString*)name autorelease];
}

+ (void)printAllAudioOutput:(AudioDeviceID)deviceID
{
    size_t count = 0;
    AudioStreamID* streams = getAllStreams(deviceID, &count);
    if (streams == NULL) {
        return;
    }
    
    size_t i;
    for (i = 0; i < count; i++) {
        if (isOutputStream(streams[i])) {
            NSLog(@"    Physical Format:");
            [self printStreamAvailableFormats:streams[i] isPhysical:YES];
            NSLog(@"    Virtual Format:");
            [self printStreamAvailableFormats:streams[i] isPhysical:NO];
        }
    }
    free(streams);
}


+(void)printAllAudioDevices
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = kAudioHardwarePropertyDevices;
    
    AudioObjectID systemObject = kAudioObjectSystemObject;
    UInt32 outDataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(systemObject, &address, 0, NULL, &outDataSize);
    if (status != noErr) return;
    
    AudioDeviceID* devices = malloc(sizeof(AudioDeviceID) * outDataSize);
    status = AudioObjectGetPropertyData(systemObject, &address,
                                        0, NULL, &outDataSize, devices);
    if (status != noErr) {
        free(devices);
        return;
    }
    
    size_t i;
    for (i = 0; i < outDataSize/sizeof(AudioDeviceID); i++) {
        NSLog(@"(ID:%ld) %@:", devices[i], [self getDeviceName:devices[i]]);
        [self printAllAudioOutput:devices[i]];
    }
    free(devices);
}



@end
