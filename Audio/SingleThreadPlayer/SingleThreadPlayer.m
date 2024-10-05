//
// Created by Dmitry Promsky on 03/06/14.
//
//


#import "SingleThreadPlayer.h"
#import "AudioPlayer.h"
#import "Output.h"
#import "Logging.h"
#import "Status.h"
#import "PluginController.h"

AudioChannelLayout* fillChannelLayout(AudioChannelLayout* pLayout) {
    UInt32 propSize = 0;
    AudioChannelLayout* result = NULL;
    OSStatus ret = noErr;

    if (pLayout->mNumberChannelDescriptions > 0) {
        // already filled
        return result;
    }

    if (pLayout->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelBitmap) {
        ret = AudioFormatGetPropertyInfo(kAudioFormatProperty_ChannelLayoutForBitmap,
                sizeof(UInt32),
                &pLayout->mChannelBitmap,
                &propSize);
        if (ret == noErr) {
            result = (AudioChannelLayout*) malloc(propSize);
            AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutForBitmap,
                    sizeof(UInt32),
                    &pLayout->mChannelBitmap,
                    &propSize,
                    result);
        }
    } else if (pLayout->mChannelLayoutTag != kAudioChannelLayoutTag_UseChannelDescriptions) {
        // ALog(@"Filling layout for tag");
        ret = AudioFormatGetPropertyInfo(kAudioFormatProperty_ChannelLayoutForTag,
                sizeof(AudioChannelLayoutTag),
                &pLayout->mChannelLayoutTag,
                &propSize);
        if (ret == noErr) {
            result = (AudioChannelLayout*) malloc(propSize);
            AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutForTag,
                    sizeof(AudioChannelLayoutTag),
                    &pLayout->mChannelLayoutTag,
                    &propSize,
                    result);
        }
    }

    return result;
}

static BOOL formatsEq(const AudioStreamBasicDescription* l, const AudioStreamBasicDescription* r) {
    BOOL ptrEq = (l == r);

    return ptrEq ||
           (l->mBytesPerFrame == r->mBytesPerFrame &&
            l->mBitsPerChannel == r->mBitsPerChannel &&
            l->mBytesPerPacket == r->mBytesPerPacket &&
            l->mChannelsPerFrame == r->mChannelsPerFrame &&
            l->mFormatID == r->mFormatID &&
            l->mFormatFlags == r->mFormatFlags &&
            l->mSampleRate == r->mSampleRate &&
            l->mFramesPerPacket == r->mFramesPerPacket);
}

static BOOL layoutsEq(const AudioChannelLayout* l, const AudioChannelLayout* r) {
   if (l == r) {
       return YES;
   }

   if (l->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelBitmap) {
       if (r->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelBitmap) {
           return l->mChannelBitmap == r->mChannelBitmap;
       } else {
           return NO;
       }
   } else if (l->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelDescriptions) {
       if (r->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelDescriptions) {
           if (l->mNumberChannelDescriptions == r->mNumberChannelDescriptions) {
               for (int i=0; i<l->mNumberChannelDescriptions; i++) {
                   if (l->mChannelDescriptions[i].mChannelLabel != r->mChannelDescriptions[i].mChannelLabel) {
                       return NO;
                   }
               }
               return YES;
           } else {
               return NO;
           }
       } else {
           return NO;
       }
   } else {
       return l->mChannelLayoutTag == r->mChannelLayoutTag;
   }
}

static int copyBytes(VirtualRingBuffer* bufFrom, void* ptrTo, int amount) {
    void* bufPtr = NULL;
    int bytesCopied = 0;
    int bytesAvailable = [bufFrom lengthAvailableToReadReturningPointer:&bufPtr];

    if (bytesAvailable > 0) {
        int bytesToCopy = bytesAvailable;
        if (bytesToCopy > amount) {
            bytesToCopy = amount;
        }
        if (ptrTo != NULL) {
            memcpy(ptrTo, bufPtr, bytesToCopy);
        };
        [bufFrom didReadLength:(UInt32)bytesToCopy];
        bytesCopied = bytesToCopy;
    }

    return bytesCopied;
}

static BOOL compatible(Input* input, Output* output) {
    return formatsEq([input format], [output format]) &&
           layoutsEq([input channelLayout], [output channelLayout]);
}

@interface SingleThreadPlayer (Private)
- (void) initOutput;
- (void) switchToNext;
@end

@implementation SingleThreadPlayer

- (id)init {
    self = [super init];
    if (self) {
        output = nil;
        currentInput = nil;
        nextInput = nil;
        delegate = nil;
        volume = 100;
        bytesPlayed = 0;
    }

    return self;
}

- (void)setDelegate:(id <AudioPlayerDelegate>)d {
    delegate = d;
}

- (id <AudioPlayerDelegate>)delegate {
    return delegate;
}

- (void)play:(NSURL *)url {
    [self play:url withUserInfo:nil];
}

