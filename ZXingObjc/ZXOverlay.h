// ----------------------------------------------------------------------------------------
// 
// File: ZXOverlayView.h
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// ----------------------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import "ZXResult.h"

// ----------------------------------------------------------------------------------------

@interface ZXOverlay : CALayer 
	{
	CGPoint		pt0;
	CGPoint		pt1;
	CGPoint		pt2;
	NSRect		cropRect;
	}

// ----------------------------------------------------------------------------------------

@property (nonatomic, assign) CGPoint   pt0;
@property (nonatomic, assign) CGPoint   pt1;
@property (nonatomic, assign) CGPoint   pt2;
@property (nonatomic, assign) NSRect	cropRect;

// ----------------------------------------------------------------------------------------

- (id)		init;
- (void)	drawRect:(NSRect) inRect;
- (void)	plotPointsOnLayer:(ZXResult*) inResult;

@end

// ----------------------------------------------------------------------------------------