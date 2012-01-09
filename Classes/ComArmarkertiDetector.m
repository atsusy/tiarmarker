//
//  ComArmarkertiDetector.m
//  tiarmarker
//
//  Created by KATAOKA,Atsushi on 11/02/15.
//  Copyright 2011 MARSHMALLOW MACHINE. All rights reserved.
//

#import "ComArmarkertiDetector.h"

#define MARKER_SIZE             (82)
#define MARKER_OFFSET           (8)
#define MARKER_CELL_SIZE        (11)
#define MARKER_THRESHOLD        (55)
#define CONTOURSIMG_INTERLACE   (1)

@implementation Marker
@synthesize code;
@synthesize rotation_x;
@synthesize rotation_y;
@synthesize rotation_z;
@synthesize translation_x;
@synthesize translation_y;
@synthesize translation_z;
@synthesize transform;

static float intrinsic_values[9];
static float distortion_values[4] = { 0.f, 0.f, 0.f, 0.f };

- (void)dealloc
{
    [super dealloc];
}
@end

@implementation ComArmarkertiDetector

- (id)initWithCGSize:(CGSize)size 
      andFocalLength:(float)focalLength 
               andFx:(float)fx 
               andFy:(float)fy;
{
	self = [super init];
	if(self)
	{
		imageSize = size;
		contourStrage = cvCreateMemStorage(0);
		polyStrage = cvCreateMemStorage(0);
        
        intrinsic_values[0] = size.width*focalLength/fx;
        intrinsic_values[1] = 0.0f;
        intrinsic_values[2] = size.width/2.0f;
        intrinsic_values[3] = 0.0f;
        intrinsic_values[4] = size.height*focalLength/fy;
        intrinsic_values[5] = size.height/2.0f;
        intrinsic_values[6] = 0.0f;
        intrinsic_values[7] = 0.0f;
        intrinsic_values[8] = 1.0f;
        
        intrinsic = cvCreateMat(3, 3, CV_32FC1);
        for(int i = 0; i < 3 * 3; i++){
            intrinsic->data.fl[i] = intrinsic_values[i];
        }
        
        distortion = cvCreateMat(1, 4, CV_32FC1);
        for(int i = 0; i < 4; i++){
            distortion->data.fl[i] = distortion_values[i];
        }
        
		binaryImage = cvCreateImage(cvSize(size.width, size.height), IPL_DEPTH_8U, 1);
		contourImage = cvCreateImage(cvSize((int)size.width >> CONTOURSIMG_INTERLACE,
                                            (int)size.height >> CONTOURSIMG_INTERLACE),
                                     IPL_DEPTH_8U, 
                                     1);
    }
	return self;
}

- (void)dealloc
{
	cvReleaseMemStorage(&contourStrage);
	cvReleaseMemStorage(&polyStrage);
	cvReleaseMat(&intrinsic);
    cvReleaseMat(&distortion);
	cvReleaseImage(&binaryImage);
	cvReleaseImage(&contourImage);
	[super dealloc];
}

#pragma mark -
- (BOOL)detect:(IplImage *)image inRect:(CGRect)rect withHomography:(CvMat *)homography
{
    int cx = rect.origin.x + rect.size.width / 2;
    int cy = rect.origin.y + rect.size.height /2;
    
    float x = homography->data.fl[0]*cx + homography->data.fl[1]*cy + homography->data.fl[2];
    float y = homography->data.fl[3]*cx + homography->data.fl[4]*cy + homography->data.fl[5];
    float w = homography->data.fl[6]*cx + homography->data.fl[7]*cy + homography->data.fl[8];
    cx = (int)(x / w);
    cy = (int)(y / w);
    
    uchar *p = (uchar *)image->imageData + cx + cy * image->widthStep;
    
    return *p > 1;    
}

- (CvMat *)createHomographyMatrix:(CvPoint *)src To:(CvPoint *)dst
{
	CvMat srcMat;
	CvMat dstMat;
    
	float dstPoints[4 * 2];
	float srcPoints[4 * 2];
	for(int n = 0; n < 4; n++)
	{
		srcPoints[n * 2 + 0] = src[n].x;
		srcPoints[n * 2 + 1] = src[n].y;
        
        dstPoints[n * 2 + 0] = dst[n].x;
        dstPoints[n * 2 + 1] = dst[n].y;
	}
	srcMat = cvMat(4, 2, CV_32FC1, srcPoints);
	dstMat = cvMat(4, 2, CV_32FC1, dstPoints);
	
	CvMat *mapMatrix = cvCreateMat(3, 3, CV_32FC1);
    
	cvFindHomography(&srcMat, &dstMat, mapMatrix, 0, 0, 0);
  	
	return mapMatrix;
}

