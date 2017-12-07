

#import "YouKooHelper.h"

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
	NSString *metasPath = NSCacheSubPath(@"YouKooMetas.plist");
	NSDictionary *oldMetas = [NSDictionary dictionaryWithContentsOfFile:metasPath];
	NSMutableDictionary *newMetas = [NSMutableDictionary dictionary];

	// Load caches
	AFCApplicationDirectory *dir = [_device newAFCApplicationDirectory:@"net.yonsm.Armor"];
	NSArray *documents = [dir directoryContents:@"Documents"];
	documents = [documents sortedArrayUsingSelector:@selector(compare:)];
	_caches = [NSMutableArray arrayWithCapacity:documents.count];

	
	NSUInteger total = documents.count;
	NSUInteger current = 0;
	progress(current, total);

	for (NSString *videoId in documents)
	{
		// Check potential valid
		if (videoId.length != 17)
		{
			continue;
		}
		NSString *path = [@"Documents" stringByAppendingPathComponent:videoId];
//		NSDictionary *info = [dir getFileInfo:path];
//		if (![info[@"st_ifmt"] isEqualToString:@"S_IFDIR"])
//		{
//			continue;
//		}

		// Check video count
		NSArray *segments = [dir directoryContents:path];
		NSUInteger segmentsCount = 0;
		for (NSString *segment in segments)
		{
			if ([segment hasSuffix:@".flv"] || [segment hasSuffix:@".mp4"])
			{
				segmentsCount++;
			}
		}
		if (segmentsCount == 0)
		{
			continue;
		}

		//
		NSMutableDictionary *cache = [NSMutableDictionary dictionary];
		cache[@"VideoId"] = videoId;
		cache[@"SegmentsCount"] = [NSString stringWithFormat:@"%ld", segmentsCount];

		NSDictionary *meta = oldMetas[videoId];
		if (meta == nil)
		{
			meta = [self downloadMeta:videoId];
		}
		if (meta)
		{
			newMetas[videoId] = meta;
			[cache addEntriesFromDictionary:meta];
		}

		[_caches addObject:cache];
		
		[NSThread sleepForTimeInterval:1];
		progress(++current, total);
	}

	// Overwrite metas
	if (newMetas.count && ![oldMetas isEqualToDictionary:newMetas])
	{
		[newMetas writeToFile:metasPath atomically:YES];
	}

	progress(total, total);
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
			 @"Title": title ?: @"未知剧集"
			 };
}

//
- (NSString *)exportMedia:(NSIndexSet *)indexes
{
	__block NSString *result = nil;
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *ffmpeg = NSAssetSubPath(@"ffmpeg");

	AFCApplicationDirectory *dir = [_device newAFCApplicationDirectory:@"net.yonsm.Armor"];
	[indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
		NSString *path = [@"Documents" stringByAppendingPathComponent:_caches[idx][@"VideoId"]];
		NSArray *segments = [[dir directoryContents:path] sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
			int i1 = [obj1 intValue];
			int i2 = [obj2 intValue];
			return (i1 == i2) ? NSOrderedSame : ((i1 < i2) ? NSOrderedAscending : NSOrderedDescending);
		}];
		if (segments.count)
		{
			NSMutableString *concats = [NSMutableString string];
			NSString *localDir = [NSString stringWithFormat:@"/tmp/%@/%@", _caches[idx][@"Title"] ?: @"未知剧集", _caches[idx][@"Subtitle"] ?: _caches[idx][@"VideoId"]];
			for (NSString *segment in segments)
			{
				if ([segment hasSuffix:@".flv"] || [segment hasSuffix:@".mp4"])
				{
					NSString *remote = [path stringByAppendingPathComponent:segment];
					BOOL isDir = NO;
					if (![fileManager fileExistsAtPath:localDir isDirectory:&isDir])
					{
						isDir = [fileManager createDirectoryAtPath:localDir withIntermediateDirectories:YES attributes:nil error:nil];
					}
					if (isDir)
					{
						NSString *local = [localDir stringByAppendingPathComponent:segment];
						if (![fileManager fileExistsAtPath:local])
						{
							[dir copyYouKuFile:remote toLocalFile:local];
							
						}
						[concats appendFormat:@"file %@\n", segment];
					}
				}
			}
			
			if (concats.length)
			{
				NSString *videoList = [localDir stringByAppendingPathComponent:@"VideoList.txt"];
				[concats writeToFile:videoList atomically:NO encoding:NSUTF8StringEncoding error:nil];
				
				NSString *outFile = [localDir stringByAppendingPathExtension:@"mp4"];
				
				//						NSArray *arguments = @[@"-n", @"-i", concats, @"-acodec", @"copy", @"-vcodec", @"copy", @"-absf", @"aac_adtstoasc", outFile];
				//					NSString *result = [self runTask:ffmpeg arguments:arguments currentDirectory:localDir];
				NSArray *arguments = @[@"-f", @"concat", @"-i", @"VideoList.txt", @"-c", @"copy", outFile];
				result = [self runTask:ffmpeg arguments:arguments currentDirectory:localDir];
			}
		}
	}];
	
	return result;
}

//
- (NSString *)runTask:(NSString *)path arguments:(NSArray *)arguments currentDirectory:(NSString *)currentDirectory
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

//
- (void)openDetailPage:(NSUInteger)row
{
	if (row != -1)
	{
		NSString *videoId = _caches[row][@"VideoId"];
		NSString *url = [NSString stringWithFormat:@"https://v.youku.com/v_show/id_%@", videoId];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
	}
}
@end


@implementation AFCDirectoryAccess (Helper)

//
- (BOOL)copyYouKuFile:(NSString*)path1 toLocalFile:(NSString*)path2
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

