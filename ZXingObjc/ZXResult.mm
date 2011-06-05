// -*- mode:objc; c-basic-offset:2; indent-tabs-mode:nil -*-
/*
 * Copyright 2011 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ZXResult.h"
#import <ZXing/ResultPoint.h>

using namespace zxing;

@implementation ZXResult

// ----------------------------------------------------------------------

- (ZXResult*)initWithNative:(zxing::Result*)result 
	{
	self = [super init];
	if (nil != self) 
		{
		native = result;
		}
	return self;
	}
	
// ----------------------------------------------------------------------

- (void)dealloc 
	{
	native = 0;
	[super dealloc];
	}
	
// ----------------------------------------------------------------------

- (CGPoint) resultPoint:(int) pointIndex
	{
	CGPoint thepoint = {0.0,0.0};
	
	size_t	pointsqty = native->getResultPoints().size();
	
	#ifdef __DEBUG_LOGGING__
	NSLog(@"ZXResult::resultPoints - resultPoints size is [%d] points", (int)pointsqty);
	#endif
	
	if(0 < pointsqty)
		{
		const std::vector<Ref<zxing::ResultPoint> > &resultPoints = native->getResultPoints();
		const Ref<zxing::ResultPoint> &rp = resultPoints[pointIndex];
		thepoint = CGPointMake(rp->getX(), rp->getY());
		}
		
	return(thepoint);
	}

// ----------------------------------------------------------------------

- (NSString*)text 
	{
	return [NSString stringWithCString:native->getText()->getText().c_str()
                            encoding:NSUTF8StringEncoding];
	}

// ----------------------------------------------------------------------

@end
