//
//  GNISDatabase.m
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

#import "Project.h"
#import "GNISDatabase.h"
#import "sqlite3.h"
@import CoreLocation;


@interface GNISDatabase ()

@property(nonatomic) sqlite3* sql3Database1;
@property(nonatomic) NSRegularExpression* regexWords;
@property(nonatomic) NSRegularExpression* regexExtraWS;
@property(nonatomic) NSMutableString* likeExpression1;  // geo name
@property(nonatomic) NSMutableString* likeExpression2;  // state
@property(nonatomic) NSString*  likeStateExpression;
@property(nonatomic) NSString*  globExpr1;              // Geo Name
@property(nonatomic) NSString*  lastQuery;
@property(nonatomic) NSString*  lastParseString;
@property(nonatomic) NSArray*   lastResults;
@property(nonatomic) BOOL       isIndexedName;          // DB indexed on 'name'
@property(nonatomic) BOOL       isIndexedLatLon;        // DB indexed for 'lat' 'lon'

@end


static GNISDatabase* gnisDB1_;


@implementation GNISDatabase

+(GNISDatabase*) database
{
    if (gnisDB1_ == nil) {
        gnisDB1_ = [[GNISDatabase alloc] init];
    }
    return gnisDB1_;
}


-(instancetype) init
{
    if ((self = [super init]))
    {
        DLOG(@"%s: SQLITE3 VERSION: %s",__func__,sqlite3_libversion());

        NSError* error = nil;

        self.regexWords = [[NSRegularExpression alloc] initWithPattern:@"(\\w+)[^,\\w]*([,]?)" options:0 error:&error];
        self.regexExtraWS = [NSRegularExpression regularExpressionWithPattern:@"\\s{2,}|[\\t]" options:0 error:nil]; // Note: Use @"\\s{2,}|[\\t\\n\\r]" if \n \r seen in search string
        if (error) {
            NSLog(@"%s: ERROR: '%@'",__func__,error);
        }
    }
    return self;
}


-(BOOL) openDB:(NSString *)filepath
{
    if (_sql3Database1) {
        sqlite3_close(_sql3Database1);
    }
    _sql3Database1 = nil;

    // if no file name, return fail, since sqlite3_open succeeds with NULL file name.
    if (filepath.length == 0) {
        return NO;
    }

    int stat = sqlite3_open([filepath UTF8String], &_sql3Database1);

    if (stat != SQLITE_OK) {
        NSLog(@"%s: Error SQLITE code: %d opening file '%@'",__func__,stat,filepath);
    }
    else {
        [self readSchema];
    }

    return (stat == SQLITE_OK);
}


// Read the DB schema to see if index tables exist so search queries can be optimized for indexed tables.
//
-(void) readSchema
{
    NSString* query = @"SELECT type,name FROM sqlite_master;";

    DLOG(@"%s: ENTER QUERY = '%@'",__func__,query);

    _isIndexedLatLon = _isIndexedName = NO;

    sqlite3_stmt *statement = NULL;

    @try {

        int stat = sqlite3_prepare_v2(_sql3Database1, [query UTF8String], -1, &statement, nil);

        if (stat == SQLITE_OK)
        {
            while (sqlite3_step(statement) == SQLITE_ROW)
            { @autoreleasepool {

                const unsigned char *typeC = sqlite3_column_text(statement, 0);
                const unsigned char *nameC = sqlite3_column_text(statement, 1);
                NSString *type = [[NSString alloc] initWithUTF8String:(char*)typeC];
                NSString *name = [[NSString alloc] initWithUTF8String:(char*)nameC];

                DLOG(@"  SCHEMA type: '%@' name: '%@'",type,name);

                if ([type.lowercaseString isEqualToString:@"index"]) {
                    if ([name.lowercaseString isEqualToString:[kGNIS_IndexName lowercaseString]]) {
                        self.isIndexedName = YES;
                    }
                    else if ([name.lowercaseString isEqualToString:[kGNIS_IndexLatLon lowercaseString]]) {
                        self.isIndexedLatLon = YES;
                    }
                }
            }}

            if (self.isCancelledQueries) {
                DLOG(@"%s: CANCELED",__func__);
            }

            DLOG(@"%s: SORT DONE",__func__);
            
            // clean up mem
            sqlite3_finalize(statement);
        }
    } @catch (NSException *exception) {
        DLOG(@"%s: Error exception: %@",__func__,exception);
    } @finally { }
}