- (int)decodeMarker:(CvPoint *)cornerPoints degreeIs:(int *)degree
{	
	float p1 = MARKER_OFFSET;
	float p2 = MARKER_SIZE - MARKER_CELL_SIZE - MARKER_OFFSET;
	
    CvPoint src[4] = {
        {0,             0},
        {MARKER_SIZE,   0},
        {MARKER_SIZE,   MARKER_SIZE },
        {0,             MARKER_SIZE } 
    };
    CvMat *homography = (CvMat *)[self createHomographyMatrix:src To:cornerPoints];
    
	CGPoint corners[4]; 
	corners[0] = CGPointMake(p1, p1);
	corners[1] = CGPointMake(p2, p1);
	corners[2] = CGPointMake(p2, p2);
	corners[3] = CGPointMake(p1, p2);
	
	*degree = -1;
	for(int i = 0; i < 4; i++)
	{
		CGRect r = CGRectMake(corners[i].x, 
							  corners[i].y, 
							  MARKER_CELL_SIZE, 
							  MARKER_CELL_SIZE);
		if([self detect:binaryImage inRect:r withHomography:homography])
		{
			*degree = i * 90;
			break;
		}
	}
	
	if(*degree < 0)
	{ 
        cvReleaseMat(&homography);
		return -1; 
	}
	
	int sx, sy;
	int code = 0;
	for(int y = 0; y < 4; y++)
	{
		for(int x = 0; x < 4; x++)
		{
			sx = MARKER_OFFSET + MARKER_CELL_SIZE + x * MARKER_CELL_SIZE;
			sy = MARKER_OFFSET + MARKER_CELL_SIZE + y * MARKER_CELL_SIZE;
			if([self detect:binaryImage
					 inRect:CGRectMake(sx, sy, MARKER_CELL_SIZE, MARKER_CELL_SIZE)
             withHomography:homography])
			{		
				//NSLog(@"marked at (%d,%d)", x, y);
				switch(*degree){
					case 90:
						code |= 1 << ((3-x)*4+y);
						break;
					case 180:
						code |= 1 << ((3-y)*4+(3-x));
						break;
					case 270:
						code |= 1 << (x*4+(3-y));
						break;						
					default:
						code |= 1 << (y * 4 + x);
						break;
				}
			}
		}
	}	
    
    cvReleaseMat(&homography);
	//NSLog(@"detected deg=%d code=%x", *degree, code);
	return code;
}
	
- (void)binarize:(uint8_t *)rgba
{
    CvSize size = { imageSize.width, imageSize.height };
    
    IplImage *src = cvCreateImageHeader(size, IPL_DEPTH_8U, 4);
    src->imageData = (char *)rgba;
    
    IplImage *dst = binaryImage;
#ifdef _ARM_ARCH_7
    int pixels = size.width * size.height;
    char *src_ptr, *dst_ptr;
    
    src_ptr = src->imageData;
    dst_ptr = dst->imageData;
    
    __asm__ volatile (
        "lsr %2, %2, #3;"
        "mov r4, #77;"
        "mov r5, #151;"
        "mov r6, #28;"
        "vdup.8 d4, r4;"
        "vdup.8 d5, r5;"
        "vdup.8 d6, r6;"
        "vmov.u8 d8, #128;"
        "0:;"
        // load 8pixels
        "vld4.8 {d0-d3},[%1]!;"
        // gray scaling
        "vmull.u8 q7, d0, d4;"
        "vmlal.u8 q7, d1, d5;"
        "vmlal.u8 q7, d2, d6;"
        "vshrn.u16 d7, q7, #8;"
        // binarize (threshold is 128)
        "vcge.u8 d7, d8, d7;"
        "vst1.8 {d7},[%0]!;"	        
        // next 8pixels
        "subs %2,%2,#1;"
        "bne 0b;"
        :
        :"r"(dst_ptr),"r"(src_ptr),"r"(pixels)
        :"r4","r5","r6"
    );
#else
    cvCvtColor(src, dst, CV_RGBA2GRAY);
    cvThreshold(dst, dst, 128, 255, CV_THRESH_BINARY_INV);
#endif    
    
    cvReleaseImageHeader(&src);
}

