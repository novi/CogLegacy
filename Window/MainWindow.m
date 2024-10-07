//
//  MainWindow.m
//  Cog
//
//  Created by Vincent Spader on 2/22/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MainWindow.h"
#import "NSInteger-compat.h"
#import "PlaybackButtons.h"
#import "AppController.h"
#import "VolumeButton.h"
#import "TimeField.h"
#import "PositionSlider.h"

static NSString* MainToolbarIdentifier = @"MainToolbar";
static NSString* PlaybackButtonToolbarItemIdentifier = @"PlaybackButton";

static NSString* VolumeButtonToolbarItemIdentifier = @"VolumeButton";

static NSString* PositionToolbarItemIdentifier = @"Position";
static NSString* CurrentTimeToolbarItemIdentifier = @"CurrentTime";

static NSString* ShuffleButtonToolbarItemIdentifier = @"Shuffle";
static NSString* RepeatButtonToolbarItemIdentifier = @"Repeat";

static NSString* InfoButtonToolbarItemIdentifier = @"Info";
static NSString* FileTreeButtonToolbarItemIdentifier = @"FileTree";

static NSString* DummyButtonToolbarItemIdentifier = @"Dummy";

static NSSize PositionSliderSize = {96, 15};

@interface DummyView : NSView


@end

@implementation DummyView

-(void)drawRect:(NSRect)rect
{
    [[NSColor whiteColor] setFill];
    NSRectFill(rect);
}

@end

@implementation MainWindow

- (AppController*)appController
{
    return self.delegate;
}

- (void)setupToolbar
{
    
    _positionSlider = [[PositionSlider alloc] initWithFrame:NSMakeRect(0, 0, PositionSliderSize.width, PositionSliderSize.height)];
    [_positionSlider setContinuous:NO];
    [_positionSlider setTarget:[[self appController] valueForKey:@"playbackController"]];
    [_positionSlider setAction:@selector(seek:)];
    [_positionSlider setMaxValue:0];
    NSSliderCell* cell = _positionSlider.cell;
    cell.controlSize = NSMiniControlSize;
    
    [_positionSlider bind:@"doubleValue" toObject:[[self appController] valueForKey:@"playbackController"] withKeyPath:@"position" options:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:YES],
      NSAllowsEditingMultipleValuesSelectionBindingOption,
      [NSNumber numberWithBool:YES],
      NSConditionallySetsEnabledBindingOption,
      nil ]];
    [_positionSlider bind:@"maxValue" toObject:[[self appController] valueForKey:@"currentEntryController"] withKeyPath:@"content.length" options:
     [NSDictionary dictionary]];
    [_positionSlider bind:@"enabled" toObject:[[self appController] valueForKey:@"playbackController"] withKeyPath:@"seekable" options:
     [NSDictionary dictionary]];
    
    NSToolbar* toolbar = [[[NSToolbar alloc] initWithIdentifier:MainToolbarIdentifier] autorelease];
    toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    toolbar.sizeMode = NSToolbarSizeModeRegular;
    toolbar.delegate = self;
    self.showsToolbarButton = NO;
    
    self.toolbar = toolbar;
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
	self = [super initWithContentRect:contentRect styleMask:windowStyle backing:bufferingType defer:deferCreation];
	if (self)
	{
		[self setExcludedFromWindowsMenu:YES];
        // TODO: 10.4
//		[self setContentBorderThickness:24.0 forEdge:NSMinYEdge];
	}
	
	return self;
}

- (void)awakeFromNib
{
//	if ([self hiddenDefaultsKey]) {
//		[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:[self hiddenDefaultsKey]]];
//	}
	[self setupToolbar];
//	[super awakeFromNib];
}

@end


@implementation MainWindow (NSToolbarDelegate)

-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:PlaybackButtonToolbarItemIdentifier,
//            DummyButtonToolbarItemIdentifier,
            NSToolbarSpaceItemIdentifier,
            VolumeButtonToolbarItemIdentifier,
            NSToolbarSpaceItemIdentifier,
            PositionToolbarItemIdentifier,
            CurrentTimeToolbarItemIdentifier,
            NSToolbarSpaceItemIdentifier,
            ShuffleButtonToolbarItemIdentifier,
            RepeatButtonToolbarItemIdentifier,
            NSToolbarSpaceItemIdentifier,
            InfoButtonToolbarItemIdentifier,
            FileTreeButtonToolbarItemIdentifier,
//            NSToolbarFlexibleSpaceItemIdentifier,
            nil];
}