-(void)dealloc {
    sqlite3_close(_sql3Database1);
    _sql3Database1 = nil;
}


- (NSArray<ForwardGeoResult*>*) GNISQuery:(NSString *)searchQuery latSW:(double) latSW lonSW:(double)lonSW latNE:(double)latNE lonNE:(double)lonNE limit:(NSInteger)limit timeout:(NSTimeInterval)timeout0
{
    DLOG(@"%s: ENTER",__func__);

    self.isCancelledQueries = NO;

    if (searchQuery.length == 0) {
        return nil;
    }

    NSArray* results = [self _forwardGeocodeWithQuery:searchQuery latSW:latSW lonSW:lonSW latNE:latNE lonNE:lonNE limit:limit timeout:timeout0];


    if (results.count == 0) {

        CLLocationCoordinate2D center = CLLocationCoordinate2DMake((latSW+latNE)/2,(lonSW+lonNE)/2);
        CLLocationDegrees latSpan = latNE - latSW;
        CLLocationDegrees lonSpan = lonNE - lonSW;

        // Start with 7.5' search region (1/8 degrees)
        if (latSpan < kGNIS_MinBacktrackSpan || lonSpan < kGNIS_MinBacktrackSpan) {
            latSpan = lonSpan = kGNIS_MinBacktrackSpan;
        }

        for(int ii = 1; ii < 15 && (results.count == 0) && !_isCancelledQueries; ii += 1, latSpan += latSpan, lonSpan += lonSpan)
        {
            DLOG(@"%s: Try level up %d",__func__,ii);
            CLLocationDegrees latsw1 = center.latitude - latSpan;
            CLLocationDegrees lonsw1 = center.longitude - lonSpan;
            CLLocationDegrees latne1 = center.latitude + latSpan;
            CLLocationDegrees lonne1 = center.longitude + lonSpan;
            if (fabs(latsw1) >= 90 || fabs(latne1) >= 90 || fabs(lonsw1) >= 180 || fabs(lonne1) >= 180)
            {
                DLOG(@"%s: BREAK",__func__);
                break;
            }
            results = [self _forwardGeocodeWithQuery:searchQuery latSW:latsw1 lonSW:lonsw1 latNE:latne1 lonNE:lonne1 limit:limit timeout:timeout0];
        }
    }

    DLOG(@"%s: EXIT  results.count: %ld",__func__,(long)results.count);

    return results;
}


-(NSString*) whereExpressionFromLatSW:(double) latSW lonSW:(double)lonSW latNE:(double)latNE lonNE:(double)lonNE isSmallRegion:(BOOL) globHint
{
    NSString* latLonExp = @"1";
    NSString* stateExp = @"1";
    NSString* nameExp1 = self.likeExpression1.length?[NSString stringWithFormat:@"name LIKE \"%@\"",self.likeExpression1] : @"1";
    NSString* nameExp2 = self.likeExpression2.length?[NSString stringWithFormat:@"name LIKE \"%@\"",self.likeExpression2] : @"0";

    if (!(latSW == 0 && latNE == 0 && lonSW == 0 && latSW == 0)) {
        latLonExp =  [NSString stringWithFormat:@"lat>=%.6f AND lat<=%.6f AND lon>=%.6f AND lon<=%.6f",latSW,latNE,lonSW,lonNE];
    }

    if (self.likeStateExpression.length != 0) {
        stateExp = [NSString stringWithFormat:@"state LIKE \"%@\"",self.likeStateExpression];
    }

    NSString* whereExp = @"(1)";

    if (self.globExpr1.length)
    {
        if (globHint) {
            whereExp = [NSString stringWithFormat:@"(%@) AND ( ( ((%@) AND (%@)) OR (%@) ) AND (%@))",latLonExp,self.globExpr1,nameExp1, nameExp2, stateExp];
        } else {
            whereExp = [NSString stringWithFormat:@"(%@) AND ( ( ((%@) AND (%@)) OR (%@) ) AND (%@))",self.globExpr1, latLonExp,nameExp1, nameExp2, stateExp];
        }
    } else {
        whereExp = [NSString stringWithFormat:@"(((%@) AND (%@)) OR (%@)) AND (%@)", latLonExp,nameExp1, nameExp2, stateExp];
    }

    DLOG(@"%s: whereExp = '%@'",__func__,whereExp);

    return whereExp;
}


