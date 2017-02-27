//
//  MapGeocoderViewController.m
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

#import "MapGeocoderViewController.h"


@interface MapGeocoderViewController ()

// Timer to update distance key with realtime MapView panning. Runs at 10Hz
@property(nonatomic,weak)       NSTimer*        timerUpdateMap;
@property(nonatomic,weak)       UIImageView*    usageHintImage;

@end


@implementation MapGeocoderViewController


- (void)viewDidLoad
{
    [super viewDidLoad];

    self.geoCoderSearchOutlet.geoCoderDelegate = self;
    self.distanceKeyOutlet.mapView = self.map1;
    self.map1.delegate = self;

}


-(void) viewDidAppear:(BOOL)animated {

    [super viewDidAppear:animated];

    // Start up usage hint message (optional)
    //
    { // BLOCK: (optional usage start up hint)
        UIImage* png = [UIImage imageNamed:@"Usage.png"];
        UIImageView* image = [[UIImageView alloc] initWithImage:png];
        CGRect frameImage = self.geoCoderSearchOutlet.frame;
        frameImage.size = CGSizeMake(240, 240);
        image.frame = frameImage;
        self.usageHintImage = image;

        [self.view addSubview:image];

        [UIView animateWithDuration:0.5 delay:30 options:0 animations:^{
            image.alpha = 0;
            self.geoCoderSearchOutlet.imagePoweredByGoo.alpha = 1;
        } completion:^(BOOL finished) {
            [image removeFromSuperview];
            self.geoCoderSearchOutlet.imagePoweredByGoo.alpha = 1;
        }];

#ifdef USE_GOOGE_LOGO
        self.geoCoderSearchOutlet.imagePoweredByGoo.alpha = 0;
#endif
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - GeoCoderDelegate Callbacks

// GeoCoderDelegate callback
-(MKCoordinateRegion) region
{
    return self.map1.region;
}


-(void) geoCoder:(GeoCoderTextField*)geoCoder hasResult:(ForwardGeoResult*) result
{
    if (result.hasViewPortRegion)
    {
        [self.map1 setRegion:result.coordinateRegion animated:YES];
    }
    else
    {
        MKCoordinateRegion mapRegion = self.map1.region;
        
        mapRegion.center = result.coordinate;
        
        if (mapRegion.span.latitudeDelta < kMGVC_spanLowThreshold || mapRegion.span.longitudeDelta < kMGVC_spanLowThreshold)
        {
            // zoom out a bit
            mapRegion.span = MKCoordinateSpanMake(kMGVC_spanLowZoomOut, kMGVC_spanLowZoomOut);
        }
        else if (mapRegion.span.latitudeDelta > kMGVC_spanHighThreshold || mapRegion.span.longitudeDelta > kMGVC_spanHighThreshold)
        {
            mapRegion.span = MKCoordinateSpanMake(kMGVC_spanHighZoomIn, kMGVC_spanHighZoomIn);
        }
        else { } /* else ignore, keep map view current span */
        
        [self.map1 setRegion:mapRegion animated:YES];
    }
}


-(void) geoCoderDidBeginEditing:(GeoCoderTextField *)geoCoder {

    [UIView animateWithDuration:0.2 delay:0 options:0 animations:^{
        self.usageHintImage.alpha = 0;
        self.geoCoderSearchOutlet.imagePoweredByGoo.alpha = 1;
    } completion:^(BOOL finished) {
        [self.usageHintImage removeFromSuperview];
        self.geoCoderSearchOutlet.imagePoweredByGoo.alpha = 1;
    }];
}


#pragma mark -

-(void) timerUpdateHandler:(NSTimer*) timer
{
    [self.distanceKeyOutlet updateCoordinates];
}


#pragma mark - MapView Callbacks

-(void) mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
    [self.timerUpdateMap invalidate];   // if currently a timer happens to exists, must invalidate it
    self.timerUpdateMap = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timerUpdateHandler:) userInfo:nil repeats:YES];
    [self.geoCoderSearchOutlet resignFirstResponder];
}


-(void) mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    [self.timerUpdateMap invalidate];

    // calculate current distance
    [self.distanceKeyOutlet updateCoordinates];

    // update distances
    [self.geoCoderSearchOutlet updateTable];
}


@end
