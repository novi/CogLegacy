//
//  PlaylistEntry.m
//  Cog
//
//  Created by Vincent Spader on 3/14/05.
//  Copyright 2005 Vincent Spader All rights reserved.
//

#import "PlaylistEntry.h"

@implementation PlaylistEntry

//@synthesize index;
//@synthesize shuffleIndex;
- (void)setIndex:(int)anIndex
{
    index = anIndex;
}

- (int)index
{
    return index;
}


- (void)setShuffleIndex:(int)anIndex
{
    shuffleIndex = anIndex;
}

- (int)shuffleIndex
{
    return shuffleIndex;
}

//@synthesize current;
//@synthesize removed;
- (void)setCurrent:(BOOL)aCurrent
{
    current = aCurrent;
    [self willChangeValueForKey:@"status"];
    [self didChangeValueForKey:@"status"];
    [self willChangeValueForKey:@"statusMessage"];
    [self didChangeValueForKey:@"statusMessage"];
}

- (BOOL)current
{
    return current;
}

- (void)setRemoved:(BOOL)aRemoved
{
    removed = aRemoved;
}

- (BOOL)removed
{
    return removed;
}


//@synthesize stopAfter;
- (void)setStopAfter:(BOOL)aStopAfter
{
    stopAfter = aStopAfter;
    [self willChangeValueForKey:@"status"];
    [self didChangeValueForKey:@"status"];
    [self willChangeValueForKey:@"statusMessage"];
    [self didChangeValueForKey:@"statusMessage"];
}

- (BOOL)stopAfter
{
    return stopAfter;
}


//@synthesize queued;
//@synthesize queuePosition;
- (void)setQueued:(BOOL)aQueued
{
    queued = aQueued;
    [self willChangeValueForKey:@"status"];
    [self didChangeValueForKey:@"status"];
    [self willChangeValueForKey:@"statusMessage"];
    [self didChangeValueForKey:@"statusMessage"];
}

- (BOOL)queued
{
    return queued;
}

- (void)setQueuePosition:(int)aQueuePosition
{
    queuePosition = aQueuePosition;
    [self willChangeValueForKey:@"statusMessage"];
    [self didChangeValueForKey:@"statusMessage"];
}

- (int)queuePosition
{
    return queuePosition;
}

//@synthesize error;
//@synthesize errorMessage;

//@synthesize URL;

- (void)setError:(BOOL)anError
{
    error = anError;
    [self willChangeValueForKey:@"status"];
    [self didChangeValueForKey:@"status"];
    [self willChangeValueForKey:@"statusMessage"];
    [self didChangeValueForKey:@"statusMessage"];
}

- (BOOL)error
{
    return error;
}

- (void)setErrorMessage:(NSString*)aMessage
{
    [errorMessage release];
    errorMessage = [aMessage copy];
    [self willChangeValueForKey:@"statusMessage"];
    [self didChangeValueForKey:@"statusMessage"];
}

- (NSString*)errorMessage
{
    return errorMessage;
}

- (void)setURL:(NSURL*)anURL
{
    [URL release];
    URL = [anURL retain];
    [self willChangeValueForKey:@"path"];
    [self didChangeValueForKey:@"path"];
    [self willChangeValueForKey:@"filename"];
    [self didChangeValueForKey:@"filename"];
}

- (NSURL*)URL
{
    return URL;
}

//@synthesize artist;
//@synthesize album;
//@synthesize genre;
//@synthesize year;
//@synthesize track;
//@synthesize albumArt;

- (void)setAlbum:(NSString *)anAlbum
{
    [album release];
    album = [anAlbum copy];
}

- (NSString*)album
{
    return album;
}

- (void)setArtist:(NSString *)anArtist
{
    [artist release];
    artist = [anArtist copy];
    [self willChangeValueForKey:@"display"];
    [self didChangeValueForKey:@"display"];
}

- (NSString*)artist
{
    return artist;
}

- (void)setGenre:(NSString *)aGenre
{
    [genre release];
    genre = [aGenre copy];
}

- (NSString *)genre
{
    return genre;
}

- (void)setYear:(NSNumber *)aYear
{
    [year release];
    year = [aYear retain];
}

- (NSNumber *)year
{
    return year;
}

- (void)setTrack:(NSNumber *)aTrack
{
    [track release];
    track = aTrack;
}

- (NSNumber *)track
{
    return track;
}

- (void)setAlbumArt:(NSImage *)anAlbumArt
{
    [albumArt release];
    albumArt = [anAlbumArt retain];
}

- (NSImage *)albumArt
{
    return albumArt;
}

//@synthesize totalFrames;
//@synthesize bitrate;
//@synthesize channels;
//@synthesize bitsPerSample;
//@synthesize sampleRate;

- (void)setTotalFrames:(long long)aTotalFrames
{
    totalFrames = aTotalFrames;
    [self willChangeValueForKey:@"length"];
    [self didChangeValueForKey:@"length"];
}