- (NSArray<ForwardGeoResult*>*) _forwardGeocodeWithQuery:(NSString *)searchQuery latSW:(double) latSW0 lonSW:(double)lonSW0 latNE:(double)latNE0 lonNE:(double)lonNE0 limit:(NSInteger)limit timeout:(NSTimeInterval) timeout0
{ @autoreleasepool {

    assert(latSW0<latNE0 && lonSW0<lonNE0);

    NSUInteger arraySize = limit >= 0 ? MIN(100,limit) : 100;

    NSMutableArray *barray = [[NSMutableArray alloc] initWithCapacity:arraySize];

    // No GLOB expression if in small view region and 3 or more letters since LIKE expression are nil for 1 or 2 letter queries.
    BOOL noGlobSpan = latNE0 - latSW0 <= kGNIS_NoGlobSpan && lonNE0 - lonSW0 <= kGNIS_NoGlobSpan;
    if (noGlobSpan && searchQuery.length > kGNIS_NoLikeMinLength)
    {
        _globExpr1 = nil;
    } else {
        _globExpr1 = [self glogExpressionFromQuery:searchQuery length:-1];
    }

    [self parseLikeStringFromQuery:searchQuery];

    CLLocationCoordinate2D center0 = CLLocationCoordinate2DMake((latSW0+latNE0)/2,(lonSW0+lonNE0)/2);

    double latNE,latSW,lonNE,lonSW;
    if (latNE0 - latSW0 <= kGNIS_SearchSpanMin) {
        latNE = center0.latitude + kGNIS_SearchSpanMin/2.0;
        latSW = center0.latitude - kGNIS_SearchSpanMin/2.0;
    }
    else {
        latNE = latNE0;
        latSW = latSW0;
    }
    if (lonNE0 - lonSW0 <= kGNIS_SearchSpanMin) {
        lonNE = center0.longitude + kGNIS_SearchSpanMin/2.0;
        lonSW = center0.longitude - kGNIS_SearchSpanMin/2.0;
    } else {
        lonNE = lonNE0;
        lonSW = lonSW0;
    }

    NSString *whereExp = [self whereExpressionFromLatSW: latSW lonSW:lonSW latNE:latNE lonNE:lonNE isSmallRegion:noGlobSpan];

    NSString* limitExp = @"LIMIT 50000";
//    NSString* limitExp = (limit >= 0) ? [NSString stringWithFormat:@"LIMIT %ld",(long)MIN(limit,10000)] : @"";

    NSString* query = [NSString stringWithFormat:@"SELECT name,state,lat,lon FROM Tgnis WHERE (%@) %@;",whereExp,limitExp];

    DLOG(@" QUERY = '%@'",query);
    
    if (self.lastQuery != nil && [self.lastQuery isEqualToString:query])
    {
        return _lastResults;
    }
    self.lastQuery = query;
    self.lastResults = nil;

    sqlite3_stmt *statement = NULL;

    DLOG(@"%s: SEARCH",__func__);

    if (!_isCancelledQueries && sqlite3_prepare_v2(_sql3Database1, [query UTF8String], -1, &statement, nil) == SQLITE_OK)
    {
        NSDate* timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout0];

        CLLocation* center = [[CLLocation alloc] initWithLatitude:center0.latitude longitude:center0.longitude];

        DLOG(@"%s: SORT  arraySize %ld",__func__,(long)arraySize);

        while (!_isCancelledQueries && sqlite3_step(statement) == SQLITE_ROW)
        { @autoreleasepool {

            //DLOG(@"%s: SORTING",__func__);

            //int uniqueId = sqlite3_column_int(statement, 0);
            const uint8_t *nameChars = sqlite3_column_text(statement, 0);
            const uint8_t *stateChars = sqlite3_column_text(statement, 1);
            double lat = sqlite3_column_double(statement,2);
            double lon = sqlite3_column_double(statement,3);
            NSString *name = [[NSString alloc] initWithUTF8String:(char*)nameChars];
            NSString *state = [[NSString alloc] initWithUTF8String:(char*)stateChars];
            ForwardGeoResult *info = [[ForwardGeoResult alloc] init];
            info.latitude = lat;
            info.longitude = lon;
            info.address = [NSString stringWithFormat:@"%@, %@",name,state];

            // insert sorted by distance from center location
            NSUInteger insertIndex =
            [barray indexOfObject: info
                    inSortedRange: NSMakeRange(0, barray.count)
                          options: NSBinarySearchingInsertionIndex
                  usingComparator: ^NSComparisonResult(ForwardGeoResult* _Nonnull obj1, ForwardGeoResult*  _Nonnull obj2) {

                      CLLocationDistance dis1 = [obj1.location distanceFromLocation:center];
                      CLLocationDistance dis2 = [obj2.location distanceFromLocation:center];
                      if (dis1 < dis2) {
                          return NSOrderedAscending;
                      } else if (dis1 > dis2) {
                          return NSOrderedDescending;
                      } else {
                          // sort by name
                          return [obj1.address compare:obj2.address options:NSNumericSearch];
                      }
                  }
             ];

            if (insertIndex < arraySize) {
                if ( barray.count >= arraySize ) {
                    [barray replaceObjectAtIndex:insertIndex withObject:info];
                    //DLOG(@" BSORT REPLACE @%ld '%@'",(long)insertIndex,info.address);
                } else {
                    [barray insertObject:info atIndex:insertIndex];
                    //DLOG(@" BSORT INSERT @%ld '%@'",(long)insertIndex,info.address);
                }
            }
            else { /* else array size limit hit */ }

            if (self.isCancelledQueries) {
                DLOG(@"%s: CANCELING",__func__);
            }
            
            if ([timeoutDate timeIntervalSinceNow] < 0) {
                DLOG(@"%s: TIMEOUT %g sec",__func__,timeout0);
                break;
            }
        }}
        
        if (self.isCancelledQueries) {
            DLOG(@"%s: CANCELED",__func__);
        }
        
        DLOG(@"%s: SORT DONE",__func__);
        
        // clean up mem
        sqlite3_finalize(statement);
        
    }

    self.lastResults = barray;

    return barray;
}}


