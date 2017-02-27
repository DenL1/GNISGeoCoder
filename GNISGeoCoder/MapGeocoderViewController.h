//
//  MapGeocoderViewController.h
//  GNISGeoCoder
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

#import <UIKit/UIKit.h>
@import MapKit;
#import "MapDistanceKeyView.h"
#import "GeoCoderTextField.h"


// If no view port from GNIS search, the use the map view region span threshold for zoom:
#define kMGVC_spanLowThreshold      (0.002)     // (degrees) Span lat/lon min zoomed-in
#define kMGVC_spanLowZoomOut        (0.003)     // (degrees) zoom out a bit
#define kMGVC_spanHighThreshold     (0.2)       // (degrees) Span lat/lon max zoomed-out
#define kMGVC_spanHighZoomIn        (0.01)      // (degrees) zoom in to


@interface MapGeocoderViewController : UIViewController <MKMapViewDelegate,GeoCoderDelegate>

@property (weak, nonatomic) IBOutlet MapDistanceKeyView *distanceKeyOutlet;
@property (weak, nonatomic) IBOutlet GeoCoderTextField *geoCoderSearchOutlet;
@property (weak, nonatomic) IBOutlet MKMapView *map1;

@end

