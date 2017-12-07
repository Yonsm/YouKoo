

#import "MobileDeviceAccess.h"
#import "YouKooHelper.h"

//
@interface AppDelegate : NSObject <NSApplicationDelegate, MobileDeviceAccessListener, NSTableViewDelegate, NSTableViewDataSource>
{
	IBOutlet NSTableView *_tableView;
	IBOutlet NSButton *_exportButton;
	IBOutlet NSTextField *_outputField;
	IBOutlet NSTextField *_tempField;
	IBOutlet NSProgressIndicator *_progressIndicator;

	BOOL _sortAscending;
	YouKooHelper *_youkoo;
}

typedef enum {StateDisconnected, StateLoading, StateReady, StateExporting} AppState;

@property (assign, nonatomic) AppState state;
@property (assign) IBOutlet NSWindow *window;

@end
