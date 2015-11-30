//
//  NADController.h
//  NADControlApp
//
//  Created by andrei_c on 11/26/15.
//  Copyright © 2015 Codium Labs LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NCDeviceController : NSObject

+ (instancetype)sharedController;
- (void)detectDevicesUsingBlock:(void (^)(NSArray *devices, NSError *error))block;

@end
