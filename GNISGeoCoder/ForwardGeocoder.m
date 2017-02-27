//
//  ForwardGeocoder.m
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

#import "Project.h"
#import "ForwardGeocoder.h"
#import "GeoCoderJsonParser.h"


#ifdef DEBUG
#define NSLOG(x...) // NSLog(x)
#else
#define NSLOG(x...)
#endif


@interface ForwardGeocoder ()

#ifdef USE_NSURLSESSION
@property (nonatomic)           NSURLSessionDataTask*   geocoderSession;
@property (nonatomic)           NSData*                 geocodeConnectionData;
#else
@property (nonatomic, retain)   NSURLConnection *   geocodeConnection;
@property (nonatomic, retain)   NSMutableData *     geocodeConnectionData;
#endif
@property (nonatomic)           NSString*           boundsString;
@property (nonatomic)           NSCharacterSet*     allowedCharacterSet;

@end


@implementation ForwardGeocoder

- (instancetype)initWithDelegate:(id<ForwardGeocoderDelegate>)aDelegate
{
    self = [super init];
    if (self) {
        self.delegate = aDelegate;
        [self doInit];
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
    _queryCount = [[NSUserDefaults standardUserDefaults] integerForKey:kKeyUserDefaultsGeoCoderQCount];
    _responseCount = _queryCount;
    NSTimeInterval qTime = [[NSUserDefaults standardUserDefaults] doubleForKey:kKeyUserDefaultsGeoCoderDate];
    NSDate *qdate = [NSDate dateWithTimeIntervalSinceReferenceDate:qTime];
    NSTimeInterval age = -[qdate timeIntervalSinceNow];

    if ( age > 86400 ) { // 24hrs in seconds
        _queryCount = 0;
        _responseCount = 0;
        [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSinceReferenceDate] forKey:kKeyUserDefaultsGeoCoderDate];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kKeyUserDefaultsGeoCoderQCount];
    }
}


- (NSInteger) forwardGeocodeWithQuery:(NSString *)searchQuery mapRegion:(MKCoordinateRegion)mapRegion
{
    double southwest_latitude = mapRegion.center.latitude - mapRegion.span.latitudeDelta/2;
    double southwest_longitude = mapRegion.center.longitude - mapRegion.span.latitudeDelta/2;
    double northeast_latitude = mapRegion.center.latitude + mapRegion.span.latitudeDelta/2;
    double northeast_longitude = mapRegion.center.longitude + mapRegion.span.longitudeDelta/2;

    _boundsString = [NSString stringWithFormat:@"%f,%f|%f,%f", southwest_latitude, southwest_longitude, northeast_latitude, northeast_longitude];

    return [self forwardGeocodeWithQuery_:searchQuery];
}


- (NSInteger) forwardGeocodeWithQuery:(NSString *)searchQuery
{
    _boundsString = nil;
    return [self forwardGeocodeWithQuery_:searchQuery];
}


- (NSInteger) forwardGeocodeWithQuery_:(NSString *)searchQuery
{
    if (searchQuery.length == 0) {
        return -1;
    }

    if (self.queryCount == 0) {
        [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSinceReferenceDate] forKey:kKeyUserDefaultsGeoCoderDate];
    }

    _queryCount++;

    DLOG(@"%s: queryCount:%ld search:'%@'",__func__,(long)_queryCount,searchQuery);

#ifdef USE_NSURLSESSION
    if (self.geocoderSession) {
        [self.geocoderSession cancel];
    }
#else
    if (self.geocodeConnection) {
        [self.geocodeConnection cancel];
    }
#endif

    // Create the url object for our request. It's important to escape the
    // search string to support spaces and international characters
    // https: //maps.googleapis.com/maps/api/geocode/json?address=%@&sensor=false
    // NOTE: "sensor" parameter no longer required (Jan 10, 2017).
    //
    NSString *geocodeUrl = [NSString stringWithFormat:@"https://maps.goo%s.com/maps/%s/geocode/json?address=%@","gleapis","api",[self URLEncodedString:searchQuery]];

    if (_boundsString != nil && _boundsString.length > 0) {
        // We need to escape the parameters
        geocodeUrl = [geocodeUrl stringByAppendingFormat:@"&bounds=%@", [self URLEncodedString:_boundsString]];
    }

#ifdef YOUR_API_KEY
    geocodeUrl = [geocodeUrl stringByAppendingFormat@"&key=%@",YOUR_API_KEY];
#else
#warning NO Google API key defined (YOUR_API_KEY define in ForwardGeocoder.h)
#endif
    
    DLOG(@"%s: URL req: '%@'",__func__,geocodeUrl);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:geocodeUrl] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:kTimeoutGeoCoderConnection];

