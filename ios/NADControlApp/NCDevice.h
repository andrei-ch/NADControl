//
//  NCDevice.h
//  NADControlApp
//
//  Created by andrei_c on 11/27/15.
//  Copyright © 2015 Codium Labs LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NCDevice : NSObject

- (instancetype)initWithHostname:(NSString*)hostname;
- (void)sendCommand:(NSInteger)command completion:(void (^)(NSError *error))completion;

@end
