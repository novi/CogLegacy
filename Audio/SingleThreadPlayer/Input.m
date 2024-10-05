//
// Created by Dmitry Promsky on 04/06/14.
//
//


#import <AudioToolbox/AudioToolbox.h>
#import "Input.h"
#import "Node.h"
#import "AudioSource.h"
#import "Logging.h"
#import "AudioDecoder.h"
#import "CoreAudioUtils.h"
#import "CogAudio/SingleThreadPlayer.h"
#import "SingleThreadPlayer.h"

#define BUFFER_SIZE 1024*1024
#define CHUNK_FRAMES 64*1024

@implementation Input

- (id)init {
    self = [super init];
    if (self) {
        buffer = [[VirtualRingBuffer alloc] initWithLength:BUFFER_SIZE];
        pauseCond = [[NSCondition alloc] init];
        paused = NO;
        format = NULL;
        channelLayout = NULL;
        [self setSeekFrame:-1];
    }

    return self;
}

- (void)dealloc {
    if (format != NULL) {
        free(format);
    }

    if (channelLayout != NULL) {
        free(channelLayout);
    }

    if (decoder != nil) {
        [decoder release];
    }

    [buffer release];
    [pauseCond release];

    [super dealloc];
}

- (BOOL)openUrl:(NSURL *)url {
    id<CogSource> source = [AudioSource audioSourceForURL:url];
    if (source == nil) {
        ALog(@"Can't make source for url: $@", url);
        return NO;
    }

    if (![source open:url]) {
        ALog(@"Can't open url: $@", url);
        source = nil;
        return NO;
    }

    decoder = [AudioDecoder audioDecoderForSource:source];
    if (decoder == nil) {
        ALog(@"Can't make decoder");
        decoder = nil;
        return NO;
    }

    if (![decoder open:source]) {
        ALog(@"Can't open decoder");
        decoder = nil;
        return NO;
    }

    AudioChannelLayoutTag channelLayoutTag = kAudioChannelLayoutTag_Stereo;
    UInt32 chlsize = 0;
    NSNumber* chlobj = [[decoder properties] objectForKey:@"channelLayoutTag"];
    if (chlobj != nil) {
        channelLayoutTag = [chlobj unsignedIntValue];
        if (channelLayoutTag == kAudioChannelLayoutTag_DiscreteInOrder) {
            NSNumber* chnobj = [[decoder properties] objectForKey:@"channels"];
            UInt32 chans = 2;
            if (chnobj != nil) {
                chans = [chnobj unsignedIntValue];
            }
            channelLayoutTag |= chans;
        }
    }

    OSStatus ret = AudioFormatGetPropertyInfo(kAudioFormatProperty_ChannelLayoutForTag,
                                              sizeof(AudioChannelLayoutTag),
                                              &channelLayoutTag,
                                              &chlsize);
    if (ret != noErr) {
        ALog(@"Can't get channel layout for tag %x (errcode %x,%d)",
        (int) channelLayoutTag, (int) ret, (int) ret);
        decoder = nil;
        source = nil;
        return NO;
    }

    channelLayout = (AudioChannelLayout*) malloc(chlsize);
    AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutForTag,
                           sizeof(AudioChannelLayoutTag),
                           &channelLayoutTag,
                           &chlsize,
                           channelLayout);

    if (channelLayout->mNumberChannelDescriptions == 0) {
        AudioChannelLayout* filledLayout = fillChannelLayout(channelLayout);
        free(channelLayout);
        channelLayout = filledLayout;
    }

    AudioStreamBasicDescription asbd = propertiesToASBD([decoder properties]);
    format = malloc(sizeof(AudioStreamBasicDescription));
    memcpy(format, &asbd, sizeof(AudioStreamBasicDescription));

    [decoder retain];

    [self setShouldContinue:YES];
    [self setSeekFrame:-1];

    return YES;
}

- (const AudioStreamBasicDescription *)format {
    return format;
}

- (const AudioChannelLayout *)channelLayout {
    return channelLayout;
}

- (void)pause {
    [pauseCond lock];
    paused = YES;
    [pauseCond unlock];
}

- (void)unpause {
    [pauseCond lock];
    paused = NO;
    [pauseCond signal];
    [pauseCond unlock];
}


- (VirtualRingBuffer *)buffer {
    return buffer;
}

- (void)run:(NSURL*) url {
    DLog(@"Input opening");
    if ([self openUrl:url]) {
        DLog(@"Input opened");
        [self setReady:YES];
        [[self player] inputReady:self];
    } else {
        DLog(@"Input is not opened");
        [self setShouldContinue:NO];
        [self setEofReached:YES];
        [[self player] inputEofReached:self];
    }

    while([self shouldContinue]) {
        @autoreleasepool {
            [pauseCond lock];
            while(paused) {
                [pauseCond wait];
            }
            [pauseCond unlock];

            long seekFrame = [self seekFrame];
            if (seekFrame >= 0) {
                NSLog(@"Will seek");
                [decoder seek:seekFrame];
                [self setEofReached:NO];
                [self setSeekFrame:-1];
                // since we're at the writing end of circular buffer, we can't just clean
                // it, so pause until that is done by the reading end.
                [self pause];
            }

            void *buf = NULL;
            UInt32 bufBytesAvailable = [buffer lengthAvailableToWriteReturningPointer:&buf];
//            NSLog(@"Available for writing: %d", (int) bufBytesAvailable);
            UInt32 framesToRead = bufBytesAvailable / format->mBytesPerFrame;
            if (framesToRead == 0 && [self shouldContinue]) {
                [self pause];
            }

            if ([self shouldContinue] && !paused) {

                if (framesToRead > CHUNK_FRAMES) {
                    framesToRead = CHUNK_FRAMES;
                }

                int framesRead = [decoder readAudio:buf frames:framesToRead];
                if (framesRead <= 0) {
                    DLog(@"Input eof reached");
                    [self setEofReached:YES];
                    [[self player] inputEofReached:self];
                    [self pause];
                } else {
                    [buffer didWriteLength:(framesRead * format->mBytesPerFrame)];
                }
            }
        }
    }

    if (decoder != nil) {
        [decoder close];
    }

    [[self player] inputExited:self];
    DLog(@"Input exiting");
}

- (void)startWithUrl:(NSURL*)url player:(id<InputDelegate>)p {
    [self setPlayer:p];
    [NSThread detachNewThreadSelector:@selector(run:) toTarget:self withObject:url];
}

- (void)stop {
    [self setShouldContinue:NO];
    [self unpause];
}

@end