#ifdef USE_NSURLSESSION
    {
        NSInteger tagResponseCount = _queryCount; // stack local copy, not __block type
        NSURLSessionDataTask* task1 = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * jsonData, NSURLResponse * response, NSError * connectionError)
        {
            _responseCount = tagResponseCount;
            
            if (connectionError)
            {
                [self geocoderConnectionFailedWithError:connectionError];
            }
            else {
                // ok
                [self parseGeocodeWithData:jsonData];
            }
        }];
        self.geocoderSession = task1;
        [task1 resume]; // start
    }
#else
    self.geocodeConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
#endif

    [[NSUserDefaults standardUserDefaults] setInteger:self.queryCount forKey:kKeyUserDefaultsGeoCoderQCount];

    return _queryCount;
}


- (NSString *)URLEncodedString:(NSString *)string
{
    // Apples' documentation fails to provide what are in the predefined sets:
    //    URLFragmentAllowedCharacterSet  "#%<>[\]^`{|}
    //    URLHostAllowedCharacterSet      "#%/<>?@\^`{|}
    //    URLPasswordAllowedCharacterSet  "#%/:<>?@[\]^`{|}
    //    URLPathAllowedCharacterSet      "#%;<>?[\]^`{|}
    //    URLQueryAllowedCharacterSet     "#%<>[\]^`{|}
    //    URLUserAllowedCharacterSet      "#%/:<>?@[\]^`
    /*
    URLQueryAllowedCharacterSet
    !$&'()*+,-./0123456789:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~

    URLHostAllowedCharacterSet
    !$&'()*+,-.0123456789:;=ABCDEFGHIJKLMNOPQRSTUVWXYZ[]_abcdefghijklmnopqrstuvwxyz~

    URLPathAllowedCharacterSet
    !$&'()*+,-./0123456789:=@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~

    URLUserAllowedCharacterSet
    !$&'()*+,-.0123456789;=ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~

    URLFragmentAllowedCharacterSet
    !$&'()*+,-./0123456789:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~

    URLPasswordAllowedCharacterSet
    !$&'()*+,-.0123456789;=ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~
    */

    if ( self.allowedCharacterSet == nil ) {
        self.allowedCharacterSet = [NSCharacterSet URLUserAllowedCharacterSet];
    }

    NSString* enString = [string stringByAddingPercentEncodingWithAllowedCharacters:self.allowedCharacterSet];
    return enString;
}


#ifndef USE_NSURLSESSION

#pragma mark - NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    if (response.statusCode != 200)
    {
        [self.geocodeConnection cancel];
        [self geocoderConnectionFailedWithError:nil]; //[NSString stringWithFormat:@"Server returned an invalid status code: %ld",(long)response.statusCode]];
    }
    else
    {
        self.geocodeConnectionData = [NSMutableData data];
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.geocodeConnectionData appendData:data];
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
#if defined(DEBUG) || defined(_TESTING)
    NSLog(@"%s: error:'%@'",__func__,error.localizedDescription);
#endif
    [self geocoderConnectionFailedWithError:error];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.geocodeConnection = nil;

    [self parseGeocodeWithData:self.geocodeConnectionData];
    
    self.geocodeConnectionData = nil;
}
#endif // #ifndef USE_NSURLSESSION


- (void)geocoderConnectionFailedWithError:(NSError *)error
{
    if ( self.delegate && [self.delegate respondsToSelector:@selector(forwardGeocoderConnectionDidFail:withError:)] )
    {
        [self.delegate forwardGeocoderConnectionDidFail:self withError:error];
    }

#ifndef USE_NSURLSESSION
    [self.geocodeConnection cancel];
    self.geocodeConnectionData = nil;
    self.geocodeConnection = nil;
#endif
}


- (void)parseGeocodeWithData:(NSData *)responseData
{
	NSError *parseError = nil;

    GeoCoderJsonParser *parser = [[GeoCoderJsonParser alloc] init];

    [parser parseJSONData:responseData parseError:&parseError];
    
    if (self.delegate)
    {
        if (!parseError && parser.statusCode == G_GEO_SUCCESS) {
            [self.delegate forwardGeocodingDidSucceed:self withResults:parser.results];
        }
        else if ([self.delegate respondsToSelector:@selector(forwardGeocodingDidFail:withErrorCode:andErrorMessage:)]) {
            [self.delegate forwardGeocodingDidFail:self withErrorCode:parser.statusCode andErrorMessage:parseError?[parseError localizedDescription]:parser.statusMessage];
        }
    }
}


@end
