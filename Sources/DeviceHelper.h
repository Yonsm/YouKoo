
#import "MobileDeviceAccess.h"

//
@interface AMDevice (Helper)
+ (AMDevice *)anyone;

@end

@interface AFCDirectoryAccess (Helper)
- (BOOL)copyYouKuFile:(NSString*)path1 toLocalFile:(NSString*)path2;
@end