- (NSArray<ForwardGeoResult*>*) GNISQuery:(NSString *)searchQuery limit:(NSInteger)limit timeout:(NSTimeInterval)timeout0
{
    DLOG(@"%s: ENTER",__func__);

    self.isCancelledQueries = NO;

    if (searchQuery.length == 0)
        return nil;

    NSMutableArray *retval = [[NSMutableArray alloc] init];

    _globExpr1 = [self glogExpressionFromQuery:searchQuery length:-1];
    [self parseLikeStringFromQuery:searchQuery];

    if (self.likeExpression1.length == 0) {
        return @[];
    }

    NSString *whereExp = [self whereExpressionFromLatSW:0 lonSW:0 latNE:0 lonNE:0 isSmallRegion:NO];
    NSString* limitExp = (limit >= 0) ? [NSString stringWithFormat:@"LIMIT %ld",(long)MIN(limit,10000)] : @"";

    NSString* query = [NSString stringWithFormat:@"SELECT name,state,lat,lon FROM Tgnis WHERE (%@) %@;",whereExp,limitExp];

    DLOG(@" QUERY = '%@'",query);

    if (self.lastQuery != nil && [self.lastQuery isEqualToString:query]) {
        return self.lastResults;
    }
    self.lastQuery = query;

    sqlite3_stmt *statement;

    if (!_isCancelledQueries && sqlite3_prepare_v2(_sql3Database1, [query UTF8String], -1, &statement, nil) == SQLITE_OK)
    {
        NSDate* timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout0];

        while (!_isCancelledQueries && sqlite3_step(statement) == SQLITE_ROW)
        { @autoreleasepool {

            //int uniqueId = sqlite3_column_int(statement, 0);
            const uint8_t *nameChars = sqlite3_column_text(statement, 0);
            const uint8_t *stateChars = sqlite3_column_text(statement, 1);
            double lat = sqlite3_column_double(statement,2);
            double lon = sqlite3_column_double(statement,3);
            NSString *name = [[NSString alloc] initWithUTF8String:(char*)nameChars];
            NSString *state = [[NSString alloc] initWithUTF8String:(char*)stateChars];
            ForwardGeoResult *info = [[ForwardGeoResult alloc] init];
            info.latitude = lat;
            info.longitude = lon;
            info.address = [NSString stringWithFormat:@"%@, %@",name,state];

            [retval addObject:info];

            if ([timeoutDate timeIntervalSinceNow] < 0) {
                DLOG(@"%s: TIMEOUT %g sec",__func__,timeout0);
                break;
            }
        }}
        
        // clean up mem
        sqlite3_finalize(statement);
    }

    self.lastResults = retval;

    DLOG(@"%s: EXIT  results.count: %ld",__func__,(long)retval.count);

    return retval;
}


