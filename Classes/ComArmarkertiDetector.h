//
//  ComArmarkertiDetector.h
//  tiarmarker
//
//  Created by KATAOKA,Atsushi on 11/02/15.
//  Copyright 2011 MARSHMALLOW MACHINE. All rights reserved.
//

#import <opencv/cv.h>
#import <QuartzCore/CALayer.h>
#import <UIKit/UIKit.h>

@interface Marker : NSObject {
}

@property (nonatomic) int code;
@property (nonatomic) float rotation_x;
@property (nonatomic) float rotation_y;
@property (nonatomic) float rotation_z;

@property (nonatomic) float translation_x;
@property (nonatomic) float translation_y;
@property (nonatomic) float translation_z;

@property (nonatomic) CATransform3D transform;
@end

@interface ComArmarkertiDetector: NSObject {
	CGSize imageSize;
	
	CvMemStorage *contourStrage;
	CvMemStorage *polyStrage;

	CvMat *intrinsic;
    CvMat *distortion;
    
	IplImage *binaryImage;
	IplImage *contourImage;
}

- (id)initWithCGSize:(CGSize)size 
      andFocalLength:(float)focalLength 
               andFx:(float)fx 
               andFy:(float)fy;
- (NSArray *)detect:(uint8_t *)rgba;
@end
