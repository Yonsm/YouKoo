
#import "MobileDeviceAccess.h"

//
@interface YouKooHelper : NSObject

- (instancetype)initWithDevice:(AMDevice *)device;
- (void)loadCaches:(void (^)(NSUInteger current, NSUInteger total))progress;
- (NSString *)exportMedia:(NSIndexSet *)indexes;
- (void)openDetailPage:(NSUInteger)row;

@property(strong,nonatomic) AMDevice *device;
@property(strong,nonatomic) NSMutableArray *caches;

@end

//
@interface AFCDirectoryAccess (Helper)
- (BOOL)copyYouKuFile:(NSString*)path1 toLocalFile:(NSString*)path2;
@end
