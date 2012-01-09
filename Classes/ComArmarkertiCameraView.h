//
//  ComArmarkertiCameraView.h
//  tiarmarker
//
//  Created by KATAOKA,Atsushi on 11/02/18.
//  Copyright 2011 MARSHMALLOW MACHINE. All rights reserved.
//

#import "TiUIView.h"
#import "ComArmarkertiDetector.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#if !TARGET_IPHONE_SIMULATOR
@interface ComArmarkertiCameraView : TiUIView <AVCaptureVideoDataOutputSampleBufferDelegate> {
#else
@interface ComArmarkertiCameraView : TiUIView {
#endif
    id session;
	id previewLayer;
	ComArmarkertiDetector *detector;
}

@end
