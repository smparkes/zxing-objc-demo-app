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

#import "ZXCapture.h"

#if !TARGET_IPHONE_SIMULATOR
#import "ZXCGImageLuminanceSource.h"
#import "ZXHybridBinarizer.h"
#import "ZXBinaryBitmap.h"
#import "ZXQRCodeReader.h"
#import "ZXDecodeHints.h"
#import "ZXResult.h"
#import "ZXReaderException.h"
#import "ZXIllegalArgumentException.h"

#if TARGET_OS_EMBEDDED || TARGET_IPHONE_SIMULATOR
#define ZXCaptureDevice AVCaptureDevice
#define ZXCaptureOutput AVCaptureOutput
#define ZXMediaTypeVideo AVMediaTypeVideo
#define ZXCaptureConnection AVCaptureConnection
#else
#define ZXCaptureOutput QTCaptureOutput
#define ZXCaptureConnection QTCaptureConnection
#define ZXCaptureDevice QTCaptureDevice
#define ZXMediaTypeVideo QTMediaTypeVideo
#endif

#ifndef kBLANKSTR
#define kBLANKSTR @""
#endif

@implementation ZXCapture

@synthesize captureDelegate;
@synthesize transform;
@synthesize captureToFilename;

@synthesize captureSession;
@synthesize captureInput;
@synthesize captureDevice;
@synthesize captureLayer;
@synthesize mirrorVideo;


// -------------------------------------------------------------------------------------------

- (ZXCapture*) init 
	{
	#ifdef __DEBUG_LOGGING__
	NSLog(@"ZXCapture::init - ENTER");
	#endif
	
	self = [super init];
	
	if (nil != self) 
		{
		on_screen		= NO;
		zxRunning		= NO;
		reported_width	= 0;
		reported_height = 0;
		width			= 640;
		height			= 480;
		hard_stop		= false;
		mirrorVideo		= NO;
		deviceID		= -1;
		order_in_skip	= 0;
		order_out_skip	= 0;
		transform		= CGAffineTransformIdentity;
		}
	return(self);
	}
	
// -------------------------------------------------------------------------------------------

- (BOOL) isRunning
	{
	return((YES == zxRunning) ? YES : NO);
	}

// -------------------------------------------------------------------------------------------

- (void) order_skip 
	{
	order_out_skip = 1;
	order_in_skip  = 1;
	}

// -------------------------------------------------------------------------------------------
// For iOS devices, this returns the default video device 
// for MacOS, it returns the SELECTED video device - assumed to have been SET elsewhere

- (ZXCaptureDevice*) captureDevice 
	{
	ZXCaptureDevice* result = nil;
	
	#if(TARGET_OS_MAC)
	
	// device is assumed having been provided by MacOS app
	result = captureDevice;	
			
	#else  // TARGET lives in iOS world
		
		#if ZXAV(1)+0
			NSArray* devicesArray = [ZXCaptureDevice ZXAV(devicesWithMediaType:)
								   ZXQT(inputDevicesWithMediaType:) ZXMediaTypeVideo];

			if ([devicesArray count] > 0) 
				{
				if (deviceID == -1) 
					{
					AVCaptureDevicePosition position = AVCaptureDevicePositionBack;
					if (camera == self.front) 
						{
						position = AVCaptureDevicePositionFront;
						}

				  for(unsigned int i=0; i < [devicesArray count]; ++i) 
					  {
					  ZXCaptureDevice* dev = [devicesArray objectAtIndex:i];
					  if (dev.position == position) 
							{
							deviceID = i;
							zxd = dev;
							break;
							}
						}
					}

				if (!zxd && deviceID != -1) 
					{
					result = [devicesArray objectAtIndex:deviceID];
					}
				}
		#else
			  result = [ZXCaptureDevice ZXAV(defaultDeviceWithMediaType:)
						ZXQT(defaultInputDeviceWithMediaType:) ZXMediaTypeVideo];
		#endif
	
	#endif
	
	return(result);
	}
	
// -----------------------------------------------------------------------

