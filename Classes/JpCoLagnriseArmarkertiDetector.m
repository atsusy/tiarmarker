//
//  JpCoLangriseArmarkertiDetector.m
//  tiarmarker
//
//  Created by KATAOKA,Atsushi on 11/02/15.
//  Copyright 2011 LANGRISE Co.,Ltd. All rights reserved.
//

#import "JpCoLangriseArmarkertiDetector.h"

#define MARKER_SIZE			(82)
#define MARKER_OFFSET		(8)
#define MARKER_CELL_SIZE	(11)

static float intrinsic_values[] = {
    2.63201147e+03, 0.,             1.18882300e+03, 
    0.,             2.68470044e+03, 1.01778882e+03,
    0.,             0.,             1.
};	

static float distortion_values[] = {
    -8.89522210e-02, 1.18418604e-01, -1.61491688e-02, 6.88027870e-03
};

@implementation Marker
@synthesize code;
@synthesize moment;
@synthesize transform;

- (id)init
{
    self = [super init];
    if(self)
    {
        transform = cvCreateMat(4, 4, CV_32FC1);
    }
    return self;
}

- (void)setRotation:(CvMat *)rotationVec andTranslation:(CvMat *)translationVec
{
    CvMat *intrinsic = cvCreateMat(3, 3, CV_32FC1);
    CvMat *temp = cvCreateMat(3, 4, CV_32FC1);
    CvMat *rotation = cvCreateMat(3, 3, CV_32FC1);    

    cvRodrigues2(rotationVec, rotation, NULL);
    
    float z = translationVec->data.fl[2];
    if(z == 0.0f){ z = 1.0f; }
    
    for(int i = 0; i < 3; i++)
    {
        for(int j = 0; j < 3; j++)
        {
            temp->data.fl[i * 4 + j] = rotation->data.fl[i * 3 + j];
        }
        temp->data.fl[i * 4 + 3] = translationVec->data.fl[i];
    }
    
    for(int i = 0; i < 3 * 3; i++)
    {
        intrinsic->data.fl[i] = intrinsic_values[i] / z;
    }
    
    cvmMul(intrinsic, temp, temp);
    
    for(int row = 0; row < 3; row++)
    {
        for(int col = 0; col < 4; col++)
        {
            transform->data.fl[row * 4 + col] = temp->data.fl[row * 4 + col];
        }
    }
    
    transform->data.fl[4*2+3] = -1/z; //m34
    transform->data.fl[4*3+0] = 0;
    transform->data.fl[4*3+1] = 0;
    transform->data.fl[4*3+2] = 0;
    transform->data.fl[4*3+3] = 1;
    
    cvTranspose(transform, transform);
    
    cvReleaseMat(&intrinsic);
    cvReleaseMat(&temp);
    cvReleaseMat(&rotation);
}

- (void)dealloc
{
    cvReleaseMat(&transform);
    [super dealloc];
}

@end

@implementation JpCoLangriseArmarkertiDetector
- (id)initWithCGSize:(CGSize)size
{
	self = [super init];
	if(self)
	{
		imageSize = size;
		contourStrage = cvCreateMemStorage(0);
		polyStrage = cvCreateMemStorage(0);
  
		binaryImage = cvCreateImage(cvSize(size.width, size.height), IPL_DEPTH_8U, 1);
		contourImage = cvCreateImage(cvSize(size.width, size.height), IPL_DEPTH_8U, 1);
		detectedImage = cvCreateImage(cvSize(size.width, size.height), IPL_DEPTH_8U, 4);
	}
	return self;
}

- (void)dealloc
{
	cvReleaseMemStorage(&contourStrage);
	cvReleaseMemStorage(&polyStrage);	
    cvReleaseImage(&binaryImage);
	cvReleaseImage(&contourImage);
	cvReleaseImage(&detectedImage);
	[super dealloc];
}

#pragma mark OpenCV Support Methods

#pragma mark -
- (BOOL)detect:(IplImage *)image inRect:(CGRect)rect
{
	CvSize sz = cvGetSize(image);

    int cx = rect.origin.x + rect.size.width / 2;
    int cy = rect.origin.y + rect.size.height / 2;
    
    for(int y = -2; y <= 2; y++){
        for(int x = -2; x <= 2; x++){
            uchar *p = (uchar *)image->imageData + (sz.width - (cx + x)) + (sz.height-(cy + y)) * image->widthStep;
            if(*p < 10)
            {
                return false;
            }
        }
    }
    return true;
}

- (int)decode:(IplImage *)image degree:(int *)degree
{	
	double p1 = MARKER_OFFSET;
	double p2 = MARKER_SIZE - MARKER_CELL_SIZE - MARKER_OFFSET;
	
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
		if([self detect:image inRect:r])
		{
			*degree = i * 90;
			break;
		}
	}
	
	if(*degree < 0)
	{ 
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
			if([self detect:image
					 inRect:CGRectMake(sx, sy, MARKER_CELL_SIZE, MARKER_CELL_SIZE)])
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
	//NSLog(@"detected deg=%d code=%x", degree, code);
	return code;
}
								   
