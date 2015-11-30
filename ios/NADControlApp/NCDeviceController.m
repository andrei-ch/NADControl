//
//  NADController.m
//  NADControlApp
//
//  Created by andrei_c on 11/26/15.
//  Copyright © 2015 Codium Labs LLC. All rights reserved.
//

#import "NCDeviceController.h"
#import "NCDevice.h"

#include <unistd.h>
#include <memory.h>
#include <stdio.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <net/if.h>


#define NAD_CTRL_PORT 8839


static ssize_t local_broadcast_address(struct sockaddr_in *buffer)
{
	ssize_t ret = -1;
	if (buffer == NULL)
		return ret;
	
	struct ifaddrs *interfaces;
	if (getifaddrs(&interfaces))
		return ret;
	
	struct ifaddrs *cursor = interfaces;
	while (cursor)
	{
		if (cursor->ifa_addr->sa_family == AF_INET &&
			(cursor->ifa_flags & IFF_LOOPBACK) == 0 &&
			(strcmp(cursor->ifa_name, "en0") == 0 ||
			strcmp(cursor->ifa_name, "bridge0") == 0))
		{
			*buffer = *((struct sockaddr_in*)cursor->ifa_addr);
			buffer->sin_addr.s_addr |= ~((struct sockaddr_in*)cursor->ifa_netmask)->sin_addr.s_addr;
			ret = 0;
			break;
		}
		cursor = cursor->ifa_next;
	}
	
	freeifaddrs(interfaces);
	return ret;
}


static char *local_arduino_hostname()
{
	struct sockaddr_in bcast_in;
	ssize_t ret = local_broadcast_address(&bcast_in);
	if (ret)
		return NULL;
	
	bcast_in.sin_port = htons(NAD_CTRL_PORT);
	
	int sd = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (sd <= 0)
		return NULL;
	
	static const int broadcastEnable = 1;
	ret = setsockopt(sd, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, sizeof(broadcastEnable));
	if (ret)
	{
		close(sd);
		return NULL;
	}
	
	ret = sendto(sd, @"NADC", 4, 0, (struct sockaddr*)&bcast_in, sizeof(bcast_in));
	if (ret < 0)
	{
		close(sd);
		return NULL;
	}
	
	struct timeval tv;
	tv.tv_sec = 1;
	tv.tv_usec = 0;
	if (setsockopt(sd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0)
	{
		close(sd);
		return NULL;
	}
	
	struct sockaddr_in adr_clnt;
	socklen_t len_inet = sizeof(adr_clnt);
	char dgram[64];
	
	ret = recvfrom(sd, dgram, sizeof(dgram), 0, (struct sockaddr*)&adr_clnt, &len_inet);
	if (ret < 0)
	{
		close(sd);
		return NULL;
	}
	
	close(sd);
	
	char hostname[64];
	inet_ntop(AF_INET, &adr_clnt.sin_addr, hostname, sizeof(hostname));
	return strdup(hostname);
}


@implementation NCDeviceController

+ (instancetype)sharedController {
	static NCDeviceController *singleton;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		singleton = [[NCDeviceController alloc] init];
	});
	return singleton;
}

- (void)detectDevicesUsingBlock:(void (^)(NSArray *devices, NSError *error))block {
	block = [block copy];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		char *hostname = local_arduino_hostname();
		if (hostname)
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				NCDevice *device = [[NCDevice alloc] initWithHostname:
						[NSString stringWithCString:hostname encoding:NSASCIIStringEncoding]];
				block(@[ device ], nil);
				free(hostname);
			});
		}
		else
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				block(nil, nil);
			});
		}
	});
}

@end
