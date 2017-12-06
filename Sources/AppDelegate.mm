

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
		
		NSIndexSet *indexes = _tableView.selectedRowIndexes;
		if (indexes.count == 0)
		{
			indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _caches.count)];
		}
		[self performSelectorInBackground:@selector(exporting:)  withObject:indexes];
	}
}

//
- (void)exporting:(NSIndexSet *)indexes
{
	@autoreleasepool
	{
		NSString *result = nil;
		
		AMDevice *device = AMDevice.anyone;
		if (device == nil)
		{
			result = @"设备不再连接";
		}
		else
		{
			NSFileManager *fileManager = [NSFileManager defaultManager];
			NSString *ffmpeg = NSAssetSubPath(@"ffmpeg");

			AFCApplicationDirectory *dir = [device newAFCApplicationDirectory:@"net.yonsm.Armor"];
			[indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
				NSString *path = [@"Documents" stringByAppendingPathComponent:_caches[idx][@"VideoId"]];
				NSArray *items = [[dir directoryContents:path] sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
					int i1 = [obj1 intValue];
					int i2 = [obj2 intValue];
					return (i1 == i2) ? NSOrderedSame : ((i1 < i2) ? NSOrderedAscending : NSOrderedDescending);
				}];
				if (items.count)
				{
					NSMutableString *concats = [NSMutableString string];
					NSString *localDir = [NSString stringWithFormat:@"/tmp/%@/%@", _caches[idx][@"Title"] ?: @"未知剧集", _caches[idx][@"Subtitle"] ?: _caches[idx][@"VideoId"]];
					for (NSString *item in items)
					{
						if ([item hasSuffix:@".flv"] || [item hasSuffix:@".mp4"])
						{
							NSString *remote = [path stringByAppendingPathComponent:item];
							BOOL isDir = NO;
							if (![fileManager fileExistsAtPath:localDir isDirectory:&isDir])
							{
								isDir = [fileManager createDirectoryAtPath:localDir withIntermediateDirectories:YES attributes:nil error:nil];
							}
							if (isDir)
							{
								NSString *local = [localDir stringByAppendingPathComponent:item];
								if (![fileManager fileExistsAtPath:local])
								{
									[dir copyYouKuFile:remote toLocalFile:local];
								
								}

#if 0
								NSArray *arguments = @[@"-n", @"-i", item, @"-vcodec", @"copy", @"-acodec", @"copy", @"-vbsf", @"h264_mp4toannexb", [item stringByAppendingPathExtension:@"ts"]];
								NSString *result = [self doTask:ffmpeg arguments:arguments currentDirectory:localDir];
								if (hasItems == NO)
								{
									hasItems = YES;
								}
								else
								{
									[concats appendString:@"|"];
								}
								[concats appendString:item];
#else
								[concats appendFormat:@"file %@\n", item];
#endif
							}
						}
					}

					if (concats.length)
					{
						NSString *videoList = [localDir stringByAppendingPathComponent:@"VideoList.txt"];
						[concats writeToFile:videoList atomically:NO];
						
						NSString *outFile = [localDir stringByAppendingPathExtension:@"mp4"];
						
//						NSArray *arguments = @[@"-n", @"-i", concats, @"-acodec", @"copy", @"-vcodec", @"copy", @"-absf", @"aac_adtstoasc", outFile];
	//					NSString *result = [self doTask:ffmpeg arguments:arguments currentDirectory:localDir];
						NSArray *arguments = @[@"-f", @"concat", @"-i", @"VideoList.txt", @"-c", @"copy", outFile];
						NSString *result = [self doTask:ffmpeg arguments:arguments currentDirectory:localDir];
					}
				}
			}];
		}
		
		[self performSelectorOnMainThread:@selector(exported:) withObject:result waitUntilDone:YES];
	}
}

//
- (void)exported:(NSString *)result
{
	[activityIndicator stopAnimation:nil];
	activityIndicator.hidden = YES;
	
	NSRunAlertPanel(@"提示", result ? result : @"已经完成。", @"确定", nil, nil, nil);
}

//
- (NSString *)doTask:(NSString *)path arguments:(NSArray *)arguments currentDirectory:(NSString *)currentDirectory
{
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = path;
	task.arguments = arguments;
	if (currentDirectory) task.currentDirectoryPath = currentDirectory;
	
	NSPipe *pipe = [NSPipe pipe];
	task.standardOutput = pipe;
	task.standardError = pipe;
	
	NSFileHandle *file = [pipe fileHandleForReading];
	
	[task launch];
	
	NSData *data = [file readDataToEndOfFile];
	NSString *result = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
	
	//NSLog(@"CMD:\n%@\n%@ARG\n\n%@\n\n", path, arguments, (result ? result : @""));
	return result;
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
				if (_metas[videoId] == nil)
				{
					NSDictionary *meta = [self downloadMeta:videoId];
					if (meta)
					{
						dirty = YES;
						_metas[videoId] = meta;
						[self performSelectorOnMainThread:@selector(loadMeta:) withObject:videoId waitUntilDone:YES];
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
- (NSDictionary *)downloadMeta:(NSString *)videoId
{
	NSString *url = [NSString stringWithFormat:@"https://v.youku.com/v_show/id_%@", videoId];
	NSURL *URL = [NSURL URLWithString:url];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
	[request setValue:@"http://www.youku.com/" forHTTPHeaderField:@"Referer"];
	[request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36" forHTTPHeaderField:@"User-Agent"];
	NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
	if (data == nil)
	{
		return nil;
	}
	
	NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSString *subtitleSpan = @"<span id=\"subtitle\" title=\"";
	NSRange start = [html rangeOfString:subtitleSpan];
	if (start.location == NSNotFound)
	{
		return nil;
	}
	
	NSInteger location = start.location + subtitleSpan.length;
	NSRange end = [html rangeOfString:@"\"" options:0 range:NSMakeRange(location, html.length - location)];
	if (end.location == NSNotFound)
	{
		return nil;
	}
	
	NSString *subtitle = [html substringWithRange:NSMakeRange(location, end.location - location)];
	if (subtitle.length == 0)
	{
		return nil;
	}

	NSString *title = nil;
	end = [html rangeOfString:@"</span>：" options:NSBackwardsSearch range:NSMakeRange(0, location)];
	if (end.location != NSNotFound)
	{
		NSString *titleSpan = @"<span>";
		start = [html rangeOfString:titleSpan options:NSBackwardsSearch range:NSMakeRange(0, end.location)];
		if (start.location != NSNotFound)
		{
			NSInteger location = start.location + titleSpan.length;
			title = [html substringWithRange:NSMakeRange(location, end.location - location)];
		}
	}
	
	return @{
			 @"Subtitle": subtitle,
			 @"Title": title ?: @""
			 };
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