- (void)binarizeCGImageRef:(CGImageRef)src toIplImage:(IplImage *)dest
{
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
	CGContextRef contextRef = CGBitmapContextCreate(binaryImage->imageData, 
													binaryImage->width, 
													binaryImage->height,
													binaryImage->depth, 
													binaryImage->widthStep,
													colorSpace, 
													kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, 
					   CGRectMake(0, 0, CGImageGetWidth(src), CGImageGetHeight(src)), 
					   src);
	
	cvSmooth(dest, dest, CV_GAUSSIAN, 3, 0, 0, 0);
	cvThreshold(dest, dest, 0, 255, CV_THRESH_BINARY | CV_THRESH_OTSU);
	cvNot(dest, dest);
	
	CGContextRelease(contextRef);	
	CGColorSpaceRelease(colorSpace);
}

- (IplImage *)perspectivedMarkerImage:(IplImage *)image withFourPoints:(CvPoint *)points
{
	IplImage *markerImage = cvCreateImage(cvSize(MARKER_SIZE, MARKER_SIZE), IPL_DEPTH_8U, 1);

	CvMat srcMat;
	double srcPoints[4 * 2];
	for(int n = 0; n < 4; n++)
	{
		srcPoints[n * 2 + 0] = points[n].x;
		srcPoints[n * 2 + 1] = points[n].y;
	}
	srcMat = cvMat(4, 2, CV_64FC1, srcPoints);
	
	CvMat dstMat;
	double dstPoints[4 * 2];
	dstPoints[0] = 0;			dstPoints[1] = 0;
	dstPoints[2] = MARKER_SIZE;	dstPoints[3] = 0;
	dstPoints[4] = MARKER_SIZE;	dstPoints[5] = MARKER_SIZE;
	dstPoints[6] = 0;			dstPoints[7] = MARKER_SIZE;
	dstMat = cvMat(4, 2, CV_64FC1, dstPoints);
	
	CvMat *mapMatrix = cvCreateMat(3, 3, CV_64FC1);

	cvFindHomography(&srcMat, &dstMat, mapMatrix, 0, 0, 0);
	
	cvWarpPerspective(image, 
					  markerImage, 
					  mapMatrix, 
					  CV_INTER_LINEAR+CV_WARP_FILL_OUTLIERS, 
					  cvScalarAll(0));
	
	cvReleaseMat(&mapMatrix);
	
	return markerImage;
}

