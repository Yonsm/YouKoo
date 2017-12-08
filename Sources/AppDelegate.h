

#import "MobileDeviceAccess.h"
#import "YouKooHelper.h"

//
@interface AppDelegate : NSObject <NSApplicationDelegate, MobileDeviceAccessListener, NSTableViewDelegate, NSTableViewDataSource>
{
	IBOutlet NSTableView *_tableView;
	IBOutlet NSButton *_exportButton;
	IBOutlet NSTextField *_outField;
	IBOutlet NSTextField *_tmpField;
	IBOutlet NSButton *_browseOutButton;
	IBOutlet NSButton *_browseTmpButton;
	IBOutlet NSProgressIndicator *_progressIndicator;
	IBOutlet NSProgressIndicator *_progressIndicator2;

	BOOL _sortAscending;
	YouKooHelper *_youkoo;
}

typedef enum {StateDisconnected, StateLoading, StateReady, StateExporting} AppState;

@property (assign, nonatomic) AppState state;
@property (assign) IBOutlet NSWindow *window;

@end