- (void) setupZXingCapture:(ZXCaptureDevice*)		inDevice
				   delegate:(id<ZXCaptureDelegate>) inDelegate
				     mirror:(BOOL)					inMirrormode
	{
	#ifdef __DEBUG_LOGGING__
	NSLog(@"ZXCapture::setupZXingCapture - ENTER - mirrorMode [%@]", 
		  ((YES == inMirrormode) ? @"YES":@"NO"));
	#endif
	
	[self stop];
	
	if(nil != captureDevice) // QTCaptureDevice
		{
		BOOL isOpen = [captureDevice isOpen];
		if(YES == isOpen)
			{
			[captureDevice close];
			}
		}
		
	[self setCaptureDevice:		inDevice];
	[self setCaptureDelegate:	inDelegate];
	[self setMirrorVideo:		inMirrormode];
	
	[self layer];	// this will cause CAAffineTransform to be modified and re-implemented
			
	// Set OUTPUT for SESSION HERE
	
	[self captureOutput];  // ZXCaptureVideoOutput*
	
	[self replaceInput];
	
	[self start];
	}
	
// ----------------------------------------------------------------------
// replace DEVICE may also be needed to be called - this is just the INPUT

- (void) replaceInput	
	{
	#ifdef __DEBUG_LOGGING__
	NSLog(@"ZXCapture::replaceInput - ENTER w/on_screen [%@]", ((YES == on_screen) ? @"YES" : @"NO"));
	#endif
	
	if(nil != captureSession) 
		{
		#ifdef __DEBUG_LOGGING__
		NSLog(@"ZXCapture::replaceInput - captureSession was not nil");
		#endif
		NSError* error = nil;
		
		if(YES == [captureSession isRunning])
			{
			[captureSession stopRunning];
			}
			
		ZXCaptureDevice* zxd = [self captureDevice];
		
		// below could also check... && (NO == [captureDevice isInUseByAnotherApplication])
		if((nil != captureDevice) && (NO == [captureDevice isOpen]))
			{
			ZXQT([zxd open:&error]);
			
			#if(TARGET_OS_MAC)
			if(nil != error)
				{
				[NSAlert alertWithError:error];
				}
			#endif
			}
		
		// again, could also check...  && (NO == [captureDevice isInUseByAnotherApplication])	
		if((nil != captureDevice) && (YES == [captureDevice isOpen]))
			{
			#ifdef __DEBUG_LOGGING__
			NSLog(@"ZXCapture::replaceInput - captureDevice is open");
			#endif
			
			[self setCaptureInput:[ZXCaptureDeviceInput deviceInputWithDevice:zxd ZXAV(error:&error)]];
			
			#if(TARGET_OS_MAC)
			if(nil != error)
				{
				[NSAlert alertWithError:error];
				}
			else
				{
				#ifdef __DEBUG_LOGGING__
				NSLog(@"ZXCapture::replaceInput - captureDevice added to CaptureInput");
				#endif
				}
			#endif
			
			if(nil != captureInput)
				{
				// [captureInput retain]; // ???
				[captureSession addInput:captureInput ZXQT(error:&error)];
				
				#if(TARGET_OS_MAC)
				if(nil != error)
					{
					[NSAlert alertWithError:error];
					}
				else
					{
					#ifdef __DEBUG_LOGGING__
					NSLog(@"ZXCapture::replaceInput - captureInput added to captureSession");
					#endif				
					}
				#endif
				}
			}
		#if(TARGET_OS_MAC)
		else
			{
			[NSAlert alertWithMessageText: @"Could not open the input captureDevice" 
							defaultButton: @"OK"		//defaultButton 
						  alternateButton: nil			//alternateButton 
						      otherButton: nil			//otherButton 
				informativeTextWithFormat: kBLANKSTR];	//format, ...;];
			}
		#endif
		}
	}
	
// ----------------------------------------------------------------------

- (ZXCaptureSession*) captureSession 
	{
	//#if(!TARGET_OS_MAC)
	if (nil == captureSession) 
		{
		captureSession = [[ZXCaptureSession alloc] init];
		ZXAV({captureSession.sessionPreset = AVCaptureSessionPresetMedium;});
		[self replaceInput];
		}
	//#endif
	return(captureSession);
	}

// ----------------------------------------------------------------------

