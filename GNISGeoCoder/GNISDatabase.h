//
//  GNISDatabase.h
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
// Then GNIS is stored in a SQLite3 database.

#import <Foundation/Foundation.h>
#import "ForwardGeoResult.h"

// kGNIS_NoLikeMinLength
// When search string is 2 or fewer letters, use glob search only and no LIKE search since is scans the whole database and timesout.
#define kGNIS_NoLikeMinLength   (2)     // (int)
// kGNIS_NoGlobSpan (double) degrees
// Why: When zoomed out, search is large and slow so use GLOB search predicate to speed up.
#define kGNIS_NoGlobSpan        (2.0)   // (degrees) lat/lon span if within, don't glob search
#define kGNIS_IndexName     @"INDEX_name"   // in gnis2sqlite.ph, index table name
#define kGNIS_IndexLatLon   @"INDEX_latlon" // in gnis2sqlite.ph, index table name
// kGNIS_SearchSpanMin (double) degrees
// Why: If user zoomed in close, small search results, clamp search latitude and longitude span to this size in degrees or larger.
#define kGNIS_SearchSpanMin     (2.0)   // (degrees) degrees lat lon search span min
// kGNIS_MinBacktrackSpan
// If search region has 0 results, retries with 2x span upto 15 time, start with min span
// of 7.5' (1/8 degree).
#define kGNIS_MinBacktrackSpan  (0.125) // (degrees) is search 0 results, level up min span

@interface GNISDatabase : NSObject

@property(nonatomic)    BOOL    isCancelledQueries;
//@property(nonatomic)    NSTimeInterval  timeout;

+ (GNISDatabase*)database;

- (void) cancelQueries;

// returns sqlite3_open() status, YES for success, NO is error
- (BOOL) openDB:(NSString*) filepath;

// sorted results by distance, if limit<0 then no limit
- (NSArray<ForwardGeoResult*>*) GNISQuery:(NSString *)searchQuery latSW:(double) latSW lonSW:(double)lonSW latNE:(double) latNE lonNE:(double)lonNE limit:(NSInteger)limit timeout:(NSTimeInterval) timeout;

// unsorted results, , if limit<0 then no limit
- (NSArray<ForwardGeoResult*>*) GNISQuery:(NSString *)searchQuery limit:(NSInteger)limit timeout:(NSTimeInterval) timeout;

- (NSUInteger) countGNISQuery:(NSString *)searchQuery latSW:(double) latSW lonSW:(double)lonSW latNE:(double) latNE lonNE:(double)lonNE;

-(NSUInteger) countGNISQuery:(NSString*) searchQuery;

@end
