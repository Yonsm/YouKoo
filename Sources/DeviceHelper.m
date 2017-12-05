

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