- (void) stop 
	{
	// NSLog(@"ZXCapture::stop - ENTER");
	
	if(nil != captureSession)	// how could zxRunning be true if not?? 
		{
		if(YES == [captureSession isRunning])	// QTCaptureSession
			{
			#ifdef __DEBUG_LOGGING__
			NSLog(@"ZXCapture::stop - captureSession was running - will stop");
			#endif
			
			#if(TARGET_OS_MAC)
			
			if(nil != [captureSession inputs])
				{
				NSArray*  inputsarray = [captureSession inputs];
				if(nil != inputsarray)
					{
					NSInteger inputsCount = [inputsarray count];
					NSInteger dex;
					for(dex = 0; dex < inputsCount; dex++)	// QTCaptureDeviceInput
						{
						QTCaptureDeviceInput* theinput = [inputsarray objectAtIndex:dex];
						if(nil != theinput)
							{
							QTCaptureDevice* thedevice = [theinput device];
							if(nil != thedevice)
								{
								#ifdef __DEBUG_LOGGING__
								NSLog(@"ZXCapture::stop - remove input for device [%@]",[thedevice localizedDisplayName]);
			#endif
								[captureSession removeInput:theinput];
								}
							}
						}
					}
				}
				
			[captureSession stopRunning];
			
			#else
			if (true ZXAV(&& self.captureSession.running))   // TODO: not sure why this ZXAV is needed
				{
			[self.captureSession stopRunning];
			} 
			#endif
			}
		}
		
	zxRunning = false;
	}

// ----------------------------------------------------------------------

- (void) setOutputAttributes 
	{
    NSString* key	= (NSString*)kCVPixelBufferPixelFormatTypeKey; 
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]; 
	
    NSMutableDictionary* attributes = [NSMutableDictionary dictionaryWithObject:value forKey:key]; 
    
	key				= (NSString*)kCVPixelBufferWidthKey;
    value			= [NSNumber numberWithUnsignedInt:(int)width]; 
	
    [attributes setObject:value forKey:key]; 
    
	key				= (NSString*)kCVPixelBufferHeightKey;
    value			= [NSNumber numberWithUnsignedInt:(int)height];
	
    [attributes setObject:value forKey:key]; 
    
	[captureOutput ZXQT(setPixelBufferAttributes:)ZXAV(setVideoSettings:)attributes];
	}

// ----------------------------------------------------------------------

- (ZXCaptureVideoOutput*) captureOutput
	{
	#ifdef __DEBUG_LOGGING__
	NSLog(@"ZXCapture::captureOutput - ENTER");
	#endif

	if (nil == captureOutput) 
		{
		NSError* err = nil;
		captureOutput = [[ZXCaptureVideoOutput alloc] init];
		
		[self setOutputAttributes];
		
		[captureOutput ZXQT(setAutomaticallyDropsLateVideoFrames:)
					ZXAV(setAlwaysDiscardsLateVideoFrames:)YES];
					
		[captureOutput ZXQT(setDelegate:)ZXAV(setSampleBufferDelegate:)self
					ZXAV(queue:dispatch_get_main_queue())];
					
		[self.captureSession addOutput:captureOutput ZXQT(error:&err)]; // QTCaptureSession
		
		#ifdef __DEBUG_LOGGING__
		NSArray*  outs = [captureSession outputs];
		NSInteger qty  = 0;
		if(nil != outs) qty = [outs count];
		NSLog(@"ZXCapture::captureOutput - captureOutput created and added to session - qty of outputs[%d]", (int)qty);
		#endif
		
		#if(TARGET_OS_MAC)
		if(nil != err)
			{
			[NSAlert alertWithError:err];
			}
		#endif
		}
		
	return(captureOutput);
	}

// ----------------------------------------------------------------------

- (void) start 
	{
	// NSLog(@"start %@ %d %@ %@", self.captureSession, zxRunning, captureOutput, captureDelegate);

	if (YES == hard_stop) 
		{
		return;
		}

  if ((nil != captureDelegate) || (nil != luminanceLayer) || (nil != binaryLayer)) 
	  {
	  // for side effects
	  #if(!TARGET_OS_MAC)
	  [self captureOutput];	// MAcOSX API already has this working
	  #endif
	  }
    
	if (false ZXAV(|| self.captureSession.running)) 
		{
		// NSLog(@"already running");
		} 
	else 
		{
		static int i = 0;
		if (++i == -2) 
			{
			abort();
			}
			
		if(NO == [self.captureSession isRunning])
			{
			NSLog(@"ZXCapture::start - call start running");
			[self.captureSession startRunning];
			}
		}
	zxRunning = true;
	}

