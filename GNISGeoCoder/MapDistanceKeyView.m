//
//  TNDistanceKeyView2.m
//  GNISGeoCoder
//
//  Created by Dennis E. Lindsey on 4/25/14.
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

#import "MapDistanceKeyView.h"
#import <math.h>


#define kLINECAP                kCGLineCapRound
#define kDK_FONT_NAME           @"Arial"    //  "Helvetica" "Verdana"
#define kDK_FONT_SMALL_SCALE    (0.75)
#define kDK_TEXT_BAR_SPACE      (4.0f)      // Top of bar to bottom of text space
#define kDK_FONT_STROKE         (25.0f)     // Percent font size
#define kDistSegsMinCount       (2)
#define kDistSegsMaxCount       (3)


@interface MapDistanceKeyView ()
{
    size_t      baseRanges_count;
    size_t      segmentCounts_count;
    NSUInteger  maxSegments_;

    // Drawing variables based on fontsize & consts
    CGFloat     barMidY_;
    CGFloat     xLeft_;
    CGFloat     yBotLine_,yTopLine_;
    CGFloat     yTopSeg_,yBotSeg_;
    CGFloat     yTopTick_;
    CGFloat     textY_;
    CGFloat     widthConstraintSave_;
}

@property (nonatomic) double                    frameWidthMeters;   // width in meters of this frame in MKMapView zoom
@property (nonatomic) CGFloat                   frameWidthBar;      // Indictor bar width (frame less margins)
@property (nonatomic) double                    metersPerPoint;
@property (nonatomic) NSUInteger                segmentsCount;
@property (nonatomic) CGFloat                   segmentFrameWidthUnits;
@property (nonatomic) CGFloat                   lastSegmentValue;

// pixels width of segment (length in pixels)
@property (nonatomic) CGFloat                   segmentWidth;

// units per segment (ie., miles/segment)
@property (nonatomic) CGFloat                   segmentValue;

@property (nonatomic) UIColor*                  lineColor;
@property (nonatomic) UIColor*                  segEvenColor;
@property (nonatomic) UIColor*                  segOddColor;
@property (nonatomic) CGFloat                   rightMargin;
@property (nonatomic) CGFloat                   fontSize;           // 15 pt default
@property (nonatomic) NSDictionary*             fontAttributes;     // Stroke
@property (nonatomic) NSDictionary*             fontAttributes2;    // Fill
@property (nonatomic) NSDictionary*             fontAttributes_small;   // Stroke
@property (nonatomic) NSDictionary*             fontAttributes2_small;  // Fill
@property (nonatomic) UIFont*                   uifont;
@property (nonatomic) UIFont*                   uifontSmall;
@property (nonatomic) NSShadow*                 shadow;
@property (nonatomic) NSMutableArray<NSAttributedString*>* textValues;  // fonts STROKE
@property (nonatomic) NSMutableArray<NSAttributedString*>* textValues2; // fonts FILL
@property (nonatomic) CGFloat*                  textValuesWidths;
@property (nonatomic) NSAttributedString*       unitsText;          // Units string
@property (nonatomic) NSAttributedString*       unitsText2;         // Units string
@property (nonatomic) CGFloat                   unitsTextWidth;
@property (nonatomic) CGFloat                   unitsTextX;
@property (nonatomic) CGFloat                   maxTextWidth;
@property (nonatomic) UITapGestureRecognizer*   tapGesture;
@property (nonatomic,weak) UIView*              gestureView;
@property (nonatomic) BOOL                      faded;
@property (nonatomic) NSTimer*                  timerStartFade;

@end


#define kSegCount   (3)
#define kBaseCount  (3)


// [1,10) base 10 ranges
static const double baseRanges_[kSegCount][kBaseCount] =
{
//    { 1.0, 2.0, 5.0 },  // 5 segs
    { 1.0, 0.0, 0.0 },  // 3 segs
    { 1.0, 2.0, 0.0 },  // 5 segs
    { 1.0, 2.5, 5.0 }   // 2 segs
};

// segment counts iterators
//static const int segmentCounts_[] = { 5, 4, 3, 2 };
static const NSUInteger segmentCounts_[] = { 3, 5, 2 };


