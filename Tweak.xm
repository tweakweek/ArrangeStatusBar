#import <UIKit/UIStatusBar.h>
#import <UIKit/UIStatusBarItemView.h>
#import <UIKit/UIStatusBarItem.h>
#import <QuartzCore/CALayer.h>
#import <notify.h>
#define SBDICTPATH @"/var/mobile/Library/Preferences/net.limneos.arrangesbstatusbar.plist"
#define PREFSPATH @"/var/mobile/Library/Preferences/net.limneos.arrangestatusbar.plist"

@interface NSFileManager (iOS4additions)
-(BOOL)removeFileAtPath:(id)path handler:(id)handler;
@end

static CGRect ownFrame=CGRectMake(0,0,0,0);
static NSMutableArray *statusBarItems=nil;
static BOOL isDragging=NO;

%hook PSRootController
%new(v@:)
-(void)_ASBPostResetStatusBarNotification{
	notify_post("net.limneos.arrangestatusbar.reset");
}
%end

%hook UIStatusBarItemView
-(void)setUserInteractionEnabled:(BOOL)enabled{
	%orig(YES);
}
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *) event{
	if ([[self item] type]!=1){
		self.layer.borderColor=[[[UIColor whiteColor] colorWithAlphaComponent:0.7] CGColor];
		self.layer.borderWidth=1;
		self.layer.cornerRadius=2;
	}
}
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *) event{
	if ([[self item] type]!=1){
	isDragging=YES;
	UITouch *touch=[touches anyObject];
	CGPoint location=[touch locationInView:[self window]];
	[self setNeedsDisplay];
	ownFrame=self.frame;
	ownFrame.origin.x=location.x-self.frame.size.width/2;
	self.frame=ownFrame;
	}
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *) event{
	
	if ([[self item] type]!=1){
	
		self.layer.borderWidth=0;
		self.frame=ownFrame;
		if (statusBarItems)
			[statusBarItems release];
		statusBarItems=[[NSMutableArray array] retain];
		UIStatusBar *statusBar=[[UIApplication sharedApplication] statusBar];
		UIView *frontView=MSHookIvar<UIView *>(statusBar,"_foregroundView");
		for (UIStatusBarItemView *subview in [frontView subviews]){
			NSDictionary *dict=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:[[subview item] type]],@"item",NSStringFromCGPoint([subview origin]),@"origin",nil];
			[statusBarItems addObject:dict];
		}
		int orientation=[[UIApplication sharedApplication] interfaceOrientation];
		NSDictionary *dictToSave=[NSDictionary dictionaryWithObjectsAndKeys:statusBarItems,@"items",[NSNumber numberWithInt:orientation],@"orientation",nil];
		[dictToSave writeToFile:SBDICTPATH atomically:YES];
		isDragging=NO;
		
	}
	
}

-(void)setFrame:(CGRect)frame{

	if (!isDragging && [[self item] type]!=1){
		NSDictionary *dictToLoad=[NSDictionary dictionaryWithContentsOfFile:SBDICTPATH];
		if (dictToLoad){
			NSArray *originsOfViews=[dictToLoad objectForKey:@"items"];
			int cachedOrientation=[[dictToLoad objectForKey:@"orientation"] intValue];
			int orientation=[[UIApplication sharedApplication] interfaceOrientation];
			CGRect screenBounds=[[UIScreen mainScreen] bounds];
			CGSize screenSize=screenBounds.size;
			float divider=screenSize.width>screenSize.height ? screenSize.width/screenSize.height : screenSize.height/screenSize.width;
			for (NSDictionary *valuesDict in originsOfViews){
				if ([[self item] type] == [[valuesDict objectForKey:@"item"] intValue]){
					frame.origin=CGPointFromString([valuesDict objectForKey:@"origin"]);
					frame.origin.x=((orientation>2 && cachedOrientation>2) || (orientation<3 && cachedOrientation<3)) ? frame.origin.x : ((orientation>2 && cachedOrientation<3) ? frame.origin.x*divider : frame.origin.x/divider) ;
					break;
				}
			}
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
[[NSFileManager defaultManager] removeFileAtPath:SBDICTPATH handler: nil]; 	[[NSFileManager defaultManager] removeFileAtPath:PREFSPATH handler: nil];

}


%ctor {
		if ([[[NSBundle mainBundle] bundleIdentifier] isEqual:@"com.apple.springboard"]){
			CFNotificationCenterRef r = CFNotificationCenterGetDarwinNotifyCenter();
			CFNotificationCenterAddObserver(r, NULL, &resetSBArrangement, CFSTR("net.limneos.arrangestatusbar.reset"), NULL, 0);
		}
}
