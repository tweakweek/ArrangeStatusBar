#import <UIKit/UIStatusBar.h>
#import <UIKit/UIStatusBarItemView.h>
#import <UIKit/UIStatusBarItem.h>
#import <QuartzCore/CALayer.h>
#import <UIKit/UIKit2.h>
#import <notify.h>
#define SBDICTPATH @"/var/mobile/Library/Preferences/net.limneos.arrangesbstatusbar.plist"
#define PREFSPATH @"/var/mobile/Library/Preferences/net.limneos.arrangestatusbar.plist"

@interface NSFileManager (iOS4additions)
-(BOOL)removeFileAtPath:(id)path handler:(id)handler;
@end

static CGRect ownFrame=CGRectMake(0,0,0,0);
static BOOL isDragging=NO;
static BOOL ItemsLocked=NO;

%hook PSRootController
%new(v@:)
-(void)_ASBPostResetStatusBarNotification{
	notify_post("net.limneos.arrangestatusbar.reset");
}
%end

%hook UIStatusBarItemView
-(void)setUserInteractionEnabled:(BOOL)enabled{
	enabled=!ItemsLocked;
	%orig;
}
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *) event{
	
	if (ItemsLocked){
		%orig;
		return;
	}
	self.layer.borderColor=[[[UIColor whiteColor] colorWithAlphaComponent:0.7] CGColor];
	self.layer.borderWidth=1;
	self.layer.cornerRadius=2;
}
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *) event{
	
	if (ItemsLocked){
		%orig;
		return;
	}
	isDragging=YES;
	UITouch *touch=[touches anyObject];
	CGPoint location=[touch locationInView:[self window]];
	[self setNeedsDisplay];
	ownFrame=self.frame;
	ownFrame.origin.x=location.x-self.frame.size.width/2;
	self.frame=ownFrame;
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *) event{
	if (ItemsLocked){
		%orig;
		return;
	}
	self.layer.borderWidth=0;
	self.frame=ownFrame;
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithContentsOfFile:SBDICTPATH];
	if (!dict)
		dict=[NSMutableDictionary dictionary];
	UIStatusBar *statusBar=[[UIApplication sharedApplication] statusBar];
	UIView *frontView=MSHookIvar<UIView *>(statusBar,"_foregroundView");
	for (UIStatusBarItemView *subview in [frontView subviews]){
		float originX=subview.frame.origin.x;
		[dict setObject:[NSNumber numberWithFloat:originX] forKey:[NSString stringWithFormat:@"originXForItem%d",[[subview item] type]] ];
	}
	int orientation=[[UIApplication sharedApplication] interfaceOrientation];
	[dict setObject:[NSNumber numberWithInt:orientation] forKey:@"orientation"];
	[dict writeToFile:SBDICTPATH atomically:YES];
	isDragging=NO;
}

-(void)setFrame:(CGRect)frame{

	if (!isDragging){
		NSDictionary *dict=[NSDictionary dictionaryWithContentsOfFile:SBDICTPATH];
		
		if (dict && [dict objectForKey:[NSString stringWithFormat:@"originXForItem%d",[[self item] type]]] ){
			int cachedOrientation=[[dict objectForKey:@"orientation"] intValue];
			int orientation=[[UIApplication sharedApplication] interfaceOrientation];
			CGRect screenBounds=[[UIScreen mainScreen] bounds];
			CGSize screenSize=screenBounds.size;
			float divider=screenSize.width>screenSize.height ? screenSize.width/screenSize.height : screenSize.height/screenSize.width;
			frame.origin.x=[[dict objectForKey:[NSString stringWithFormat:@"originXForItem%d",[[self item] type] ] ] floatValue];
			frame.origin.x=((orientation>2 && cachedOrientation>2) || (orientation<3 && cachedOrientation<3)) ? frame.origin.x : ((orientation>2 && cachedOrientation<3) ? frame.origin.x*divider : frame.origin.x/divider) ;
		}
	}
	
	%orig;

}

%end

%hook UIStatusBarServer
-(void)_receivedStatusBarData:(id*)data actions:(int)actions{
if (!isDragging)
	%orig;
}
%end

static void resetSBArrangement(CFNotificationCenterRef center,
					void *observer,
					CFStringRef name,
					const void *object,
					CFDictionaryRef userInfo) {
[[NSFileManager defaultManager] removeFileAtPath:SBDICTPATH handler: nil]; 

}


static void getSettings(){

	NSDictionary *settingsDict=[NSDictionary dictionaryWithContentsOfFile:PREFSPATH];
	ItemsLocked=[settingsDict objectForKey:@"Locked"]!=nil ? [[settingsDict objectForKey:@"Locked"] boolValue] : NO;

}
static void updateSettings(CFNotificationCenterRef center,
					void *observer,
					CFStringRef name,
					const void *object,
					CFDictionaryRef userInfo) {
	getSettings();
}

%hook UIApplication
-(void)_reportAppLaunchFinished{
	
	%orig;
	getSettings();
	
}
%end



%ctor {
		CFNotificationCenterRef r = CFNotificationCenterGetDarwinNotifyCenter();
		CFNotificationCenterAddObserver(r, NULL, &updateSettings, CFSTR("net.limneos.arrangestatusbar.updatesettings"), NULL, 0);
		if ([[[NSBundle mainBundle] bundleIdentifier] isEqual:@"com.apple.springboard"]){
			CFNotificationCenterAddObserver(r, NULL, &resetSBArrangement, CFSTR("net.limneos.arrangestatusbar.reset"), NULL, 0);
		}
		
}
