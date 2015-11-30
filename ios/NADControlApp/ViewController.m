//
//  ViewController.m
//  NADControlApp
//
//  Created by andrei_c on 11/26/15.
//  Copyright © 2015 Codium Labs LLC. All rights reserved.
//

#import "ViewController.h"
#import "NCDeviceController.h"
#import "NCDevice.h"

@interface ViewController ()
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, retain) IBOutlet UIView *controlView;
@property (nonatomic, retain) NCDevice *device;
- (IBAction)buttonPressed:(UIButton*)button;
@end

@implementation ViewController {
	BOOL inBackground;
}
@synthesize activityIndicatorView;
@synthesize controlView;
@synthesize device;

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"pattern.png"]];
	
	for (UIButton *button in self.controlView.subviews)
	{
		if (![button isKindOfClass:[UIButton class]])
			continue;
		[button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
	}
	
	[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication] queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
		self.device = nil;
		inBackground = YES;
	}];
	
	[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication] queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
		NSAssert(self.device == nil, nil);
		inBackground = NO;
		[self beginDeviceDetection];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self beginDeviceDetection];
}

- (void)beginDeviceDetection {
	self.device = nil;
	
	self.controlView.hidden = YES;
	self.activityIndicatorView.hidden = NO;
	
	[[NCDeviceController sharedController] detectDevicesUsingBlock:^(NSArray *devices, NSError *error) {
		NSAssert(self.device == nil, nil);
		
		if (inBackground)
			return;
		
		if (devices.count == 0)
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self beginDeviceDetection];
			});
			return;
		}
		
		self.activityIndicatorView.hidden = YES;
		
		self.device = devices.firstObject;
		self.controlView.hidden = NO;
	}];
}

- (IBAction)buttonPressed:(UIButton*)button {
	if ([button isKindOfClass:[UIButton class]] && button.tag && self.device)
	{
		__weak NCDevice *_device = self.device;
		[self.device sendCommand:button.tag completion:^(NSError *error) {
			if (error && _device == self.device)
				[self beginDeviceDetection];
		}];
	}
}

@end
