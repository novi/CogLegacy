//
// Created by Dmitry Promsky on 04/06/14.
//
//


#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import "VirtualRingBuffer.h"
#import "Plugin.h"

@protocol InputDelegate;

@interface Input : NSObject
{
    id<CogDecoder> decoder;
    VirtualRingBuffer* buffer;
    AudioStreamBasicDescription* format;
    AudioChannelLayout* channelLayout;

    NSCondition* pauseCond;
    BOOL paused;
}

@property BOOL shouldContinue;
@property long seekFrame;
@property BOOL eofReached;
@property BOOL ready;
@property id<InputDelegate> player;

- (BOOL) openUrl:(NSURL *) url;
- (const AudioStreamBasicDescription *)format;
- (const AudioChannelLayout *)channelLayout;
- (void) run:(NSURL *) url;
- (void) startWithUrl:(NSURL *)url player:(id<InputDelegate>)p;
- (void) stop;
- (void) pause;
- (void) unpause;
- (VirtualRingBuffer *)buffer;
@end