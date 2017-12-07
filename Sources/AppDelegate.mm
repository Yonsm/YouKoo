

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
	[_youkoo openDetailPage:_tableView.clickedRow];
}

#pragma mark -
#pragma mark Control methods

//
- (IBAction)browseOutput:(id)sender
{
}

//
- (IBAction)browseTemp:(id)sender
{
}

//
- (IBAction)exportMedia:(id)sender
{
	if (_progressIndicator.isHidden != NO)
	{
		_progressIndicator.hidden = NO;
		//[_progressIndicator setCurrent]
		[_progressIndicator startAnimation:nil];
		
		NSIndexSet *indexes = _tableView.selectedRowIndexes;
		if (indexes.count == 0)
		{
			indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _youkoo.caches.count)];
		}
		[self performSelectorInBackground:@selector(exportWorker:)  withObject:indexes];
	}
}

//
- (void)exportWorker:(NSIndexSet *)indexes
{
	@autoreleasepool
	{
		NSString *result = [_youkoo exportMedia:indexes];
		[self performSelectorOnMainThread:@selector(exportEnded:) withObject:result waitUntilDone:YES];
	}
}

//
- (void)exportEnded:(NSString *)result
{
	[_progressIndicator stopAnimation:nil];
	_progressIndicator.hidden = YES;
	
	NSRunAlertPanel(@"提示", result ? result : @"已经完成。", @"确定", nil, nil, nil);
}

#pragma mark -
#pragma mark Device and state handler

//
- (void)deviceConnected:(AMDevice*)device
{
	if (_state == StateDisconnected)
	{
		_youkoo.device = nil;
		_youkoo = [[YouKooHelper alloc] initWithDevice:device];
		[_tableView reloadData];

		self.state = StateLoading;
		_progressIndicator.doubleValue = 0;

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[_youkoo loadCaches:^(NSUInteger current, NSUInteger total) {
				dispatch_sync(dispatch_get_main_queue(), ^{
					_progressIndicator.doubleValue = current * 100 / total;
					_progressIndicator.toolTip = [NSString stringWithFormat:@"%lu/%lu", current, total];
					[_tableView reloadData];
					if (current == total)
					{
						self.state = StateReady;
					}
				});
			}];
		});
	}
}

//
- (void)deviceDisconnected:(AMDevice*)device
{
	if (device == _youkoo.device)
	{
		_youkoo.device = nil;
		_youkoo = nil;
		self.state = StateDisconnected;
		[_tableView reloadData];
	}
}

//
- (void)setState:(AppState)state
{
	_state = state;

	_exportButton.enabled = (state != StateDisconnected);
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

