//
//  DoWork.h
//  Archive To Storage
//
//  Created by Tim on 3/9/12.
//  Copyright 2012 tim lindner. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DoWork : NSOperation {

	NSString *directoryPath;
    BOOL        executing;
    BOOL        finished;
	
	NSTask		*convertingTask;
	NSTask		*compressingTask;
}

-(id)initWithString:(NSString *)data;
- (void)completeOperation;

@end
