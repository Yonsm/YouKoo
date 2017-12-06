

#import "MobileDeviceAccess.h"

//
@interface AppDelegate : NSObject <NSApplicationDelegate, MobileDeviceAccessListener, NSTableViewDelegate, NSTableViewDataSource>
{
	IBOutlet NSTableView *_tableView;
	IBOutlet NSButton *deployButton;
	IBOutlet NSProgressIndicator *activityIndicator;
	
	BOOL _sortAscending;
	NSMutableArray *_caches;
	NSMutableDictionary *_metas;
}

@property (assign) IBOutlet NSWindow *window;

@end
