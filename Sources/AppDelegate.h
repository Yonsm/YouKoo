

#import "MobileDeviceAccess.h"

//
@interface AppDelegate : NSObject <NSApplicationDelegate, MobileDeviceAccessListener, NSTextFieldDelegate>
{
	NSInteger _selectedColor;
	IBOutlet NSButton *infoPane;
	
	IBOutlet NSTextField *typeField;
	IBOutlet NSTextField *reguField;
	IBOutlet NSTextField *modelField;
	IBOutlet NSTextField *regionField;
	
	IBOutlet NSTextField *colorLabel;
	IBOutlet NSSegmentedControl *colorField;
	IBOutlet NSTextField *verField;
	IBOutlet NSTextField *buildField;

	IBOutlet NSTextField *snField;
	IBOutlet NSTextField *ecidField;
	IBOutlet NSTextField *btField;
	IBOutlet NSTextField *wifiField;

	IBOutlet NSTextField *ethField;
	IBOutlet NSTextField *mlbField;

	IBOutlet NSTextField *imeiField;
	IBOutlet NSTextField *bbsnField;
	IBOutlet NSTextField *bbverField;

	IBOutlet NSTextField *cnameField;
	IBOutlet NSTextField *cverField;

	IBOutlet NSTextField *postLabel;
	IBOutlet NSTextField *prlField;
	IBOutlet NSTextField *priField;
	IBOutlet NSTextField *cidField;

	IBOutlet NSTextField *keyField;
	IBOutlet NSTextField *valField;

	IBOutlet NSButton *fetchButton;
	IBOutlet NSButton *restartButton;
	IBOutlet NSButton *shutdownButton;
	IBOutlet NSButton *activateButton;

	IBOutlet NSButton *deployButton;
	IBOutlet NSProgressIndicator *activityIndicator;
}

@property (assign) IBOutlet NSWindow *window;

@end
