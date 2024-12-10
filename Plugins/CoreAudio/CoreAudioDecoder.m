/*
 *  $Id$
 *
 *  Copyright (C) 2006 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <unistd.h>

#import "CoreAudioDecoder.h"
#import <CoreAudio/AudioHardware.h>

#define FILE_STREAM_DEBUG 0

#if FILE_STREAM_DEBUG
static NSFileHandle* debugFileDecoder = nil;
#endif

@interface CoreAudioDecoder (Private)

// for direct mode
AudioStreamRangedDescription* ca_getAvailableFormatsForFirstOutput(AudioDeviceID deviceID, BOOL isPhysical, size_t* count);
AudioDeviceID getCurrentOutputDevice();
- (void)determineOutputVirtualFormat;

- (BOOL) readInfoFromExtAudioFileRef;
@end

@implementation CoreAudioDecoder

- (void) close
{
	OSStatus			err;
	
	err = ExtAudioFileDispose(_in);
	if(noErr != err) {
		NSLog(@"Error closing ExtAudioFile");
	}
}

- (BOOL)open:(id<CogSource>)source;
{
	OSStatus						err;
	FSRef							ref;
	
	NSURL *url = [source url];
	[source close]; //There's no room for your kind around here!
	
	if (![[url scheme] isEqualToString:@"file"])
		return NO;
		
	
	// Open the input file
	err = FSPathMakeRef((const UInt8 *)[[url path] UTF8String], &ref, NULL);
	if(noErr != err) {
		return NO;
	}
	
	err = ExtAudioFileOpen(&ref, &_in);
	if(noErr != err) {
		NSLog(@"Error opening file: %ld", err);
		return NO;
	}
	
	return [self readInfoFromExtAudioFileRef];
}

- (BOOL) readInfoFromExtAudioFileRef
{
	OSStatus						err;
	UInt32							size;
	AudioStreamBasicDescription		asbd;
	
	// Get input file information
	size	= sizeof(asbd);
	err		= ExtAudioFileGetProperty(_in, kExtAudioFileProperty_FileDataFormat, &size, &asbd);
	if(err != noErr) {
		err = ExtAudioFileDispose(_in);
		return NO;
	}
    fileFormat = asbd;
	
	SInt64 total;
	size	= sizeof(total);
	err		= ExtAudioFileGetProperty(_in, kExtAudioFileProperty_FileLengthFrames, &size, &total);
	if(err != noErr) {
		err = ExtAudioFileDispose(_in);
		return NO;
	}
	totalFrames = total;
	
	//Is there a way to get bitrate with extAudioFile?
	bitrate				= 0;
	
	// Set our properties
	bitsPerSample		= asbd.mBitsPerChannel;
	channels			= asbd.mChannelsPerFrame;
	frequency			= asbd.mSampleRate;
	
	// mBitsPerChannel will only be set for lpcm formats
	if(0 == bitsPerSample) {
		bitsPerSample = 16;
	}
	
	// Set output format
	AudioStreamBasicDescription		result;
	
	bzero(&result, sizeof(AudioStreamBasicDescription));
	
	result.mFormatID			= kAudioFormatLinearPCM;
	result.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian;
	
	result.mSampleRate			= frequency;
	result.mChannelsPerFrame	= channels;
	result.mBitsPerChannel		= bitsPerSample;
	
	result.mBytesPerPacket		= channels * (bitsPerSample / 8);
	result.mFramesPerPacket		= 1;
	result.mBytesPerFrame		= channels * (bitsPerSample / 8);
    
    // TODO: direct mode only
    [self determineOutputVirtualFormat];
   NSLog(@"determineOutputVirtualFormat: %ld, %ld bit", (unsigned long)outputFormat.mSampleRate, outputFormat.mBitsPerChannel);
    result = outputFormat;
	
	err = ExtAudioFileSetProperty(_in, kExtAudioFileProperty_ClientDataFormat, sizeof(result), &result);
	if(noErr != err) {
		err = ExtAudioFileDispose(_in);
		return NO;
	}
	
	[self willChangeValueForKey:@"properties"];
	[self didChangeValueForKey:@"properties"];
    
    
#if FILE_STREAM_DEBUG
    if (!debugFileDecoder) {
        NSString* filePath = @"/Users/ito/Desktop/test1_decoder";
//        [[NSFileManager defaultManager] removeFileAtPath:filePath handler:nil];
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
        debugFileDecoder = [fileHandle retain];
    }
#endif
	
	return YES;
}

- (int) readAudio:(void *)buf frames:(UInt32)frames
{
	OSStatus				err;
	AudioBufferList			bufferList;
	UInt32					frameCount;
	
	// Set up the AudioBufferList
	bufferList.mNumberBuffers				= 1;
	bufferList.mBuffers[0].mNumberChannels	= channels;
	bufferList.mBuffers[0].mData			= buf;
	bufferList.mBuffers[0].mDataByteSize	= frames * channels * (bitsPerSample/8);
	
	// Read a chunk of PCM input (converted from whatever format)
	frameCount	= frames;
	err			= ExtAudioFileRead(_in, &frameCount, &bufferList);
	if(err != noErr) {
		return 0;
	}	
	
#if FILE_STREAM_DEBUG
    int result = write([debugFileDecoder fileDescriptor], buf, bufferList.mBuffers[0].mDataByteSize);
    assert(result == bufferList.mBuffers[0].mDataByteSize);
#endif
    
    
    
//	return frameCount; // TODO: not direct mode
    
    // for direct mode
    if (frameCount <= 0) {
        return 0;
    }
    return frames;
}

- (long) seek:(long)frame
{
	OSStatus			err;
	
	err = ExtAudioFileSeek(_in, frame);
	if(noErr != err) {
		return -1;
	}
	
	return frame;
}

+ (NSArray *)fileTypes
{
	OSStatus			err;
	UInt32				size;
	NSArray *sAudioExtensions;
	
	size	= sizeof(sAudioExtensions);
	err		= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AllExtensions, 0, NULL, &size, &sAudioExtensions);
	if(noErr != err) {
		return nil;
	}
	
	return [sAudioExtensions autorelease];
}

+ (NSArray *)mimeTypes
{
	return nil;
}

- (NSDictionary *)properties
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:channels],@"channels",
		[NSNumber numberWithInt:bitsPerSample],@"bitsPerSample",
		[NSNumber numberWithInt:bitrate],@"bitrate",
		[NSNumber numberWithFloat:frequency],@"sampleRate",
		[NSNumber numberWithLong:totalFrames],@"totalFrames",
		[NSNumber numberWithBool:YES], @"seekable",
		@"big", @"endian",
		nil];
}

-(void)setAvailableVirtualFormats:(AudioStreamRangedDescription *)descriptions descriptionCount:(size_t)count
{
    availableVirtualFormatCount = count;
    availableVirtualFormats = descriptions;
}

-(NSValue*)outputFormatForDirectMode
{
    return [NSValue valueWithPointer:&outputFormat];
}

- (void)determineOutputVirtualFormat_
{
//    [[self class] performSelectorOnMainThread:@selector(printAllAudioDevices) withObject:nil waitUntilDone:YES];
    
    NSLog(@"File format: %ld, %ld bit", (unsigned long)fileFormat.mSampleRate, fileFormat.mBitsPerChannel);
    
//    AudioDeviceID deviceID = getCurrentOutputDevice();
    size_t count = availableVirtualFormatCount;
    AudioStreamRangedDescription* descriptions = availableVirtualFormats;
    
    NSLog(@"num of virtual format: %ld", count);
    
    NSAssert(descriptions, nil);
    
    bzero(&outputFormat, sizeof(AudioStreamBasicDescription));
    size_t i;
    
    BOOL hasNonMixable = NO;
    for (i = 0; i < count; i++) {
        AudioStreamBasicDescription d = descriptions[i].mFormat;
        if ( (d.mFormatFlags & kAudioFormatFlagIsNonMixable) ) {
            hasNonMixable = YES;
            break;
        }
    }
    
    if (hasNonMixable) {
        outputFormat.mSampleRate = fileFormat.mSampleRate;
        outputFormat.mFormatID = kAudioFormatLinearPCM;
        outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonMixable;
        outputFormat.mBytesPerPacket = (fileFormat.mBitsPerChannel/8) * fileFormat.mChannelsPerFrame;
        outputFormat.mBytesPerFrame = outputFormat.mBytesPerPacket;
        outputFormat.mFramesPerPacket = 1;
        outputFormat.mChannelsPerFrame = fileFormat.mChannelsPerFrame;
        outputFormat.mBitsPerChannel = fileFormat.mBitsPerChannel;
        return;
    }
    
    
    if (0) {
        // prefer float
        for (i = 0; i < count; i++) {
            AudioStreamBasicDescription d = descriptions[i].mFormat;
//            //            NSLog(@"test1: %ld, %ld bit", (unsigned long)d.mSampleRate, d.mBitsPerChannel);
            if (d.mSampleRate == fileFormat.mSampleRate && d.mFormatFlags & kAudioFormatFlagIsFloat) {
                outputFormat = d;
                break;
            }
        }
        
        if (outputFormat.mFormatID) {
            return;
        }
    }
    
    if (1) {
        // prefer non mixable
        for (i = 0; i < count; i++) {
            AudioStreamBasicDescription d = descriptions[i].mFormat;
            NSLog(@"test1: %ld, %ld bit, 0x%lx", (unsigned long)d.mSampleRate, d.mBitsPerChannel, d.mFormatFlags);
            if (d.mSampleRate == fileFormat.mSampleRate && d.mBitsPerChannel == fileFormat.mBitsPerChannel && (d.mFormatFlags & kAudioFormatFlagIsNonMixable) ) {
                outputFormat = d;
                break;
            }
        }
        
        if (outputFormat.mFormatID) {
            return;
        }
    }
    
    {
        for (i = 0; i < count; i++) {
            AudioStreamBasicDescription d = descriptions[i].mFormat;
            NSLog(@"test10: %ld, %ld bit, 0x%lx", (unsigned long)d.mSampleRate, d.mBitsPerChannel, d.mFormatFlags);
            if (d.mSampleRate == fileFormat.mSampleRate && d.mBitsPerChannel == fileFormat.mBitsPerChannel) {
                outputFormat = d;
                break;
            }
        }
        
        if (outputFormat.mFormatID) {
            return;
        }
    }
    
    for (i = 0; i < count; i++) {
        AudioStreamBasicDescription d = descriptions[i].mFormat;
        NSLog(@"test2: %ld, %ld bit, 0x%lx", (unsigned long)d.mSampleRate, d.mBitsPerChannel, d.mFormatFlags);
        if (d.mSampleRate == fileFormat.mSampleRate) {
            outputFormat = d;
            break;
        }
    }
    
}

- (void)determineOutputVirtualFormat
{
    [self performSelectorOnMainThread:@selector(determineOutputVirtualFormat_) withObject:nil waitUntilDone:YES];
    NSAssert(outputFormat.mSampleRate > 0, nil);
}

@end
