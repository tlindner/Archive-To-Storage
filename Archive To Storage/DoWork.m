//
//  DoWork.m
//  Archive To Storage
//
//  Created by Tim on 3/9/12.
//  Copyright 2012 tim lindner. All rights reserved.
//

#import "DoWork.h"

void logString( NSString *log );
void logwindowf( char *formatString, ... );

@implementation DoWork

- (id)init {
    self = [super init];
    if (self) {
        executing = NO;
        finished = NO;
		convertingTask = nil;
		compressingTask = nil;
    }
    return self;
}

- (id)initWithString:(NSString *)data {
	if (self = [super init])
		directoryPath = [data retain];
	return self;
}

- (void)dealloc {
	[directoryPath release];
	[convertingTask release];
	[compressingTask release];
	[super dealloc];
}

- (void)start {
	
	// Always check for cancellation before launching the task.
	if ([self isCancelled])
	{
		// Must move the operation to the finished state if it is canceled.
		[self willChangeValueForKey:@"isFinished"];
		finished = YES;
		[self didChangeValueForKey:@"isFinished"];
		return;
	}
	
	// If the operation is not canceled, begin executing the task.
	[self willChangeValueForKey:@"isExecuting"];
	[NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
	executing = YES;
	[self didChangeValueForKey:@"isExecuting"];
}

-(void)main {
	@try {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		double last_value = 1.0;
		int convertingTaskTerminationStatus = -1;
		int compressingTaskTerminationStatus = -1;
		
		[[NSApp delegate] performSelectorOnMainThread:@selector(progressStart:) withObject:nil waitUntilDone:YES];
		[[NSApp delegate] performSelectorOnMainThread:@selector(setMaxProgress:) withObject:[NSNumber numberWithDouble:200.0] waitUntilDone:YES];
		
		
		NSString *currentDirectory = [[directoryPath stringByDeletingLastPathComponent] stringByExpandingTildeInPath];
		NSString *sourceDirectory = [[directoryPath lastPathComponent] stringByExpandingTildeInPath];
		NSString *tempImage = [sourceDirectory stringByAppendingString:@".tmp.dmg"];
		NSString *volumeName = sourceDirectory;
		NSString *finalImageName = [sourceDirectory stringByAppendingString:@".dmg"];

		/* Determine final image location */
		
		int Begining, Ending, jobValue = [tempImage intValue];
		Begining = jobValue / 1000 * 1000;
		
		if ( (jobValue % 1000) > 499)
		{
			Begining += 500;
		}
		
		Ending = Begining + 499;
		
		NSString *range = [NSString stringWithFormat:@"%d - %d", Begining, Ending];
		NSString *destination = @"/Volumes/RAID/STORAGE/";
		
		BOOL directoryExists, sucess;
		[[NSFileManager defaultManager] fileExistsAtPath:destination isDirectory:&directoryExists];
		
		if (directoryExists)
		{
			NSError *err = nil;
			destination = [destination stringByAppendingPathComponent:range];
			
			sucess = [[NSFileManager defaultManager] fileExistsAtPath:destination isDirectory:&directoryExists];
			
			if (sucess == NO) {
				sucess = [[NSFileManager defaultManager] createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:[NSDictionary dictionary] error:&err];
				
				if (!sucess) {
					
					logString([NSString stringWithFormat:@"Error creating range directory: %@\n\n%@\n\n", destination, err] );
					goto done;
				}
			}
			
			destination = [destination stringByAppendingPathComponent:finalImageName];
		}
		else
		{
			destination = finalImageName;
		}
		
		sucess = [[NSFileManager defaultManager] fileExistsAtPath:destination isDirectory:nil];
		
		if( sucess == YES )
		{
			logString([NSString stringWithFormat:@"\n\n%@\n\nFinal disk image already exists.\nAborting.\n\n", directoryPath] );
			goto done;
		}
		
		logString([NSString stringWithFormat:@"Creating disk image of %@\n", directoryPath]);
		/* /usr/bin/hdiutil create -srcfolder ${SRC} ${TMP} -volname ${DATE} */
		
		convertingTask = [[NSTask alloc] init];
		NSPipe *convertingPipe = [NSPipe pipe];
		NSFileHandle *readHandle = [convertingPipe fileHandleForReading];
		NSData *inData = nil;
		[convertingTask setLaunchPath:@"/usr/bin/hdiutil"];
		[convertingTask setStandardOutput:convertingPipe];
		[convertingTask setCurrentDirectoryPath:currentDirectory];
		[convertingTask setArguments:[NSArray arrayWithObjects:@"create",
								@"-puppetstrings",
								@"-anyowners",
								@"-srcfolder",
								sourceDirectory,
								tempImage,
								@"-volname",
								volumeName,
								nil]];
		[convertingTask launch];

		while( [convertingTask isRunning] )
		{
			inData = [readHandle availableData];
			
			if( inData && [inData length] != 0 )
			{
				NSString *output;
				double value;
				output = [[[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding] autorelease];
				
				if ([output hasPrefix:@"PERCENT:"])
				{
					value = [[output substringFromIndex:8] doubleValue];
					//logString([NSString stringWithFormat:@"double: %f\n", value]);
					
					if (value < last_value)
						value = last_value;
					else
						last_value = value;
					
					[[NSApp delegate] performSelectorOnMainThread:@selector(setDoubleProgress:) withObject:[NSNumber numberWithDouble:value] waitUntilDone:YES];
				}
				else
				{
					logString(output);
				}
			}
		}
		
		logString([NSString stringWithFormat:@"Converting task termination status: %d\n\n", [convertingTask terminationStatus]]);
		
		convertingTaskTerminationStatus = [convertingTask terminationStatus];
		[convertingTask release];
		convertingTask = nil;

		if( convertingTaskTerminationStatus == 0 )
		{
			/* /usr/bin/hdiutil convert ${TMP} -format UDBZ -o ${DMG} */
			
			logString([NSString stringWithFormat:@"Creating compressed disk image of %@ in %@\n", tempImage, destination]);
			compressingTask = [[NSTask alloc] init];
			NSPipe *compressingPipe = [NSPipe pipe];
			readHandle = [compressingPipe fileHandleForReading];
			[compressingTask setLaunchPath:@"/usr/bin/hdiutil"];
			[compressingTask setStandardOutput:compressingPipe];
			[compressingTask setCurrentDirectoryPath:currentDirectory];
			[compressingTask setArguments:[NSArray arrayWithObjects:@"convert",
										  tempImage,
										  @"-puppetstrings",
										  @"-format",
										  @"UDBZ",
										  @"-o",
										  destination,
										  nil]];
			[compressingTask launch];

			while( [compressingTask isRunning] )
			{
				inData = [readHandle availableData];
				
				if( inData && [inData length] != 0 )
				{
					NSString *output;
					double value;
					output = [[[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding] autorelease];
					
					if ([output hasPrefix:@"PERCENT:"])
					{
						value = [[output substringFromIndex:8] doubleValue] + 100.0;
						//logString([NSString stringWithFormat:@"double: %f\n", value]);
						
						if (value < last_value)
							value = last_value;
						else
							last_value = value;
						
						[[NSApp delegate] performSelectorOnMainThread:@selector(setDoubleProgress:) withObject:[NSNumber numberWithDouble:value] waitUntilDone:YES];
					}
					else
					{
						logString(output);
					}
				}
			}
			
			logString([NSString stringWithFormat:@"Compressing task termination status: %d\n", [compressingTask terminationStatus]]);
			
			NSError *err = nil;
			
			sucess = [[NSFileManager defaultManager] removeItemAtPath:[currentDirectory stringByAppendingPathComponent:tempImage] error:&err];
			
			if( sucess == NO )
			{
				logString(@"Error deleting temporary disk image.\n" );
			}
			
			compressingTaskTerminationStatus = [compressingTask terminationStatus];
			[compressingTask release];
			compressingTask = nil;
		}
		
		if( compressingTaskTerminationStatus == 0 && convertingTaskTerminationStatus == 0 )
		{
			NSError *err = nil;
			sucess = [[NSFileManager defaultManager] removeItemAtPath:directoryPath error:&err];
	
			if( sucess == NO )
			{
				logString([NSString stringWithFormat:@"Error deleting directory: %@\n\n%@\n\n", destination, err] );
			}
		}
		
	done:			
		[[NSApp delegate] performSelectorOnMainThread:@selector(progressDone:) withObject:nil waitUntilDone:YES];

		[self completeOperation];		
		[pool release];
		
	}
	@catch(...) {
		// Do not rethrow exceptions.
	}
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
	
    executing = NO;
    finished = YES;
	
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isConcurrent
{
	return YES;
}

- (BOOL)isExecuting {
    return executing;
}

- (BOOL)isFinished {
    return finished;
}

@end

void logString( NSString *log )
{
	[[NSApp delegate] performSelectorOnMainThread:@selector(logString:) withObject:log waitUntilDone:NO];
}

void logwindowf( char *formatString, ... )
{
    char result[4096];
    
	va_list args;
    va_start(args, formatString);
    vsnprintf(result, 4096, formatString, args);
    va_end(args);
    
    result[4095] = '\0';
    
	logString( [NSString stringWithCString:result encoding:NSMacOSRomanStringEncoding] );
}