-(NSUInteger) countGNISQuery:(NSString *)searchQuery latSW:(double)latSW lonSW:(double)lonSW latNE:(double)latNE lonNE:(double)lonNE
{
    DLOG(@"%s: ENTER",__func__);

    self.isCancelledQueries = NO;

    if (searchQuery.length == 0)
        return 0;

    BOOL noGlobSpan = latNE - latSW <= kGNIS_NoGlobSpan && lonNE - lonSW <= kGNIS_NoGlobSpan;
    if (noGlobSpan && searchQuery.length > kGNIS_NoLikeMinLength)
    {
        _globExpr1 = nil;
    } else {
        _globExpr1 = [self glogExpressionFromQuery:searchQuery length:-1];
    }

    [self parseLikeStringFromQuery:searchQuery];

    NSString* whereExp = [self whereExpressionFromLatSW:latSW lonSW:lonSW latNE:latNE lonNE:lonNE isSmallRegion:noGlobSpan];
    NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM Tgnis WHERE %@;",whereExp];

    sqlite3_stmt *statement;

    NSUInteger retcount = 0;

    if (!_isCancelledQueries && sqlite3_prepare_v2(_sql3Database1, [query UTF8String], -1, &statement, nil) == SQLITE_OK)
    {
        int stat = 0;
        while (!_isCancelledQueries && (stat = sqlite3_step(statement)) == SQLITE_ROW)
        { @autoreleasepool {
            uint64_t count = sqlite3_column_int64(statement, 0);
            retcount += count;
        }}

        DLOG(@"  stat=%d",stat);

        // clean up mem
        sqlite3_finalize(statement);
    }

    DLOG(@"%s: EXIT",__func__);

    return retcount;
}


-(NSUInteger) countGNISQuery:(NSString*) searchQuery
{
    return [self countGNISQuery:searchQuery latSW:0 lonSW:0 latNE:0 lonNE:0];
}


-(void) parseLikeStringFromQuery:(NSString*) string
{
    if ([self.lastParseString isEqualToString:string])
        return;

    self.lastParseString = string;
    self.likeExpression1 = nil;
    self.likeExpression2 = nil;
    self.likeStateExpression = nil;

    NSArray *matches = [self.regexWords matchesInString:string
                                                options:0
                                                  range:NSMakeRange(0, [string length])];

    int stateComma = 0;

    if (matches.count > 1 || ( matches.count == 1 && ( [matches[0] rangeAtIndex:1].length > kGNIS_NoLikeMinLength /*|| self.isIndexedName == NO*/) ) )
    {
        self.likeExpression1 = [NSMutableString stringWithString:@"%"];
        //[retStr appendString:@"%"];
        self.likeExpression2 = string.length > 1 ? [NSMutableString new] : nil;

        for (NSInteger ii = 0; ii < matches.count; ii += 1)
        {
            NSTextCheckingResult *match = matches[ii];

#ifdef DEBUG_off // test
            NSUInteger num = match.numberOfRanges;
            for (NSUInteger nn=0; nn<num; nn+=1) {
                NSRange range = [match rangeAtIndex:nn];
                printf("numberOfRanges: %ld of %ld:(loc:%ld,len:%ld) '%s'\n",(long)nn,(long)num,(long)range.location,(long)range.length,[string substringWithRange:range].UTF8String);
            }
#endif
            NSRange commaRange = [match rangeAtIndex:2];

            if (stateComma <= 1) {
                if (stateComma == 1) {
                    //if (commaRange.length == 0 && stateComma == 1)
                    {
                        NSRange firstRange = [match rangeAtIndex:1];
                        NSString* subString = [string substringWithRange:firstRange];
                        self.likeStateExpression = [NSString stringWithFormat:@"%@%%",subString];
                    }
                }
                else {
                    // Match (\\w+) word
                    NSRange firstRange = [match rangeAtIndex:1];
                    NSString* subString = [string substringWithRange:firstRange];
                    [_likeExpression1 appendString:subString];
                    [_likeExpression2 appendString:subString];
                    
                    //if (commaRange.length == 0)
                    {
                        if (ii + 1 == matches.count || commaRange.length != 0) {
                            [_likeExpression1 appendString:@"%"];
                            [_likeExpression2 appendString:@"%"];
                        } else {
                            [_likeExpression1 appendString:@"% %"];
                            [_likeExpression2 appendString:@" "];
                        }
                    }
                }
            }
            
            if (commaRange.length != 0) {
                stateComma += 1;
            }

        }
    }

    DLOG(@"%s: _likeExpression1 = '%@'  _likeExpression2='%@'",__func__,_likeExpression1,_likeExpression2);
}