- (void)play:(NSURL *)url withUserInfo:(id)userInfo {
    [self stop];

    currentInput = [[Input alloc] init];
    currentUserInfo = userInfo;
    bytesPlayed = 0;
    [currentInput startWithUrl:url player:self];
    [delegate audioPlayer:self didChangeStatus:[NSNumber numberWithInt:kCogStatusPlaying] userInfo:userInfo];
    [delegate audioPlayer:self didBeginStream:currentUserInfo];
}

- (void)stop {
    if (nil != output) {
        [output stop];
        [output release];
        output = nil;
    }

    if (nil != currentInput) {
        [currentInput stop];
        currentInput = nil;
        currentUserInfo = nil;
    }

    if (nil != nextInput) {
        [nextInput stop];
        nextInput = nil;
        nextUserInfo = nil;
    }

    [delegate audioPlayer:self didChangeStatus:[NSNumber numberWithInt:kCogStatusStopped] userInfo:currentUserInfo];
}

- (void)pause {
    if (nil != output) {
        [output stop];
    }

    [delegate audioPlayer:self didChangeStatus:[NSNumber numberWithInt:kCogStatusPaused] userInfo:currentUserInfo];
}

- (void)resume {
    if (nil != output) {
        [output start];
    }

    [delegate audioPlayer:self didChangeStatus:[NSNumber numberWithInt:kCogStatusPlaying] userInfo:currentUserInfo];
}

- (void)seekToTime:(double)time {
    @synchronized (self) {
        if (nil != currentInput && nil != output) {
            const AudioStreamBasicDescription* fmt = [currentInput format];
            Float64 sampleRate = fmt->mSampleRate;
            long frame = (long) round(time * sampleRate);
            [currentInput setSeekFrame:frame];

            bytesPlayed = (UInt64)frame * fmt->mBytesPerFrame;

            void *dummy = NULL;
            // querying for buffer byte count is probably safe enough here, since it doens't modify anything
            // modifying data pointed to by dummy or calling didReadLength isn't safe, since
            // this isn't the reading or writing thread for the buffer
            int toSkip = [[currentInput buffer] lengthAvailableToReadReturningPointer:&dummy];
            [self setOutputSkipBytes:toSkip];

            [currentInput unpause];
        }
    }
}

- (void)setVolume:(double)v {
    if (output != nil) {
        [output setVolume:v];
    }

    volume = v;
}

- (double)volume {
    return volume;
}

- (double)volumeUp:(double)amount {
    volume = volume + amount;
    if (volume > 100) {
        volume = 100;
    }
    [self setVolume:volume];
    return volume;
}

- (double)volumeDown:(double)amount {
    volume = volume - amount;
    if (volume < 0) {
        volume = 0;
    }
    [self setVolume:volume];
    return volume;
}

- (double)amountPlayed {
    if (output != nil) {
        const AudioStreamBasicDescription* fmt = [output format];
        if (fmt != NULL) {
            return ((double)bytesPlayed) / fmt->mSampleRate / fmt->mBytesPerFrame;
        } else {
            return 0;
        }
    }
    return 0;
}

- (void)setNextStream:(NSURL *)url {
    [self setNextStream:url withUserInfo:nil];
}

- (void)setNextStream:(NSURL *)url withUserInfo:(id)userInfo {
    @synchronized (self) {
        if (nextInput != nil) {
            [nextInput stop];
            nextInput = nil;
        }

        if (url != nil) {
            nextInput = [[Input alloc] init];
            nextUserInfo = userInfo;
            [nextInput startWithUrl:url player:self];
        }
    }
}

- (void)resetNextStreams {
    @synchronized (self) {
        if (nextInput != nil) {
            [nextInput stop];
            nextInput = nil;
            nextUserInfo = nil;
        }

        if ([currentInput eofReached]) {
            [delegate audioPlayer:self willEndStream:currentUserInfo];
        }
    }
}

+ (NSArray *)fileTypes {
    id<CogPluginController> pluginController = [PluginController sharedPluginController];

    NSArray *containerTypes = [[pluginController containers] allKeys];
    NSArray *decoderTypes = [[pluginController decodersByExtension] allKeys];
    NSArray *metdataReaderTypes = [[pluginController metadataReaders] allKeys];
    NSArray *propertiesReaderTypes = [[pluginController propertiesReadersByExtension] allKeys];

    NSMutableSet *types = [NSMutableSet set];

    [types addObjectsFromArray:containerTypes];
    [types addObjectsFromArray:decoderTypes];
    [types addObjectsFromArray:metdataReaderTypes];
    [types addObjectsFromArray:propertiesReaderTypes];

    return [types allObjects];
}

+ (NSArray *)schemes {
    id<CogPluginController> pluginController = [PluginController sharedPluginController];
    return [[pluginController sources] allKeys];
}

+ (NSArray *)containerTypes {
    return [[[PluginController sharedPluginController] containers] allKeys];
}

@end

