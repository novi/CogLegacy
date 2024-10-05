#import "PluginController.h"
#import "Plugin.h"

@implementation PluginController

//@synthesize sources;
//@synthesize containers;
//@synthesize metadataReaders;
//
//@synthesize propertiesReadersByExtension;
//@synthesize propertiesReadersByMimeType;
//
//@synthesize decodersByExtension;
//@synthesize decodersByMimeType;

//@synthesize configured;

static PluginController *sharedPluginController = nil;

+ (id<CogPluginController>)sharedPluginController
{
	@synchronized(self) {
		if (sharedPluginController == nil) {
			sharedPluginController = [[self alloc] init];
		}
	}
	
	return sharedPluginController;
}


- (id)init {
	self = [super init];
	if (self) {
        sources = [[NSMutableDictionary alloc] init];
        containers = [[NSMutableDictionary alloc] init];
 
        metadataReaders = [[NSMutableDictionary alloc] init];
 
        propertiesReadersByExtension = [[NSMutableDictionary alloc] init];
        propertiesReadersByMimeType = [[NSMutableDictionary alloc] init];
 
        decodersByExtension = [[NSMutableDictionary alloc] init];
        decodersByMimeType = [[NSMutableDictionary alloc] init];

        [self setup];
	}
	
	return self;
}

-(NSDictionary *)sources
{
    return sources;
}

-(NSDictionary *)containers
{
    return containers;
}

-(NSDictionary *)metadataReaders
{
    return metadataReaders;
}

-(NSDictionary *)propertiesReadersByExtension
{
    return propertiesReadersByExtension;
}

-(NSDictionary *)propertiesReadersByMimeType
{
    return propertiesReadersByMimeType;
}

-(NSDictionary *)decodersByExtension
{
    return decodersByExtension;
}

-(NSDictionary *)decodersByMimeType
{
    return decodersByMimeType;
}

- (void)setup
{
	if (configured == NO) {
		configured = YES;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bundleDidLoad:) name:NSBundleDidLoadNotification object:nil];

		[self loadPlugins];
		[self printPluginInfo];
	}	
}

- (void)bundleDidLoad:(NSNotification *)notification
{
	NSArray *classNames = [[notification userInfo] objectForKey:@"NSLoadedClasses"];
    NSEnumerator* enumerator = [classNames objectEnumerator];
    NSString *className;
	while (className = [enumerator nextObject])
	{
		NSLog(@"Class loaded: %@", className);
		Class bundleClass = NSClassFromString(className);
		if ([bundleClass conformsToProtocol:@protocol(CogContainer)]) {
			[self setupContainer:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogDecoder)]) {
			[self setupDecoder:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogMetadataReader)]) {
			[self setupMetadataReader:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogPropertiesReader)]) {
			[self setupPropertiesReader:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogSource)]) {
			[self setupSource:className];
		}
	}
}

- (void)loadPluginsAtPath:(NSString *)path
{

	NSArray *dirContents = [[NSFileManager defaultManager] directoryContentsAtPath:path];
    NSEnumerator* enumerator = [dirContents objectEnumerator];
    NSString *pname;
	while (pname = [enumerator nextObject])
	{
		NSString *ppath;
		ppath = [NSString pathWithComponents:[NSArray arrayWithObjects:path,pname,nil]];
		
		if ([[pname pathExtension] isEqualToString:@"bundle"])
		{
			NSBundle *b = [NSBundle bundleWithPath:ppath];
			[b load];
		}
	}
}

- (void)loadPlugins
{
	[self loadPluginsAtPath:[[NSBundle mainBundle] builtInPlugInsPath]];
	[self loadPluginsAtPath:[@"~/Library/Application Support/Cog/Plugins" stringByExpandingTildeInPath]];
}

- (void)setupContainer:(NSString *)className
{
	Class container = NSClassFromString(className);
	if (container && [container respondsToSelector:@selector(fileTypes)]) {
        NSEnumerator* enumerator = [[container fileTypes] objectEnumerator];
        id fileType;
		while (fileType = [enumerator nextObject])
		{
			[containers setObject:className forKey:[fileType lowercaseString]];
		}
	}
}

- (void)setupDecoder:(NSString *)className
{
	Class decoder = NSClassFromString(className);
	if (decoder && [decoder respondsToSelector:@selector(fileTypes)]) {
        NSEnumerator* enumerator = [[decoder fileTypes] objectEnumerator];
        id fileType;
		while (fileType = [enumerator nextObject])
		{
			[decodersByExtension setObject:className forKey:[fileType lowercaseString]];
		}
	}
	
	if (decoder && [decoder respondsToSelector:@selector(mimeTypes)]) {
        NSEnumerator* enumerator = [[decoder mimeTypes] objectEnumerator];
        id mimeType;
		while (mimeType = [enumerator nextObject])
		{
			[decodersByMimeType setObject:className forKey:[mimeType lowercaseString]];
		}
	}
}