- (long long)totalFrames
{
    return totalFrames;
}

- (void)setBitrate:(int)aBitrate
{
    bitrate = aBitrate;
}

- (int)bitrate
{
    return bitrate;
}

- (void)setChannels:(int)aChannels
{
    channels = aChannels;
}

- (int)channels
{
    return channels;
}

- (void)setBitsPerSample:(int)aBitsPerSample
{
    bitsPerSample = aBitsPerSample;
}

- (int)bitsPerSample
{
    return bitsPerSample;
}

- (void)setSampleRate:(float)aSampleRate
{
    sampleRate = aSampleRate;
}

- (float)sampleRate
{
    return sampleRate;
}

//@synthesize endian;

//@synthesize seekable;

- (void)setEndian:(NSString*)anEndian
{
    [endian release];
    endian = [anEndian copy];
}

- (NSString*)endian
{
    return endian;
}


- (void)setSeekable:(BOOL)aSeekable
{
    seekable = aSeekable;
}

- (BOOL)seekable
{
    return seekable;
}

- (void)setMetadataLoaded:(BOOL)aMetadataLoaded
{
    metadataLoaded = aMetadataLoaded;
}

- (BOOL)metadataLoaded
{
    return metadataLoaded;
}

//@synthesize metadataLoaded;

// The following read-only keys depend on the values of other properties

//+ (NSSet *)keyPathsForValuesAffectingDisplay
//{
//    return [NSSet setWithObjects:@"artist",@"title",nil];
//}

//+ (NSSet *)keyPathsForValuesAffectingLength
//{
//    return [NSSet setWithObject:@"totalFrames"];
//}

//+ (NSSet *)keyPathsForValuesAffectingPath
//{
//    return [NSSet setWithObject:@"URL"];
//}

//+ (NSSet *)keyPathsForValuesAffectingFilename
//{
//    return [NSSet setWithObject:@"URL"];
//}

//+ (NSSet *)keyPathsForValuesAffectingStatus
//{
//	return [NSSet setWithObjects:@"current",@"queued", @"error", @"stopAfter", nil];
//}

//+ (NSSet *)keyPathsForValuesAffectingStatusMessage
//{
//	return [NSSet setWithObjects:@"current", @"queued", @"queuePosition", @"error", @"errorMessage", @"stopAfter", nil];
//}

- (NSString *)description
{
	return [NSString stringWithFormat:@"PlaylistEntry %i:(%@)", self.index, self.URL];
}

- (void)dealloc
{
	self.errorMessage = nil;
	
	self.URL = nil;
	
	self.artist = nil;
	self.album = nil;
	self.title = nil;
	self.genre = nil;
	self.year = nil;
	self.track = nil;
	self.albumArt = nil;
	
	self.endian = nil;
	
	[super dealloc];
}

// Get the URL if the title is blank
//@synthesize title;
- (void)setTitle:(NSString*)aTitle
{
    [title release];
    title = [aTitle copy];
    [self willChangeValueForKey:@"display"];
    [self didChangeValueForKey:@"display"];
}

- (NSString *)title
{
    if((title == nil || [title isEqualToString:@""]) && self.URL)
    {
        return [[self.URL path] lastPathComponent];
    }
    return title;
}

- (NSString *)display
{
	if ((self.artist == NULL) || ([self.artist isEqualToString:@""]))
		return self.title;
	else {
		return [NSString stringWithFormat:@"%@ - %@", self.artist, self.title];
	}
}

- (NSNumber *)length
{
    if (totalFrames > 0 && sampleRate > 0) {
        return [NSNumber numberWithDouble:((double)self.totalFrames / self.sampleRate)];
    } else {
        return 0;
    }
}

- (NSString *)path
{
	return [[self.URL path] stringByAbbreviatingWithTildeInPath];
}

- (NSString *)filename
{
	return [[self.URL path] lastPathComponent];
}

- (NSString *)status
{
	if (self.stopAfter)
	{
		return @"stopAfter";
	}
	else if (self.current)
	{
		return @"playing";
	}
	else if (self.queued)
	{
		return @"queued";
	}
	else if (self.error)
	{
		return @"error";
	}
	
	return nil;
}

- (NSString *)statusMessage
{
	if (self.stopAfter)
	{
		return @"Stopping once finished...";
	}
	else if (self.current)
	{
		return @"Playing...";
	}
	else if (self.queued)
	{
		return [NSString stringWithFormat:@"Queued: %i", self.queuePosition + 1];
	}
	else if (self.error)
	{
		return errorMessage;
	}
	
	return nil;
}

- (void)setMetadata:(NSDictionary *)metadata
{
    if (metadata == nil)
    {
        self.error = YES;
        self.errorMessage = @"Unable to retrieve metadata.";
    }
    else
    {
		[self setValuesForKeysWithDictionary:metadata];
    }
	
	metadataLoaded = YES;
}

@end
