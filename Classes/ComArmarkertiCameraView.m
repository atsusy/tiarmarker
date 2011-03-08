//
//  ComArmarkertiCameraView.m
//  tiarmarker
//
//  Created by KATAOKA,Atsushi on 11/02/18.
//  Copyright 2011 Langrise Co.,Ltd. All rights reserved.
//

#include <sys/types.h>
#include <sys/sysctl.h>

#import "ComArmarkertiCameraView.h"
#import "TiUtils.h"
#import "Ti3DMatrix.h"
#import "opencv/cv.h"

@implementation ComArmarkertiCameraView
@synthesize session;

- (void)setDebug_:(id)value 
{
	debug = [value boolValue];
}

- (void)setDetected_:(id)value
{
	RELEASE_TO_NIL(detected_handler);
	detected_handler = [value retain];
}

- (NSString *) platform
{
	size_t size;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	char *machine = malloc(size);
	sysctlbyname("hw.machine", machine, &size, NULL, 0);
	/*
	 Possible values:
	 "iPhone1,1" = iPhone 1G
	 "iPhone1,2" = iPhone 3G
	 "iPhone2,1" = iPhone 3GS
	 "iPod1,1"   = iPod touch 1G
	 "iPod2,1"   = iPod touch 2G
	 */
	NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
	
	free(machine);
	return platform;
}

- (void)startCapture
{			
#if !TARGET_IPHONE_SIMULATOR
	NSError *error = nil;
		
	// Create the session
	AVCaptureSession *_session = [[AVCaptureSession alloc] init];
		
	// Configure the session to produce lower resolution video frames, if your 
	// processing algorithm can cope. We'll specify medium quality for the
	// chosen device.
	_session.sessionPreset = AVCaptureSessionPresetMedium;
		
	// Find a suitable AVCaptureDevice
	AVCaptureDevice *device = [AVCaptureDevice
							   defaultDeviceWithMediaType:AVMediaTypeVideo];
		
	// Create a device input with the device and add it to the session.
	AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device 
																			error:&error];
	if (!input) {
		// Handling the error appropriately.
	}
	[_session addInput:input];
		
	// Create a VideoDataOutput and add it to the session
	AVCaptureVideoDataOutput *output = [[[AVCaptureVideoDataOutput alloc] init] autorelease];
	[_session addOutput:output];
		
	// Configure your output.
	dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
	[output setSampleBufferDelegate:self queue:queue];
	dispatch_release(queue);
		
	// Specify the pixel format
	output.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] 
													   forKey:(id)kCVPixelBufferPixelFormatTypeKey];
		
		
	// If you wish to cap the frame rate to a known value, such as 15 fps, set 
	// minFrameDuration.
	output.minFrameDuration = CMTimeMake(1, 15);
	
	// Start the session running to start the flow of data
	[_session startRunning];
		
	// Assign session to an ivar.
	[self setSession:_session];
#else
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not supported"
                                                    message:@"only works on device."
                                                   delegate:nil
                                          cancelButtonTitle:nil
                                          otherButtonTitles:@"OK", nil];
    [alert show];
#endif	
}

- (void)stopCapture
{
#if !TARGET_IPHONE_SIMULATOR
	[session stopRunning];
	RELEASE_TO_NIL(session);
#endif
}

- (CGImageRef)CGImageRotatedByAngle:(CGImageRef)imgRef angle:(CGFloat)angle
{
    CGFloat angleInRadians = angle * (M_PI / 180);
    CGFloat width = CGImageGetWidth(imgRef);
    CGFloat height = CGImageGetHeight(imgRef);
    
    CGRect imgRect = CGRectMake(0, 0, width, height);
    CGAffineTransform transform = CGAffineTransformMakeRotation(angleInRadians);
    CGRect rotatedRect = CGRectApplyAffineTransform(imgRect, transform);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bmContext = CGBitmapContextCreate(NULL,
                                                   rotatedRect.size.width,
                                                   rotatedRect.size.height,
                                                   8,
                                                   0,
                                                   colorSpace,
                                                   kCGImageAlphaPremultipliedFirst);
    CGContextSetInterpolationQuality(bmContext, kCGInterpolationNone);
    CGColorSpaceRelease(colorSpace);
    
    CGContextTranslateCTM(bmContext,
                          +(rotatedRect.size.width/2),
                          +(rotatedRect.size.height/2));
    CGContextRotateCTM(bmContext, angleInRadians);
    CGContextTranslateCTM(bmContext,
                          -(rotatedRect.size.height/2),
                          -(rotatedRect.size.width/2));
    
    CGContextDrawImage(bmContext, 
                       CGRectMake(0, 0,
                                  rotatedRect.size.height,
                                  rotatedRect.size.width),
                       imgRef);
    
    CGImageRef rotatedImage = CGBitmapContextCreateImage(bmContext);
    CGContextRelease(bmContext);
    
    return rotatedImage;
}

- (void)addSubview:(UIView *)view
{
    [super addSubview:view];
    view.layer.anchorPoint = CGPointMake(0.5f, 0.5f);
}

