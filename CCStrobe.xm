// CCStrobe by Julian (insanj) Weiss
// (CC) 2014 Julian Weiss, see full license in README.md

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface SBControlCenterButton : UIButton
@end

@interface SBCCQuickLaunchSectionController{
	SBControlCenterButton *_torchButton;
}

-(id)init;
-(void)_enableTorch:(BOOL)torch;
@end

@interface SBCCQuickLaunchSectionController (CCStrobe)
-(void)ccstrobe_strobe;
@end

%hook SBCCQuickLaunchSectionController
static char * kCCStrobeHitOnce;
static char * kCCStrobeHitTwice;
static char * kCCStrobeShouldStrobe;

-(void)_enableTorch:(BOOL)torch{
	%orig();

	if([objc_getAssociatedObject(self, &kCCStrobeHitOnce) boolValue]){
		objc_setAssociatedObject(self, &kCCStrobeHitOnce, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(self, &kCCStrobeHitTwice, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	else
		objc_setAssociatedObject(self, &kCCStrobeHitOnce, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
		if([objc_getAssociatedObject(self, &kCCStrobeHitTwice) boolValue]){
			objc_setAssociatedObject(self, &kCCStrobeShouldStrobe, @(![objc_getAssociatedObject(self, &kCCStrobeShouldStrobe) boolValue]), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			[self ccstrobe_strobe];
		}
	});
}

%new -(void)ccstrobe_strobe{
	if(![objc_getAssociatedObject(self, &kCCStrobeShouldStrobe) boolValue])
		return;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.025 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
		[self _enableTorch:!(MSHookIvar<BOOL>(self, "_flashlightOn"))];
		[self ccstrobe_strobe];
	});
}
%end