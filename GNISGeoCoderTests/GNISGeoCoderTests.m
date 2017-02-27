//
//  GNISGeoCoderTests.m
//  GNISGeoCoderTests
//
//  Created by Dennis on 1/27/17.
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

#import <XCTest/XCTest.h>
#import "GNISGeocoder.h"
#import "GNISDatabase.h"


#define yield(seconds) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:((double)(seconds))]]


@interface GNISGeoCoderTests : XCTestCase

@end


@implementation GNISGeoCoderTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


// The Jug test
//
// Test the GNIS DB search query string with sloppy user like input "the Jug.  ,  .az,  usa"
// and expect "The Jug, AZ" results
//
// INPUT: @"the Jug.  ,  .az,  usa"
// EXEPECT: At least 1 ForwardGeoResult entry with .address = "The Jug, AZ"
//
- (void)testGNIS_The_Jug {

    NSString* testInput = @"the Jug.  ,  .az,  usa";
    //testInput = @"salome creek";

    NSString* testExpect = @"The Jug, AZ";

    GNISGeocoder* geocoder = [GNISGeocoder new];
    NSArray<ForwardGeoResult*> *results;

    NSTimeInterval defaultTimeout = geocoder.timeout;
    XCTAssertTrue(defaultTimeout == kGNISDatabaseTimeout);
    geocoder.timeout = 0.0001;
    XCTAssertTrue(geocoder.timeout == 0.0001);

    // Start forward geocode query at Salome Creek/The Jug trail head zoomed in.
    long qTag = [geocoder forwardGeocodeWithQuery:testInput mapRegion:MKCoordinateRegionMake(CLLocationCoordinate2DMake(33.7712,-111.1357), MKCoordinateSpanMake(0.02, 0.02))];

    NSLog(@" 0 qTag = %ld  responseCount = %ld",qTag,(long)geocoder.responseCount);

    XCTAssertTrue(qTag > 0, @"FAIL: expect qTag(%ld) > 0.",qTag);

    while(qTag > geocoder.responseCount) {
        yield(0.333333);
        NSLog(@" qTag = %ld  responseCount = %ld",qTag,(long)geocoder.responseCount);
    }

    NSLog(@" FETCHED qTag = %ld  responseCount = %ld",qTag,(long)geocoder.responseCount);

    results = [geocoder results];

    NSLog(@" GOT: results (count %ld): '%@'\n",(long)results.count,results.description);

    XCTAssertTrue((results.count >= 1),@"FAIL: 0 count results for 'The Jug, AZ'");

    __block NSUInteger ind = NSNotFound;

    [results indexOfObjectPassingTest:^BOOL(ForwardGeoResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ( [obj.address.lowercaseString isEqualToString:testExpect.lowercaseString] ) {
            *stop = YES;
            ind = idx;
            return YES;
        }
        return NO;
    }];

    if (ind == NSNotFound) {
        XCTFail("FAIL: 'The Jug, AZ' not found, have results: '%@'",results);
        return;
    }

    double lat = results[ind].latitude;
    double lon = results[ind].longitude;
    BOOL assert1 = (fabs(lat - 33.7972688) < 0.0000001) && (fabs(lon - (-111.1004005)) < 0.0000001);

    XCTAssertTrue(assert1, @"FAIL: lat,lon = %0.9g,%0.9g (expect: %0.9g,%0.9g ±0.0000001)",[results[ind] latitude],[results[ind] longitude],33.7972688,-111.1004005);
}



