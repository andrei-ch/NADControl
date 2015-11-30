//
//  NCDevice.m
//  NADControlApp
//
//  Created by andrei_c on 11/27/15.
//  Copyright © 2015 Codium Labs LLC. All rights reserved.
//

#import "NCDevice.h"

@interface NCDevice ()
@property (nonatomic, retain) NSString *hostname;
@property (atomic) BOOL invalid;
@end


@implementation NCDevice
@synthesize hostname;

- (instancetype)initWithHostname:(NSString*)_hostname {
	self = [super init];
	if (self)
	{
		self.hostname = _hostname;
	}
	return self;
}

- (void)sendCommand:(NSInteger)command completion:(void (^)(NSError *error))completion {
	static dispatch_queue_t serialQueue;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		serialQueue = dispatch_queue_create("queue.com.codiumlabs.nadcontrol", DISPATCH_QUEUE_SERIAL);
	});
	
	completion = [completion copy];
	
	NSString *URLString = [NSString stringWithFormat:@"http://%@/%u", self.hostname, (unsigned)command];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URLString]
			cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:5.0];
	
	dispatch_async(serialQueue, ^{
		if (self.invalid)
		{
			completion([NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]);
			return;
		}
		
		NSURLResponse *response = nil;
		NSError *error = nil;
		[NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
		if (error)
			self.invalid = YES;
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(error);
		});
	});
}

@end
