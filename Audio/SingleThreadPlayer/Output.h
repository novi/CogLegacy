#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol OutputDelegate;
@class SingleThreadPlayer;

@interface Output : NSObject {
    AUGraph auGraph;
    AudioUnit outputUnit;
    AudioStreamBasicDescription* currentInFormat;
    AudioChannelLayout* currentInChannelLayout;

    id<OutputDelegate> player;

    @public Float32 time;
}

- (BOOL) setupWithPlayer:(id<OutputDelegate>) player;
- (BOOL) start;
- (BOOL) stop;
- (BOOL) isRunning;
- (BOOL) setVolume:(double)vol;
- (SingleThreadPlayer*) player;
- (const AudioStreamBasicDescription*) format;
- (const AudioChannelLayout*) channelLayout;
@end