@implementation MapDistanceKeyView

#pragma mark - Class Init

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self doInit];
    }
    return self;
}


- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self doInit];
    }
    return self;
}


- (void) doInit
{
    self.clipsToBounds = NO;
    self.exclusiveTouch = NO;

    self.textValues = [NSMutableArray new];
    self.textValues2 = [NSMutableArray new];

    MKMapType mapType = MKMapTypeStandard;
    _mapType = mapType;

    self.shadow = [[NSShadow alloc]init];
    self.fontStrokeColor = [UIColor colorWithWhite:0.99f alpha:1];

    segmentCounts_count = sizeof(segmentCounts_) / sizeof(*segmentCounts_);
    baseRanges_count = sizeof(*baseRanges_) / sizeof(**baseRanges_);
    assert(segmentCounts_count == kSegCount);
    assert(baseRanges_count == kBaseCount);

    // Set maxSegments_ by searching segmentsCounts_ array for largest value
    //
    for (NSUInteger xx=0; xx < segmentCounts_count; xx++) {
        if (maxSegments_ < segmentCounts_[xx]) {
            maxSegments_ = segmentCounts_[xx];   // set max segments
        }
    }

    self.textValuesWidths = calloc(maxSegments_ + 2, sizeof(CGFloat)); // + 1 for [0..maxSegments_] and +2 for array bounds assert check

    [self setFontSize:[UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody].pointSize];

    // Fetch default units
    _unitsMode = keyStatute;
    assert(self.unitsMode < key_END);
    if ( self.unitsMode >= key_END)
        self.unitsMode = keyStatute;

    [self configUnitsText];

    // Tap Gesture setup
    CGRect gvFrame = self.bounds;
    UIView* gv = [[UIView alloc] initWithFrame:gvFrame];
    [self addSubview:gv];
    self.gestureView = gv;
    self.gestureView.exclusiveTouch = NO;

    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    self.tapGesture.cancelsTouchesInView = NO;
    self.tapGesture.delaysTouchesBegan = YES;
    [self.gestureView addGestureRecognizer:self.tapGesture];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userTextSizeDidChange)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UI Kit Callbacks

-(void) layoutSubviews {
    // XCode 10.0 uses a frame size of 1000x1000 in init
    [super layoutSubviews];
    [self configDrawingVariables];
}


-(UIView*) hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if ([self.gestureView pointInside:point withEvent:nil])
        return [super hitTest:point withEvent:event];
    else
        return nil;
}


#pragma mark - Interface

// updateCoordinates:
//   Called to induce redraw of this view object if change in the map view span detected.
//   Can be called in MKMapView callback [mapView:regionDidChangeAnimated:].
//
- (void) updateCoordinates
{
    CLLocationDistance keySpanMeters = [self frameWidthOnMapInMeters];

    if (keySpanMeters <= 0) {
        // Foobar; not init, bad frame values
        [self startFade];
        return;
    }

    [self fadeAnimation];

    // If change in span, schedule drawRect call
    //
    if ( abs((int)trunc(self.frameWidthMeters - keySpanMeters)) >= (int)self.metersPerPoint )
    {
        self.frameWidthMeters = keySpanMeters;
        self.metersPerPoint = keySpanMeters / self.bounds.size.width;
        [self updateIndicator];
    }
}


- (void) setFontSize:(CGFloat)fontSize
{
    _fontSize = MIN(fontSize,kDK_MAX_FONTPOINTSIZE);    // clip to 30pt max

    self.uifont = [UIFont fontWithName:kDK_FONT_NAME size:_fontSize];
    self.uifontSmall = [UIFont fontWithName:kDK_FONT_NAME size:_fontSize * kDK_FONT_SMALL_SCALE];

    [self configDrawingVariables];

    // Set font attributes
    //
    [self configColors];
}


// setMapType:
//   Changes the shadow colors.
-(void) setMapType:(MKMapType)mapType
{
    _mapType = mapType;
    [self configColors];
    self.metersPerPoint = 0;    // force updateCoordinates to draw
    self.lastSegmentValue = 0;  // force new text
    [self configUnitsText];
    [self updateCoordinates];   // calls -updateIndicator

    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDistanceKeyUnitsChange object:self];
}


