

#import "AppDelegate.h"
#import "DeviceHelper.h"

//
@implementation AppDelegate
@synthesize window;

#pragma mark -

//
- (void)deviceConnected:(AMDevice*)device
{
	[self reloadData:device];
	
	deployButton.enabled = YES;
}

//
- (void)deviceDisconnected:(AMDevice*)device
{
	deployButton.enabled = NO;
}

#pragma mark -

//
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	window.title = [NSString stringWithFormat:@"%@ - %@", NSBundleName(), NSBundleVersion()];

	//
	MobileDeviceAccess.singleton.listener = self;
	
	_tableView.target = self;
	_tableView.doubleAction = @selector(doubleClick:);
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
		
		//for ()
		
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

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return _caches.count;
}

//
- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSString *identifier = tableColumn.identifier;
	return _caches[row][identifier];
}

//
- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	_sortAscending = !_sortAscending;
	[_caches sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
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
}

#pragma mark -

//
- (void)reloadData:(AMDevice*)device
{
	if (_metas == nil)
	{
		NSString *path = NSCacheSubPath(@"YouKooMetas.plist");
		_metas = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
	}

	AFCApplicationDirectory *dir = [device newAFCApplicationDirectory:@"net.yonsm.Armor"];
	NSArray *documents = [dir directoryContents:@"Documents"];
	documents = [documents sortedArrayUsingSelector:@selector(compare:)];
	_caches = [NSMutableArray arrayWithCapacity:documents.count];
	for (NSString *document in documents)
	{
		NSString *path = [@"Documents" stringByAppendingPathComponent:document];
		NSDictionary *info = [dir getFileInfo:path];
		if ([info[@"st_ifmt"] isEqualToString:@"S_IFDIR"])
		{
			NSArray *items = [dir directoryContents:path];
			NSMutableArray *videos = [NSMutableArray arrayWithCapacity:items.count];
			for (NSString *item in items)
			{
				if ([item hasSuffix:@".flv"] || [item hasSuffix:@".mp4"])
				{
					[videos addObject:item];
				}
			}
			if (videos.count)
			{
				NSMutableDictionary *cache = [NSMutableDictionary dictionary];
				cache[@"VideoId"] = document;
				//cache[@"Videos"] = videos;
				if (_metas[document])
				{
					[cache addEntriesFromDictionary:_metas[document]];
				}
				cache[@"VideoCount"] = [NSString stringWithFormat:@"%ld", videos.count];
				[_caches addObject:cache];
			}
		}
	}
	[_tableView reloadData];
	
	[self performSelectorInBackground:@selector(reloadMeta:) withObject:_caches];
}

//
- (void)reloadMeta:(NSArray *)caches
{
	@autoreleasepool
	{
		@synchronized(self)
		{
			BOOL dirty = NO;
			for (NSDictionary *cache in caches)
			{
				NSString *videoId = cache[@"VideoId"];
				if (_metas[videoId])
				{
					//[self performSelectorOnMainThread:@selector(loadMeta:) withObject:videoId waitUntilDone:YES];
					continue;
				}

				NSString *url = [NSString stringWithFormat:@"https://v.youku.com/v_show/id_%@", videoId];
				NSURL *URL = [NSURL URLWithString:url];
				NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
				[request setValue:@"http://www.youku.com/" forHTTPHeaderField:@"Referer"];
				[request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36" forHTTPHeaderField:@"User-Agent"];
				NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
				if (data)
				{
					NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
					NSString *subtitleSpan = @"<span id=\"subtitle\" title=\"";
					NSRange start = [html rangeOfString:subtitleSpan];
					if (start.location != NSNotFound)
					{
						NSInteger location = start.location + subtitleSpan.length;
						NSRange end = [html rangeOfString:@"\"" options:0 range:NSMakeRange(location, html.length - location)];
						if (end.location != NSNotFound)
						{
							NSString *subtitle = [html substringWithRange:NSMakeRange(location, end.location - location)];
							NSLog(@"%@",subtitle);
							
							NSRange end = [html rangeOfString:@"</span>：" options:NSBackwardsSearch range:NSMakeRange(0, location)];
							if (end.location != NSNotFound)
							{
								NSString *titleSpan = @"<span>";
								NSRange start = [html rangeOfString:titleSpan options:NSBackwardsSearch range:NSMakeRange(0, end.location)];
								if (start.location != NSNotFound)
								{
									NSInteger location = start.location + titleSpan.length;
									NSString *title = [html substringWithRange:NSMakeRange(location, end.location - location)];
									NSLog(@"%@",title);
									
									NSDictionary *meta = @{@"Subtitle": subtitle ?: @"",
														   @"Title": title ?: @""};
									_metas[videoId] = meta;
									dirty = YES;
									[self performSelectorOnMainThread:@selector(loadMeta:) withObject:videoId waitUntilDone:YES];
								}
							}
						}
					}
				}
			}

			if (dirty)
			{
				NSString *path = NSCacheSubPath(@"YouKooMetas.plist");
				[_metas writeToFile:path atomically:YES];
			}
		}
	}
}

//
- (void)loadMeta:(NSString *)videoId
{
	NSUInteger count = _caches.count;
	for (NSUInteger i = 0; i < count; i++)
	{
		NSMutableDictionary *cache = _caches[i];
		if ([cache[@"VideoId"] isEqualToString:videoId])
		{
			[cache addEntriesFromDictionary:_metas[videoId]];
			[_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:i] columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(2, 2)]];
			[_tableView setNeedsDisplay];
			break;
		}
	}
}

#pragma -

//
- (void)doubleClick:(id)object
{
	NSInteger row = [_tableView clickedRow];
	NSString *videoId = _caches[row][@"VideoId"];
	NSString *url = [NSString stringWithFormat:@"https://v.youku.com/v_show/id_%@", videoId];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

@end

