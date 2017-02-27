//
//  GeoCoderJsonParser.h
//  GNISGeoCoder
//
//  Created by Dennis on 9/3/14.
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

@interface GeoCoderJsonParser : NSObject

@property (nonatomic, readonly) int statusCode;
@property (nonatomic, readonly) NSString* statusMessage;
@property (nonatomic, readonly) NSMutableArray<ForwardGeoResult*> *results; // List of FowardGeoResult objects

- (NSDictionary*) parseJSONData:(NSData *)JSONData parseError:(NSError **)error;

@end
