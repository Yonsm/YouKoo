

#import "AppDelegate.h"

//
@implementation AppDelegate
@synthesize window;

#pragma mark -

//
- (void)deviceConnected:(AMDevice*)device;
{
	deployButton.enabled = YES;
	fetchButton.enabled = YES;
	restartButton.enabled = YES;
	shutdownButton.enabled = YES;
	activateButton.enabled = YES;
}

//
- (void)deviceDisconnected:(AMDevice*)device;
{
	fetchButton.enabled = NO;
	deployButton.enabled = NO;
	restartButton.enabled = NO;
	shutdownButton.enabled = NO;
	activateButton.enabled = NO;
}

#pragma mark -

//
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	window.title = [NSString stringWithFormat:@"%@ - %@", NSBundleName(), NSBundleVersion()];
	
	_selectedColor = -1;
	
	//
	MobileDeviceAccess.singleton.listener = self;
}

//
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}
//
- (void)applicationWillTerminate:(NSNotification *)notification
{
}

#pragma mark -

//
- (IBAction)deploy:(id)sender
{
	if (activityIndicator.isHidden != NO)
	{
		[self deviceDisconnected:nil];
		activityIndicator.hidden = NO;
		[activityIndicator startAnimation:nil];
		
		[self performSelectorInBackground:@selector(deploying:)  withObject:nil];
	}
}

//
- (void)deploying:(NSDictionary *)spark
{
	@autoreleasepool
	{
		NSString *result = nil;
		
		[self performSelectorOnMainThread:@selector(deployed:) withObject:result waitUntilDone:YES];
	}
}

//
- (void)deployed:(NSString *)result
{
	[activityIndicator stopAnimation:nil];
	activityIndicator.hidden = YES;
	
	NSInteger ret = NSRunAlertPanel(@"提示", @"%@", @"确定", @"重启设备", nil, result ? result : @"已经部署到设备上。\n\n您需要重新启动设备才能生效。", nil);
}

#pragma mark -

@end

