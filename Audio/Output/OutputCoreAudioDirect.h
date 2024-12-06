//
//  OutputCoreAudioDirect.h
//  CogAudio
//
//  Created by ito on 12/6/24.
//
//

#import <Foundation/Foundation.h>
#import <CoreAudio/AudioHardware.h>


@class OutputNode;

@interface OutputCoreAudioDirect : NSObject
{
    OutputNode * outputController;
    AudioDeviceID outputDevice;
    
    AudioStreamBasicDescription deviceFormat;
    BOOL isRunning;
    BOOL isPaused;
}

- (OutputCoreAudioDirect*)initWithController:(OutputNode *)c;

- (BOOL)setupWithInputFormat:(AudioStreamBasicDescription)f;
- (BOOL)setup;
- (BOOL)setOutputDevice:(AudioDeviceID)outputDevice;
- (void)start;
- (void)pause;
- (void)resume;
- (void)stop;

- (void)setVolume:(double) v;


@end