// These are called by Output on the main thread, except outputReadAudio:frameCount:
@implementation SingleThreadPlayer (OutputCallbacks)
- (AudioDeviceID) outputGetDeviceId {
    NSDictionary* device = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"outputDevice"];
    if (device) {
        return (AudioDeviceID) [[device objectForKey:@"deviceID"] longValue];
    } else {
        UInt32 size = sizeof(AudioDeviceID);
        AudioDeviceID defaultDeviceId;
        AudioObjectPropertyAddress addr = {
                .mSelector = kAudioHardwarePropertyDefaultOutputDevice,
                .mScope = kAudioObjectPropertyScopeGlobal,
                .mElement = kAudioObjectPropertyElementMaster
        };

        OSStatus err = AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &defaultDeviceId);
        if (err != noErr) {
            ALog(@"Can't get default device id: err = %d", (int) err);
            return (AudioDeviceID) -1;
        }

        return defaultDeviceId;
    }
}

- (const AudioStreamBasicDescription *)outputGetFormat {
    return [currentInput format];
}

- (const AudioChannelLayout *)outputGetChannelLayout {
    return [currentInput channelLayout];
}

// This is called by Output and executed on AudioUnit thread
- (int)outputReadAudio:(void *)ptr frameCount:(int)frameCount {
    @synchronized (self) {
        int bytesToRead = frameCount * [currentInput format]->mBytesPerFrame;
        int bytesRead = 0;

        VirtualRingBuffer *curBuf = [currentInput buffer];

        int skip = [self outputSkipBytes];
        if (skip > 0) {
            copyBytes(curBuf, NULL, skip);
            [self setOutputSkipBytes:0];
            NSLog(@"SKip bytes = %d", skip);
        }

        bytesRead += copyBytes(curBuf, ptr, bytesToRead);
        bytesPlayed += bytesRead;

        if ([currentInput eofReached]) {
            if (bytesRead < bytesToRead) {
                // we're finished with playback of current input
                if (nil != nextInput && [nextInput ready] && compatible(nextInput, output)) {
                    bytesRead += copyBytes([nextInput buffer], ptr + bytesRead, bytesToRead - bytesRead);
                }

                [self performSelectorOnMainThread:@selector(switchToNext) withObject:nil waitUntilDone:NO];
            }
        } else {
            [currentInput unpause];
        }

        return bytesRead;
    }
}

@end

// These are called by Input on its thread
@implementation SingleThreadPlayer (InputCallbacks)
- (void)inputReady:(Input *)sender {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (sender == currentInput) {
            [self initOutput];
        }
    }];
}

- (void)inputEofReached:(Input *)sender {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (sender == currentInput) {
            [delegate audioPlayer:self willEndStream:currentUserInfo];
            if (output == nil || ![output isRunning]) {
                [currentInput stop];
                currentInput = nextInput;
                currentUserInfo = nextUserInfo;
                nextInput = nil;
                nextUserInfo = nil;

                if (currentInput != nil) {
                    [delegate audioPlayer:self didBeginStream:currentUserInfo];
                }
            }
        }
    }];
}

- (void)inputExited:(Input *)sender {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (sender == currentInput) {
            currentInput = nil;
            currentUserInfo = nil;
        }

        if (sender == nextInput) {
            nextInput = nil;
            nextUserInfo = nil;
        }

        [sender release];
    }];
}
@end

@implementation SingleThreadPlayer (Private)
- (void)initOutput {
    if (output != nil) {
        [output stop];
        [output release];
        output = nil;
    }

    output = [[Output alloc] init];
    [output setupWithPlayer:self];
    [output setVolume:volume];
    [output start];
}

- (void)switchToNext {
    bytesPlayed = 0;
    if (nil == nextInput) {
        [output stop];
        [currentInput stop];
        [delegate audioPlayer:self willEndStream:currentUserInfo];
        currentInput = nextInput;
        currentUserInfo = nextUserInfo;
        nextInput = nil;
        nextUserInfo = nil;
    } else {
        if ([nextInput ready]) {
            if (compatible(nextInput, output)) {
                @synchronized (self) {
                    Input *oldInput = currentInput;
                    currentInput = nextInput;
                    currentUserInfo = nextUserInfo;
                    nextInput = nil;
                    nextUserInfo = nil;
                    [oldInput stop];
                    [delegate audioPlayer:self didBeginStream:currentUserInfo];
                }
            } else {
                [output stop];
                [currentInput stop];
                currentInput = nextInput;
                currentUserInfo = nextUserInfo;
                nextInput = nil;
                nextUserInfo = nil;
                [self inputReady:currentInput];
            }
        } else {
            [output stop];
            [currentInput stop];
            currentInput = nextInput;
            currentUserInfo = nextUserInfo;
            nextInput = nil;
            nextUserInfo = nil;
        }
    }

    if (currentInput != nil) {
        [delegate audioPlayer:self didBeginStream:currentUserInfo];
    }
}

@end