// A negative length defaults to 4
-(NSString*) glogExpressionFromQuery:(NSString*) string length:(NSInteger)limit
{
#define kLengthLimit (4) // max letter count default
    if (limit < 0)
        limit = kLengthLimit;
    else if (limit == 0)
        return nil;

    NSString* globString = [self.regexExtraWS stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0,string.length) withTemplate:@" "];

    NSString* globExpr1 = [self globEntry:@"name" letters:[globString substringToIndex:MIN(limit,globString.length)]];

    DLOG(@"%s: globExpr1 = '%@'",__func__,globExpr1);

    return globExpr1;
}


// ie., '(name GLOB "D*" OR name GLOB "d*")'
// A leading "*", " " or "." induces LIKE search "%<search query string>%"
//
-(NSString*) globEntry:(NSString*) name letters:(NSString*) letters0
{
    if (letters0.length == 0)
        return nil;

    @autoreleasepool {

        unichar ch0 = [letters0 characterAtIndex:0];

        NSRange commaRange = [letters0 rangeOfString:@","];

        if (ch0 == ' ' || ch0 == '.' || ch0 == ',' || ch0 == '*' || ch0 == '?')
        {
            if (letters0.length > 2)
            {
                if (commaRange.location != NSNotFound && commaRange.location+1 != letters0.length)
                {
                    self.likeStateExpression = [letters0 substringFromIndex:commaRange.location+1];
                    self.likeStateExpression = [self.likeStateExpression stringByAppendingString:@"%"];
                }

                return nil;
            }

            if (letters0.length == 1)
                return nil;
        }

        NSString* letters = letters0;

        if (commaRange.location != NSNotFound) {
            // has comma
            letters = [letters0 substringToIndex:commaRange.location];
            if ([letters hasSuffix:@" "]) {
                letters = [letters substringToIndex:letters.length - 1];
            }
            if (letters.length == 0) {
                return nil;
            }
        }

        // If DB not indexed on name, then globbing search becomes too slow, so nil
        if ( ! _isIndexedName && letters.length > kGNIS_NoLikeMinLength ) {
            return nil;
        }

        NSString* upper = letters.uppercaseString;
        NSString* lower = letters.lowercaseString;

        NSMutableString* retStr = [NSMutableString new];

        BOOL doOR = NO;

        NSUInteger runs2 = 1UL << letters.length; // 2^len

        NSMutableSet* globs = [NSMutableSet new];

        for(NSUInteger uu = 0; uu < runs2; uu += 1)
        {
            NSMutableString* glob1 = [NSMutableString stringWithCapacity:letters.length];

            for(NSUInteger cii = 0; cii < letters.length; cii += 1)
            {
                BOOL upOrLow = ((1UL << cii) & uu) == 0;
                unichar ch1 = upOrLow ? [upper characterAtIndex:cii] : [lower characterAtIndex:cii];
                [glob1 appendFormat:@"%C",ch1];
            }

            [globs addObject:glob1];
        }

        for (NSString* glob2 in globs.allObjects)
        {
            if (doOR) {
                [retStr appendString:@" OR "];
            }
            doOR = YES;

            [retStr appendFormat:@"%@ GLOB \"%@%@\"",name,glob2,[glob2 hasSuffix:@"*"]?@"":@"*"];
        }

        return retStr;
    }
}


-(void) cancelQueries {
    self.isCancelledQueries = YES;
}

@end