-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
//    NSLog(@"itemForItemIdentifier %@", itemIdentifier);
    NSSize buttonSize = NSMakeSize(24, 25);
    NSToolbarItem* item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    if (itemIdentifier == PlaybackButtonToolbarItemIdentifier) {
        NSSize size = NSMakeSize(80, 25);
        PlaybackButtons* playbackButton = [[PlaybackButtons alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
        playbackButton.segmentCount = 3;
        item.view = playbackButton;
        [playbackButton setValue:[[self appController] valueForKey:@"playbackController"] forKey:@"playbackController"];
        NSSegmentedCell* cell = playbackButton.cell;
        cell.trackingMode = NSSegmentSwitchTrackingMomentary;
        cell.segmentCount = 3;
        NSArray* images = [NSArray arrayWithObjects:@"previous",
                           @"play",
                           @"next",
                           nil];
        int i;
        for (i = 0; i < 3; i++) {
            [cell setImage:[NSImage imageNamed:[images objectAtIndex:i]] forSegment:i];
            [cell setWidth:24 forSegment:i];
        }
        [playbackButton sizeToFit];
        [playbackButton awakeFromNib];
        [playbackButton release];
        
        [item setMaxSize:size];
        [item setMinSize:size];
        item.label = @"Playback Buttons";
    } else if (itemIdentifier == DummyButtonToolbarItemIdentifier) {
        item.label = @"Dummy";
        NSSize size = NSMakeSize(32, 32);
        item.view = [[[DummyView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)] autorelease];
        [item setMinSize:size];
        [item setMaxSize:size];
    } else if (itemIdentifier == VolumeButtonToolbarItemIdentifier) {
        item.label = @"Volume";
        VolumeButton* button = [[VolumeButton alloc] initWithFrame:NSMakeRect(0, 0, buttonSize.width, buttonSize.height)];
        [button setBezelStyle:NSTexturedRoundedBezelStyle];
        [button setImage:[NSImage imageNamed:@"volume_high"]];
        [button setValue:[[[self appController] valueForKey:@"playbackController"] valueForKey:@"volumeSlider"] forKey:@"_popView"];
        [item setView:button];
        [item setMinSize:buttonSize];
        [item setMaxSize:buttonSize];
    } else if (itemIdentifier == PositionToolbarItemIdentifier) {
        item.label = @"Position";
        [item setView:_positionSlider];
        [item setMinSize:PositionSliderSize];
        [item setMaxSize:NSMakeSize(10000, PositionSliderSize.height)];
    } else if (itemIdentifier == CurrentTimeToolbarItemIdentifier) {
        item.label = @"Current Time";
        NSSize size = NSMakeSize(38, 14);
        TimeField* timeField = [[TimeField alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
        timeField.stringValue = @"0:00";
        [timeField setEditable:NO];
        [timeField setSelectable:NO];
        [timeField setBordered:NO];
        [timeField setDrawsBackground:NO];
        [_positionSlider setValue:timeField forKey:@"positionTextField"];
        [item setView:timeField];
        [item setMinSize:size];
        [item setMaxSize:size];
    } else if (itemIdentifier == ShuffleButtonToolbarItemIdentifier) {
        item.label = @"Shuffle";
        NSButton* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, buttonSize.width, buttonSize.height)];
        [button setBezelStyle:NSTexturedRoundedBezelStyle];
        [button setImage:[NSImage imageNamed:@"shuffle_on"]];
        [button setTarget:[[self appController] valueForKey:@"playlistController"]];
        [button setAction:@selector(toggleShuffle:)];
        [button bind:@"image" toObject:[[self appController] valueForKey:@"playlistController"] withKeyPath:@"shuffle" options:
         [NSDictionary dictionaryWithObjectsAndKeys:@"ShuffleImageTransformer", NSValueTransformerNameBindingOption, nil ]];
        [item setView:button];
        [item setMinSize:buttonSize];
        [item setMaxSize:buttonSize];
    } else if (itemIdentifier == RepeatButtonToolbarItemIdentifier) {
        item.label = @"Repeat";
        NSButton* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, buttonSize.width, buttonSize.height)];
        [button setBezelStyle:NSTexturedRoundedBezelStyle];
        [button setImage:[NSImage imageNamed:@"repeat_none"]];
        [button setTarget:[[self appController] valueForKey:@"playlistController"]];
        [button setAction:@selector(toggleRepeat:)];
        [button bind:@"image" toObject:[[self appController] valueForKey:@"playlistController"] withKeyPath:@"repeat" options:
         [NSDictionary dictionaryWithObjectsAndKeys:@"RepeatModeImageTransformer", NSValueTransformerNameBindingOption, nil ]];
        [item setView:button];
        [item setMinSize:buttonSize];
        [item setMaxSize:buttonSize];
    } else if (itemIdentifier == InfoButtonToolbarItemIdentifier) {
        item.label = @"Info Inspector";
        NSButton* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, buttonSize.width, buttonSize.height)];
        [button setBezelStyle:NSTexturedRoundedBezelStyle];
        [button setImage:[NSImage imageNamed:@"info_off"]];
        [button setTarget:[[self appController] valueForKey:@"infoWindowController"]];
        [button setAction:@selector(toggleWindow:)];
        [[self appController] setValue:button forKey:@"infoButton"];
        [item setView:button];
        [item setMinSize:buttonSize];
        [item setMaxSize:buttonSize];
    } else if (itemIdentifier == FileTreeButtonToolbarItemIdentifier) {
        item.label = @"File Tree";
        NSButton* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, buttonSize.width, buttonSize.height)];
        [button setBezelStyle:NSTexturedRoundedBezelStyle];
        [button setImage:[NSImage imageNamed:@"files_off"]];
        [button setTarget:[[self appController] valueForKey:@"fileTreeViewController"]];
        [button setAction:@selector(toggleSideView:)];
        [[self appController] setValue:button forKey:@"fileButton"];
        [item setView:button];
        [item setMinSize:buttonSize];
        [item setMaxSize:buttonSize];
    }
    return item;
}

@end