// nothing_found
//
// Test the GNIS DB search query string with a non-existing input search string.
//
// INPUT: @"the Juzz,az"
// EXEPECT: 0 ForwardGeoResult entrys.
//
- (void)testGNIS_nothing_found {

    NSString* testInput = @"the JuZZ,az"; // not in DB
    //testInput = @"salome creek";

    //NSString* testExpect = nil;

    GNISGeocoder* geocoder = [GNISGeocoder new];
    NSArray<ForwardGeoResult*> *results;

    NSTimeInterval defaultTimeout = geocoder.timeout;
    XCTAssertTrue(defaultTimeout == kGNISDatabaseTimeout);
    geocoder.timeout = 10.0;
    XCTAssertTrue(geocoder.timeout == 10.0);

    long qTag = [geocoder forwardGeocodeWithQuery:testInput mapRegion:MKCoordinateRegionMake(CLLocationCoordinate2DMake(33.7712,-111.1357), MKCoordinateSpanMake(0.02, 0.02))];

    NSLog(@" 0 qTag = %ld  responseCount = %ld",qTag,(long)geocoder.responseCount);

    XCTAssertTrue(qTag > 0, @"FAIL: expect qTag(%ld) > 0.",qTag);

    while(qTag > geocoder.responseCount) {
        yield(0.333333);
        NSLog(@" qTag = %ld  responseCount = %ld",qTag,(long)geocoder.responseCount);
    }

    NSLog(@" FETCHED qTag = %ld  responseCount = %ld",qTag,(long)geocoder.responseCount);

    results = [geocoder results];

    NSLog(@" GOT: results (count %ld): '%@'\n",(long)results.count,results.description);

    XCTAssertTrue((results.count == 0),@"FAIL: >0 count results, expect: 0 count, have: %ld (Or, is the test input string now a valid GNIS entry)",(long)results.count);

}


// The Jug test
//
// Test the GNIS DB search query string with a valid search, but requires the search to expand the lat lon span levels to find.
//
// INPUT: @"craters moon, id" while map region is initially zoomed into Arizona.
// EXEPECT: At least 1 ForwardGeoResult entry with .address = "Craters of the Moon National Monument, ID".
//
- (void)testGNIS_jug2craters_of_the_moon {

    NSString* testInput = @"craters moon,Id";
    //testInput = @"salome creek";

    const NSString* testExpect = @"Craters of the Moon National Monument, ID";
    const CLLocationCoordinate2D expectCoord = CLLocationCoordinate2DMake(43.2023088,-113.478887);
    const CLLocationDegrees expectGuardband = MAX(fabs(43.2023088-43.4165704),fabs(-113.517514-(-113.478887))) * 1.05;
    const int expectEntries = 2;

    GNISGeocoder* geocoder = [GNISGeocoder new];
    NSArray<ForwardGeoResult*> *results;

    NSTimeInterval defaultTimeout = geocoder.timeout;
    XCTAssertTrue(defaultTimeout == kGNISDatabaseTimeout);
    geocoder.timeout = 15.0;
    XCTAssertTrue(geocoder.timeout == 15.0);

    long qTag = [geocoder forwardGeocodeWithQuery:testInput mapRegion:MKCoordinateRegionMake(CLLocationCoordinate2DMake(33.7712,-111.1357), MKCoordinateSpanMake(0.0001, 0.0001))];

    NSLog(@" 0 qTag = %ld  responseCount = %ld",qTag,(long)geocoder.responseCount);

    XCTAssertTrue(qTag > 0, @"FAIL: expect qTag(%ld) > 0.",qTag);

    while(qTag > geocoder.responseCount) {
        yield(0.333333);
        NSLog(@" qTag = %ld  responseCount = %ld",qTag,(long)geocoder.responseCount);
    }

    NSLog(@" FETCHED qTag = %ld  responseCount = %ld",qTag,(long)geocoder.responseCount);

    results = [geocoder results];

    NSLog(@" GOT: results (count %ld): '%@'\n",(long)results.count,results.description);

    XCTAssertTrue((results.count >= 1),@"FAIL: 0 count results for '%@'",testInput);

    __block NSUInteger ind = NSNotFound;
    __block int entries = 0;

    [results indexOfObjectPassingTest:^BOOL(ForwardGeoResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ( [obj.address.lowercaseString isEqualToString:testExpect.lowercaseString] ) {
            ind = idx;
            entries += 1;
        }
        return NO;
    }];

    XCTAssertTrue(entries == expectEntries,@"FAIL: Wrong number of expected matches, expected %d, have: %d",expectEntries,entries);

    if (ind == NSNotFound) {
        XCTFail("FAIL: address not found, expect: '%@', have results: '%@'",testExpect,results);
        return;
    }

    double lat = results[ind].latitude;
    double lon = results[ind].longitude;
    BOOL assert1 = (fabs(lat - expectCoord.latitude) < expectGuardband) && (fabs(lon - expectCoord.longitude) < expectGuardband);

    XCTAssertTrue(assert1, @"FAIL: lat,lon = %0.9g,%0.9g (expect: %0.9g,%0.9g ±%0.9g)",[results[ind] latitude],[results[ind] longitude],expectCoord.latitude,expectCoord.longitude,expectGuardband);
}



- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