// -------------------------------------------------------------------------------------------

- (void) start_stop 
	{
	// NSLog(@"ss %d %@ %d %@ %@ %@", zxRunning, captureDelegate, on_screen, captureOutput, luminanceLayer, binaryLayer);
	
	if (((NO == zxRunning) && ((nil != captureDelegate) || (YES == on_screen))) ||
	    ((nil == captureOutput) && ((nil != captureDelegate) || ((YES == on_screen) && ((nil != luminanceLayer) || (nil != binaryLayer)))))) 
		{
		[self start];
		}
		
	if ((YES == zxRunning) && (nil != captureDelegate) && (NO == on_screen)) 
		{
		[self stop];
		}
	}

// -------------------------------------------------------------------------------------------

- (void)setDelegate:(id<ZXCaptureDelegate>)_delegate 
	{
	captureDelegate = _delegate;
	
	if (nil != captureDelegate) 
		{
		hard_stop = false;
		}
		
	[self start_stop];
	}

// -------------------------------------------------------------------------------------------

- (void)hard_stop 
	{
	hard_stop = true;
	
	if (zxRunning) 
		{
		[self stop];
		}
	}

// -------------------------------------------------------------------------------------------

- (void)setLuminanceBool:(BOOL)on 
	{
	if((YES == on) && (nil == luminanceLayer))
		{
		// [luminanceLayer release];
		luminanceLayer = [[CALayer layer] retain];
		} 
	else
		{
		if((NO == on) && (nil != luminanceLayer))
			{
			[luminanceLayer release];
			luminanceLayer = nil;
			}
		}
	}

// -------------------------------------------------------------------------------------------

- (CALayer*)luminanceLayer 
	{
	return(luminanceLayer);
	}

// -------------------------------------------------------------------------------------------

- (void)setBinaryBool:(BOOL) inOn	
	{
	if ((YES == inOn) && (nil == binaryLayer)) 
		{
		binaryLayer = [[CALayer layer] retain];
		} 
	else 
		{
		if ((NO == inOn) && (nil != binaryLayer)) 
			{
			[binaryLayer release];
			binaryLayer = nil;
			}
		}
	}

// -------------------------------------------------------------------------------------------

- (CALayer*)binaryLayer 
	{
	return(binaryLayer);
	}

// -------------------------------------------------------------------------------------------

