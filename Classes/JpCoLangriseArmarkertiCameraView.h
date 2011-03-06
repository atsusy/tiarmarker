//
//  JpCoLangriseArmarkertiCameraView.h
//  tiarmarker
//
//  Created by KATAOKA,Atsushi on 11/02/18.
//  Copyright 2011 Langrise Co.,Ltd. All rights reserved.
//

#import "TiUIView.h"
#import "JpCoLangriseArmarkertiDetector.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#if !TARGET_IPHONE_SIMULATOR
@interface JpCoLangriseArmarkertiCameraView : TiUIView <AVCaptureVideoDataOutputSampleBufferDelegate> {
#else
@interface JpCoLangriseArmarkertiCameraView : TiUIView {
#endif
	BOOL debug;
	JpCoLangriseArmarkertiDetector *detector;
	CGImageRef image;
	id overlay;
	KrollCallback *detected_handler;
}
	
@property (nonatomic, retain) id session;

@end
