//
//  ComArmarkertiCameraView.m
//  tiarmarker
//
//  Created by KATAOKA,Atsushi on 11/02/18.
//  Copyright 2011 MARSHMALLOW MACHINE. All rights reserved.
//

#include <sys/types.h>
#include <sys/sysctl.h>
#import "opencv/cv.h"
#import "ComArmarkertiCameraView.h"
#import "TiUtils.h"

@implementation ComArmarkertiCameraView

#define IPHONE_CAMERA_FOCALLENGTH   (3.85f)
#define IPHONE_CAMERA_FX            (4.536f)
#define IPHONE_CAMERA_FY            (3.416f)

- (NSString *)platform
{
	size_t size;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	char *machine = malloc(size);
	sysctlbyname("hw.machine", machine, &size, NULL, 0);
	/*
	 Possible values:
	 "iPhone1,1" = iPhone 1G        NOT SUPPORTED
	 "iPhone1,2" = iPhone 3G
	 "iPhone2,1" = iPhone 3GS
     "iPhone3,1" = iPhone 4
	 "iPod1,1"   = iPod touch 1G    NOT SUPPORTED
	 "iPod2,1"   = iPod touch 2G    NOT SUPPORTED
     "iPod3,1"   = iPod touch 3G
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
	AVCaptureSession *_session  = [[AVCaptureSession alloc] init];
		
	// Configure the session to produce lower resolution video frames, if your 
	// processing algorithm can cope. We'll specify medium quality for the
	// chosen device.
	_session.sessionPreset = AVCaptureSessionPresetMedium;
		
	// Find a suitable AVCaptureDevice
	AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
		
	// Create a device input with the device and add it to the session.
	AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device 
                                                                        error:&error];
	if (!input) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Input device"
                                                        message:@"Failure to create input device."
                                                       delegate:nil
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"OK", nil];
        [alert show];
	}
	[_session addInput:input];
		
	// Create a VideoDataOutput and add it to the session
	AVCaptureVideoDataOutput *output = [[[AVCaptureVideoDataOutput alloc] init] autorelease];
	[_session addOutput:output];
    
	// Create preview layer.
	previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    [previewLayer setFrame:self.bounds];
	[previewLayer setVideoGravity:AVLayerVideoGravityResize];
    [previewLayer setZPosition:-1000000.0];
	[[self layer] insertSublayer:previewLayer atIndex:0];

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
    session = _session;
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

- (void)addSubview:(UIView *)view
{
    [super addSubview:view];
    view.layer.anchorPoint = CGPointMake(0.5f, 0.5f);
}

- (CvMat *)createProjectionZ:(CGFloat)z 
              andFocalLength:(CGPoint)focalLength 
                   andCenter:(CGPoint)center;
{
    CvMat *projection = cvCreateMat(4, 4, CV_32FC1);
    
    for(int i = 0; i < 4 * 4; i++)
    {
        projection->data.fl[i] = 0.0;
    }
    projection->data.fl[0]  = focalLength.x/z;
    projection->data.fl[2]  = center.x/z;
    projection->data.fl[5]  = focalLength.y/z;
    projection->data.fl[6]  = center.y/z;
    projection->data.fl[8]  = 1.0;
    projection->data.fl[14] = 1/z;
    
    return projection;
}

- (CvMat *)createMatrixRotationX:(float)rx Y:(float)ry Z:(float)rz
                 andTranslationX:(float)tx Y:(float)ty Z:(float)tz
{
    CvMat *matrix = cvCreateMat(4, 4, CV_32FC1);
    
    CvMat *rvec = cvCreateMat(1, 3, CV_32FC1);    
    CvMat *rotation = cvCreateMat(3, 3, CV_32FC1);    
    
    rvec->data.fl[0] = rx;
    rvec->data.fl[1] = ry;
    rvec->data.fl[2] = rz;
    
    cvRodrigues2(rvec, rotation, NULL);
    
    for(int i = 0; i < 3; i++)
    {
        for(int j = 0; j < 3; j++)
        {
            matrix->data.fl[i * 4 + j] = rotation->data.fl[i * 3 + j];
        }
    }
    matrix->data.fl[3]  = tx;
    matrix->data.fl[7]  = ty;
    matrix->data.fl[11] = tz;
    
    matrix->data.fl[12] = 0.0f;
    matrix->data.fl[13] = 0.0f;
    matrix->data.fl[14] = 0.0f;
    matrix->data.fl[15] = 1.0f;
    
    cvReleaseMat(&rotation);
    cvReleaseMat(&rvec);
    
    return matrix;
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

	if(detector == nil){
        detector = [[ComArmarkertiDetector alloc] initWithCGSize:CGSizeMake(width, height)
                                                  andFocalLength:IPHONE_CAMERA_FOCALLENGTH 
                                                           andFx:IPHONE_CAMERA_FX 
                                                           andFy:IPHONE_CAMERA_FY];    
    }
    
    NSArray *found = [detector detect:baseAddress];

	// Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
   
	if (detector) 
	{
		NSMutableDictionary *args = [[NSMutableDictionary alloc] init];
        NSMutableArray *markers = [[NSMutableArray alloc] init];
		@synchronized(self)
		{
            for(Marker *marker in found)
			{
                NSMutableDictionary *marker_dic = [[NSMutableDictionary alloc] init];

                [marker_dic setValue:NUMINT(marker.code) forKey:@"code"];                
                
                CvMat *transform = [self createMatrixRotationX:[marker rotation_x]
                                                             Y:[marker rotation_y] 
                                                             Z:[marker rotation_z] 
                                               andTranslationX:[marker translation_x]
                                                             Y:[marker translation_y]
                                                             Z:[marker translation_z]];
                CvMat *localworld = [self createMatrixRotationX:0.0
                                                              Y:0.0
                                                              Z:M_PI/2
                                                andTranslationX:0.0
                                                              Y:0.0
                                                              Z:0.0];            
                CGSize sz = self.bounds.size;
                CvMat *projection = [self createProjectionZ:[marker translation_z] 
                                             andFocalLength:CGPointMake(sz.width *IPHONE_CAMERA_FOCALLENGTH/IPHONE_CAMERA_FY, 
                                                                        sz.height*IPHONE_CAMERA_FOCALLENGTH/IPHONE_CAMERA_FX) 
                                                  andCenter:CGPointMake(sz.width/2, sz.height/2)];
                cvMatMul(localworld, transform, transform);
                cvMatMul(projection, transform, transform);
                
                cvTranspose(transform, transform);
                
                NSDictionary *marker_transform = [[NSDictionary alloc] initWithObjectsAndKeys:
                                                  NUMFLOAT(transform->data.fl[0]),  @"m11",
                                                  NUMFLOAT(transform->data.fl[1]),  @"m12",
                                                  NUMFLOAT(transform->data.fl[2]),  @"m13",
                                                  NUMFLOAT(transform->data.fl[3]),  @"m14",
                                                  NUMFLOAT(transform->data.fl[4]),  @"m21",
                                                  NUMFLOAT(transform->data.fl[5]),  @"m22",
                                                  NUMFLOAT(transform->data.fl[6]),  @"m23",
                                                  NUMFLOAT(transform->data.fl[7]),  @"m24",
                                                  NUMFLOAT(transform->data.fl[8]),  @"m31",
                                                  NUMFLOAT(transform->data.fl[9]),  @"m32",
                                                  NUMFLOAT(transform->data.fl[10]), @"m33",
                                                  NUMFLOAT(transform->data.fl[11]), @"m34",
                                                  NUMFLOAT(transform->data.fl[12]), @"m41",
                                                  NUMFLOAT(transform->data.fl[13]), @"m42",
                                                  NUMFLOAT(transform->data.fl[14]), @"m43",
                                                  NUMFLOAT(transform->data.fl[15]), @"m44",nil];
                
                [marker_dic setValue:marker_transform forKey:@"transform"];
                [marker_transform release];
                
                cvReleaseMat(&transform);
                cvReleaseMat(&localworld);
                cvReleaseMat(&projection);
                
                [markers addObject:marker_dic];
                [marker_dic release];
			}
		}
		
        [args setValue:markers forKey:@"markers"];
		[self.proxy fireEvent:@"detected" withObject:args];
        
		[markers release];
		[args release];
	}

	if ([[self platform] isEqualToString:@"iPhone1,2"])
	{
		free(baseAddress);
	}	
}
#endif

-(void)dealloc 
{
	[self stopCapture];	

    RELEASE_TO_NIL(session);
	RELEASE_TO_NIL(detector);
	
    [super dealloc];
}

@end
