//
//  FowardGeoResult.h
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
@import MapKit;


@interface ForwardGeoResult : NSObject <NSCoding>

@property (nonatomic) NSString *address;
@property (nonatomic) NSArray *addressComponents;
@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic) double viewportSouthWestLat;
@property (nonatomic) double viewportSouthWestLon;
@property (nonatomic) double viewportNorthEastLat;
@property (nonatomic) double viewportNorthEastLon;
@property (nonatomic) BOOL noCoordinate;    // Non geo result (ie. "(15327 matches)")

- (CLLocationCoordinate2D) coordinate;
- (MKCoordinateSpan) coordinateSpan;
- (MKCoordinateRegion) coordinateRegion;
- (BOOL) hasViewPortRegion;

@property (nonatomic,getter=getLocation) CLLocation* location;

@end