- (NSArray *)detect:(uint8_t *)rgba
{
	NSMutableArray *result = [[[NSMutableArray alloc] init] autorelease];

	// generate binary image
    [self binarize:rgba];
    
    cvResize(binaryImage, contourImage, CV_INTER_NN);
	
	// find contours
	CvSeq *firstContour = NULL;
	cvClearMemStorage(contourStrage);
	int contourCount = cvFindContours(contourImage, 
									  contourStrage, 
									  &firstContour, 
									  sizeof(CvContour), 
									  CV_RETR_CCOMP, 
									  CV_CHAIN_APPROX_SIMPLE, 
									  cvPoint(0,0));
	
	// contours not found
	if(contourCount <= 0)
	{
		return nil;
	}

	for(CvSeq *s = firstContour; s != NULL; s = s->h_next)
	{        
		if(s->v_next != NULL)
		{
			// 輪郭をポリライン近似する
			cvClearMemStorage(polyStrage);
			CvSeq *vsp = cvApproxPoly(s->v_next,
									  sizeof(CvContour),
									  polyStrage,
									  CV_POLY_APPROX_DP,
									  4,
									  0);
			// 輪郭の形状が四角形である
			if(vsp->total == 4)
			{
				// マーカー画像を生成する
				CvPoint p[4];
				for(int n = 0; n < 4; n++)
				{
					p[n] = *CV_GET_SEQ_ELEM(CvPoint, vsp, n);
                    p[n].x = p[n].x << CONTOURSIMG_INTERLACE;
                    p[n].y = p[n].y << CONTOURSIMG_INTERLACE;
				}
                
				// マーカー画像からコードを検出する
				int degree;
				int code = [self decodeMarker:p degreeIs:&degree];
				if(code >= 0)
				{
					CvPoint3D32f baseMarkerPoints[4];		

					baseMarkerPoints[0].x =(float)-1 * MARKER_SIZE/2;
					baseMarkerPoints[0].y =(float)-1 * MARKER_SIZE/2;
					baseMarkerPoints[0].z = 0.0;
					
					baseMarkerPoints[1].x =(float) 1 * MARKER_SIZE/2;
					baseMarkerPoints[1].y =(float)-1 * MARKER_SIZE/2;
					baseMarkerPoints[1].z = 0.0;
					
					baseMarkerPoints[2].x =(float) 1 * MARKER_SIZE/2;
					baseMarkerPoints[2].y =(float) 1 * MARKER_SIZE/2;
					baseMarkerPoints[2].z = 0.0;
					
					baseMarkerPoints[3].x =(float)-1 * MARKER_SIZE/2;
					baseMarkerPoints[3].y =(float) 1 * MARKER_SIZE/2;
					baseMarkerPoints[3].z = 0.0;

					CvPoint2D32f src_pnt[4];
					if(degree==0)
					{
						src_pnt[0].x=p[0].x;
						src_pnt[0].y=p[0].y;
						src_pnt[1].x=p[1].x;
						src_pnt[1].y=p[1].y;
						src_pnt[2].x=p[2].x;
						src_pnt[2].y=p[2].y;
						src_pnt[3].x=p[3].x;
						src_pnt[3].y=p[3].y;
					}
                    
					if(degree==90)
					{
						src_pnt[0].x=p[1].x;
						src_pnt[0].y=p[1].y;
						src_pnt[1].x=p[2].x;
						src_pnt[1].y=p[2].y;
						src_pnt[2].x=p[3].x;
						src_pnt[2].y=p[3].y;
						src_pnt[3].x=p[0].x;
						src_pnt[3].y=p[0].y;
					}
                    
					if(degree==180)
					{
						src_pnt[0].x=p[2].x;
						src_pnt[0].y=p[2].y;
						src_pnt[1].x=p[3].x;
						src_pnt[1].y=p[3].y;
						src_pnt[2].x=p[0].x;
						src_pnt[2].y=p[0].y;
						src_pnt[3].x=p[1].x;
						src_pnt[3].y=p[1].y;
					}
                    
					if(degree==270)
					{
						src_pnt[0].x=p[3].x;
						src_pnt[0].y=p[3].y;
						src_pnt[1].x=p[0].x;
						src_pnt[1].y=p[0].y;
						src_pnt[2].x=p[1].x;
						src_pnt[2].y=p[1].y;
						src_pnt[3].x=p[2].x;
						src_pnt[3].y=p[2].y;
					}
					
					CvMat object_points;
					CvMat image_points;
					CvMat *rotation     = cvCreateMat(1, 3, CV_32FC1);
					CvMat *translation  = cvCreateMat(1, 3, CV_32FC1);
					CvMat *srcPoints3D  = cvCreateMat(4, 1, CV_32FC3);
					CvMat *dstPoints2D  = cvCreateMat(4, 1, CV_32FC2);
                    
					cvInitMatHeader(&image_points, 4, 1, CV_32FC2, src_pnt, CV_AUTOSTEP);
					cvInitMatHeader(&object_points, 4, 1, CV_32FC3, baseMarkerPoints, CV_AUTOSTEP);
					
                	cvFindExtrinsicCameraParams2(&object_points,&image_points,intrinsic,distortion,rotation,translation,0);	
                    
					Marker *m = [[[Marker alloc] init] autorelease];
                    
					m.code = code;

                    m.rotation_x = rotation->data.fl[0];
                    m.rotation_y = rotation->data.fl[1];
                    m.rotation_z = rotation->data.fl[2];
                    
                    m.translation_x = translation->data.fl[0];
                    m.translation_y = translation->data.fl[1];
                    m.translation_z = translation->data.fl[2];
                    
                    cvReleaseMat(&rotation);
					cvReleaseMat(&translation);
					cvReleaseMat(&srcPoints3D);
					cvReleaseMat(&dstPoints2D);
                    
                    [result addObject:m];
                }
			}
		}
	}
    return result;
}
@end