// Rotate between Statute, metric, nautical
//
- (void) setUnitsMode:(keyUnits_t)unitsMode
{
    if (unitsMode >= key_END) {
        unitsMode = key_BEGIN;
    }

    _unitsMode = unitsMode;

    self.metersPerPoint = 0; // force updateCoordinates to draw
    [self configUnitsText];     // set before undateIndicator called
    [self updateCoordinatesForced];

    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDistanceKeyUnitsChange object:self];
}


+(double) unitsPerMeter:(keyUnits_t) unitsMode
{
    double unitsPerMeter;
    switch (unitsMode) {
        case keyStatute:
            unitsPerMeter = 1.0/kMetersPerMile;
            break;
        case keyKilometers:
            unitsPerMeter = 1.0/kMetersPerKm;
            break;
        case keyNautical:
            unitsPerMeter = 1.0/kMetersPerNautical;
            break;
        case keyFeet:
            unitsPerMeter = 1.0/kMetersPerFoot;
            break;
        case keyMeters:
            unitsPerMeter = 1.0;
            break;
        case key_END:
        default:
            assert(0);
            unitsPerMeter = -1;
            break;
    }
    return unitsPerMeter;
}


+(double) metersPerUnit:(keyUnits_t) unitsMode
{
    double metersPerUnit;

    switch (unitsMode) {
        case keyStatute:
            metersPerUnit = kMetersPerMile; // 1609.344
            break;
        case keyKilometers:
            metersPerUnit = kMetersPerKm;
            break;
        case keyNautical:
            metersPerUnit = kMetersPerNautical;
            break;
        case keyFeet:
            metersPerUnit = kMetersPerFoot;
            break;
        case keyMeters:
            metersPerUnit = 1;
            break;
        case key_END:
        default:
            assert(0);
            metersPerUnit = -1;
            break;
    }
    return metersPerUnit;
}


+ (NSString*) distanceShortStringForDistance:(CLLocationDistance)meters units:(keyUnits_t)unitsMode{

    NSString* unitStr = [MapDistanceKeyView shortStringForUnit:unitsMode];
    double factor = [MapDistanceKeyView unitsPerMeter:unitsMode];
    double dist = meters * factor;
    NSString* fmt = @" %g";
    if ( dist >= 100.0 || unitsMode == keyFeet ) {
        fmt = @" %.0f";
    } else if (dist >= 10.0 || unitsMode == keyMeters) {
        fmt = @" %.1f";
    } else if (dist >= 1.0) {
        fmt = @" %.2f";
    } else {
        fmt = @" %.3f";
    }

    fmt = [fmt stringByAppendingString:@" %@"]; // unit string
    NSString* text = [NSString stringWithFormat:fmt,dist,unitStr];

    return text;
}


+(NSString*) stringToTenthsForDistance:(CLLocationDistance) objectDistanceMeters units:(keyUnits_t)unitsMode
{
    NSString* unitStr = [MapDistanceKeyView shortStringForUnit:unitsMode];
    double factor = [MapDistanceKeyView unitsPerMeter:unitsMode];
    double dist = objectDistanceMeters * factor;
    NSString* fmt = @"%g"; // default
    if ( dist >= 100.0 || unitsMode == keyFeet ) {
        fmt = @"%.0f";
    } else if (dist >= 10.0 || unitsMode == keyMeters) {
        fmt = @"%.1f";
    } else if (dist >= 1.0) {
        fmt = @"%.2f";
    } else if (dist >= 0.1) {
        fmt = @"%.3f";
    } else {
        fmt = @"%.3f";
        if (unitsMode == keyStatute || ( unitsMode == keyNautical && [[[NSLocale currentLocale] objectForKey:NSLocaleUsesMetricSystem] boolValue] == NO )) {
            unitsMode = keyFeet;
            unitStr = [MapDistanceKeyView shortStringForUnit:unitsMode];
            factor = [MapDistanceKeyView unitsPerMeter:unitsMode];
            fmt = @"%.0f";
        }
        else if ( unitsMode == keyKilometers || ( unitsMode == keyNautical && [[[NSLocale currentLocale] objectForKey:NSLocaleUsesMetricSystem] boolValue] == YES ) ) {
            unitsMode = keyMeters;
            unitStr = [MapDistanceKeyView shortStringForUnit:unitsMode];
            factor = [MapDistanceKeyView unitsPerMeter:unitsMode];
            fmt = @"%.1f";
        }
    }

    fmt = [fmt stringByAppendingString:@" %@"]; // unit string

    NSString *text = [NSString stringWithFormat:fmt,objectDistanceMeters * factor,unitStr];
    return text;
}


