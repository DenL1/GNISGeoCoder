//
//  NetworkConnected.h
//  GNISGeoCoder
//
//  Created by Dennis on 9/18/14.
//  The author disclaims copyright to this source code.
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SCNetworkReachability.h>


@interface NetworkConnected : NSObject

+ (BOOL) connectedToNetwork;    // 
+ (BOOL) connectedToInternet;
+ (BOOL) connectedToWiFi;
+ (SCNetworkReachabilityFlags) connectionFlags; // uint32_t

@end
