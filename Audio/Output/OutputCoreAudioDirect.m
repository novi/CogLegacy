//
//  OutputCoreAudioDirect.m
//  CogAudio
//
//  Created by ito on 12/6/24.
//
//

#import "OutputCoreAudioDirect.h"
#import "Helper.h"
#import "ConverterNode.h"

@interface OutputCoreAudioDirect (Private)

- (void)stopCurrentForMainThread;
- (BOOL)isPaused;
- (BOOL)stopCurrent;

@end

@implementation OutputCoreAudioDirect


-(BOOL)isPaused
{
    return isPaused;
}

#define FILE_STREAM_DEBUG 0

#if FILE_STREAM_DEBUG
static NSFileHandle* debugFileOut = nil;
#endif

static OSStatus Sound_Renderer_Direct(   AudioDeviceID           inDevice,
                                      const AudioTimeStamp*   inNow,
                                      const AudioBufferList*  inInputData,
                                      const AudioTimeStamp*   inInputTime,
                                      AudioBufferList*        outOutputData,
                                      const AudioTimeStamp*   inOutputTime,
                                      void*                   inClientData)
{
	OutputCoreAudioDirect *output = (id)inClientData;
	OSStatus err = noErr;
    
    assert(outOutputData->mNumberBuffers == 1);
    
	void *readPointer = outOutputData->mBuffers[0].mData;
	
	int amountToRead, amountRead;
    amountToRead = outOutputData->mBuffers[0].mDataByteSize;
    
    if (output->outputController == nil) {
        NSLog(@"outputController is nil! %p", output);
    }
    
    if ([output isPaused]) {
        memset(readPointer, 0, amountToRead);
        return noErr;
    }
    
	if ([output->outputController shouldContinue] == NO)
	{
        memset(readPointer, 0, amountToRead);
		[output performSelectorOnMainThread:@selector(stopCurrentForMainThread) withObject:nil waitUntilDone:NO];
		return err;
	}
    
	amountRead = [output->outputController readData:(readPointer) amount:amountToRead];

#if FILE_STREAM_DEBUG
//    size_t debugSize = 8192;
//    void* buffer = malloc(debugSize);
//    [output->outputController readData:(buffer) amount:debugSize];
//    int result = write([debugFileOut fileDescriptor], buffer, debugSize);
//    assert(result == debugSize);
//    free(buffer);
    
    int result = write([debugFileOut fileDescriptor], readPointer, amountToRead);
    assert(result == amountToRead);
#endif
    
	if ((amountRead < amountToRead) && [output->outputController endOfStream] == NO) //Try one more time! for track changes!
	{
		int amountRead2; //Use this since return type of readdata isnt known...may want to fix then can do a simple += to readdata
		amountRead2 = [output->outputController readData:(readPointer+amountRead) amount:amountToRead-amountRead];
        amountRead += amountRead2;
	}
	
	return err;
}

- (BOOL)getHogMode
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = kAudioDevicePropertyHogMode;
    UInt32 size = sizeof(pid_t);
    pid_t data;
    OSStatus status = AudioObjectGetPropertyData(outputDevice, &address, 0, NULL, &size, &data);
    if (status != noErr) {
        NSLog(@"Get hog mode. error: %ld", status);
        return NO;
    }
    NSLog(@"current hog mode %d", data);
    return data != -1;
}

- (BOOL)setHogMode:(BOOL)hogMode
{
    if ([self getHogMode]) {
        if (hogMode) return YES;
    } else {
        if (!hogMode) return YES;
    }
    if (hogMode) {
        return setHogMode(outputDevice);
    } else {
        return unsetHogMode(outputDevice);
//        return YES;
    }
}

- (OSStatus)setFormat:(AudioStreamBasicDescription)description selector:(AudioObjectPropertySelector)selector
{
    size_t streamCount = 0;
    AudioStreamID* streams = getAllOutputStreams(outputDevice, &streamCount);
    NSAssert(streamCount > 0, @"no streams on current output");
    
    AudioStreamID first = streams[0];
    free(streams);
    
    UInt32 size = sizeof(AudioStreamBasicDescription);
    return AudioStreamSetProperty(first, NULL, 0, selector, size, &description);
}

