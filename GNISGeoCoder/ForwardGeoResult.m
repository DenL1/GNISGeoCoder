//
//  FowardGeoResult.m
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

#import "ForwardGeoResult.h"


@implementation ForwardGeoResult

- (instancetype)initWithCoder:(NSCoder*)decoder
{
    if (self = [super init]) {
        self.address = [decoder  decodeObjectOfClass:[NSString class] forKey:@"address"];

        self.addressComponents = [decoder  decodeObjectOfClass:[NSString class] forKey:@"addressComponents"];

        self.latitude = [decoder decodeFloatForKey:@"latitude"];
        self.longitude = [decoder decodeFloatForKey:@"longitude"];
        self.viewportSouthWestLat = [decoder decodeDoubleForKey:@"viewportSouthWestLat"];
        self.viewportSouthWestLon = [decoder decodeDoubleForKey:@"viewportSouthWestLon"];
        self.viewportNorthEastLat = [decoder decodeDoubleForKey:@"viewportNorthEastLat"];
        self.viewportNorthEastLon = [decoder decodeDoubleForKey:@"viewportNorthEastLon"];
    }

    return self;
}


- (void)encodeWithCoder:(NSCoder*)encoder
{

    if (self.address) {
        [encoder encodeObject:self.address
                       forKey:@"address"];
    }

    if (self.addressComponents) {
        [encoder encodeObject:self.addressComponents
                       forKey:@"addressComponents"];
    }

    [encoder encodeFloat:self.latitude forKey:@"latitude"];
    [encoder encodeFloat:self.longitude forKey:@"longitude"];

    [encoder encodeFloat:self.viewportSouthWestLat forKey:@"viewportSouthWestLat"];
    [encoder encodeFloat:self.viewportSouthWestLon forKey:@"viewportSouthWestLon"];
    [encoder encodeFloat:self.viewportNorthEastLat forKey:@"viewportNorthEastLat"];
    [encoder encodeFloat:self.viewportNorthEastLon forKey:@"viewportNorthEastLon"];
}


-(BOOL) hasViewPortRegion
{
    return !(_viewportNorthEastLat == 0 && _viewportNorthEastLon == 0 && _viewportSouthWestLat == 0 && _viewportSouthWestLon == 0);
}


- (CLLocationCoordinate2D)coordinate
{
	CLLocationCoordinate2D coordinate = {self.latitude, self.longitude};
	return coordinate;
}


- (MKCoordinateSpan)coordinateSpan
{
	// Calculate the difference between north and south to create a span.
	float latitudeDelta = fabs((self.viewportNorthEastLat) - (self.viewportSouthWestLat));
	float longitudeDelta = fabs((self.viewportNorthEastLon) - (self.viewportSouthWestLon));

	MKCoordinateSpan spn = {latitudeDelta, longitudeDelta};

	return spn;
}


- (MKCoordinateRegion)coordinateRegion
{
	MKCoordinateRegion region;
	region.center = self.coordinate;
	region.span = self.coordinateSpan;

	return region;
}


-(CLLocation*) getLocation {
    if (_location == nil) {
        _location = [[CLLocation alloc] initWithLatitude:self.latitude longitude:self.longitude];
    }
    return _location;
}


-(NSString*) description
{
    NSString* desc = [NSString stringWithFormat:@"[%@ %p]: {\n   address: \"%@\"\n   addressComponents: '%@'\n   latitude: %0.9g\n   longitude: %0.9g\n   viewportSouthWestLat: %0.9g\n   viewportSouthWestLon: %0.9g\n   viewportNorthEastLat: %0.9g\n   viewportNorthEastLon: %0.9g\n}\n",NSStringFromClass([self class]),self, self.address, self.addressComponents, self.latitude, self.longitude, self.viewportSouthWestLat, self.viewportSouthWestLon, self.viewportNorthEastLat, self.viewportNorthEastLon];

    return desc;
}

@end