- (CALayer*) layer 
	{
	#ifdef __DEBUGGING__
	NSLog(@"ZXCapture::layer - ENTER - return a QTCaptureLayer object");
	#endif
	
	if (nil == captureLayer) 
		{
		#ifdef __DEBUGGING__
		NSLog(@"ZXCapture::layer - create captureLayer (A QTCaptureLayer object)");
		#endif
		
		captureLayer = [[ZXCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];

		ZXAV(layer.videoGravity = AVLayerVideoGravityResizeAspect);
		ZXAV(layer.videoGravity = AVLayerVideoGravityResizeAspectFill);
		

		 captureLayer.delegate = self;

		ZXQT(
			 {
			 ProcessSerialNumber psn;
			 GetCurrentProcess(&psn);
			 TransformProcessType(&psn, 1);
			 });
		}
		
	ZXQT({ transform.a = ((YES == mirrorVideo) ? -1: 1); });
	[captureLayer setAffineTransform:transform];
		
	return(captureLayer);
	}

// -------------------------------------------------------------------------------------------

- (void) runActionForKey:(NSString*)		key
                  object:(id)				anObject
               arguments:(NSDictionary*)	dict 
	{
	// NSLog(@" rAFK %@ %@ %@", key, anObject, dict); 
	(void)anObject;
	(void)dict;
	if ([key isEqualToString:kCAOnOrderIn]) 
		{
		if (order_in_skip) 
			{
			--order_in_skip;
			// NSLog(@"order in skip");
			return;
			}

		// NSLog(@"order in");

		on_screen = true;
		
		if ((nil != luminanceLayer) && (luminanceLayer.superlayer != captureLayer)) 
			{
			// [layer addSublayer:luminanceLayer];
			}
		if (binaryLayer && binaryLayer.superlayer != captureLayer) 
			{
			// [layer addSublayer:binaryLayer];
			}
		[self start_stop];
		} 
	else 
		{
		if ([key isEqualToString:kCAOnOrderOut]) 
			{
			if (order_out_skip) 
				{
				--order_out_skip;
				// NSLog(@"order out skip");
				return;
				}
				
			on_screen = false;
			// NSLog(@"order out");
			[self start_stop];
			}
		}
	}

// -------------------------------------------------------------------------------------------

- (id<CAAction>)actionForLayer:(CALayer*)_layer forKey:(NSString*)event 
	{
	(void)_layer;
	
	id result = nil;

	// NSLog(@"layer event %@", event);

	// never animate
	[CATransaction setValue:[NSNumber numberWithFloat:0.0f]
				   forKey:kCATransactionAnimationDuration];

	// NSLog(@"afl %@ %@", _layer, event);
	
	if ((YES == [event isEqualToString:kCAOnOrderIn]) || 
		(YES == [event isEqualToString:kCAOnOrderOut])) 
	  // || ([event isEqualToString:@"bounds"] && (binaryLayer || luminanceLayer))
	  // || ([event isEqualToString:@"onLayout"] && (binaryLayer || luminanceLayer))
		{
		result = (id)self;
		}
	  else if ([event isEqualToString:@"contents"])		{
	} else if ([event isEqualToString:@"sublayers"])	{
	} else if ([event isEqualToString:@"onLayout"])		{
	} else if ([event isEqualToString:@"position"])		{
	} else if ([event isEqualToString:@"bounds"])		{
	} else if ([event isEqualToString:@"layoutManager"]){
	} else if ([event isEqualToString:@"transform"])	{
	} else { NSLog(@"afl other event %@ %@", _layer, event);
	}
	
	return(result);
	}

// -------------------------------------------------------------------------------------------

- (void)dealloc 
	{
	[captureToFilename release];
	
	[binaryLayer release];
	[luminanceLayer release];
	
	// TODO: should stop/close and release QTKit object resources first ??
	[captureOutput  release];
	[captureInput   release];		 
	[captureLayer   release];
	[captureSession release];
	
	[super dealloc];
	}

// -------------------------------------------------------------------------------------------

- (void)captureOutput:(ZXCaptureOutput*)inOutput	
						ZXQT(didOutputVideoFrame:(CVImageBufferRef)		videoFrame
								withSampleBuffer:(QTSampleBuffer*)		inSampleBuffer)
					  ZXAV(didOutputSampleBuffer:(CMSampleBufferRef)	inSampleBuffer)
								  fromConnection:(ZXCaptureConnection*)	inConnection 
	{
	#pragma unused(inOutput, inSampleBuffer, inConnection)
	
	#ifdef __DEBUG_CAPTURE_LOGGING__
	NSLog(@"ZXCapture::captureOutput - ENTER videoFrame[0x%08X] buffer[0x%08X] connection[0x%08X]",
		  (unsigned int) videoFrame, (unsigned int)inSampleBuffer, (unsigned int)inConnection);
	#endif
	
	if ((nil == captureToFilename) && 
		(nil == luminanceLayer) && 
		(nil == binaryLayer) && 
		(nil == captureDelegate))
		{
		#ifdef __DEBUG_CAPTURE_LOGGING__
		NSLog(@"NOTE: ZXCapture::captureOutput - skipping capture because all OBJs are nil");
		#endif
		return;
		}

  // NSLog(@"received frame");

  ZXAV(CVImageBufferRef videoFrame = CMSampleBufferGetImageBuffer(sampleBuffer));

  // NSLog(@"%d %d", CVPixelBufferGetWidth(videoFrame), CVPixelBufferGetHeight(videoFrame));
  // NSLog(@"captureDelegate %@", captureDelegate);

  ZXQT({
	  if ((0 == reported_width) || (0 == reported_height)) 
		  {
		  NSSize size = [[[[captureInput.device.formatDescriptions objectAtIndex:0]
						   formatDescriptionAttributes] objectForKey:@"videoEncodedPixelsSize"] sizeValue];
		  width  = size.width;
		  height = size.height;
		  [self performSelectorOnMainThread:@selector(setOutputAttributes) withObject:nil waitUntilDone:NO];
		  reported_width  = size.width;
		  reported_height = size.height;
		  [captureDelegate captureSize:self width:[NSNumber numberWithFloat:size.width]
										   height:[NSNumber numberWithFloat:size.height]];
		  }
	  });

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	#if(!TARGET_OS_EMBEDDED)
  // The routines don't exist in iOS. There are alternatives, but a good
  // solution would have to figure out a reasonable path and might be
  // better as a post to url

  if (nil != captureToFilename) 
	  {
	  CGImageRef	image		 =  [ZXCGImageLuminanceSource createImageFromBuffer:videoFrame];
	  NSURL*		url			 = [NSURL fileURLWithPath:captureToFilename];
	  CGImageDestinationRef dest =  CGImageDestinationCreateWithURL((CFURLRef)url, kUTTypePNG, 1, nil);
	  
	  CGImageDestinationAddImage(dest, image, nil);
	  CGImageDestinationFinalize(dest);
	  CGImageRelease(image);
	  CFRelease(dest);
	  self.captureToFilename = nil;
	  }
	#endif

  ZXCGImageLuminanceSource* source = [[[ZXCGImageLuminanceSource alloc] initWithBuffer:videoFrame] autorelease];

  if (nil != luminanceLayer) 
	  {
	  CGImageRef image = source.image;
	  CGImageRetain(image);
	  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), 
						dispatch_get_main_queue(), 
						^{luminanceLayer.contents = (id)image; 
						CGImageRelease(image);
						});
	  }

  if ((nil != binaryLayer) || (nil != captureDelegate)) 
	  {
	  // compiler issue?
	  ZXHybridBinarizer* binarizer = [ZXHybridBinarizer alloc];
	  [[binarizer initWithSource:source] autorelease];

	  if (nil != binaryLayer) // was already checked above? 
		  {
		  CGImageRef image = binarizer.createImage;
		  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), 
						 ^{  binaryLayer.contents = (id)image;  CGImageRelease(image); });
		  }

		if (nil != captureDelegate) 
			{
			ZXDecodeHints* hints	= [[[ZXDecodeHints alloc] init] autorelease];
			ZXBinaryBitmap* bitmap	= [[[ZXBinaryBitmap alloc] initWithBinarizer:binarizer] autorelease];

			@try 
				{
				ZXQRCodeReader* reader = [[[ZXQRCodeReader alloc] init] autorelease];
				// NSLog(@"started decode");
				ZXResult* result = [reader decode:bitmap hints:hints];
				// NSLog(@"finished decode");
				[captureDelegate captureResult:self result:result];
				} 
			@catch (ZXReaderException* rex) 
				{
				if (![rex.reason isEqualToString:@"Could not find three finder patterns"]) 
					{
					// NSLog(@"failed to decode, caught ReaderException '%@'", rex.reason);
					}
				} 
			@catch (ZXIllegalArgumentException* iex) 
				{
				// NSLog(@"failed to decode, caught IllegalArgumentException '%@'", iex.reason);
				} 
			@catch (id ue) 
				{
				NSLog(@"Caught unknown exception: %@", ue);
				}
			}
		// NSLog(@"finished frame");
		}

	[pool drain];
	}

