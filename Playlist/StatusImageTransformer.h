//
//  StatusImageTransformer.h
//  Cog
//
//  Created by Vincent Spader on 2/21/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface StatusImageTransformer : NSObject {
	NSImage *playImage;
	NSImage *queueImage;
	NSImage *errorImage;
	NSImage *stopAfterImage;
}

//@property(retain) NSImage *playImage;
//@property(retain) NSImage *queueImage;
//@property(retain) NSImage *errorImage;
//@property(retain) NSImage *stopAfterImage;

- (void)setPlayImage:(NSImage*)anImage;
- (NSImage*)playImage;

- (void)setQueueImage:(NSImage*)anImage;
- (NSImage*)queueImage;

- (void)setErrorImage:(NSImage*)anImage;
- (NSImage*)errorImage;

- (void)setStopAfterImage:(NSImage*)anImage;
- (NSImage*)stopAfterImage;



@end