- (NSArray *)detectWithinCGImageRef:(CGImageRef)image
{
    CvMat intrinsic, distortion;
    cvInitMatHeader(&intrinsic, 3, 3, CV_32FC1, intrinsic_values, CV_AUTOSTEP);
    cvInitMatHeader(&distortion,1, 4, CV_32FC1, distortion_values, CV_AUTOSTEP);

	NSMutableArray *result = [[[NSMutableArray alloc] init] autorelease];

	// 2値画像を生成する
	[self binarizeCGImageRef:image toIplImage:binaryImage];

	// 輪郭画像は2値画像のコピー
	cvCopy(binaryImage, contourImage, NULL);
	
	// デバッグ用画像は２値画像をRGBA形式に変換しておく
	cvCvtColor(binaryImage, detectedImage, CV_GRAY2RGBA);
	
	// 輪郭を抽出する
	CvSeq *firstContour = NULL;
	cvClearMemStorage(contourStrage);
	int contourCount = cvFindContours(contourImage, 
									  contourStrage, 
									  &firstContour, 
									  sizeof(CvContour), 
									  CV_RETR_CCOMP, 
									  CV_CHAIN_APPROX_SIMPLE, 
									  cvPoint(0,0));
	
	// 輪郭を検出しなかった
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
									  8,
									  0);
			// 輪郭の形状が四角形である
			if(vsp->total == 4)
			{
				// マーカー画像を生成する
				CvPoint p[4];
				for(int n = 0; n < 4; n++)
				{
					p[n] = *CV_GET_SEQ_ELEM(CvPoint, vsp, n);
				}
				IplImage *markerImage = [self perspectivedMarkerImage:binaryImage
													   withFourPoints:p];
									
				// マーカー画像からコードを検出する
				int degree;
				int code = [self decode:markerImage degree:&degree];
				if(code >= 0)
				{
					cvDrawContours(detectedImage, 
								   s->v_next, 
								   cvScalar(255,0,255,255), 
								   cvScalar(255,255,0,255), 
								   1, 
								   2, 
								   CV_AA, 
								   cvPoint (0, 0));
					
					CvPoint3D32f baseMarkerPoints[4];					
					baseMarkerPoints[0].x =(float)0 * MARKER_SIZE;
					baseMarkerPoints[0].y =(float)0 * MARKER_SIZE;
					baseMarkerPoints[0].z = 0.0;
					
					baseMarkerPoints[1].x =(float)1 * MARKER_SIZE;
					baseMarkerPoints[1].y =(float)0 * MARKER_SIZE;
					baseMarkerPoints[1].z = 0.0;
					
					baseMarkerPoints[2].x =(float)1 * MARKER_SIZE;
					baseMarkerPoints[2].y =(float)1 * MARKER_SIZE;
					baseMarkerPoints[2].z = 0.0;
					
					baseMarkerPoints[3].x =(float)0 * MARKER_SIZE;
					baseMarkerPoints[3].y =(float)1 * MARKER_SIZE;
					baseMarkerPoints[3].z = 0.0;
					
					CvPoint2D32f src_pnt[4];
					if(degree==0)
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
					if(degree==90)
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
					if(degree==180)
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
					if(degree==270)
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
					
					CvMat object_points;
					CvMat image_points;
					CvMat *rotation = cvCreateMat(1, 3, CV_32FC1);
					CvMat *translation = cvCreateMat(1 , 3, CV_32FC1);
					CvMat *srcPoints3D = cvCreateMat(4, 1, CV_32FC3);
					CvMat *dstPoints2D = cvCreateMat(4, 1, CV_32FC3);

					srcPoints3D->data.fl[0]  = 0;
					srcPoints3D->data.fl[1]  = 0;
					srcPoints3D->data.fl[2]  = 0;
					srcPoints3D->data.fl[3]  = (float)MARKER_SIZE;
					srcPoints3D->data.fl[4]  = 0;
					srcPoints3D->data.fl[5]  = 0;
					srcPoints3D->data.fl[6]  = 0;
					srcPoints3D->data.fl[7]  = (float)MARKER_SIZE;
					srcPoints3D->data.fl[8]  = 0;
					srcPoints3D->data.fl[9]  = 0;
					srcPoints3D->data.fl[10] = 0;
					srcPoints3D->data.fl[11] = -(float)MARKER_SIZE;;

					cvInitMatHeader(&image_points, 4, 1, CV_32FC2, src_pnt, CV_AUTOSTEP);
					cvInitMatHeader(&object_points, 4, 3, CV_32FC1, baseMarkerPoints, CV_AUTOSTEP);
					
					cvFindExtrinsicCameraParams2(&object_points,
                                                 &image_points,
                                                 &intrinsic,
                                                 &distortion,
                                                 rotation,
                                                 translation,
                                                 0);	
                    
					cvProjectPoints2(srcPoints3D,
                                     rotation,
                                     translation,
                                     &intrinsic,
                                     &distortion,
                                     dstPoints2D,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     0);					

					Marker *m = [[[Marker alloc] init] autorelease];
					m.code = code;
					
                    m.moment = CGPointMake((p[0].x + p[1].x + p[2].x + p[3].x) / 4,
										   (p[0].y + p[1].y + p[2].y + p[3].y) / 4);
                    
                    [m setRotation:rotation andTranslation:translation];
                    
                    CvPoint pt1 = cvPoint(dstPoints2D->data.fl[0], dstPoints2D->data.fl[1]);
                    CvPoint pt2;
                    for(int i = 1; i < 4; i++){
                        pt2 = cvPoint(dstPoints2D->data.fl[i*3+0], dstPoints2D->data.fl[i*3+1]);
                        cvLine(detectedImage, pt1, pt2, cvScalar(i==1?255:0, i==2?255:0, i==3?255:0, 255), 2, 8, 0);
                    }
                    
					cvReleaseMat(&rotation);
					cvReleaseMat(&translation);
					cvReleaseMat(&srcPoints3D);
					cvReleaseMat(&dstPoints2D);
					
					[result addObject:m];
				}
				
				cvReleaseImage(&markerImage);
			}
		}
	}
	
	return result;
}

- (void)drawDetectedImage:(CGContextRef)context rect:(CGRect)rect
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSData *data = [NSData dataWithBytes:detectedImage->imageData
								  length:detectedImage->imageSize];
	
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

	CGImageRef imageRef = CGImageCreate(detectedImage->width,
										detectedImage->height,
										detectedImage->depth,
										detectedImage->depth * detectedImage->nChannels,
										detectedImage->widthStep,
										colorSpace,
										kCGBitmapByteOrderDefault,
										provider,
										NULL,
										false,
										kCGImageAlphaLast | kCGRenderingIntentDefault);
	CGContextDrawImage(context, rect, imageRef);

	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	CGImageRelease(imageRef);
	
	[pool release];
}

@end