+ (NSString*) stringForUnit:(keyUnits_t) unitsMode
{
    NSString* unitString;

    switch (unitsMode) {
        case keyStatute:
            unitString = @"Miles";
            break;
        case keyKilometers:
            unitString = @"km";
            break;
        case keyNautical:
            unitString = @"NMi";
            break;
        case keyFeet:
            unitString = @"Feet";
            break;
        case keyMeters:
            unitString = @"Meters";
            break;
        case key_END:
            assert(0);
            unitString = @"";
            break;
    }

    return unitString;
}


+ (NSString*) shortStringForUnit:(keyUnits_t) unitsMode
{
    NSString* unitString;

    switch (unitsMode) {
        case keyStatute:
            unitString = @"mi";
            break;
        case keyKilometers:
            unitString = @"km";
            break;
        case keyNautical:
            unitString = @"NMi";
            break;
        case keyFeet:
            unitString = @"ft";
            break;
        case keyMeters:
            unitString = @"m";
            break;
        case key_END:
            assert(0);
            unitString = @"";
            break;
    }

    return unitString;
}


#pragma mark -

- (void) updateCoordinatesForced {
    self.metersPerPoint = 0;
    [self updateCoordinates];
}


- (void) configDrawingVariables
{
    NSAttributedString* zeroText = [[NSAttributedString alloc] initWithString:@"0" attributes:self.fontAttributes];
    CGFloat zeroWidth = [zeroText size].width;
    xLeft_ = kDK_MARGIN_LEFT + zeroWidth / 2; // Left justified

    CGFloat netHeight = self.fontSize + kDK_TEXT_BAR_SPACE + kDK_BAR_HEIGHT + kDK_BAR_LINEWIDTH * 3; /* 3=2 lines + tick mark */
    CGFloat bottomY = ( self.bounds.size.height + netHeight ) / 2;
    barMidY_ = bottomY - kDK_BAR_LINEWIDTH - kDK_BAR_HEIGHT / 2;
    yBotLine_ = barMidY_ + kDK_BAR_LINEWIDTH / 2 + kDK_BAR_HEIGHT / 2;
    yTopLine_ = yBotLine_ - kDK_BAR_HEIGHT - kDK_BAR_LINEWIDTH;
    yTopSeg_ = barMidY_ - kDK_BAR_HEIGHT / 2 - kDK_BAR_LINEWIDTH;
    yBotSeg_ = barMidY_ + kDK_BAR_HEIGHT / 2 + kDK_BAR_LINEWIDTH;
    yTopTick_ = yTopSeg_ - kDK_BAR_LINEWIDTH;
    textY_ = yTopTick_ - self.fontSize - kDK_TEXT_BAR_SPACE;
}


