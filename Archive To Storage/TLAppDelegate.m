//
//  TLAppDelegate.m
//  Archive To Storage
//
//  Created by Tim on 1/16/13.
//  Copyright 2013 tim lindner. All rights reserved.
//

#import "TLAppDelegate.h"
#import "DoWork.h"

NSOperationQueue* aQueue;
NSDate *dateStarted;

@implementation TLAppDelegate

@synthesize window;
@synthesize logView;
@synthesize progress;
@synthesize logWindow;
@synthesize timeView;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
	m = asl_new(ASL_TYPE_MSG);
	
	if( m == NULL )
	{
		NSLog( @"Could not open logging facility" );
	}
	else
	{
		asl_set(m, ASL_KEY_FACILITY, "org.macmess.ArchiveToStorage");
	}
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	if( aQueue == nil ) aQueue = [[NSOperationQueue alloc] init];
	[aQueue setMaxConcurrentOperationCount:1];
	[aQueue setSuspended:YES];
	
	for (NSString *filename in filenames)
	{
		DoWork *theOp = [[[DoWork alloc] initWithString:filename] autorelease];
		
		[aQueue addOperation:theOp];
	}
	
	[aQueue setSuspended:NO];
	
	NSUInteger count = [[aQueue operations] count];
	[window setTitle:[NSString stringWithFormat:@"Archive To Storage — %ld Queued Item%s", (long)count, count > 1 ? "s" : ""]];
}

- (void)setMaxProgress:(id)max
{
	NSNumber *number = max;
	
	[progress setMaxValue:[number doubleValue]];
	[progress setDoubleValue:0.0];
}

- (void)incrementProgress:(id)unused
{
	[progress incrementBy:1.0];	
}

- (void)setDoubleProgress:(NSNumber *)value
{
	[progress setDoubleValue:[value doubleValue]];
}

- (void)progressStart:(id)Unused
{
	[dateStarted release];
	dateStarted = [[NSDate alloc] init];
	[timeView setStringValue:@"Calculating…"];
	
	[self performSelector:@selector(updateRemainingTime:) withObject:nil afterDelay:1.5];
}

- (void)progressDone:(id)unused
{
	[progress setDoubleValue:[progress maxValue]];
	[dateStarted release];
	dateStarted = nil;

	NSInteger count = [[aQueue operations] count];
	count--;
	
	if (count > 0)
	{
		[window setTitle:[NSString stringWithFormat:@"Archive To Storage — %ld Queued Item%s", (long)count, count > 1 ? "s" : ""]];
	}
	else {
		[window setTitle:@"Archive To Storage"];
	}
}

- (void)logString: (NSString *) log
{
	[[logView textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:log] autorelease]];
	
	if( logView.textStorage.length > 1 )
	{
		NSRange range = NSMakeRange(logView.textStorage.length - 1, 1);
		[logView scrollRangeToVisible:range];
	}
	
	asl_log(NULL, m, ASL_LEVEL_NOTICE, "%s", [log UTF8String]);

}

- (void)updateRemainingTime:(id)unused
{
	NSString *unit = @"seconds";
	NSTimeInterval checkAgain = 0.75;
	
	if( [progress doubleValue] == [progress maxValue] )
	{
		[timeView setStringValue:@"Done."];
		return;
	}
	
	double count = [progress maxValue];
	double current = [progress	doubleValue];
	double percentDone = current/count;
	double timeTaken = [dateStarted timeIntervalSinceNow];
	double totalTime = timeTaken/percentDone;
	double timeLeft = timeTaken - totalTime;
	
	if( timeLeft > 60 * 60 * 24 )
	{
		unit = @"days";
		checkAgain = 60 * 60;
		timeLeft /= 60 * 60 * 12;
		if( timeLeft < 1.5f ) unit = @"day";
	}
	else if ( timeLeft > 60 * 60 )
	{
		unit = @"hours";
		checkAgain = 60;
		timeLeft /= 60 * 60;
		if( timeLeft < 1.5f ) unit = @"hour";
	}
	
	else if ( timeLeft > 60 )
	{
		unit = @"minutes";
		checkAgain = 1;
		timeLeft /= 60;
		
		if( timeLeft < 1.5f ) unit = @"minute";
	}
	else
	{
		if( timeLeft < 1.5f ) unit = @"second";
		
	}
	
	if( timeLeft < 0.5f ) unit = @"seconds";
	
	[timeView setStringValue:[NSString stringWithFormat:@"%.0f %@ remaining", timeLeft, unit]];
	
	[self performSelector:@selector(updateRemainingTime:) withObject:nil afterDelay:checkAgain];
	
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if (dateStarted != nil)
	{
		return  NSTerminateCancel;
	}
	else
	{
		return NSTerminateNow;
		asl_free( m );
	}
}


@end
