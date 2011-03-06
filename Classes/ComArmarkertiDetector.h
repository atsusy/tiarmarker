//
//  ComArmarkertiDetector.h
//  tiarmarker 
//
//  Created by KATAOKA,Atsushi on 11/02/15.
//  Copyright 2011 LANGRISE Co.,Ltd. All rights reserved.
//

#import <opencv/cv.h>
#import <UIKit/UIKit.h>

@interface Marker : NSObject {
	int code;
	CGPoint moment;
    CvMat *transform;
}

@property (nonatomic) int code;
@property (nonatomic) CGPoint moment;
@property (nonatomic, readonly) CvMat *transform;
@end

@interface ComArmarkertiDetector: NSObject {
	CGSize imageSize;
	
	CvMemStorage *contourStrage;
	CvMemStorage *polyStrage;
	IplImage *binaryImage;
	IplImage *contourImage;
	IplImage *detectedImage;
}

- (id)initWithCGSize:(CGSize)size;

- (NSArray *)detectWithinCGImageRef:(CGImageRef)image;
- (void)drawDetectedImage:(CGContextRef)context rect:(CGRect)rect;
@end
