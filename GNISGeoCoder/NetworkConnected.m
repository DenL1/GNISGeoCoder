//
//  NetworkConnected.m
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

#import "NetworkConnected.h"
#include <netinet/in.h>
#import <CoreLocation/CoreLocation.h>


@implementation NetworkConnected


+ (BOOL) connectedToNetwork
{
    // Create zero addy
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;

    // Recover reachability flags
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;

    Boolean didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);

    if (!didRetrieveFlags)
    {
        NSLog(@"Error. Could not recover network reachability flags");
        return NO;
    }

    boolean_t isReachable = flags & kSCNetworkFlagsReachable;
    boolean_t needsConnection = flags & kSCNetworkFlagsConnectionRequired;
	boolean_t nonWiFi = flags & kSCNetworkReachabilityFlagsTransientConnection;

//	NSURL *testURL = [NSURL URLWithString:@"http://www.apple.com/"];
//	NSURLRequest *testRequest = [NSURLRequest requestWithURL:testURL  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
//	NSURLConnection *testConnection = [[NSURLConnection alloc] initWithRequest:testRequest delegate:self startImmediately:YES];
//    return ((isReachable && ! needsConnection) || nonWiFi) ? (testConnection ? YES : NO) : NO;

    return ((isReachable && ! needsConnection) || nonWiFi);
}


+ (BOOL) connectedToInternet
{
    // Create zero addy
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;

    // Recover reachability flags
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;

    Boolean didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);

    if (!didRetrieveFlags)
    {
        NSLog(@"Error. Could not recover network reachability flags");
        return NO;
    }

    boolean_t isReachable = flags & kSCNetworkFlagsReachable;
    boolean_t needsConnection = flags & kSCNetworkFlagsConnectionRequired;

    return (isReachable && ! needsConnection);
}


+ (BOOL) connectedToWiFi
{
    SCNetworkReachabilityFlags flags = [NetworkConnected connectionFlags];
    boolean_t isReachable = flags & kSCNetworkFlagsReachable;
    boolean_t needsConnection = flags & kSCNetworkFlagsConnectionRequired;
    boolean_t nonWiFi = flags & kSCNetworkReachabilityFlagsTransientConnection;
    return (isReachable && ! needsConnection) && ! nonWiFi;
}


+ (SCNetworkReachabilityFlags) connectionFlags
{
    // Create zero addy
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;

    // Recover reachability flags
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags=0;
    Boolean didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);
    if (!didRetrieveFlags)
    {
        NSLog(@"Error. Could not recover network reachability flags");
        flags = 0;
    }
    return flags;
}

@end
