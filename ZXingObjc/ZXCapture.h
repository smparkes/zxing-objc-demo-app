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

#import "ZXCaptureDelegate.h"

#if !TARGET_IPHONE_SIMULATOR

#if TARGET_OS_EMBEDDED
	#include <AVFoundation/AVFoundation.h>
		#define ZX(x) x
		#define ZXAV(x) x
		#define ZXAVC(x) ,x
		#define ZXQT(x)
		#define ZXCaptureSession			AVCaptureSession
		#define ZXCaptureVideoPreviewLayer	AVCaptureVideoPreviewLayer
		#define ZXCaptureDeviceInput		AVCaptureDeviceInput
		#define ZXCaptureDevice				AVCaptureDevice 
		#define ZXCaptureVideoOutput		AVCaptureVideoDataOutput
	#else
		#import <QTKit/QTKit.h>
		#define ZX(x) x
		#define ZXAV(x)
		#define ZXAVC(x)
		#define ZXQT(x) x
		#define ZXCaptureSession			QTCaptureSession
		#define ZXCaptureVideoPreviewLayer	QTCaptureLayer
		#define ZXCaptureDevice				QTCaptureDevice
		#define ZXCaptureDeviceInput		QTCaptureDeviceInput
		#define ZXCaptureVideoOutput		QTCaptureDecompressedVideoOutput
	#endif

// this is support for "NOT TARGET_IPHONE_SIMULATOR"
@interface ZXCapture : NSObject ZX(<CAAction ZXAVC(AVCaptureVideoDataOutputSampleBufferDelegate)>) 
	{
	ZX(
	ZXCaptureVideoPreviewLayer* captureLayer;
	ZXCaptureSession*			captureSession;
	ZXCaptureDeviceInput*		captureInput;
	ZXCaptureDevice*			captureDevice;
	ZXCaptureVideoOutput*		captureOutput;
	id<ZXCaptureDelegate>		captureDelegate;
	)

	int			order_in_skip;
	int			order_out_skip;
	BOOL		zxRunning;
	BOOL		on_screen;
	BOOL		mirrorVideo;
	CALayer*	luminanceLayer;
	CALayer*	binaryLayer;
	size_t		width;
	size_t		height;
	size_t		reported_width;
	size_t		reported_height;
	NSString*	captureToFilename;
	BOOL		hard_stop;
	int			camera;
	BOOL		torch;
	int			deviceID;
	CGAffineTransform transform;
	}


@property (nonatomic, assign)	id<ZXCaptureDelegate>	captureDelegate;
@property (nonatomic, copy)		NSString*				captureToFilename;
@property (nonatomic)			CGAffineTransform		transform;
@property (nonatomic, readonly) ZXCaptureVideoOutput*	captureOutput;
@property (nonatomic, readonly) CALayer*				captureLayer;
@property (nonatomic, readonly) CALayer*				luminanceLayer;
@property (nonatomic, readonly) CALayer*				binaryLayer;

@property (nonatomic, retain)	ZXCaptureSession*		captureSession;
@property (nonatomic, retain)	ZXCaptureDeviceInput*	captureInput;
@property (nonatomic, retain)	ZXCaptureDevice*		captureDevice;


@property (nonatomic, readonly) BOOL	hasFront;
@property (nonatomic, readonly) BOOL	hasBack;
@property (nonatomic, readonly) BOOL	hasTorch;

@property (nonatomic, readonly) int		front;
@property (nonatomic, readonly) int		back;

@property (nonatomic)			int		camera;
@property (nonatomic)			BOOL	torch;
@property (nonatomic, assign)	BOOL	mirrorVideo;

- (id)		init;
- (void)	start;
- (void)	stop;
- (void)	start_stop;
- (void)	hard_stop;
- (void)	order_skip;
- (void)	replaceInput;
- (BOOL)	isRunning;

- (void)	setLuminanceBool:(BOOL)		on_off;
- (void)	setBinaryBool:(BOOL)		on_off;

- (CALayer*) layer;		// returns a QTCaptureLayer object

#if(TARGET_OS_MAC)
- (void) setupZXingCapture:(ZXCaptureDevice*)		 inDevice
				  delegate:(id<ZXCaptureDelegate>)	 inDelegate
					mirror:(BOOL)					 inMirrorMode;
#endif

@end

#else	// below is the support for the TARGET_IPHONE_SIMULATOR

@interface ZXCapture : NSObject 
	{
	}

@property (nonatomic,assign)	id<ZXCaptureDelegate>	captureDelegate;
@property (nonatomic,copy)		NSString*				captureToFilename;
@property (nonatomic)			CGAffineTransform		transform;

@property (nonatomic, retain)	ZXCaptureSession*		captureSession;
@property (nonatomic, retain)	ZXCaptureDeviceInput*	captureInput;
@property (nonatomic, retain)	ZXCaptureDevice*		captureDevice;

@property (nonatomic, readonly) void*					captureOutput;
@property (nonatomic, retain)   CALayer*				captureLayer;

@property (nonatomic, readonly) CALayer*				luminanceLayer;
@property (nonatomic, readonly) CALayer*				binaryLayer;

@property (nonatomic,readonly) BOOL						hasFront;
@property (nonatomic,readonly) BOOL						hasBack;
@property (nonatomic,readonly) BOOL						hasTorch;
@property (nonatomic,readonly) BOOL						mirrorVideo;

@property (nonatomic,readonly) int						front;
@property (nonatomic,readonly) int						back;

@property (nonatomic) int								camera;
@property (nonatomic) BOOL								torch;

- (id)		init;
- (void)	setLuminanceBool:(BOOL)	on_off;
- (void)	setBinaryBool:(BOOL)	on_off;
- (void)	start;
- (void)	stop;
- (void)	start_stop;
- (void)	hard_stop;
- (void)	order_skip;
- (BOOL)	isRunning;

- (CALayer*) captureLayer;

@end

#endif
