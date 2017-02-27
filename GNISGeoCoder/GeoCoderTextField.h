//
//  GeoCoderTextField.h
//  GNISGeoCoder
//
//  Created by Dennis on 9/17/14.
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

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "ForwardGeoResult.h"


#define USE_GOOGE_LOGO
#define kTimerSearchTextForgetTime  (180.0)     // Forget prior search after 3 minutes
#define kGCTF_keyboardTextfieldGap  (13.0)      // min gap between KB and hint table
#define kGCTF_fadeDuration          (2.7)       // (seconds)
#define kGCTF_fadeDelay             (2.0)       // (seconds)
#define kGCTF_fadeAlpha             (0.5)     // (cgfloat)

@class GeoCoderTextField;


// Subset of MKMapView
@protocol GeoCoderDelegate <NSObject>

@required
-(MKCoordinateRegion) region;

@optional
-(void) geoCoder:(GeoCoderTextField*) geoCoder hasResult:(ForwardGeoResult*) selectedResult;
-(void) geoCoderDidBeginEditing:(GeoCoderTextField*) geoCoder;

@end


@interface GeoCoderTextField : UITextField

@property (nonatomic,weak)      id<GeoCoderDelegate>    geoCoderDelegate;
@property (nonatomic)           ForwardGeoResult*       selectedResult;
@property (nonatomic)           MKCoordinateRegion      viewRegion;     // set span with 0 or negative values to invalidate
#ifdef USE_GOOGE_LOGO
@property (nonatomic,weak)      UIImageView*            imagePoweredByGoo;
#endif

-(void) updateTable;

@end