-(void) configColors
{
    if ( self.mapType == MKMapTypeStandard )
    {
        self.lineColor = [UIColor colorWithRed:0.7 green:0.71 blue:0.71 alpha:1];
        self.fontColor = [UIColor colorWithWhite:0 alpha:1]; // [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
        self.segEvenColor = [UIColor colorWithRed:230.0f/255 green:90.0f/255 blue:55.0f/255 alpha:0.7];
        self.segOddColor = [UIColor colorWithRed:0.982f green:1 blue:1 alpha:0.7f];
        self.shadowColor = [UIColor orangeColor];
    }
    else // Satellite & Hybrid map type
    {
        self.lineColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
        self.fontColor = [UIColor colorWithWhite:0.1f alpha:1]; // [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1];
        self.segEvenColor = [UIColor colorWithRed:230.0f/255 green:90.0f/255 blue:55.0f/255 alpha:0.7];
        self.segOddColor = [UIColor colorWithRed:0.982f green:1 blue:1 alpha:0.7f];
        self.shadowColor = [UIColor cyanColor];
    }

    if (self.shadow == nil) {
        self.shadow = [NSShadow new];
    }

    self.shadow.shadowColor =  self.shadowColor;
    self.shadow.shadowOffset = CGSizeZero;
    self.shadow.shadowColor =  self.shadowColor;
    self.shadow.shadowBlurRadius = self.fontSize * kDK_SHADOW_RADIX;

    // Stroke
    self.fontAttributes =  @{NSFontAttributeName: self.uifont,
                             NSShadowAttributeName: self.shadow,
                             NSStrokeColorAttributeName: self.fontStrokeColor,
                             NSStrokeWidthAttributeName: [NSNumber numberWithFloat:kDK_FONT_STROKE],
                             };

    self.fontAttributes_small = @{NSFontAttributeName: self.uifontSmall,
                                  NSShadowAttributeName: self.shadow,
                                  NSStrokeColorAttributeName: self.fontStrokeColor,
                                  NSStrokeWidthAttributeName: [NSNumber numberWithFloat:kDK_FONT_STROKE],
                                  };

    // Fill
    self.fontAttributes2 = @{NSFontAttributeName: self.uifont,
                             NSForegroundColorAttributeName: self.fontColor
                             };
    self.fontAttributes2_small = @{NSFontAttributeName: self.uifontSmall,
                                   NSForegroundColorAttributeName: self.fontColor
                                   };
}


-(void) fadeAnimation
{
    if (self.timerStartFade == nil) {
        self.timerStartFade = [NSTimer scheduledTimerWithTimeInterval:kDK_FADE_DELAY target:self selector:@selector(startFade) userInfo:nil repeats:NO];
    } else {
        self.timerStartFade.fireDate = [NSDate dateWithTimeIntervalSinceNow:kDK_FADE_DELAY];
    }

    if (self.faded || self.alpha < 0.99)
    {
        _faded = NO;

        static BOOL startupFade_N;  // first start up delay
        if ( startupFade_N == NO ) {
            // init startup delay unfade. Why: map is zooming in and animating.
            startupFade_N = YES;
            [UIView animateWithDuration:2 delay:1 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.alpha = 1;
            } completion:nil];
        }
        else {
            [UIView animateWithDuration:kDK_UNFADE_DURATION animations:^{
                self.alpha = 1;
            }];
        }
    }
}


-(void) startFade
{
    self.faded = YES;
    [self.timerStartFade invalidate];
    _timerStartFade = nil;
    [UIView animateWithDuration:kDK_FADE_DURATION animations:^{ self.alpha = kDK_FADE_ALPHA; }];
}


- (void) updateIndicator
{
    double unitsPerMeter = [MapDistanceKeyView unitsPerMeter:self.unitsMode];

    double segUnits = self.frameWidthMeters * unitsPerMeter;

    [self calcSegments:segUnits];

    if ( self.segmentValue != self.lastSegmentValue ) {
        [self configText];
        self.lastSegmentValue = self.segmentValue;
    }

    CGRect gestureFrame = self.bounds;

    CGFloat barWidth;
    barWidth = kDK_MARGIN_LEFT + kDK_BAR_LINEWIDTH + self.frameWidthBar * self.segmentValue * self.segmentsCount / self.segmentFrameWidthUnits + self.unitsTextWidth + self.maxTextWidth;

    gestureFrame.size.width = barWidth;

    self.gestureView.frame = gestureFrame;

    [self setNeedsDisplay];
}


- (void)handleTap:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded)
    {
        if ( ! self.faded ) {
            self.unitsMode += 1;
        }
        [self fadeAnimation];
    }
}


