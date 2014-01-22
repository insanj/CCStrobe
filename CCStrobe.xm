// CCStrobe by Julian (insanj) Weiss
// (CC) 2014 Julian Weiss, see full license in README.md

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "CydiaSubstrate.h"

@interface NSDistributedNotificationCenter : NSNotificationCenter
@end

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
-(void)ccstrobe_longPressEvent:(CCTControlCenterButton *)button;
-(void)ccstrobe_setupStrobe:(AVCaptureDevice *)light withSession:(AVCaptureSession *)session;
-(void)ccstrobe_beginStrobing:(AVCaptureDevice *)light;
-(void)ccstrobe_toggleStrobe:(AVCaptureDevice *)light;
-(void)ccstrobe_toggleStrobe:(AVCaptureDevice *)light state:(BOOL)state;
@end

@interface SBCCQuickLaunchSectionController
-(void)_enableTorch:(BOOL)torch;
@end

@interface SBCCQuickLaunchSectionController (CCStrobe)
-(void)ccstrobe_overrideEnable:(NSNotification *)notification;
@end

%hook SBCCQuickLaunchSectionController
static char * kCCStrobeShouldOverrideKey;

-(id)init{
	SBCCQuickLaunchSectionController *c = %orig();
	[[NSDistributedNotificationCenter defaultCenter] addObserver:c selector:@selector(ccstrobe_overrideEnable:) name:@"CCStrobeChangeOverride" object:nil];
	return c;
}

%new -(void)ccstrobe_overrideEnable:(NSNotification *)notification{
	objc_setAssociatedObject(self, &kCCStrobeShouldOverrideKey, [[notification userInfo] objectForKey:@"shouldOverride"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(void)_enableTorch:(BOOL)torch{
	if([objc_getAssociatedObject(self, &kCCStrobeShouldOverrideKey) boolValue])
		%orig(YES);
	else
		%orig();
}
%end

%hook SBControlCenterContainerView
static char * kCCStrobeSwitchKey;

-(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
	UIView *o = %orig();

	if([o isKindOfClass:[%c(CCTControlCenterButton) class]]){
		if([[o valueForKey:@"identifier"] isEqualToString:@"com.apple.controlcenter.quicklaunch.torch"]){
			NSLog(@"[CCStrobe] Detected tap on Torch button, waiting for long press...");
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
				[self ccstrobe_longPressEvent:(CCTControlCenterButton*)o];
			});
		}
	}

	return %orig();
}

%new -(void)ccstrobe_longPressEvent:(CCTControlCenterButton *)button{
	if([objc_getAssociatedObject(self, &kCCStrobeSwitchKey) boolValue]){
		NSLog(@"[CCStrobe] Recognized secondary long press on Torch button, ending strobe");
	
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"CCStrobeChangeOverride" object:nil userInfo:@{@"shouldOverride" : @(NO)}];
		objc_setAssociatedObject(self, &kCCStrobeSwitchKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	else if(button.selected){
		NSLog(@"[CCStrobe] Recognized long press on Torch button, starting strobe");
		
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"CCStrobeChangeOverride" object:nil userInfo:@{@"shouldOverride" : @(YES)}];
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
	if(!objc_getAssociatedObject(self, &kCCStrobeSwitchKey)){
		[self ccstrobe_toggleStrobe:light state:NO];
		objc_setAssociatedObject(self, &kCCStrobeSwitchKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	}
	
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