// CCStrobe by Julian (insanj) Weiss
// (CC) 2014 Julian Weiss, see full license in README.md

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface SBControlCenterButton : UIButton
@property(copy, nonatomic) NSString *identifier;
@end

@interface SBControlCenterButton (CCStrobe)
-(void)ccstrobe_longPressEvent:(UILongPressGestureRecognizer *)sender;
-(void)ccstrobe_setupStrobe:(AVCaptureDevice *)light withSession:(AVCaptureSession *)session;
-(void)ccstrobe_beginStrobing:(AVCaptureDevice *)light;
-(void)ccstrobe_toggleStrobe:(AVCaptureDevice *)light;
-(void)ccstrobe_toggleStrobe:(AVCaptureDevice *)light state:(BOOL)state;
@end

%hook SBControlCenterButton
static char * kCCStrobeSwitchKey;

-(id)initWithFrame:(CGRect)frame{
	SBControlCenterButton *b = %orig();
	NSLog(@"---- init! %@", b);

	/*

	UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:b action:@selector(ccstrobe_longPressEvent:)];
	[b addGestureRecognizer:press];

	*/

	return b;
}

-(void)setIdentifier:(NSString *)arg1{
	NSLog(@"---- set:%@", arg1);	//apparently quicklaunches hide from this!
	%orig();
}

%new -(void)ccstrobe_longPressEvent:(UILongPressGestureRecognizer *)sender{
	if(sender.state == UIGestureRecognizerStateBegan){
		NSLog(@"[CCStrobe] Recognized long press on Torch button, starting strobe");
		AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
		AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
		[self ccstrobe_setupStrobe:captureDevice withSession:captureSession];
	
		objc_setAssociatedObject(self, &kCCStrobeSwitchKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		[self ccstrobe_beginStrobing:captureDevice];
	}

	else if(sender.state == UIGestureRecognizerStateEnded){
		NSLog(@"[CCStrobe] Recognized lift off of the Torch button, ending possible strobe");
		objc_setAssociatedObject(self, &kCCStrobeSwitchKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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