- (OSStatus)setFormatToDevice:(AudioStreamBasicDescription)description selector:(AudioObjectPropertySelector)selector
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    return AudioDeviceSetProperty(outputDevice, NULL, 0, false, selector, size, &description);
}

- (OSStatus)getFormatAlt:(AudioStreamBasicDescription*)description selector:(AudioObjectPropertySelector)selector
{
    size_t streamCount = 0;
    AudioStreamID* streams = getAllOutputStreams(outputDevice, &streamCount);
    NSAssert(streamCount > 0, @"no streams on current output");
    
    AudioStreamID first = streams[0];
    free(streams);
    
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = selector;
    UInt32 size = sizeof(AudioStreamBasicDescription);
    return AudioObjectGetPropertyData(first, &address, 0, NULL, &size, description);
}

- (OSStatus)setFormatAlt:(AudioStreamBasicDescription)description selector:(AudioObjectPropertySelector)selector
{
    size_t streamCount = 0;
    AudioStreamID* streams = getAllOutputStreams(outputDevice, &streamCount);
    NSAssert(streamCount > 0, @"no streams on current output");
    
    AudioStreamID first = streams[0];
    free(streams);
    
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = selector;
    UInt32 size = sizeof(AudioStreamBasicDescription);
    return AudioObjectSetPropertyData(first, &address,
                                      0, nil,
                                      size, &description);
}

