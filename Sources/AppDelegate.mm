

#import "AppDelegate.h"

//
@implementation AppDelegate
@synthesize window;

#pragma mark -
#pragma mark Application delegate

//
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	window.title = [NSString stringWithFormat:@"%@ - %@", NSBundleName(), NSBundleVersion()];
	
	_tableView.target = self;
	_tableView.doubleAction = @selector(doubleClick:);
	
	//
	NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
	NSString *outDir = [preferences stringForKey:@"OutDir"];
	if (outDir.length == 0)
	{
		outDir = [NSUserDirectoryPath(NSMoviesDirectory) stringByAppendingPathComponent:@"YouKoo"];
	}
	NSString *tmpDir = [preferences stringForKey:@"TmpDir"];
	if (tmpDir.length == 0)
	{
		tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"YouKoo"];
	}
	_outField.stringValue = outDir;
	_tmpField.stringValue = tmpDir;

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
	NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
	[preferences setValue:_outField.stringValue forKey:@"OutDir"];
	[preferences setValue:_tmpField.stringValue forKey:@"TmpDir"];
	[preferences synchronize];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return _youkoo.caches.count;
}

//
- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	return _youkoo.caches[row][tableColumn.identifier];
}

#pragma mark -
#pragma mark Table view delegate

//
- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	if (_youkoo.caches.count == 0)
		return;
	
	_sortAscending = !_sortAscending;
	[_youkoo.caches sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
		if (_sortAscending)
		{
			return [obj1[tableColumn.identifier] localizedCompare:obj2[tableColumn.identifier]];
		}
		else
		{
			return [obj2[tableColumn.identifier] localizedCompare:obj1[tableColumn.identifier]];
		}
	}];
	[_tableView reloadData];
	[_tableView deselectAll:_tableView];
	[_tableView scrollRowToVisible:0];
}

//
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	self.state = _state;
}

//
- (void)doubleClick:(id)object
{
	[_youkoo showPage:_tableView.clickedRow];
}

#pragma mark -
#pragma mark Control methods

//
- (IBAction)browseDir:(id)sender
{
	NSTextField *field = (sender == _browseOutButton) ? _outField : _tmpField;
	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.directoryURL = [NSURL fileURLWithPath:field.stringValue];
	openPanel.canChooseFiles = NO;
	openPanel.canChooseDirectories = YES;
	if ([openPanel runModal] == NSModalResponseOK)
	{
		field.stringValue = openPanel.URLs[0].path;
		
		NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
		[preferences setValue:field.stringValue forKey:(sender == _browseOutButton) ? @"OutDir" : @"TmpDir"];
		[preferences synchronize];
	}
}

//
- (IBAction)exportCaches:(id)sender
{
	if (_state == StateReady)
	{
		self.state = StateExporting;
		_progressIndicator.doubleValue = 0;
		_progressIndicator.toolTip = nil;
		_youkoo.exportingCancelled = NO;

		NSIndexSet *indexes = _tableView.selectedRowIndexes;
		if (indexes.count == 0)
		{
			indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _youkoo.caches.count)];
		}
		NSString *outDir = _outField.stringValue;
		NSString *tmpDir = _tmpField.stringValue;

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSString *result = [_youkoo exportCaches:indexes outDir:outDir tmpDir:tmpDir progress:^(NSUInteger current, NSUInteger total) {
				dispatch_sync(dispatch_get_main_queue(), ^{
					_progressIndicator.doubleValue = current * 100 / total;
					_progressIndicator.toolTip = [NSString stringWithFormat:@"%lu/%lu", current, total];
				});
			}];
			dispatch_sync(dispatch_get_main_queue(), ^{
				self.state = StateReady;
				NSRunAlertPanel(@"完成", @"%@", nil, nil, nil, result ?: @"已全部导出成功。", nil);
			});
		});
	}
	else if (_state == StateExporting)
	{
		_youkoo.exportingCancelled = YES;
	}
}

#pragma mark -
#pragma mark Device and state handler

//
- (void)deviceConnected:(AMDevice*)device
{
	if (_state == StateDisconnected)
	{
		self.state = StateLoading;
		_progressIndicator.doubleValue = 0;
		_progressIndicator.toolTip = nil;
		
		_youkoo = [[YouKooHelper alloc] initWithDevice:device];
		[_tableView reloadData];
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[_youkoo loadCaches:^(NSUInteger current, NSUInteger total) {
				dispatch_sync(dispatch_get_main_queue(), ^{
					_progressIndicator.doubleValue = current * 100 / total;
					_progressIndicator.toolTip = [NSString stringWithFormat:@"%lu/%lu", current, total];
					[_tableView reloadData];
				});
			}];
			dispatch_sync(dispatch_get_main_queue(), ^{self.state = StateReady;});
		});
	}
}

//
- (void)deviceDisconnected:(AMDevice*)device
{
	if (device == _youkoo.device)
	{
		_youkoo = nil;
		self.state = StateDisconnected;
		[_tableView reloadData];
	}
}

//
- (void)setState:(AppState)state
{
	_state = state;
	
	_browseOutButton.enabled = (state == StateDisconnected) || (state == StateReady);
	_browseOutButton.enabled = (state == StateDisconnected) || (state == StateReady);
	_exportButton.enabled = (state == StateReady) || (state == StateExporting);
	_progressIndicator.hidden = (state == StateDisconnected) || (state == StateReady);
	
	switch (state)
	{
		default:
		{
			_exportButton.title = @"📱请连接设备";
			break;
		}
		case StateLoading:
		{
			_exportButton.title = @"📱载入中...";
			break;
		}
		case StateReady:
		{
			NSUInteger count = _tableView.selectedRowIndexes.count;
			_exportButton.title = count ? [NSString stringWithFormat:@"📱导出 %lu 项", count] : @"📱导出全部";
			break;
		}
		case StateExporting:
		{
			_exportButton.title = @"📱导出中...";
			break;
		}
	}
}

@end

