//
//  PlaylistEntry.h
//  Cog
//
//  Created by Vincent Spader on 3/14/05.
//  Copyright 2005 Vincent Spader All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PlaylistEntry : NSObject {
	int index;
	int shuffleIndex;
	
	BOOL current;
	BOOL removed;
	
	BOOL stopAfter;
	
	BOOL queued;
	int queuePosition;
	
	BOOL error;
	NSString *errorMessage;
	
	NSURL *URL;
	
	NSString *artist;
	NSString *album;
	NSString *title;
	NSString *genre;
	NSNumber *year;
	NSNumber *track;
	NSImage *albumArt;
	
	long long totalFrames;
	int bitrate;
	int channels;
	int bitsPerSample;
	float sampleRate;
	
	NSString *endian;
	
	BOOL seekable;
	
	BOOL metadataLoaded;
}

//+ (NSSet *)keyPathsForValuesAffectingDisplay;
//+ (NSSet *)keyPathsForValuesAffectingLength;
//+ (NSSet *)keyPathsForValuesAffectingPath;
//+ (NSSet *)keyPathsForValuesAffectingFilename;
//+ (NSSet *)keyPathsForValuesAffectingStatus;
//+ (NSSet *)keyPathsForValuesAffectingStatusMessage;

//@property(readonly) NSString *display;
//@property(retain, readonly) NSNumber *length;
//@property(readonly) NSString *path;
//@property(readonly) NSString *filename;

- (NSString*)display;
- (NSNumber*)length;
- (NSString*)path;
- (NSString*)filename;

//@property int index;
//@property int shuffleIndex;

- (void)setIndex:(int)anIndex;
- (int)index;
- (void)setShuffleIndex:(int)anIndex;
- (int)shuffleIndex;

//@property(readonly) NSString *status;
//@property(readonly) NSString *statusMessage;

- (NSString*)status;
- (NSString*)statusMessage;

//@property BOOL current;
//@property BOOL removed;

- (void)setCurrent:(BOOL)aCurrent;
- (BOOL)current;
- (void)setRemoved:(BOOL)aRemoved;
- (BOOL)removed;

//@property BOOL stopAfter;
- (void)setStopAfter:(BOOL)aStopAfter;
- (BOOL)stopAfter;

//@property BOOL queued;
//@property int queuePosition;
- (void)setQueued:(BOOL)aQueued;
- (BOOL)queued;
- (void)setQueuePosition:(int)aQueuePosition;
- (int)queuePosition;

//@property BOOL error;
//@property(retain) NSString *errorMessage;
- (void)setError:(BOOL)anError;
- (BOOL)error;
- (void)setErrorMessage:(NSString*)aMessage;
- (NSString*)errorMessage;

//@property(retain) NSURL *URL;
- (void)setURL:(NSURL*)anURL;
- (NSURL*)URL;

//@property(retain) NSString *artist;
//@property(retain) NSString *album;
//@property(retain) NSString *title;
//@property(retain) NSString *genre;
//@property(retain) NSNumber *year;
//@property(retain) NSNumber *track;
//@property(retain) NSImage *albumArt;
- (void)setAlbum:(NSString *)anAlbum;
- (NSString*)album;
- (void)setArtist:(NSString *)anArtist;
- (NSString*)artist;
- (void)setTitle:(NSString*)aTitle;
- (NSString*)title;
- (void)setGenre:(NSString *)aGenre;
- (NSString *)genre;
- (void)setYear:(NSNumber *)aYear;
- (NSNumber *)year;
- (void)setTrack:(NSNumber *)aTrack;
- (NSNumber *)track;
- (void)setAlbumArt:(NSImage *)anAlbumArt;
- (NSImage *)albumArt;

//@property long long totalFrames;
//@property int bitrate;
//@property int channels;
//@property int bitsPerSample;
//@property float sampleRate;

- (void)setTotalFrames:(long long)aTotalFrames;
- (long long)totalFrames;
- (void)setBitrate:(int)aBitrate;
- (int)bitrate;
- (void)setChannels:(int)aChannels;
- (int)channels;
- (void)setBitsPerSample:(int)aBitsPerSample;
- (int)bitsPerSample;
- (void)setSampleRate:(float)aSampleRate;
- (float)sampleRate;


//@property(retain) NSString *endian;
- (void)setEndian:(NSString*)anEndian;
- (NSString*)endian;

//@property BOOL seekable;

//@property BOOL metadataLoaded;

- (void)setSeekable:(BOOL)aSeekable;
- (BOOL)seekable;

- (void)setMetadataLoaded:(BOOL)aMetadataLoaded;
- (BOOL)metadataLoaded;


- (void)setMetadata:(NSDictionary *)metadata;

@end