- (void)setupMetadataReader:(NSString *)className
{
	Class metadataReader = NSClassFromString(className);
	if (metadataReader && [metadataReader respondsToSelector:@selector(fileTypes)]) {
        NSEnumerator* enumerator = [[metadataReader fileTypes] objectEnumerator];
        id fileType;
		while (fileType = [enumerator nextObject])
		{
			[metadataReaders setObject:className forKey:[fileType lowercaseString]];
		}
	}
}

- (void)setupPropertiesReader:(NSString *)className
{
	Class propertiesReader = NSClassFromString(className);
	if (propertiesReader && [propertiesReader respondsToSelector:@selector(fileTypes)]) {
        NSEnumerator* enumerator = [[propertiesReader fileTypes] objectEnumerator];
        id fileType;
		while (fileType = [enumerator nextObject])
		{
			[propertiesReadersByExtension setObject:className forKey:[fileType lowercaseString]];
		}
	}

	if (propertiesReader && [propertiesReader respondsToSelector:@selector(mimeTypes)]) {
        NSEnumerator* enumerator = [[propertiesReader mimeTypes] objectEnumerator];
        id mimeType;
		while (mimeType = [enumerator nextObject])
		{
			[propertiesReadersByMimeType setObject:className forKey:[mimeType lowercaseString]];
		}
	}
}

- (void)setupSource:(NSString *)className
{
	Class source = NSClassFromString(className);
	if (source && [source respondsToSelector:@selector(schemes)]) {
        NSEnumerator* enumerator = [[source schemes] objectEnumerator];
        id scheme;
		while (scheme = [enumerator nextObject])
		{
			[sources setObject:className forKey:scheme];
		}
	}
}

- (void)printPluginInfo
{
	NSLog(@"Sources: %@", self.sources);
	NSLog(@"Containers: %@", self.containers);
	NSLog(@"Metadata Readers: %@", self.metadataReaders);

	NSLog(@"Properties Readers By Extension: %@", self.propertiesReadersByExtension);
	NSLog(@"Properties Readers By Mime Type: %@", self.propertiesReadersByMimeType);

	NSLog(@"Decoders by Extension: %@", self.decodersByExtension);
	NSLog(@"Decoders by Mime Type: %@", self.decodersByMimeType);
}

- (id<CogSource>) audioSourceForURL:(NSURL *)url
{
	NSString *scheme = [url scheme];
	
	Class source = NSClassFromString([sources objectForKey:scheme]);
	
	return [[[source alloc] init] autorelease];
}

- (NSArray *) urlsForContainerURL:(NSURL *)url
{
	NSString *ext = [[url path] pathExtension];
	
	Class container = NSClassFromString([containers objectForKey:[ext lowercaseString]]);
	
	return [container urlsForContainerURL:url];
}

//Note: Source is assumed to already be opened.
- (id<CogDecoder>) audioDecoderForSource:(id <CogSource>)source
{
	NSString *ext = [[[source url] path] pathExtension];
	NSString *classString = [decodersByExtension objectForKey:[ext lowercaseString]];
	if (!classString) {
		classString = [decodersByMimeType objectForKey:[[source mimeType] lowercaseString]];
	}

	Class decoder = NSClassFromString(classString);
	
	return [[[decoder alloc] init] autorelease];
}

- (NSDictionary *)metadataForURL:(NSURL *)url
{
	NSString *ext = [[url path] pathExtension];
	
	Class metadataReader = NSClassFromString([metadataReaders objectForKey:[ext lowercaseString]]);
	
	return [metadataReader metadataForURL:url];
	
}


//If no properties reader is defined, use the decoder's properties.
- (NSDictionary *)propertiesForURL:(NSURL *)url
{
	NSString *ext = [[url path] pathExtension];
	
	id<CogSource> source = [self audioSourceForURL:url];
	if (![source open:url])
		return nil;

	NSString *classString = [propertiesReadersByExtension objectForKey:[ext lowercaseString]];
	if (!classString) {
		classString = [propertiesReadersByMimeType objectForKey:[[source mimeType] lowercaseString]];
	}

	if (classString)
	{
		Class propertiesReader = NSClassFromString(classString);

		 return [propertiesReader propertiesForSource:source];
	}
	else
	{
	
		id<CogDecoder> decoder = [self audioDecoderForSource:source];
		if (![decoder open:source])
		{
			return nil;
		}
		
		NSDictionary *properties = [decoder properties];
		
		[decoder close];
		
		return properties;
	}
}

@end

