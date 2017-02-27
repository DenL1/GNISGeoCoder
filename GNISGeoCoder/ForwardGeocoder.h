//
//  ForwardGeocoder.h
//  GNISGeoCoder
//
//  Created by Dennis on 9/5/14.
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
#import <MapKit/MapKit.h>
#import "ForwardGeoResult.h"

// Set the macro YOUR_API_KEY to be the Google API key
//#define YOUR_API_KEY @"01234567-89ab-cdef-0000-a5a5a5a5a5a5"

#define USE_NSURLSESSION

#define kKeyUserDefaultsGeoCoderQCount  @"GEO_CODER_queryCount"         // query count store for 24hrs limit
#define kKeyUserDefaultsGeoCoderDate    @"GEO_CODER_queryCount1Date"    // User to reset count after 24hrs

//#define kGoogeDailyQueryMax    (2500)

#define kTimeoutGeoCoderConnection (20.0) // Satellite internet takes just about 15 sec, so use 20 seconds

// Enum for geocoding status responses
enum {
	G_GEO_SUCCESS = 200,
	G_GEO_BAD_REQUEST = 400,
	G_GEO_SERVER_ERROR = 500,
	G_GEO_MISSING_QUERY = 601,
	G_GEO_UNKNOWN_ADDRESS = 602, // zero results
	G_GEO_UNAVAILABLE_ADDRESS = 603,
	G_GEO_UNKNOWN_DIRECTIONS = 604,
	G_GEO_BAD_KEY = 610,
	G_GEO_TOO_MANY_QUERIES = 620,
    G_GEO_NETWORK_ERROR = 900
};


@class ForwardGeocoder;


@protocol ForwardGeocoderDelegate<NSObject>

@required
// Normal response
- (void)forwardGeocodingDidSucceed:(ForwardGeocoder *)geocoder withResults:(NSArray<ForwardGeoResult*>*)results;

@optional
// URL session failed
- (void)forwardGeocoderConnectionDidFail:(ForwardGeocoder *)geocoder withError:(NSError *)error;

// geocoding server error response
- (void)forwardGeocodingDidFail:(ForwardGeocoder *)geocoder withErrorCode:(int)errorCode andErrorMessage:(NSString *)errorMessage;

@end


@interface ForwardGeocoder : NSObject <NSURLConnectionDataDelegate>

- (instancetype)initWithDelegate:(id<ForwardGeocoderDelegate>)aDelegate;

// Returns queryCount tag, <0 for no query made
- (NSInteger)forwardGeocodeWithQuery:(NSString *)searchQuery mapRegion:(MKCoordinateRegion) mapRegion;
- (NSInteger)forwardGeocodeWithQuery:(NSString *)searchQuery;

@property(nonatomic,weak)       id<ForwardGeocoderDelegate> delegate;
@property(nonatomic)            NSInteger                   queryCount;
@property(nonatomic)            NSInteger                   responseCount;
@property(nonatomic)            BOOL                        resultsAreSortedByDistance;

@end
