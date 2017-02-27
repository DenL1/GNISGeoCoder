//
//  GeoCoderJsonParser.m
//  GNISGeoCoder
//
//  Created by Dennis Lindsey on 9/3/14.
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

#import "GeoCoderJsonParser.h"
#import "ForwardGeocoder.h"


@implementation GeoCoderJsonParser

- (NSDictionary*)parseJSONData:(NSData *)JSONData parseError:(NSError **)error
{
    _statusCode = 0;

    id jsonObject = [NSJSONSerialization JSONObjectWithData:JSONData options:NSJSONReadingMutableContainers error:error];

    if ( ! [jsonObject isKindOfClass:[NSDictionary class]] ) {
        return jsonObject;
    }

    NSArray * resultList = jsonObject[@"results"];

    if (resultList.count)
    {
        _results = [NSMutableArray new];

        for (NSDictionary* dict in resultList)
        {

            ForwardGeoResult * currentResult = [ForwardGeoResult new];

            // String
            currentResult.address = dict[@"formatted_address"];

            // Array
            currentResult.addressComponents = dict[@"address_components"];

            NSDictionary* geometry = dict[@"geometry"];

            NSDictionary* location = geometry[@"location"];
            currentResult.latitude = [location[@"lat"] doubleValue];
            currentResult.longitude = [location[@"lng"] doubleValue];

            NSDictionary* viewPort = geometry[@"viewport"];
            NSDictionary* sw = viewPort[@"southwest"];
            currentResult.viewportSouthWestLat = [sw[@"lat"] doubleValue];
            currentResult.viewportSouthWestLon = [sw[@"lng"] doubleValue];
            NSDictionary* ne = viewPort[@"northeast"];
            currentResult.viewportNorthEastLat = [ne[@"lat"] doubleValue];
            currentResult.viewportNorthEastLon = [ne[@"lng"] doubleValue];

            [_results addObject:currentResult];
        }

    } // else {}
    
    NSString* status = jsonObject[@"status"];

    _statusMessage = status;

    if([status isEqualToString:@"OK"])
    {
        _statusCode = G_GEO_SUCCESS;
    }
    else if([status isEqualToString:@"ZERO_RESULTS"])
    {
        _statusCode = G_GEO_UNKNOWN_ADDRESS;
    }
    else if([status isEqualToString:@"OVER_QUERY_LIMIT"])
    {
        _statusCode = G_GEO_TOO_MANY_QUERIES;
    }
    else if([status isEqualToString:@"REQUEST_DENIED"])
    {
        _statusCode = G_GEO_SERVER_ERROR;
    }
    else if([status isEqualToString:@"INVALID_REQUEST"])
    {
        _statusCode = G_GEO_BAD_REQUEST;
    }

	return jsonObject;
}


@end
