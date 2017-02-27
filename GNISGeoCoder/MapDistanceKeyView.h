//
//  MapDistanceKeyView.h
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
// Shows distance milage key for distance units at map center latitude

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

#define kNotificationDistanceKeyUnitsChange   @"kNotificationDistanceKeyUnitsChange"

#define kMetersPerMile      (1609.344)
#define kMetersPerFoot      (0.3048)
#define kMetersPerKm        (1000.0)
#define kMetersPerMeter     (1.0)
#define kMetersPerNautical  (1852)

#define kFeetPerMeter       (3.2808399)
#define kMilesPerMeter      (0.00062137119)

#define kDK_FADE_ALPHA      (0.3)       // Fade alpha value, 0 for hidden
#define kDK_FADE_DURATION   (1.0)       // fade time in seconds
#define kDK_UNFADE_DURATION (0.1)       // Fade in in seconds
#define kDK_FADE_DELAY      (2.0)       // Timer delay before fading out

#define kDK_MARGIN_LEFT     (8.0f)      // Distance key indicator left margins in from frame [points]
#define kDK_MARGIN_RIGHT    (10.0)      // Right frame margin to distance key
#define kDK_BAR_HEIGHT      (4.5f)      // 5.0 Indicator bar height in points (segment height/thickness)
#define kDK_BAR_LINEWIDTH   (2.0f)      // 1.0 Indicator bar outline width
#define kDK_MAX_FONTPOINTSIZE (25.0)    // Clip font size if on larger accessibility text size from settings
#define kDK_SHADOW_RADIX    (0.13f)     // shadow radius = font size * kDK_SHADOW_RADIX
#define kDK_FONT_RIGHT_MARGIN_FACTOR (2.2f+(kDK_SHADOW_RADIX)) // Push in segment bar width based on font size * 2.2

typedef enum : NSUInteger {
    keyStatute = 0,
    key_BEGIN = 0,
    keyFeet,
    keyKilometers,
    keyMeters,
    keyNautical,
    key_END
} keyUnits_t;


@interface MapDistanceKeyView : UIView

@property (nonatomic,weak)      MKMapView*          mapView;
@property (nonatomic)           keyUnits_t          unitsMode;
@property (nonatomic)           MKMapType           mapType;
@property (nonatomic)           UIColor*            fontColor;
@property (nonatomic)           UIColor*            fontStrokeColor;
@property (nonatomic)           UIColor*            shadowColor;

// updateCoordinates:
// Draw if change in distance detected
- (void) updateCoordinates;

+ (double) metersPerUnit:(keyUnits_t) unitsMode;
+ (double) unitsPerMeter:(keyUnits_t) unitsMode;    // Multiply returned value to distance meters for ft/nmi/mi distance
+ (NSString*) stringForUnit:(keyUnits_t) unitsMode;
+ (NSString*) shortStringForUnit:(keyUnits_t) unitsMode;
+ (NSString*) distanceShortStringForDistance:(CLLocationDistance)distance units:(keyUnits_t) unitsMode;
+ (NSString*) stringToTenthsForDistance:(CLLocationDistance) objectDistanceMeters units:(keyUnits_t) unitsMode;  // changes to ft\m when mi\km\nm < 0.1

@end
