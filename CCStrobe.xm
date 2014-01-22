// CCStrobe by Julian (insanj) Weiss
// (CC) 2014 Julian Weiss, see full license in README.md

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "CydiaSubstrate.h"

@interface SBControlCenterButton : UIButton
@property(copy, nonatomic) NSString *identifier;
@property(copy, nonatomic) NSNumber *sortKey;
-(void)dealloc;
@end

@interface CCTControlCenterButton : SBControlCenterButton
@end

@interface SBControlCenterContainerView : UIView
@end

@interface SBControlCenterContainerView (CCStrobe)
-(void)ccstrobe_disableStrobe;
-(void)ccstrobe_longPressEvent:(CCTControlCenterButton *)button;
-(void)ccstrobe_setupStrobe:(AVCaptureDevice *)light withSession:(AVCaptureSession *)session;
-(void)ccstrobe_beginStrobing:(AVCaptureDevice *)light withSession:(AVCaptureSession *)session;
-(void)ccstrobe_toggleStrobe:(AVCaptureDevice *)light;
-(void)ccstrobe_toggleStrobe:(AVCaptureDevice *)light state:(BOOL)state;
@end

%hook SBControlCenterContainerView
static char * kCCStrobeSwitchKey;
static char * kCCStrobeLastTouchStampKey;

-(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
	UIView *o = %orig();

	[self ccstrobe_disableStrobe];
	if([objc_getAssociatedObject(self, &kCCStrobeLastTouchStampKey) floatValue] != event.timestamp)
		objc_setAssociatedObject(self, &kCCStrobeLastTouchStampKey, @((CGFloat)event.timestamp), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	if([o isKindOfClass:[%c(CCTControlCenterButton) class]]){
		if([[o valueForKey:@"identifier"] isEqualToString:@"com.apple.controlcenter.quicklaunch.torch"]){
			NSLog(@"[CCStrobe] Detected tap on Torch button, waiting for long press...");

			CGFloat lastTouch = [objc_getAssociatedObject(self, &kCCStrobeLastTouchStampKey) floatValue];
			CGFloat thisTouch = (CGFloat)event.timestamp;

			if(lastTouch - thisTouch > 0.005 && lastTouch - thisTouch < 0.5)
				[self ccstrobe_longPressEvent:(CCTControlCenterButton*)o];
		}
	}

	return %orig();
}

%new -(void)ccstrobe_disableStrobe{
	NSLog(@"[CCStrobe] Making sure strobe is ending in all non double-touch events");
	objc_setAssociatedObject(self, &kCCStrobeSwitchKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new -(void)ccstrobe_longPressEvent:(CCTControlCenterButton *)button{
	NSLog(@"[CCStrobe] Recognized long press on Torch button, starting strobe");
	
	objc_setAssociatedObject(self, &kCCStrobeSwitchKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
	[self ccstrobe_setupStrobe:captureDevice withSession:captureSession];
}
	
%new -(void)ccstrobe_setupStrobe:(AVCaptureDevice *)light withSession:(AVCaptureSession *)session{
	[session beginConfiguration];
	
	if([light hasTorch] && [light hasFlash]){
		AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:light error:nil];
		
		if(deviceInput)
			[session addInput:deviceInput];
		
		AVCaptureVideoDataOutput *dataOut = [[AVCaptureVideoDataOutput alloc] init];
		[session addOutput:dataOut];
		[session commitConfiguration];
		[session startRunning];

		[self ccstrobe_beginStrobing:light withSession:session];
	}
}

%new -(void)ccstrobe_beginStrobing:(AVCaptureDevice *)light withSession:(AVCaptureSession *)session{
	if(!objc_getAssociatedObject(self, &kCCStrobeSwitchKey)){
		[self ccstrobe_toggleStrobe:light state:NO];
		[session stopRunning];
	}
	
	else{
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.025 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
			[self ccstrobe_toggleStrobe:light];
			[self ccstrobe_beginStrobing:light withSession:session];
		});
	}
}

%new -(void)ccstrobe_toggleStrobe:(AVCaptureDevice *)light{
	[self ccstrobe_toggleStrobe:light state:!light.torchActive];
}

%new -(void)ccstrobe_toggleStrobe:(AVCaptureDevice *)light state:(BOOL)state{
	[light lockForConfiguration:nil];
	
	[light setTorchMode:state];
	[light setFlashMode:state];
	
	[light unlockForConfiguration];
}
%end