- (CLLocationDistance) frameWidthOnMapInMeters
{
    self.frameWidthBar = self.bounds.size.width - kDK_MARGIN_LEFT - self.rightMargin;

    CGFloat midY = self.mapView.frame.size.height / 2;
    CGFloat midX = self.mapView.frame.size.width / 2;
    CGFloat width1_2 = self.frameWidthBar / 2;

    CLLocationCoordinate2D leftEdge =
    [self.mapView convertPoint:CGPointMake(midX - width1_2, midY) toCoordinateFromView:self.mapView];
    CLLocationCoordinate2D rightEdge =
    [self.mapView convertPoint:CGPointMake(midX + width1_2, midY) toCoordinateFromView:self.mapView];
    CLLocation *keyWestLocation =
    [[CLLocation alloc] initWithLatitude:leftEdge.latitude longitude:leftEdge.longitude];

    CLLocation *keyEastLocation =
    [[CLLocation alloc] initWithLatitude:rightEdge.latitude longitude:rightEdge.longitude];

    CLLocationDistance keySpanMeters = [keyWestLocation distanceFromLocation:keyEastLocation];

    assert(keySpanMeters > 1);

    return keySpanMeters;
}


- (void) calcSegments:(double) frameWidthUnits
{
    assert(frameWidthUnits > 0 && isnormal(frameWidthUnits)); // is not 0 nor NAN nor INF

    self.segmentFrameWidthUnits = frameWidthUnits;

    int base10Power = floor(log10(frameWidthUnits));
    double baseMultiplier = 0; //= pow(10.0,base10Power);

    ssize_t indexSegMatch = 0;
    ssize_t indexRangeMatch = 0;
    double  largesMatch = -1;
    NSInteger smallestSeg = 10;

    for (NSInteger minSeg = 1; minSeg <= smallestSeg && largesMatch < 0; minSeg++) {

        baseMultiplier = pow(10.0, base10Power) / minSeg;

        for (size_t segII = 0;  segII < segmentCounts_count; segII++) {
            for (size_t rangeII = 0; rangeII < baseRanges_count; rangeII++) {
                double range = baseRanges_[segII][rangeII];
                if (range <= 0)
                    break;
                NSUInteger segments = segmentCounts_[segII];
                if ( segments < smallestSeg ) smallestSeg = segments;
                double indicatorUnits = baseMultiplier * range * segments;

                if ( indicatorUnits <= frameWidthUnits )
                {
                    if ( indicatorUnits > largesMatch ) {
                        largesMatch = indicatorUnits;
                        indexRangeMatch = rangeII;
                        indexSegMatch = segII;
                    }
                }
            }
        }
    }

    if ( largesMatch >= 0 ) {
        self.segmentsCount = segmentCounts_[indexSegMatch];
        _segmentValue = baseMultiplier * baseRanges_[indexSegMatch][indexRangeMatch];
    } else {
        self.segmentsCount = 0;
        _segmentValue = 0;
    }

    _segmentWidth = self.frameWidthBar * self.segmentValue / self.segmentFrameWidthUnits;
}


// configText:
// Fill textValues array with font strings of units
//
- (void) configText
{
    [self.textValues removeAllObjects];
    [self.textValues2 removeAllObjects];

    self.maxTextWidth = 0;

    assert(_textValuesWidths != NULL);

    // Fill text for all possible segment counts since number of segments may change
    // without calling this function
    //
    for (NSInteger seg = 0; seg <= maxSegments_; seg++)
    {
        NSString *segValue = [NSString stringWithFormat:@"%g", self.segmentValue * seg];

        NSAttributedString* segValueText = [[NSAttributedString alloc] initWithString:segValue
                                                                           attributes:self.fontAttributes];
        NSAttributedString* segValueText2 = [[NSAttributedString alloc] initWithString:segValue
                                                                            attributes:self.fontAttributes2];

        [self.textValues addObject:segValueText];
        [self.textValues2 addObject:segValueText2];

        CGFloat width = [segValueText size].width;

        _textValuesWidths[seg] = width;

        if ( width > self.maxTextWidth ) {
            self.maxTextWidth = width;
        }
    }
}