// -------------------------------------------------------------------------------------------

- (BOOL) hasFront	// TODO: does not deal with possible MUXED devices
	{
	BOOL result = NO;
	NSArray* devices = [ZXCaptureDevice
						ZXAV(devicesWithMediaType:)
						ZXQT(inputDevicesWithMediaType:) ZXMediaTypeVideo];
						
	result = ((1 < [devices count]) ? YES : NO);
	
	return(result);
	}

// -------------------------------------------------------------------------------------------

- (BOOL) hasBack		// TODO: does not deal with possible MUXED devices
	{	
	BOOL result = NO;
	NSArray* devices = [ZXCaptureDevice
						ZXAV(devicesWithMediaType:)
						ZXQT(inputDevicesWithMediaType:) ZXMediaTypeVideo];
						
	result = ((0 < [devices count]) ? YES : NO);
	
	return(result);
	}

// -------------------------------------------------------------------------------------------

- (BOOL) hasTorch 
	{
	BOOL result = NO;
	if (nil != [self captureDevice]) 
		{
		result = (false ZXAV(|| [self captureDevice].hasTorch));
		} 
    return(result);
	}

// -------------------------------------------------------------------------------------------

- (int) front		// assumes front facing camera will never be available for use... 
	{
	return(0);
	}	

// -------------------------------------------------------------------------------------------

