

#import "YouKooHelper.h"

@implementation NSFileManager (Helper)

//
- (BOOL)ensureDirectoryExists:(NSString *)dir
{
	BOOL isDir = NO;
	if ([self fileExistsAtPath:dir isDirectory:&isDir])
	{
		return isDir;
	}
	return [self createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
}
@end


@implementation NSTask (Helper)

//
+ (NSTask *)runTask:(NSString *)path arguments:(NSArray *)arguments currentDirectory:(NSString *)currentDirectory
{
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = path;
	task.arguments = arguments;
	task.currentDirectoryPath = currentDirectory;
	
	NSPipe *pipe = [NSPipe pipe];
	task.standardOutput = pipe;
	task.standardError = pipe;
	
	@try
	{
		[task launch];
	}
	@catch (NSException *e)
	{
		return nil;
	}
	
	[task waitUntilExit];
	return task;
}

@end


@implementation AFCDirectoryAccess (Helper)

//
- (BOOL)copyYouKooFile:(NSString*)path1 toLocalFile:(NSString*)path2
{
	BOOL result = NO;
	AFCFileReference *in = [self openForRead:path1];
	if (in)
	{
		[NSFileManager.defaultManager createFileAtPath:path2 contents:nil attributes:nil];
		NSFileHandle *out = [NSFileHandle fileHandleForWritingAtPath:path2];
		if (out)
		{
			const long bufsz = 10240;
			char *buff = malloc(bufsz);
			
			// Check YouKu header & skip it
			struct {UInt16 magic; UInt16 size;} header;
			uint32_t n = (uint32_t)[in readN:sizeof(header) bytes:(char *)&header];
			if (n == sizeof(header))
			{
				if (header.magic == 0x4B59/*'YK'*/)
				{
					[in seek:header.size mode:SEEK_SET];
				}
				else
				{
					//[in seek:0 mode:SEEK_SET];
					NSData *b2 = [[NSData alloc] initWithBytesNoCopy:&header length:sizeof(header) freeWhenDone:NO];
					[out writeData:b2];
				}
			}
			
			while (1)
			{
				uint32_t n = (uint32_t)[in readN:bufsz bytes:buff];
				if (n==0) break;
				
				NSData *b2 = [[NSData alloc] initWithBytesNoCopy:buff length:n freeWhenDone:NO];
				[out writeData:b2];
			}
			free(buff);
			[out closeFile];
			result = YES;
		}
		[in closeFile];
	}
	return result;
}

@end


@implementation YouKooHelper

//
- (instancetype)initWithDevice:(AMDevice *)device
{
	self = [super init];
	_device = device;
	return self;
}

//
- (void)loadCaches:(void (^)(NSUInteger current, NSUInteger total))progress
{
	// Load meta info
	NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
	NSDictionary *metas = [preferences objectForKey:@"Metas"];
	NSMutableDictionary *validMetas = [NSMutableDictionary dictionary];
	
	// Load caches
	AFCApplicationDirectory *afcDir = [_device newAFCApplicationDirectory:@"net.yonsm.Armor"];
	NSArray *documents = [afcDir directoryContents:@"Documents"];
	documents = [documents sortedArrayUsingSelector:@selector(compare:)];
	_caches = [NSMutableArray arrayWithCapacity:documents.count];
	
	//
	NSMutableDictionary *videos = [NSMutableDictionary dictionaryWithCapacity:documents.count];
	for (NSString *document in documents)
	{
		// Check potential valid
		if (document.length != 17)
		{
			continue;
		}
		NSString *path = [@"Documents" stringByAppendingPathComponent:document];
		//		NSDictionary *info = [afcDir getFileInfo:path];
		//		if (![info[@"st_ifmt"] isEqualToString:@"S_IFDIR"])
		//		{
		//			continue;
		//		}
		
		// Check video count
		NSArray *segments = [afcDir directoryContents:path];
		NSUInteger segmentsCount = 0;
		for (NSString *segment in segments)
		{
			if ([segment hasSuffix:@".flv"] || [segment hasSuffix:@".mp4"])
			{
				segmentsCount++;
			}
		}
		if (segmentsCount)
		{
			videos[document] = [NSString stringWithFormat:@"%ld", segmentsCount];
		}
	}
	
	//
	NSUInteger total = videos.count;
	NSUInteger current = 0;
	for (NSString *videoId in videos.allKeys)
	{
		NSMutableDictionary *cache = [NSMutableDictionary dictionary];
		cache[@"VideoId"] = videoId;
		cache[@"SegmentsCount"] = videos[videoId];
		
		//
		if ([self lookupMeta:videoId metas:metas cache:cache])
		{
			NSMutableDictionary *meta = validMetas[cache[@"Title"]];
			if (meta == nil)
			{
				meta = [NSMutableDictionary dictionary];
				validMetas[cache[@"Title"]] = meta;
			}
			meta[videoId] = cache[@"Subtitle"];
		}
		
		[_caches addObject:cache];
		progress(++current, total);
	}
	
	// Overwrite metas
	if (validMetas.count && ![metas isEqualToDictionary:validMetas])
	{
		[preferences setObject:validMetas forKey:@"Metas"];
		[preferences synchronize];
	}
}

//
- (BOOL)lookupMeta:(NSString *)videoId metas:(NSDictionary *)metas cache:(NSMutableDictionary *)cache
{
	for (NSString *title in metas.allKeys)
	{
		NSDictionary *meta = metas[title];
		for (NSString *metaId in meta.allKeys)
		{
			if ([videoId isEqualToString:metaId])
			{
				cache[@"Title"] = title;
				cache[@"Subtitle"] = meta[metaId];
				return YES;
			}
		}
	}
	return [self downloadMeta:videoId cache:cache];
}

//
- (BOOL)downloadMeta:(NSString *)videoId cache:(NSMutableDictionary *)cache
{
	NSString *url = [NSString stringWithFormat:@"https://v.youku.com/v_show/id_%@", videoId];
	NSURL *URL = [NSURL URLWithString:url];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
	[request setValue:@"http://www.youku.com/" forHTTPHeaderField:@"Referer"];
	[request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36" forHTTPHeaderField:@"User-Agent"];
	NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
	if (data == nil)
	{
		return NO;
	}
	
	NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSString *subtitleSpan = @"<span id=\"subtitle\" title=\"";
	NSRange start = [html rangeOfString:subtitleSpan];
	if (start.location == NSNotFound)
	{
		return NO;
	}
	
	NSInteger location = start.location + subtitleSpan.length;
	NSRange end = [html rangeOfString:@"\"" options:0 range:NSMakeRange(location, html.length - location)];
	if (end.location == NSNotFound)
	{
		return NO;
	}
	
	NSString *subtitle = [html substringWithRange:NSMakeRange(location, end.location - location)];
	if (subtitle.length == 0)
	{
		return NO;
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
	
	cache[@"Subtitle"] = subtitle;
	cache[@"Title"] = title ?: @"未知剧集";
	return YES;
}

//
- (NSString *)exportCaches:(NSIndexSet *)indexes
					outDir:(NSString *)outDir
					tmpDir:(NSString *)tmpDir
				  progress:(void (^)(NSUInteger current, NSUInteger total))progress
				 progress2:(void (^)(NSUInteger current, NSUInteger total))progress2
{
	__block NSString *result = nil;
	
	NSString *ffmpeg = NSAssetSubPath(@"ffmpeg");
	NSFileManager *fileManager = [NSFileManager defaultManager];
	AFCApplicationDirectory *afcDir = [_device newAFCApplicationDirectory:@"net.yonsm.Armor"];
	
	__block NSUInteger current = 0; NSUInteger total = indexes.count;
	[indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		NSString *ret = [self exportCache:_caches[index] afcDir:afcDir outDir:outDir tmpDir:tmpDir ffmpeg:ffmpeg fileManager:fileManager progress2:progress2];
		if (ret)
		{
			result = [NSString stringWithFormat:@"视频：%@\n\n%@", _caches[index][@"Subtitle"] ?: _caches[index][@"VideoId"], ret];
			*stop = YES;
		}
		else
		{
			progress(++current, total);
		}
	}];
	return result;
}

//
- (NSString *)exportCache:(NSDictionary *)cache
				   afcDir:(AFCDirectoryAccess *)afcDir
				   outDir:(NSString *)outDir
				   tmpDir:(NSString *)tmpDir
				   ffmpeg:(NSString *)ffmpeg
			  fileManager:(NSFileManager *)fileManager
				progress2:(void (^)(NSUInteger current, NSUInteger total))progress2
{
	NSUInteger current = 0;
	NSUInteger total = [cache[@"SegmentsCount"] integerValue];
	progress2(current, total);

	if (_exportingCancelled)
	{
		return @"已取消";
	}
	
	// Check output file exists
	NSString *subPath = [NSString stringWithFormat:@"%@/%@", cache[@"Title"] ?: @"未知剧集", cache[@"Subtitle"] ?: cache[@"VideoId"]];
	NSString *outFile = [NSString stringWithFormat:@"%@/%@.mp4", outDir, subPath];
	if ([fileManager fileExistsAtPath:outFile])
	{
		return nil;
	}
	// Lookup remote video segments
	NSString *remoteDir = [@"Documents" stringByAppendingPathComponent:cache[@"VideoId"]];
	NSArray *segments = [[afcDir directoryContents:remoteDir] sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
		int i1 = [obj1 intValue];
		int i2 = [obj2 intValue];
		return (i1 == i2) ? NSOrderedSame : ((i1 < i2) ? NSOrderedAscending : NSOrderedDescending);
	}];
	
	// Prepare local working directory
	NSString *localDir = [tmpDir stringByAppendingPathComponent:subPath];
	if (![fileManager ensureDirectoryExists:localDir])
	{
		return @"创建临时目录失败";
	}
	
	// Export video segments
	NSMutableString *concats = [NSMutableString string];
	for (NSString *segment in segments)
	{
		if ([segment hasSuffix:@".flv"] || [segment hasSuffix:@".mp4"])
		{
			[concats appendFormat:@"file %@\n", segment];
			
			NSString *remote = [remoteDir stringByAppendingPathComponent:segment];
			NSString *local = [localDir stringByAppendingPathComponent:segment];
			if ([fileManager fileExistsAtPath:local])
			{
				// Check file size
				NSDictionary *localInfo = [fileManager attributesOfItemAtPath:local error:nil];
				NSDictionary *remoteInfo = [afcDir getFileInfo:remote];
				long long localSize = [localInfo[@"NSFileSize"] longLongValue];
				long long remoteSize = [remoteInfo[@"st_size"] longLongValue];
				if ((localSize == remoteSize) || (localSize + 34/*magic header*/ == remoteSize))
				{
					continue;
				}
				[fileManager removeItemAtPath:local error:nil];
			}
			
			if (_exportingCancelled)
			{
				return @"已取消";
			}
			if (![afcDir copyYouKooFile:remote toLocalFile:local])
			{
				return @"导出文件失败";
			}
			progress2(++current, total);
		}
	}
	
	if (concats.length == 0)
	{
		return @"未找到视频片段";
	}
	
	// Prepare output directory
	if (![fileManager ensureDirectoryExists:outFile.stringByDeletingLastPathComponent])
	{
		return @"创建输出目录失败";
	}
	
	// Create video list file
	NSString *videoList = [localDir stringByAppendingPathComponent:@"VideoList.txt"];
	[concats writeToFile:videoList atomically:NO encoding:NSUTF8StringEncoding error:nil];
	
	// Perform vidoe segments merging
	NSArray *arguments = @[@"-y", @"-f", @"concat", @"-i", @"VideoList.txt", @"-c", @"copy", outFile];
	
	if (_exportingCancelled)
	{
		return @"已取消";
	}
	
	//
	NSTask *task = [NSTask runTask:ffmpeg arguments:arguments currentDirectory:localDir];
	if (task == nil)
	{
		return [NSString stringWithFormat:@"运行失败：%@", ffmpeg];
	}
	
	//
	int terminationStatus = task.terminationStatus;
	if (terminationStatus == 0)
	{
		[fileManager removeItemAtPath:localDir error:nil];
		return nil;
	}
	
	NSMutableString *error = [NSMutableString stringWithFormat:@"合并文件出错：%d\n\ncd %@\n%@ ", terminationStatus, [localDir stringByReplacingOccurrencesOfString:@" " withString:@"\\ "], [ffmpeg stringByReplacingOccurrencesOfString:@" " withString:@"\\ "]];
	for (NSString *argument in arguments)
	{
		[error appendString:@" "];
		[error appendString:[argument stringByReplacingOccurrencesOfString:@" " withString:@"\\ "]];
	}
	return error;
}

//
- (void)showPage:(NSUInteger)index
{
	if (index < _caches.count)
	{
		NSString *videoId = _caches[index][@"VideoId"];
		NSString *url = [NSString stringWithFormat:@"https://v.youku.com/v_show/id_%@", videoId];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
	}
}
@end