- (void)updateImage:(CGImageRef)rawImage
{	
	UIGraphicsBeginImageContext(CGSizeMake(self.bounds.size.height, self.bounds.size.width));
	
	[[UIImage imageWithCGImage:rawImage] drawInRect:CGRectMake(0, 0, self.bounds.size.height, self.bounds.size.width)];
	
	CGImageRef current = [UIGraphicsGetImageFromCurrentImageContext() CGImage];
	UIGraphicsEndImageContext();
	
	// Create a Quartz image from the pixel data in the bitmap graphics context
	if(image)
	{
		CGImageRelease(image);
	}
	image = [self CGImageRotatedByAngle:current angle:-90];
}

#if !TARGET_IPHONE_SIMULATOR
// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
	   fromConnection:(AVCaptureConnection *)connection 
{
	// Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
   
	// Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0); 
	
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    
	// Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer); 
	
    // Get the number of bytes per row for the pixel buffer
	uint8_t *baseAddress;
	if ([[self platform] isEqualToString:@"iPhone1,2"])
	{
		baseAddress = malloc( bytesPerRow * height );
		memcpy( baseAddress, CVPixelBufferGetBaseAddress(imageBuffer), bytesPerRow * height );
	}
	else
	{
		baseAddress = CVPixelBufferGetBaseAddress(imageBuffer); 
	}
	
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
	
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, 
												 width, 
												 height, 
												 8, 
												 bytesPerRow, 
												 colorSpace, 
												 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst); 
	CGImageRef temp = CGBitmapContextCreateImage(context);

	// Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
	
	// Update captured image.(UIGraphicsBeginImageContext not thread safe?)
	[self performSelectorOnMainThread:@selector(updateImage:) 
						   withObject:temp 
						waitUntilDone:YES];
   
	if (detector && detected_handler) 
	{
		NSMutableDictionary *args = [[NSMutableDictionary alloc] init];
		NSMutableArray *markers = [[NSMutableArray alloc] init];
		@synchronized(self)
		{
			for(Marker *marker in [detector detectWithinCGImageRef:image])
			{
				NSMutableDictionary *marker_dic = [[NSMutableDictionary alloc] init];
                              
                // code
                [marker_dic setValue:NUMINT(marker.code) forKey:@"code"];

                // moment
				[marker_dic setValue:[[[TiPoint alloc] initWithPoint:marker.moment] autorelease] forKey:@"moment"];
                
                // transform
                NSDictionary *marker_transform = [[NSDictionary alloc] initWithObjectsAndKeys:
                                                  NUMFLOAT(marker.transform->data.fl[0]), @"m11",
                                                  NUMFLOAT(marker.transform->data.fl[1]), @"m12",
                                                  NUMFLOAT(marker.transform->data.fl[2]), @"m13",
                                                  NUMFLOAT(marker.transform->data.fl[3]), @"m14",
                                                  NUMFLOAT(marker.transform->data.fl[4]), @"m21",
                                                  NUMFLOAT(marker.transform->data.fl[5]), @"m22",
                                                  NUMFLOAT(marker.transform->data.fl[6]), @"m23",
                                                  NUMFLOAT(marker.transform->data.fl[7]), @"m24",
                                                  NUMFLOAT(marker.transform->data.fl[8]), @"m31",
                                                  NUMFLOAT(marker.transform->data.fl[9]), @"m32",
                                                  NUMFLOAT(marker.transform->data.fl[10]),@"m33",
                                                  NUMFLOAT(marker.transform->data.fl[11]),@"m34",
                                                  NUMFLOAT(marker.transform->data.fl[12]),@"m41",
                                                  NUMFLOAT(marker.transform->data.fl[13]),@"m42",
                                                  NUMFLOAT(marker.transform->data.fl[14]),@"m43",
                                                  NUMFLOAT(marker.transform->data.fl[15]),@"m44",nil];

                [marker_dic setValue:marker_transform forKey:@"transform"];
                [marker_transform release];

				[markers addObject:marker_dic];
				[marker_dic release];
			}
		}
		[args setValue:markers forKey:@"markers"];
		[self.proxy _fireEventToListener:@"detected" 
							  withObject:args 
								listener:detected_handler 
							  thisObject:nil];
		[markers release];
		[args release];
	}

	[self performSelectorOnMainThread:@selector(setNeedsDisplay) 
						   withObject:nil 
						waitUntilDone:YES];

    CGImageRelease(temp);
	CGContextRelease(context); 
    CGColorSpaceRelease(colorSpace);
	if ([[self platform] isEqualToString:@"iPhone1,2"])
	{
		free(baseAddress);
	}	
}
#endif

- (void)drawRect:(CGRect)rect
{
	if(!image)
	{
		return;
	}
        
	CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect imageRect = CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image));

	CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        
    CGContextTranslateCTM(context, 0, CGImageGetHeight(image));
    CGContextScaleCTM(context, 1, -1);
		
    CGContextDrawImage(context, imageRect, image);
	if(debug)
	{
		[detector drawDetectedImage:context rect:imageRect];		
	}
	
	[super drawRect:rect];
}

-(void)frameSizeChanged:(CGRect)frame bounds:(CGRect)bounds 
{
	[super frameSizeChanged:frame bounds:bounds];
    RELEASE_TO_NIL(detector);
    detector = [[ComArmarkertiDetector alloc] initWithCGSize:bounds.size];    
}

-(void)dealloc 
{
	[self stopCapture];	
	CGImageRelease(image);
	
	RELEASE_TO_NIL(overlay);
	RELEASE_TO_NIL(detector);
	RELEASE_TO_NIL(detected_handler);
	
    [super dealloc];
}

@end