- (int) back		// assumes rear facing camera will always be available for use... 
	{
	return(1);
	}

// -------------------------------------------------------------------------------------------

- (int) camera	
	{
	return(camera);
	}

// -------------------------------------------------------------------------------------------

- (BOOL) torch 
	{
	return(torch);
	}

// -------------------------------------------------------------------------------------------

- (void) setCamera:(int) inCamera 
	{
	if (camera != inCamera) 
		{
		camera		= inCamera;
		deviceID	= -1;
		
		if (YES == zxRunning) 
			{
			#if(!TARGET_OS_MAC)
			[self replaceInput];
			#endif
			}
		}
	}

// -------------------------------------------------------------------------------------------

- (void) setTorch:(BOOL) torch_ 
	{
	#pragma unused(torch_)
	
	(void)torch_;  // ??? 
	
	ZXAV(
		 {
		 [captureInput.device lockForConfiguration:nil];
		 
		 switch(captureInput.device.torchMode) 
			{	
			case AVCaptureTorchModeOff:
			case AVCaptureTorchModeAuto:
			default:
				captureInput.device.torchMode = AVCaptureTorchModeOn;
			break;
			
			case AVCaptureTorchModeOn:
				captureInput.device.torchMode = AVCaptureTorchModeOff;
			break;
			}
		
		[captureInput.device unlockForConfiguration];
		});
	}

// -------------------------------------------------------------------------------------------

- (void) setTransform:(CGAffineTransform) transform_ 
	{
	transform = transform_;
	
	[captureLayer setAffineTransform:transform];
	}

@end

// -------------------------------------------------------------------------------------------

#else // IPHONE SIMULATOR SUPPORT STARTS HERE 

// -------------------------------------------------------------------------------------------

@implementation ZXCapture

@synthesize captureDelegate;
@synthesize transform;
@synthesize captureToFilename;

- (id)init 
	{
	return(0);	
	}

// -------------------------------------------------------------------------------------------

- (CALayer*) layer 
	{
	return(0);
	}

// -------------------------------------------------------------------------------------------

- (CALayer*) luminanceLayer 
	{
	return(0);
	}

// -------------------------------------------------------------------------------------------

- (CALayer*) binaryLayer 
	{
	return(0);
	}

// -------------------------------------------------------------------------------------------

- (void) setLuminanceBool:(BOOL)on 
	{
	}

// -------------------------------------------------------------------------------------------

- (void) setBinaryBool:(BOOL)on 
	{
	}

// -------------------------------------------------------------------------------------------

- (void) hard_stop 
	{
	}

// -------------------------------------------------------------------------------------------

- (BOOL) hasFront 
	{
	return(YES);
	}

// -------------------------------------------------------------------------------------------

- (BOOL) hasBack 
	{
	return(NO);
	}

// -------------------------------------------------------------------------------------------

- (BOOL) hasTorch 
	{
	return(NO);
	}

// -------------------------------------------------------------------------------------------

- (int) front 
	{
	return(0);
	}

// -------------------------------------------------------------------------------------------

- (int) back 
	{
	return(1);
	}

// -------------------------------------------------------------------------------------------

- (int) camera 
	{
	return(self.front);
	}

// -------------------------------------------------------------------------------------------

- (BOOL) torch 
	{
	return(NO);
	}

// -------------------------------------------------------------------------------------------

- (void) setCamera:(int) inCamera {}

// -------------------------------------------------------------------------------------------

- (void) setTorch:(BOOL) torch {}

// -------------------------------------------------------------------------------------------

- (void) order_skip {}

// -------------------------------------------------------------------------------------------

- (void) start {}

// -------------------------------------------------------------------------------------------

- (void) stop {}

// -------------------------------------------------------------------------------------------

- (void*) captureOutput 
	{
	return(0);
	}

// -------------------------------------------------------------------------------------------

@end

#endif
