@interface UIStatusBarItem : NSObject
@property (nonatomic, readonly) int type;
@end

@interface UIApplication (iOS4)
- (id)statusBar;
@end
