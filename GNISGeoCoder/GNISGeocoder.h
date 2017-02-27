//
//  GNISGeocoder.h
//  GNISGeoCoder
//
//  Created by Dennis on 2/6/17.
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
#import "ForwardGeoResult.h"
@import MapKit; // MKCoordinateRegion


#define kGNISDatabaseFilename   @"gnis_NAmer.sqlite3" // bundle file basename
#define kGNISDatabaseTimeout    (2.1)   // (seconds) default timeout


@class GNISGeocoder;


@protocol GNISGeocoderDelegate<NSObject>

@required
// Normal response
-(void) GNISGeocodingDidSucceed:(GNISGeocoder *)geocoder withResults:(NSArray<ForwardGeoResult*>*)results;

@optional
// geocoding server error response
-(void) GNISGeocodingDidFail:(GNISGeocoder *)geocoder withErrorCode:(int)errorCode andErrorMessage:(NSString *)errorMessage;

@end


@interface GNISGeocoder : NSObject

-(NSInteger) forwardGeocodeWithQuery:(NSString *)searchQuery mapRegion:(MKCoordinateRegion) mapRegion;
-(NSInteger) forwardGeocodeWithQuery:(NSString *)searchQuery;

-(instancetype) initWithDelegate:(id<GNISGeocoderDelegate>)aDelegate;

// Open the DB, returns YES if sqlite3 db file found and openned ok, NO if failed.
// If already open, returns YES.
-(BOOL) openDB;

@property(nonatomic)            BOOL                        hasOpenedDB; // open successfully
@property(nonatomic,weak)       id<GNISGeocoderDelegate>    delegate;
@property(nonatomic)            NSInteger                   queryCount;
@property(nonatomic)            NSInteger                   responseCount;
@property(nonatomic)            NSTimeInterval              timeout; // 2.1s default kGNISDatabaseTimeout
@property(nonatomic)            BOOL                        resultsAreSortedByDistance;

#ifdef TESTCFG
@property(nonatomic)            NSArray<ForwardGeoResult*>* results;
#endif

@end
