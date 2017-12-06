

#import "DeviceHelper.h"

@implementation AMDevice (Helper)

//
+ (AMDevice *)anyone
{
	NSArray *devices = MobileDeviceAccess.singleton.devices;
	for (AMDevice *device in devices)
	{
		if (device.deviceName)
		{
			return device;
		}
	}
	return nil;
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
			uint32_t n = (uint32_t)[in readN:sizeof(header) bytes:&header];
			if (header.magic == 'KY')
			{
				[in seek:header.size mode:SEEK_SET];
			}
			else
			{
				//[in seek:0 mode:SEEK_SET];
				NSData *b2 = [[NSData alloc] initWithBytesNoCopy:&header length:sizeof(header) freeWhenDone:NO];
				[out writeData:b2];
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

