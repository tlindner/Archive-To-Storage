//
//  TLAppDelegate.h
//  Archive To Storage
//
//  Created by Tim on 1/16/13.
//  Copyright 2013 tim lindner. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <asl.h>

@interface TLAppDelegate : NSObject {
    NSWindow *window;
	NSWindow *logWindow;
	NSProgressIndicator *progress;
	NSTextView *logView;
	NSTextField *timeView;
	aslmsg m;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSWindow *logWindow;
@property (assign) IBOutlet NSTextView *logView;
@property (assign) IBOutlet NSTextField *timeView;
@property (assign) IBOutlet NSProgressIndicator *progress;

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames;
- (void)incrementProgress:(id)unused;
- (void)setMaxProgress:(id)max;
- (void)setDoubleProgress:(NSNumber *)value;
- (void)progressStart:(id)Unused;
- (void)progressDone:(id)unused;
- (void)logString: (NSString *) log;

@end
