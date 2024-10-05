//
// Created by Dmitry Promsky on 03/06/14.
//
//


#import <Foundation/Foundation.h>
#import "Input.h"
#import "Output.h"

AudioChannelLayout* fillChannelLayout(AudioChannelLayout* pLayout);

@protocol AudioPlayerDelegate;
@class Output;

@protocol OutputDelegate
- (AudioDeviceID) outputGetDeviceId;
- (const AudioStreamBasicDescription*) outputGetFormat;
- (const AudioChannelLayout*) outputGetChannelLayout;
- (int) outputReadAudio:(void*) ptr frameCount:(int) frameCount;
@end

@protocol InputDelegate
- (void) inputReady:(Input*) sender;
- (void) inputEofReached:(Input*) sender;
- (void) inputExited:(Input*) sender;
@end

@interface SingleThreadPlayer : NSObject
{
    Output* output;
    Input* currentInput;
    Input* nextInput;
    id currentUserInfo;
    id nextUserInfo;
    id<AudioPlayerDelegate> delegate;
    double volume;
    UInt64 bytesPlayed;
}

@property int outputSkipBytes;

- (id)init;

- (void)setDelegate:(id<AudioPlayerDelegate>)d;
- (id<AudioPlayerDelegate>)delegate;

- (void)play:(NSURL *)url;
- (void)play:(NSURL *)url withUserInfo:(id)userInfo;

- (void)stop;
- (void)pause;
- (void)resume;

- (void)seekToTime:(double)time;
- (void)setVolume:(double)v;
- (double)volume;
- (double)volumeUp:(double)amount;
- (double)volumeDown:(double)amount;

- (double)amountPlayed;

- (void)setNextStream:(NSURL *)url;
- (void)setNextStream:(NSURL *)url withUserInfo:(id)userInfo;
- (void)resetNextStreams;

+ (NSArray *)fileTypes;
+ (NSArray *)schemes;
+ (NSArray *)containerTypes;

@end

@interface SingleThreadPlayer (OutputCallbacks)
- (AudioDeviceID) outputGetDeviceId;
- (const AudioStreamBasicDescription*) outputGetFormat;
- (const AudioChannelLayout*) outputGetChannelLayout;
- (int) outputReadAudio:(void*) ptr frameCount:(int) frameCount;
@end

@interface SingleThreadPlayer (InputCallbacks)
- (void) inputReady:(Input*) sender;
- (void) inputEofReached:(Input*) sender;
- (void) inputExited:(Input*) sender;
@end