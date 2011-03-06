//
//  JpCoLangriseArmarkertiCameraView.m
//  tiarmarker
//
//  Created by KATAOKA,Atsushi on 11/02/18.
//  Copyright 2011 Langrise Co.,Ltd. All rights reserved.
//

#import "JpCoLangriseArmarkertiCameraView.h"
#import "TiUtils.h"
#import "Ti3DMatrix.h"
#import "opencv/cv.h"

@implementation JpCoLangriseArmarkertiCameraView
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
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer); 
	
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    
	// Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer); 
	
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
	
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, 
												 width, 
												 height, 
												 8, 
												 bytesPerRow, 
												 colorSpace, 
												 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst); 

    CGImageRef current = CGBitmapContextCreateImage(context);
  
	// Create a Quartz image from the pixel data in the bitmap graphics context
	@synchronized(self)
	{
		if(image)
		{
			CGImageRelease(image);
		}
		image = [self CGImageRotatedByAngle:current angle:-90];
	}

    CGImageRelease(current);
   
	// Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
	
    CGSize sz = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
	if(!detector)
	{
		detector = [[JpCoLangriseArmarkertiDetector alloc] initWithCGSize:sz];
	}

	if (detected_handler) 
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
                CGPoint moment_ = CGPointMake(marker.moment.x * self.frame.size.width / sz.width, 
                                              marker.moment.y * self.frame.size.height / sz.height);
				[marker_dic setValue:[[[TiPoint alloc] initWithPoint:moment_] autorelease] forKey:@"moment"];
                
                // transform
                NSMutableDictionary *marker_transform = [[NSMutableDictionary alloc] init];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[0]) forKey:@"m11"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[1]) forKey:@"m12"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[2]) forKey:@"m13"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[3]) forKey:@"m14"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[4]) forKey:@"m21"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[5]) forKey:@"m22"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[6]) forKey:@"m23"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[7]) forKey:@"m24"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[8]) forKey:@"m31"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[9]) forKey:@"m32"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[10]) forKey:@"m33"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[11]) forKey:@"m34"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[12]) forKey:@"m41"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[13]) forKey:@"m42"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[14]) forKey:@"m43"];
                [marker_transform setValue:NUMFLOAT(marker.transform->data.fl[15]) forKey:@"m44"];

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
	
	CGContextRelease(context); 
    CGColorSpaceRelease(colorSpace);
}
#endif

- (void)drawRect:(CGRect)rect
{
	@synchronized(self)
	{
		if(!image)
		{
			return;
		}
		
		CGContextRef context = UIGraphicsGetCurrentContext();
        CGRect imageRect = CGRectMake(0, 0, rect.size.width, rect.size.height);

		CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        
        CGContextTranslateCTM(context, 0, CGImageGetHeight(image));
        CGContextScaleCTM(context, 1, -1);
		
        CGContextDrawImage(context, imageRect, image);
		if(debug)
		{
			[detector drawDetectedImage:context rect:imageRect];		
		}
	}
    [super drawRect:rect];
}

-(void)frameSizeChanged:(CGRect)frame bounds:(CGRect)bounds 
{
	[super frameSizeChanged:frame bounds:bounds];
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
