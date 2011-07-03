#import <UIStatusBar.h>
#import <UIStatusBarItemView.h>
#import <UIStatusBarItem.h>
#import <QuartzCore/CALayer.h>
#import <notify.h>
#define SBDICTPATH @"/var/mobile/Library/Preferences/net.limneos.arragesbstatusbar.plist"
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
	notify_post("net.limneos.arragestatusbar.reset");
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
		NSDictionary *dictToSave=[NSDictionary dictionaryWithObjectsAndKeys:statusBarItems,@"items",nil];
		[dictToSave writeToFile:SBDICTPATH atomically:YES];
		isDragging=NO;
		
  }
}

-(void)setFrame:(CGRect)frame{

	if (!isDragging && [[self item] type]!=1){
		NSDictionary *savedDict=[NSDictionary dictionaryWithContentsOfFile:SBDICTPATH];
		if (savedDict){
			NSArray *originsOfViews=[savedDict objectForKey:@"items"];
			for (NSDictionary *valueDict in originsOfViews){
				if ([[self item] type] == [[valueDict objectForKey:@"item"] intValue]){
					frame.origin=CGPointFromString([valueDict objectForKey:@"origin"]);
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
			CFNotificationCenterAddObserver(r, NULL, &resetSBArrangement, CFSTR("net.limneos.arragestatusbar.reset"), NULL, 0);
		}
}
