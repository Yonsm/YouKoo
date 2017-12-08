
#import "MobileDeviceAccess.h"

//
@interface YouKooHelper : NSObject

- (instancetype)initWithDevice:(AMDevice *)device;
- (void)loadCaches:(void (^)(NSUInteger current, NSUInteger total))progress;
- (NSString *)exportCaches:(NSIndexSet *)indexes outDir:(NSString *)outDir tmpDir:(NSString *)tmpDir progress:(void (^)(NSUInteger current, NSUInteger total))progress progress2:(void (^)(NSUInteger current, NSUInteger total))progress2;
- (void)showPage:(NSUInteger)index;

@property (strong, nonatomic) AMDevice *device;
@property (strong, nonatomic) NSMutableArray *caches;
@property (assign, nonatomic) BOOL exportingCancelled;

@end

