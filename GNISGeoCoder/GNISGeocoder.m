//
//  GNISGeocoder.m
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
#import "GNISGeocoder.h"
#import "GNISDatabase.h"


@interface GNISGeocoder ()

@property(nonatomic)    NSOperationQueue*   serialJobQue;

@end


@implementation GNISGeocoder

- (instancetype)initWithDelegate:(id<GNISGeocoderDelegate>)aDelegate
{
    self = [self init];
    if (self) {
        self.delegate = aDelegate;
        //[self doInit];
    }
    return self;
}

-(instancetype) init {
    self = [super init];
    if (self) {
        [self doInit];
    }
    return self;
}


- (void) doInit
{
    _timeout = kGNISDatabaseTimeout;    // 2.1 (seconds) default timeout
    [self openDB];
    [self configSerialQueue];
}


- (void) configSerialQueue
{
    if (!self.serialJobQue) {
        self.serialJobQue = [NSOperationQueue new];
    }
    self.serialJobQue.maxConcurrentOperationCount = 1;
    self.serialJobQue.qualityOfService = NSQualityOfServiceUserInteractive;
}


-(BOOL) openDB
{
    if ( ! self.hasOpenedDB ) {
        NSString *sqLiteDb = [[NSBundle mainBundle] pathForResource:kGNISDatabaseFilename ofType:nil];
        _hasOpenedDB = [[GNISDatabase database] openDB:sqLiteDb];
    }

    return _hasOpenedDB;
}


- (NSInteger) forwardGeocodeWithQuery:(NSString *)searchQuery mapRegion:(MKCoordinateRegion)mapRegion
{
    if (searchQuery.length == 0) {
        return -1;
    }

    _queryCount++;

    DLOG(@"%s: queryCount:%ld search:'%@'",__func__,(long)_queryCount,searchQuery);

    [[GNISDatabase database] cancelQueries];

    [self.serialJobQue addOperationWithBlock:^{
        
        if (self.serialJobQue.operationCount <= 1)
        {
            // Run this query

#ifdef DEBUG_off
            {
                {
                    NSDate* now1 = [NSDate date];
                    NSUInteger foundAllCount = [[GNISDatabase database] countGNISQuery:searchQuery];
                    NSDate* now2 = [NSDate date];
                    NSLog(@"%s: foundAllCount: %ld  time: %g sec",__func__,(long)foundAllCount,[now2 timeIntervalSinceDate:now1]);
                }
                NSLog(@"");
            }
#endif

            NSArray* sortedList =
            [[GNISDatabase database] GNISQuery:searchQuery
                                         latSW:mapRegion.center.latitude - mapRegion.span.latitudeDelta/2
                                         lonSW:mapRegion.center.longitude - mapRegion.span.longitudeDelta/2
                                         latNE:mapRegion.center.latitude + mapRegion.span.latitudeDelta/2
                                         lonNE:mapRegion.center.longitude + mapRegion.span.longitudeDelta/2
                                         limit:100
                                       timeout:self.timeout];

#ifdef TESTCFG
            self.results = sortedList;
#endif

            self.resultsAreSortedByDistance = YES;
            self.responseCount = self.queryCount;

            if (sortedList == nil) {
                if ([self.delegate respondsToSelector:@selector(GNISGeocodingDidFail:withErrorCode:andErrorMessage:)])
                {
                    [self.delegate GNISGeocodingDidFail:self withErrorCode:1 andErrorMessage:@"SQLITE error"];
                }
            }
            else {
                DLOG(@"%s: sortedList.count: %ld",__func__,(long)sortedList.count);
                [self.delegate GNISGeocodingDidSucceed:self withResults:sortedList];
            }
            
        } else {
            /* else skip this query since newer are queued */
            DLOG(@"%s: SKIP QUERY",__func__);
        }

#ifdef DEBUG_off
        // Test GLOB speed: results are a GLOB match starting with "*<value>" seems to search entire DB un-indexed (7.08 sec on iPad mini A5), and "<value>*" is indexed (0.19sec on iPad mini A5).
        NSLog(@"%s: TEST1 start 'select count(*) from Tgnis where name GLOB \"Gran*\"';",__func__);
        NSUInteger count = 0;
        NSDate* now1 = [NSDate date];
        count = [[GNISDatabase database] countGNISQuery:@"name GLOB \"Gran*\""];
        NSDate* now2 = [NSDate date];
        NSLog(@"   count: %ld  time: %g sec",(long)count, [now2 timeIntervalSinceDate:now1]);
        NSLog(@"%s: TEST2 start 'select count(*) from Tgnis where name GLOB \"*Gran*\";'",__func__);
        now1 = [NSDate date];
        count = [[GNISDatabase database] countGNISQuery:@"name GLOB \"*Gran*\""];
        now2 = [NSDate date];
        NSLog(@"   count: %ld  time: %g sec",(long)count, [now2 timeIntervalSinceDate:now1]);
        NSLog(@"");
#endif
    }];

    return _queryCount;
}


- (NSInteger)forwardGeocodeWithQuery:(NSString *)searchQuery
{
#ifdef TESTCFG
    self.results = nil;
#endif

    _queryCount += 1;

    [[GNISDatabase database] cancelQueries];

    [self.serialJobQue addOperationWithBlock:^{
        
        if (self.serialJobQue.operationCount <= 1)
        {
            // Run this query
            
            NSArray* list = [[GNISDatabase database] GNISQuery:searchQuery limit:100 timeout:self.timeout];
            
            self.resultsAreSortedByDistance = NO;
            self.responseCount = self.queryCount;
            
            if (list == nil) {
                if ([self.delegate respondsToSelector:@selector(GNISGeocodingDidFail:withErrorCode:andErrorMessage:)])
                {
                    // (not main thread here)
                    [self.delegate GNISGeocodingDidFail:self withErrorCode:1 andErrorMessage:@"SQLITE error"];
                }
            }
            else {
                DLOG(@"%s: sortedList.count: %ld",__func__,(long)list.count);
                [self.delegate GNISGeocodingDidSucceed:self withResults:list];
            }
        } else {
            /* else skip this query since newer are queued */
            DLOG(@"%s: SKIP QUERY",__func__);
        }
    }];

    return _queryCount;
}


@end
