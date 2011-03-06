//
//  ComArmarkertiCameraViewProxy.m
//  tiarmarker
//
//  Created by KATAOKA,Atsushi on 11/02/18.
//  Copyright 2011 Langrise Co.,Ltd. All rights reserved.
//

#import "ComArmarkertiCameraViewProxy.h"
#import "ComArmarkertiCameraView.h"

@implementation ComArmarkertiCameraViewProxy

- (void)show:(id)args 
{
    [[self view] performSelectorOnMainThread:@selector(show:) 
								  withObject:args 
							   waitUntilDone:NO];
}

- (void)windowDidOpen 
{
	[[self view] performSelectorOnMainThread:@selector(startCapture)
								  withObject:nil
							   waitUntilDone:NO];
	[super windowDidOpen];
}

- (void)windowDidClose
{
	[[self view] performSelectorOnMainThread:@selector(stopCapture)
								  withObject:nil
							   waitUntilDone:NO];
	[super windowDidClose];
}

- (void)dealloc
{
	[super dealloc];
}

@end