- (OutputCoreAudioDirect*)initWithController:(OutputNode *)c
{
    self = [super init];
    if (self) {
        

#if FILE_STREAM_DEBUG
        if (!debugFileOut) {
            NSString* filePath = @"/Users/ito/Desktop/test1_out";
            [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
            NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
            debugFileOut = [fileHandle retain];
        }        
#endif
        
        outputController = c;
        isRunning = NO;
        [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.outputDevice" options:0 context:NULL];
    }
    return self;
}

- (BOOL)setup
{
    return YES;
}

- (BOOL)setOutputDevice:(AudioDeviceID)anOutputDevice
{
    if (isRunning) {
        [[NSAlert alertWithMessageText:@"Output Device already started." defaultButton:@"Dismiss" alternateButton:nil otherButton:nil informativeTextWithFormat:@""] runModal];
        return NO;
    }
    outputDevice = anOutputDevice;
    return YES;
}

- (void)start
{
    
}

- (void)pause
{
    isPaused = YES;
}

- (void)resume
{
    isPaused = NO;
}

- (void)stop
{
    [self stopCurrent];
}

- (void)setVolume:(double) v
{
    // no volume supported
}

- (void)stopCurrentForMainThread
{
    [self stopCurrent];
}

- (BOOL)stopCurrent
{
    if (!isRunning) return YES;
    
    if (![self setHogMode:NO]) {
        return NO;
    }
    
    OSStatus status = AudioDeviceStop(outputDevice, Sound_Renderer_Direct);
    if (status != noErr) {
        NSLog(@"Failed to start IO proc. error: %ld", status);
        return NO;
    }
    
    status = AudioDeviceRemoveIOProc(outputDevice, Sound_Renderer_Direct);
    if (status != noErr) {
        NSLog(@"Failed to remove IO proc. error: %ld", status);
        return NO;
    }
    
    isRunning = NO;
    NSLog(@"Output stopped. %p", self);
    return YES;
}

- (AudioStreamBasicDescription)determinePhysicalFormatWithInputFormat:(AudioStreamBasicDescription)f
{
    size_t count = 0;
    AudioStreamRangedDescription* descriptions = getAvailableFormatsForFirstOutput(outputDevice, YES, &count);
    size_t i;
    AudioStreamBasicDescription result;
    bzero(&result, sizeof(AudioStreamBasicDescription));
    NSLog(@"num of physical format: %ld", count);
    NSAssert(count, nil);
    
    if (1) {
        // prefer non mixable
        for (i = 0; i < count; i++) {
            AudioStreamBasicDescription d = descriptions[i].mFormat;
            NSLog(@"test1: %ld, %ld bit, 0x%lx, %ld", (unsigned long)d.mSampleRate, d.mBitsPerChannel, d.mFormatFlags, d.mFormatFlags & kAudioFormatFlagIsNonMixable);
            if (d.mSampleRate == f.mSampleRate && d.mBitsPerChannel == f.mBitsPerChannel && (d.mFormatFlags & kAudioFormatFlagIsNonMixable)) {
                result = d;
                break;
            }
        }
        if (result.mFormatID) return result;
    }
    
    {
        for (i = 0; i < count; i++) {
            AudioStreamBasicDescription d = descriptions[i].mFormat;
            NSLog(@"test2: %ld, %ld bit, 0x%lx", (unsigned long)d.mSampleRate, d.mBitsPerChannel, d.mFormatFlags);
            if (d.mSampleRate == f.mSampleRate && d.mBitsPerChannel == f.mBitsPerChannel) {
                result = d;
                break;
            }
        }
        if (result.mFormatID) return result;
    }
    
    for (i = 0; i < count; i++) {
        AudioStreamBasicDescription d = descriptions[i].mFormat;
        if (d.mSampleRate == f.mSampleRate) {
            result = d;
            break;
        }
    }
    
    return result;
}

-(BOOL)setupWithInputFormat:(AudioStreamBasicDescription)f
{
    
    outputDevice = getCurrentOutputDevice();
    
    [self stopCurrent];
    
    if (![self setHogMode:YES]) {
        return NO;
    }
    
    AudioStreamBasicDescription physicalFormat = [self determinePhysicalFormatWithInputFormat:f];
    NSLog(@"Physical format determined:");
    PrintStreamDesc(&physicalFormat);
    OSStatus status = [self setFormatAlt:physicalFormat selector:kAudioStreamPropertyPhysicalFormat];
    if (status != noErr) {
        NSLog(@"Set physical format. error: %ld", status);
        return NO;
    }
    
    if (physicalFormat.mFormatFlags & kAudioFormatFlagIsNonMixable) {
        AudioStreamBasicDescription currentFormat;
        size_t i;
        for (i = 0; i < 50; i++) {
            [self getFormatAlt:&currentFormat selector:kAudioStreamPropertyVirtualFormat];
            // wait for virtual format changed to same as physical format
            if (currentFormat.mFormatFlags & kAudioFormatFlagIsNonMixable) {
                break;
            }
            usleep(100*1000);
        }
        NSLog(@"current format virtual:");
        PrintStreamDesc(&currentFormat);
        if (currentFormat.mFormatFlags & kAudioFormatFlagIsNonMixable) {
            
        } else {
            NSLog(@"virtual format change timeout.");
            return NO;
        }
//        [self getFormatAlt:&currentFormat selector:kAudioStreamPropertyPhysicalFormat];
//        NSLog(@"current format physical:");
//        PrintStreamDesc(&currentFormat);
    } else {
        status = [self setFormat:f selector:kAudioStreamPropertyVirtualFormat];
        if (status != noErr) {
            NSLog(@"Set virtual format 2. error: %ld\nformat:", status);
            PrintStreamDesc(&f);
            return NO;
        }
    }
    
    status = AudioDeviceAddIOProc(outputDevice, Sound_Renderer_Direct, self);
    if (status != noErr) {
        NSLog(@"Add IO proc. error: %ld", status);
        return NO;
    }
    
    status = AudioDeviceStart(outputDevice, Sound_Renderer_Direct);
    if (status != noErr) {
        NSLog(@"Failed to start IO proc. error: %ld", status);
        return NO;
    }
    isRunning = YES;
    NSLog(@"Output started. %p", self);
    return YES;
}

- (void)dealloc
{
	[self stopCurrent];
	
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.outputDevice"];
    
	[super dealloc];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"values.outputDevice"]) {
        
		NSDictionary *device = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"outputDevice"];
        
		NSNumber *deviceID = [device objectForKey:@"deviceID"];
		
		[self setOutputDevice:[deviceID longValue]];
	}
}


@end
