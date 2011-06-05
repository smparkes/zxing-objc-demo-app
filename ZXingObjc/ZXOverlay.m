// ----------------------------------------------------------------------------------------
// * Copyright 2009 Jeff Verkoeyen
// *
// * Licensed under the Apache License, Version 2.0 (the "License");
// * you may not use this file except in compliance with the License.
// * You may obtain a copy of the License at
// *
// *    http://www.apache.org/licenses/LICENSE-2.0
// *
// * Unless required by applicable law or agreed to in writing, software
// * distributed under the License is distributed on an "AS IS" BASIS,
// * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// * See the License for the specific language governing permissions and
// * limitations under the License.
//
// ----------------------------------------------------------------------------------------

#import "ZXOverlay.h"

static const CGFloat kPadding = 10;

#ifndef kREDCLOSE48pxPNG
#define kREDCLOSE48pxPNG @"close_RED_WHTX48px.png"
#endif

#ifndef kBRIGHTGREENCOLOR
#define kBRIGHTGREENCOLOR		CGColorCreateGenericRGB(0.3,1.0,0.4,1.0)
#endif

#ifndef kWHITEHAZECOLOR
#define kWHITEHAZECOLOR			CGColorCreateGenericRGB(1.0,1.0,1.0,0.35)
#endif

#ifndef kCLEARCOLOR
#define kCLEARCOLOR				CGColorCreateGenericRGB(1.0,1.0,1.0,0.0)
#endif


@implementation ZXOverlay

// ----------------------------------------------------------------------------------------

@synthesize cropRect;
@synthesize pt0;
@synthesize pt1;
@synthesize pt2;

// ----------------------------------------------------------------------------------------

- (id) init// WithRect:(CGRect)inRect  
	{
	self = [super init];
	
	if(nil != self) 
		{
		self.backgroundColor = kWHITEHAZECOLOR;
		}
		
	return(self);
	}
	
// ----------------------------------------------------------------------------------------

- (void) dealloc 
	{
	[super dealloc];
	}
	
// ----------------------------------------------------------------------------------------

- (void) plotPointsOnLayer:(ZXResult*) inResult
	{
	pt0		= [inResult resultPoint:0];
	pt1		= [inResult resultPoint:1];
	pt2		= [inResult resultPoint:2];

	[self setNeedsDisplay];

	//[self presentOverlayForPoints:point0 pt1:point1 pt2:point2];
	}

// ----------------------------------------------------------------------------------------
// the big square
/*
- (void) drawRect:(NSRect)inRect // inContext:(NSGraphicsContext*)context 
	{
	
	NSFrameRect(inRect);
	

	CGContextBeginPath(context);
	CGContextMoveToPoint(context, rect.origin.x, rect.origin.y);
	
	CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y);
	CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
	
	CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + rect.size.height);
	CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y);
	
	CGContextStrokePath(context);

	}
*/
// ----------------------------------------------------------------------------------------

- (CGPoint) map:(CGPoint) point 
	{
    CGPoint center;
    center.x		= cropRect.size.width/2;
    center.y		= cropRect.size.height/2;
    float x			= point.x - center.x;
    float y			= point.y - center.y;
    int rotation	= 90;
	
    switch(rotation) 
		{
		case 0:
			point.x = x;
			point.y = y;
		break;
		
		case 90:
			point.x = -y;
			point.y = x;
		break;
		
		case 180:
			point.x = -x;
			point.y = -y;
		break;
		
		case 270:
			point.x = y;
			point.y = -x;
		break;
		}
		
    point.x = point.x + center.x;
    point.y = point.y + center.y;
    return point;
	}

// ----------------------------------------------------------------------------------------

- (void) drawRect:(NSRect) rect			// CALayer
	{	
	/*	
	CGFloat rectSize1 = (rect.size.width  - kPadding * 2);
	CGFloat rectSize2 = (rect.size.height - kPadding * 2);
	cropRect = NSMakeRect(kPadding, kPadding, rectSize1, rectSize2);		
	
	NSGraphicsContext* ctx = [NSGraphicsContext currentContext];
	
	[NSGraphicsContext saveGraphicsState];
		
	[ctx setShouldAntialias:YES];
		
	NSRect smallSquare = NSMakeRect(0.0, 0.0, 12.0, 12.0);
		
	smallSquare.origin = NSMakePoint((cropRect.origin.x + pt0.x - smallSquare.size.width  / 2),
									 (cropRect.origin.y + pt0.y - smallSquare.size.height / 2));
	NSFrameRect(smallSquare);
	
	smallSquare.origin = NSMakePoint((cropRect.origin.x + pt1.x - smallSquare.size.width  / 2),
									 (cropRect.origin.y + pt1.y - smallSquare.size.height / 2));
	NSFrameRect(smallSquare);
	
	smallSquare.origin = NSMakePoint((cropRect.origin.x + pt2.x - smallSquare.size.width  / 2),
									 (cropRect.origin.y + pt2.y - smallSquare.size.height / 2));
	NSFrameRect(smallSquare);
	
	[NSGraphicsContext restoreGraphicsState];
	*/
	}

// ----------------------------------------------------------------------------------------

@end
