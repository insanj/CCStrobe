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
-(void)ccstrobe_beginStrobing:(AVCaptureDevice *)light;
-(void)ccstrobe_toggleStrobe:(AVCaptureDevice *)light;
-(void)ccstrobe_toggleStrobe:(AVCaptureDevice *)light state:(BOOL)state;
@end

%hook SBControlCenterContainerView
static char * kCCStrobeSwitchKey;

-(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
	UIView *o = %orig();

	if([o isKindOfClass:[%c(CCTControlCenterButton) class]]){
		if([[o valueForKey:@"identifier"] isEqualToString:@"com.apple.controlcenter.quicklaunch.torch"]){
			NSLog(@"[CCStrobe] Detected tap on Torch button, waiting for long press...");
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
				UIButton *replacement = [UIButton buttonWithType:UIButtonTypeRoundedRect];
				[replacement addTarget:self action:@selector(ccstrobe_disableStrobe) forControlEvents:UIControlEventTouchUpInside];
				[self addSubview:replacement];
				[replacement setFrame:o.frame];

				[self ccstrobe_longPressEvent:(CCTControlCenterButton*)o];
			});
		}
	}

	return %orig();
}

%new -(void)ccstrobe_disableStrobe{
	NSLog(@"[CCStrobe] Recognized secondary long press on Torch button, ending strobe");
	objc_setAssociatedObject(self, &kCCStrobeSwitchKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new -(void)ccstrobe_longPressEvent:(CCTControlCenterButton *)button{
	if(button.selected){
		NSLog(@"[CCStrobe] Recognized long press on Torch button, starting strobe");
		
		objc_setAssociatedObject(self, &kCCStrobeSwitchKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
		AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
		[self ccstrobe_setupStrobe:captureDevice withSession:captureSession];
		[self ccstrobe_beginStrobing:captureDevice];
	}
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
	}
}

%new -(void)ccstrobe_beginStrobing:(AVCaptureDevice *)light{
	if(!objc_getAssociatedObject(self, &kCCStrobeSwitchKey))
		[self ccstrobe_toggleStrobe:light state:NO];
	
	else{
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.025 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
			[self ccstrobe_toggleStrobe:light];
			[self ccstrobe_beginStrobing:light];
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