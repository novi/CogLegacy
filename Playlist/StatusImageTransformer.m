//
//  StatusImageTransformer.m
//  Cog
//
//  Created by Vincent Spader on 2/21/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "StatusImageTransformer.h"
#import "PlaylistEntry.h"


@implementation StatusImageTransformer

//@synthesize playImage;
//@synthesize queueImage;
//@synthesize errorImage;
//@synthesize stopAfterImage;

- (void)setPlayImage:(NSImage*)anImage
{
    [playImage release];
    playImage = [anImage retain];
}

- (NSImage*)playImage
{
    return playImage;
}

- (void)setQueueImage:(NSImage*)anImage
{
    [queueImage release];
    queueImage = [anImage retain];
}

- (NSImage*)queueImage
{
    return queueImage;
}

- (void)setErrorImage:(NSImage*)anImage
{
    [errorImage release];
    errorImage = [anImage retain];
}

- (NSImage*)errorImage
{
    return errorImage;
}

- (void)setStopAfterImage:(NSImage*)anImage
{
    [stopAfterImage release];
    stopAfterImage = [anImage retain];
}

- (NSImage*)stopAfterImage
{
    return stopAfterImage;
}

+ (Class)transformedValueClass { return [NSImage class]; }
+ (BOOL)allowsReverseTransformation { return NO; }

- (id)init
{
	self = [super init];
	if (self)
	{
		self.playImage = [NSImage imageNamed:@"play"];
		self.queueImage = [NSImage imageNamed:@"NSAddTemplate"];
		self.errorImage = [NSImage imageNamed:@"NSStopProgressTemplate"];
		self.stopAfterImage = [NSImage imageNamed:@"stop_current"];
	}
	
	return self;
}

// Convert from string to RepeatMode
- (id)transformedValue:(id)value {
    if (value == nil) return nil;

	if ([value isEqualToString:@"playing"])
	{
		return self.playImage;
	}
	else if ([value isEqualToString:@"queued"])
	{
		return self.queueImage;
	}
	else if ([value isEqualToString:@"error"]) {
		return self.errorImage;
	}
	else if ([value isEqualToString:@"stopAfter"]) {
		return self.stopAfterImage;
	}

	return nil;
}


@end