-(void) configUnitsText
{
    NSString* unitString = [MapDistanceKeyView stringForUnit:self.unitsMode];

    self.unitsText = [[NSAttributedString alloc] initWithString:unitString attributes:self.fontAttributes];
    self.unitsText2 = [[NSAttributedString alloc] initWithString:unitString attributes:self.fontAttributes2];
    self.unitsTextWidth = [self.unitsText size].width;
    self.rightMargin = self.unitsTextWidth + (_fontSize * kDK_FONT_RIGHT_MARGIN_FACTOR/*2.1*/) + kDK_MARGIN_RIGHT;
    self.frameWidthBar = self.bounds.size.width - kDK_MARGIN_LEFT - self.rightMargin;
}


- (void) userTextSizeDidChange
{
    CGFloat userFontSize = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody].pointSize;   // Nominal pointSize is 17

    [self setFontSize: userFontSize];
    [self setUnitsMode:self.unitsMode];
    [self configText];
}


#pragma mark - DrawRect 2D Graphics UIView callback

- (void)drawRect:(CGRect)rect
{
    if (self.segmentsCount == 0 || self.segmentValue <= 0) {
        return;
    }

    // Get this view context
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGFloat segWidth = self.segmentWidth;
    CGFloat keyWidth = segWidth * self.segmentsCount;

    // Draw bar boarder line
    CGContextSetLineCap(context, kCGLineCapButt);
    CGContextSetLineWidth(context, kDK_BAR_LINEWIDTH); // segments boarder line width
    CGContextSetStrokeColorWithColor(context, self.lineColor.CGColor);

    CGContextMoveToPoint(context, xLeft_, yTopLine_);
    CGContextAddLineToPoint(context, xLeft_ + keyWidth /*+ kDK_BAR_LINEWIDTH*/, yTopLine_);
    CGContextMoveToPoint(context, xLeft_, yBotLine_);
    CGContextAddLineToPoint(context, xLeft_ + keyWidth /*+ kDK_BAR_LINEWIDTH*/, yBotLine_);

    CGContextStrokePath(context);

    CGFloat xEnd,xBegin;
    for (NSUInteger seg = 0; seg < self.segmentsCount; seg++)
    {
        if ( seg & 1 ) {
            // odd segment color
            CGContextSetStrokeColorWithColor(context, self.segOddColor.CGColor);
        } else {
            // Even segment color
            CGContextSetStrokeColorWithColor(context, self.segEvenColor.CGColor);
        }

        CGContextSetLineWidth(context, kDK_BAR_HEIGHT);

        xBegin = segWidth * seg + xLeft_;
        xEnd = xBegin + segWidth;
        CGContextMoveToPoint(context, xBegin, barMidY_);
        CGContextAddLineToPoint(context,xEnd, barMidY_);
        CGContextStrokePath(context);

        // Paint segment line breaks
        if ( seg > 0 ) {
            CGContextSetStrokeColorWithColor(context, self.lineColor.CGColor);
            CGContextSetLineWidth(context, kDK_BAR_LINEWIDTH);
            CGFloat barThickness_2 = (kDK_BAR_HEIGHT + kDK_BAR_LINEWIDTH) / 2;
            CGContextMoveToPoint(context, xBegin, barMidY_ - barThickness_2);
            CGContextAddLineToPoint(context, xBegin, barMidY_ + barThickness_2);
            CGContextStrokePath(context);
        }
    }

    // Paint end line seg break (assumes paint segsment lines was last done)
    //
    CGFloat xEndSeg = xLeft_ + keyWidth;
    CGContextMoveToPoint(context, xLeft_, yTopSeg_);
    CGContextAddLineToPoint(context, xLeft_, yBotSeg_);
    CGContextMoveToPoint(context, xEndSeg, yTopSeg_);
    CGContextAddLineToPoint(context, xEndSeg, yBotSeg_);
    CGContextStrokePath(context);


    // Draw text, and top of bar tick marks which points to text
    //
    CGFloat fontBoxWidth = 0;
    BOOL fontCrunch = segWidth < self.maxTextWidth + self.textValuesWidths[0]; // "0" hitting widest number

    assert(self.segmentsCount <= self.textValues.count);
    for (NSUInteger seg = 0; seg <= self.segmentsCount; seg++)
    {
        NSAttributedString* textVal = self.textValues[seg];
        NSAttributedString* textVal2 = self.textValues2[seg];
        fontBoxWidth = self.textValuesWidths[seg];

        CGFloat tickX = segWidth * seg + xLeft_;
        CGFloat textX = tickX - fontBoxWidth / 2;

        // If number crunch, only print 1st & last
        //
        if ( ! fontCrunch ||  seg == 0 || seg == 1 || seg == self.segmentsCount )
        {
            // draw tick
            CGContextSetFillColorWithColor(context, self.lineColor.CGColor);    // Set here, font changes it
            CGContextSetLineJoin(context,kCGLineJoinMiter);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, tickX - kDK_BAR_LINEWIDTH/2, yTopSeg_);
            CGContextAddLineToPoint(context, tickX, yTopTick_);
            CGContextAddLineToPoint(context, tickX + kDK_BAR_LINEWIDTH / 2, yTopSeg_);
            CGContextClosePath(context);
            CGContextFillPath(context);

            //
            // Draw text value number
            //

            CGContextSetLineJoin(context,kCGLineJoinRound); // text thorns occur if not Round

            // if font crunch then shift 2nd text value right a bit as to not crunch into 0 text.
            //
            if ( fontCrunch && seg == 1 )
            {
                CGFloat textY_small = textY_;

                // Extra shrink font if middle number crunching
                CGFloat width0 = self.textValuesWidths[0];
                CGFloat widthEnd = self.textValuesWidths[self.segmentsCount];
                CGFloat widthEnd_2 = widthEnd / 2;
                CGFloat seg0SegEndWidths = width0 + width0 + widthEnd_2;
                CGFloat width1 = self.textValuesWidths[1];
                CGFloat width1boxed = keyWidth - seg0SegEndWidths;
                BOOL fontExtraCrunch = width1 > width1boxed;

                if (fontExtraCrunch)
                {

                    CGFloat width = MAX(0, width1boxed);

                    assert(width < width1); // test that algorythm is ok here

                    CGFloat smallFontSize = floorf(self.fontSize * width / width1);
                    UIFont* uifontSmall = [UIFont fontWithName:kDK_FONT_NAME size:smallFontSize];
                    NSDictionary* fontAttributes_small = @{NSFontAttributeName: uifontSmall,
                                                           NSShadowAttributeName: self.shadow,
                                                           NSStrokeColorAttributeName: self.fontStrokeColor,
                                                           NSStrokeWidthAttributeName: [NSNumber numberWithFloat:kDK_FONT_STROKE],
                                                           };
                    NSDictionary* fontAttributes2_small = @{NSFontAttributeName: uifontSmall,
                                                            NSForegroundColorAttributeName: self.fontColor
                                                            };

                    textVal = [[NSAttributedString alloc] initWithString:textVal.string attributes:fontAttributes_small];
                    textVal2 = [[NSAttributedString alloc] initWithString:textVal2.string attributes:fontAttributes2_small];
                    width1 = [textVal size].width;
                    textY_small += self.fontSize - smallFontSize;
                } //else {}

                // Push left if hitting end number
                textX = MIN(textX, xLeft_ + segWidth * self.segmentsCount - widthEnd_2 - width1 - width0);

                // Push right if hitting 0
                textX = MAX(textX, xLeft_ + self.textValuesWidths[0]);

                // draw number value
                [textVal drawAtPoint:CGPointMake(textX, textY_small)];
                [textVal2 drawAtPoint:CGPointMake(textX, textY_small)];

            } else {
                // draw number value
                [textVal drawAtPoint:CGPointMake(textX, textY_)];
                [textVal2 drawAtPoint:CGPointMake(textX, textY_)];
            }
        }
    }

    //
    // draw units type string "Miles" "km" "Meters" "Feet" "NMi"
    //

    // Use last fontBoxWidth set (largest value)
    //
    CGFloat unitsTextX = segWidth * self.segmentsCount + xLeft_ + (fontBoxWidth + self.fontSize) / 2;
    self.unitsTextX = unitsTextX;
    [self.unitsText drawAtPoint:CGPointMake(unitsTextX, textY_)];
    [self.unitsText2 drawAtPoint:CGPointMake(unitsTextX, textY_)];
}

@end
