//
//  GeoCoderTextField.m
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

#import "Project.h"
#import "MapDistanceKeyView.h"
#import "GeoCoderTextField.h"
#import "GeoCodeTableViewCell.h"
#import "ForwardGeocoder.h"
#import "GNISGeocoder.h"
#import "ForwardGeoResult.h"
#import <SystemConfiguration/SCNetworkReachability.h>
#include <netinet/in.h>
#import <CoreLocation/CoreLocation.h>
#import "NetworkConnected.h"


#ifdef DEBUG
#define NSLOG(x...) // NSLog(x)
#define DLOG(x...) NSLog(x)
#else
#define NSLOG(x...)
#define DLOG(...)
#endif


#define kRowMaxiPhone               (9.7)
#define kRowMaxiPad                 (11.6)
#define kTimeoutReturn              kTimeoutGeoCoderConnection // 20 sec
#define kPressedKeyPredictionDelay  (0.25)  // delay between key strokes before sending next queuey search
#define kDeleteKeyPredictionDelay   (0.9)   // Deleted a letter so delay search prediction query a bit longer
#define kPredictionQueryLimit       (2500)  // 2500 per day googe limit
#define kPredictionSlowDownSeconds  (2.0)   // 0-2.0 seconds added from 0-2500 queries
#define kFGEO_DIST_FONT  @"Avenir Next Condensed"


@interface GeoCoderTextField ()  <UITextFieldDelegate,UITableViewDelegate,UITableViewDataSource,ForwardGeocoderDelegate,GNISGeocoderDelegate>

@property (nonatomic,weak)          UITableView*        table1;
@property (weak,nonatomic)          NSLayoutConstraint* table1HeightConstraint;
@property (nonatomic)               CGFloat             rowHeight;
@property (nonatomic)               CGFloat             headerFontSize;
@property (nonatomic)               CGFloat             headerViewHeight;
@property (nonatomic)               CGFloat             fontsizeBodyStyle;
@property (nonatomic)               NSValue*            keyboardFrameVal;
@property (nonatomic)               ForwardGeocoder*    geoCoder1;  // Gooble
@property (nonatomic)               GNISGeocoder*       geoCoder2;  // GNIS
@property (nonatomic,strong)        UIView*             headerViewGoogle;
@property (nonatomic,strong)        UIView*             headerViewGNIS;
@property (nonatomic,weak)          UIActivityIndicatorView* swirlGoogle;
@property (nonatomic,weak)          UIActivityIndicatorView* swirlGNIS;
@property (nonatomic)               NSArray*            forwardGeoCoderResultsGoogle;
@property (nonatomic)               NSArray*            forwardGeoCoderResultsGNIS;
@property (nonatomic)               NSString*           searchText;
@property (nonatomic)               NSString*           searchTextSent;
@property (nonatomic,weak)          NSTimer*            timerSearchTextForget;  // Clear search text after 3 min of non use
@property (nonatomic,weak)          NSTimer*            timerQueryDelay;
@property (nonatomic)               double              unitsPerMeter;
@property (nonatomic)               NSString*           unitsString;
@property (nonatomic)               BOOL                textFieldActive;
@property (nonatomic)               BOOL                connectionError;
@property (nonatomic)               BOOL                networkConnected;
@property (nonatomic)               BOOL                noBounds;   // no bounds on geo coding flag
@property (nonatomic)               BOOL                viewRegionValid;

@end


@implementation GeoCoderTextField

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self doInit];
    }
    return self;
}


- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self doInit];
    }
    return self;
}


-(void) doInit
{
    NSLOG(@"%s: ENTER",__func__);

    _textFieldActive = NO;

    self.delegate = self;
    self.clearsOnInsertion = YES;

    [self configHeaderRowViewSize];

    _geoCoder1 = [[ForwardGeocoder alloc] initWithDelegate:self];
    _geoCoder2 = [[GNISGeocoder alloc] initWithDelegate:self];

    // If no GNIS DB file, then release GNIS geoCoder2 object so no work is done for it.
    // (Note: Same goes for Google geoCoder1, if nil then no work done for it)
    //
    if (self.geoCoder2.hasOpenedDB == NO)
    {
        self.geoCoder2 = nil;
    }

    [self configUnits:key_BEGIN]; // default statute miles

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unitsChangeNotice:) name:kNotificationDistanceKeyUnitsChange object:nil];

    [self.timerSearchTextForget invalidate];

    // When keyboard shows, shrink hint table height if keyboard overlays it
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyBoardShowNotice:) name:UIKeyboardWillShowNotification object:nil];

    //UIKeyboardDidHideNotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyBoardHideNotice:) name:UIKeyboardDidHideNotification object:nil];

    //UIKeyboardWillChangeFrameNotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyBoardShowNotice:) name:UIKeyboardDidHideNotification object:nil];

    // Reenter if settings changed for font size
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(configHeaderRowViewSize) name:UIApplicationDidBecomeActiveNotification object:nil];

#ifdef USE_GOOGE_LOGO
    if (self.geoCoder1)
    {
        UIImage* image = [UIImage imageNamed:@"Logo on color" /*asset name*/]; // 104x16 point image "powered-by-google-on-non-white@2x.png"
        if ( image != nil ) {
            CGSize imsize = image.size;
            // frame is adjusted in [layoutSubviews]
            CGRect frame = CGRectMake((CGRectGetMidX(self.frame) - imsize.width)/2,
                                      (self.bounds.size.height - imsize.height)/2,
                                      imsize.width, imsize.height);
            UIImageView* imView = [[UIImageView alloc] initWithImage:image];
            imView.frame = frame;

            imView.backgroundColor = [UIColor clearColor];

            [self addSubview:imView];
            self.imagePoweredByGoo = imView;
        }
        else {
            DLOG(@"%s: Error no logo image",__func__);
        }
    }
#endif // USE_GOOGE_LOGO
}


-(void) unitsChangeNotice:(NSNotification*) notification {
    MapDistanceKeyView* distMan = notification.object;
    [self configUnits:distMan.unitsMode];
    if (self.table1) {
        [self updateTable];
    }
}


- (void) configUnits:(keyUnits_t) units {
    _unitsPerMeter = [MapDistanceKeyView unitsPerMeter:units];
    _unitsString = [MapDistanceKeyView shortStringForUnit:units];
}


-(void) configHeaderRowViewSize
{
    self.headerFontSize = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].pointSize;
    self.headerViewHeight = ceil(_headerFontSize * 1.2);
    self.fontsizeBodyStyle = [UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize;
    self.rowHeight = MAX(25.0,ceil(_fontsizeBodyStyle * 1.5)); // Clam to 25pt smallest
}


-(void) keyBoardShowNotice:(NSNotification*) notice
{
    NSValue* kbRectVal = notice.userInfo[UIKeyboardFrameEndUserInfoKey];
    self.keyboardFrameVal = kbRectVal;
}


-(void) keyBoardHideNotice:(NSNotification*) notice
{
    self.keyboardFrameVal = nil;
}


-(void) setKeyboardFrameVal:(NSValue *)keyboardFrameVal
{
    _keyboardFrameVal = keyboardFrameVal;
    [self updateTable1Height];
}


-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#ifdef USE_GOOGE_LOGO
-(void) layoutSubviews
{
    [super layoutSubviews];
    if (self.imagePoweredByGoo.hidden == NO) {
        CGRect frame = CGRectMake(CGRectGetMidX(self.bounds) - self.imagePoweredByGoo.bounds.size.width/2,
                                  1+(self.bounds.size.height - self.imagePoweredByGoo.bounds.size.height)/2,
                                  self.imagePoweredByGoo.bounds.size.width,
                                  self.imagePoweredByGoo.bounds.size.height);
        self.imagePoweredByGoo.frame = frame;
    }
}
#endif


-(BOOL) networkConnectedCheck
{
    BOOL needsNetworkConnection = _geoCoder2 == nil;
    self.networkConnected = [NetworkConnected connectedToNetwork];

    if ( ! self.networkConnected || _connectionError )
    {
        NSDictionary* fontAttr = @{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
                                   NSForegroundColorAttributeName: [UIColor brownColor],
                                   NSObliquenessAttributeName: [NSNumber numberWithFloat:15.0f/180.0*M_PI]};
        self.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_connectionError ? @"(No internet connection)" : @"(No network connection)" attributes:fontAttr];

        if ( needsNetworkConnection ) {
            self.text = @"";
            [self resignFirstResponder];
        }
    }
    else
    {
#ifdef USE_GOOGE_LOGO
        if (self.geoCoder1)
        {
            self.attributedPlaceholder = nil;
        }
        else
#endif
        {
            NSDictionary* fontAttr = @{NSFontAttributeName: [UIFont systemFontOfSize:20.0],
                                       NSForegroundColorAttributeName: [UIColor grayColor], // was lightGrayColor
                                       NSObliquenessAttributeName: [NSNumber numberWithFloat:15.0f/180.0*M_PI]};

            self.attributedPlaceholder = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Search geographical names"] attributes:fontAttr];
        }
    }

    return self.networkConnected;
}


- (void) hideAnimated
{
    NSLOG(@"%s: ENTER",__func__);
    self.alpha = MAX(0.95,kGCTF_fadeAlpha);
    [UIView animateWithDuration:kGCTF_fadeDuration
                          delay:kGCTF_fadeDelay
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
                     animations:^{self.alpha = kGCTF_fadeAlpha;}
                     completion: ^(BOOL finished) {
                         // self.hidden = ! self.textFieldActive; // If user re-engages text field during fade, don't set hidden
                     }];

    [self resignFirstResponder];
}


-(void) setViewRegion:(MKCoordinateRegion)viewRegion
{
    _viewRegion = viewRegion;
    _viewRegionValid = viewRegion.span.latitudeDelta > 0 && viewRegion.span.longitudeDelta > 0;
}


// Returns yes query sent ok, no = ignored/not sent to googe
//
-(BOOL) sendQuery:(NSString*) searchText
{
    DLOG(@"%s: ENTER: '%@'",__func__,searchText);
    assert([NSThread isMainThread]);
    
    _searchTextSent = searchText;

    NSInteger qTag1 = 0, qTag2 = 0;

    if (self.geoCoderDelegate == nil)
        _noBounds = YES;
    else {
        self.viewRegion = [self.geoCoderDelegate region];
    }

    if (_noBounds || ! self.viewRegionValid)
    {
        if (self.geoCoder1.queryCount < kPredictionQueryLimit) {
            // google
            qTag1 = [self.geoCoder1 forwardGeocodeWithQuery:searchText];
            [self.swirlGoogle startAnimating];
        }
        
        // GNIS SQLite bundle DB
        qTag2 = [self.geoCoder2 forwardGeocodeWithQuery:searchText];
        [self.swirlGNIS startAnimating];
    }
    else
    {
        if (self.geoCoder1.queryCount < kPredictionQueryLimit) {
            qTag1 = [self.geoCoder1 forwardGeocodeWithQuery:searchText mapRegion:self.viewRegion];
            [self.swirlGoogle startAnimating];
        }
        
        qTag2 = [self.geoCoder2 forwardGeocodeWithQuery:searchText mapRegion:self.viewRegion];
        [self.swirlGNIS startAnimating];
    }

    DLOG(@"%s: qTag1:%ld  qTag2: %ld",__func__,(long)qTag1,(long)qTag2);

    if (qTag1 >= 0 || qTag2 >= 0) {
        return YES;
    } else {
        return NO;
    }
}


-(void) createTable
{
    NSLOG(@"%s: ENTER",__func__);

    CGRect frame = self.frame;

    UITableView* table1 = [[UITableView alloc] initWithFrame:CGRectMake(frame.origin.x, frame.origin.y + frame.size.height, frame.size.width, 0 ) style:UITableViewStylePlain];

    _table1 = table1;
    _table1.separatorColor = [UIColor greenColor];
    _table1.rowHeight = self.rowHeight;
    _table1.separatorStyle = UITableViewCellSeparatorStyleNone;
    _table1.delegate = self;
    _table1.dataSource = self;
    _table1.backgroundColor = [UIColor clearColor];
    _table1.allowsSelection = YES;

    [_table1 registerClass:[GeoCodeTableViewCell class] forCellReuseIdentifier:@"GeoCodeTableCellID"];

    [self.superview insertSubview:_table1 belowSubview:self];

    // enables constraints
    [self.table1 setTranslatesAutoresizingMaskIntoConstraints:NO];

    // Add constraints for any moving of the text field (banner ad animation)
    // Add height, leading & trailing to self(text field), bottom to top
    //
    NSLayoutConstraint *hgtCon = [NSLayoutConstraint
                                  constraintWithItem:_table1
                                  attribute:NSLayoutAttributeHeight
                                  relatedBy:NSLayoutRelationEqual
                                  toItem:nil
                                  attribute:NSLayoutAttributeNotAnAttribute
                                  multiplier:1.0
                                  constant:_table1.frame.size.height];

    self.table1HeightConstraint = hgtCon;

    NSLayoutConstraint *leaCon = [NSLayoutConstraint
                                  constraintWithItem:_table1
                                  attribute:NSLayoutAttributeLeading
                                  relatedBy:NSLayoutRelationEqual
                                  toItem:self
                                  attribute:NSLayoutAttributeLeading
                                  multiplier:1.0
                                  constant:1.0];    // Indent to match textfield boarder (2pt)

    NSLayoutConstraint *traCon = [NSLayoutConstraint
                                  constraintWithItem:self
                                  attribute:NSLayoutAttributeTrailing
                                  relatedBy:NSLayoutRelationEqual
                                  toItem:self.table1
                                  attribute:NSLayoutAttributeTrailing
                                  multiplier:1.0
                                  constant:1.0];    // Indent to match textfield boarder (1pt)

    NSLayoutConstraint *botCon = [NSLayoutConstraint
                                  constraintWithItem:self.table1
                                  attribute:NSLayoutAttributeTop
                                  relatedBy:NSLayoutRelationEqual
                                  toItem:self
                                  attribute:NSLayoutAttributeBottom
                                  multiplier:1.0
                                  constant:0.0];

    if (hgtCon && leaCon && traCon && botCon) {
        [self.superview addConstraints:@[hgtCon,leaCon,traCon,botCon]];
    }
    else {
        DLOG(@"%s: ipad constraint error",__func__);
    }
}


- (void) timerSearchTextForgetHandler:(NSTimer*) timer
{
    self.imagePoweredByGoo.alpha = 1;
    [self textFieldShouldClear:(timer.userInfo != nil ? timer.userInfo : self)];
}


-(void) timerQueryDelayHandler:(NSTimer*) timer
{
    DLOG(@"%s: self.searchText='%@' self.text='%@' same: %@",__func__,self.searchText,self.text,[self.searchText isEqualToString:self.text] ? @"YES":@" *** NO ***");
    
    [self sendQuery:self.searchText];
}


#pragma mark - Text Field Delegates

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    DLOG(@"%s: ENTER text:'%@'  searchText:'%@'  clearsOnBeginEditing: %d",__func__,self.text,self.searchText,self.clearsOnBeginEditing);

    [_timerSearchTextForget invalidate];
    _timerSearchTextForget = nil;

    self.textFieldActive = YES;
    _connectionError = NO;
    self.hidden = NO;
    self.text = self.searchText; // restore last search string

    // Unhide, use animation to cancel any running animation
    //
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 1;
#ifdef USE_GOOGE_LOGO
        self.imagePoweredByGoo.alpha = 0.5;
#endif
    } ];

    self.textColor = [UIColor blackColor];

    BOOL networkUp = [self networkConnectedCheck];

    if (self.geoCoder2 || networkUp)
    {
        [self createTable];
    }
    else
    {
        _textFieldActive = NO;
        _connectionError = YES;
    }

    if (self.text.length == 0)
    {
        // No text
#ifdef USE_GOOGE_LOGO
        self.imagePoweredByGoo.hidden = ! networkUp;
#endif
        self.textColor = [UIColor blackColor];
        _selectedResult = nil;
        _forwardGeoCoderResultsGoogle = nil;
        _forwardGeoCoderResultsGNIS = nil;
    }
    else
    {
        // Previous text kept
        
#ifdef USE_GOOGE_LOGO
        self.imagePoweredByGoo.hidden = YES;
#endif
        [self updateTable];

        [self sendQuery:self.searchText];
    }

    if ([self.geoCoderDelegate respondsToSelector:@selector(geoCoderDidBeginEditing:)]) {
        [self.geoCoderDelegate geoCoderDidBeginEditing:self];
    }
}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
    DLOG(@"%s: ENTER",__func__);

    [self.timerQueryDelay invalidate];

    self.textFieldActive = NO;
    [self.table1 removeFromSuperview];
    _table1 = nil;

    if (_selectedResult != nil)
    {
        self.text = self.selectedResult.address;
        self.textColor = [UIColor purpleColor];
        [self hideAnimated];
    }
    else
    {
        self.textColor = [UIColor grayColor]; // no results color
        [self hideAnimated];
    }

    // Schedule a 1 minute timeout to forget and clear search string
    //
    [_timerSearchTextForget invalidate];
    _timerSearchTextForget = [NSTimer scheduledTimerWithTimeInterval:kTimerSearchTextForgetTime target:self selector:@selector(timerSearchTextForgetHandler:) userInfo:textField repeats:NO];

#ifdef USE_GOOGE_LOGO
    self.imagePoweredByGoo.alpha = 1;
#endif

    
}


-(BOOL) textFieldShouldReturn:(UITextField *)textField
{
    DLOG(@"%s: ENTER textField='%@' _searchTextSend='%@' self.text='%@' same:%d",__func__,textField.text,_searchTextSent,self.text,_searchText.length != self.text.length);

    _textFieldActive = NO;
    
    BOOL sameText = [self.text isEqualToString:_searchTextSent];

    if ( !sameText )
    {
        [self.timerQueryDelay invalidate];
    }

    if ( self.geoCoder1.queryCount > self.geoCoder1.responseCount && self.geoCoder2.queryCount > self.geoCoder2.responseCount )
    {
        UIActivityIndicatorView *installingSwirl_ =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        CGRect frame = self.frame;
        frame.origin.x = CGRectGetMidX(frame) - frame.size.height / 2;
        frame.size.width = frame.size.height;

        installingSwirl_.frame = frame;
        installingSwirl_.color = [UIColor purpleColor];

        [self.superview insertSubview:installingSwirl_ aboveSubview:self];
        [installingSwirl_ startAnimating];

        // Wait for response if pending, 4 sec timeout
        //
        NSDate *time0 = [NSDate date];

        while(( self.geoCoder1.queryCount > self.geoCoder1.responseCount && self.geoCoder2.queryCount > self.geoCoder2.responseCount ) && fabs([time0 timeIntervalSinceNow]) < kTimeoutReturn && self.alpha > 0.1)
        {
            // yield main thread loop for 20ms or longer to poll for query response; Note: dangerous things can happen yielding the main thread, such as if the user pastes the copy buffer which can dead lock main thread.

            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }

        [installingSwirl_ stopAnimating];
        [installingSwirl_ removeFromSuperview];
    }

    // Try to use Google results as first default
    //
    if (self.forwardGeoCoderResultsGoogle.count > 0)
    {
        _selectedResult = _forwardGeoCoderResultsGoogle[0];

        if ([self.geoCoderDelegate respondsToSelector:@selector(geoCoder:hasResult:)]) {
            [self.geoCoderDelegate geoCoder:self hasResult:self.selectedResult];
        }
    }
    else if (self.forwardGeoCoderResultsGNIS.count > 0)
    {
        _selectedResult = _forwardGeoCoderResultsGNIS[0];
        
        if ([self.geoCoderDelegate respondsToSelector:@selector(geoCoder:hasResult:)]) {
            [self.geoCoderDelegate geoCoder:self hasResult:self.selectedResult];
        }
    }

    [self resignFirstResponder];

    return NO; // NO Don't do anything to text
}


- (BOOL)textFieldShouldClear:(id)textField
{
    NSLOG(@"%s: ENTER",__func__);
    [_timerSearchTextForget invalidate];
    _timerSearchTextForget = nil;
    [_timerQueryDelay invalidate];
    _timerQueryDelay = nil;
    _forwardGeoCoderResultsGNIS = nil;
    _forwardGeoCoderResultsGoogle = nil;
    _selectedResult = nil;
    self.text = @"";
    self.searchText = nil;
    self.searchTextSent = nil;
    [self updateTable];
#ifdef USE_GOOGE_LOGO
    self.imagePoweredByGoo.hidden = NO;
#endif
    return YES;
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSLOG(@"%s: range:(%ld,%ld)  string:'%@'",__func__,(long)range.location,(long)range.length,string);

    double queryDelay = 0;

    _searchText = [self.text stringByReplacingCharactersInRange:range withString:string];
    _selectedResult = nil;  // clear prior entered results upon key tap

    if ( ! (_connectionError && self.geoCoder2 == nil) )
    {
        if (self.searchText.length > 0)
        {
            if (string.length > 0)
            {
                // new letters entered
                queryDelay = (kPressedKeyPredictionDelay + kPredictionSlowDownSeconds * ((double)self.geoCoder1.queryCount / kPredictionQueryLimit));
            }
            else {
                // deleted letter - wait longer
                queryDelay = (kDeleteKeyPredictionDelay);
            }

            if ([self.timerQueryDelay isValid] && string.length == 0) {
                // restart delay if deleted letter, else fire a fixed delays
                self.timerQueryDelay.fireDate = [NSDate dateWithTimeIntervalSinceNow:queryDelay];
            }
            else {
                [_timerQueryDelay invalidate];
                _timerQueryDelay = [NSTimer scheduledTimerWithTimeInterval:queryDelay target:self selector:@selector(timerQueryDelayHandler:) userInfo:nil repeats:NO];
            }
#ifdef USE_GOOGE_LOGO
            self.imagePoweredByGoo.hidden = YES;
#endif
        }
        else {
            // No text
            [self textFieldShouldClear:self];
#ifdef USE_GOOGE_LOGO
            self.imagePoweredByGoo.hidden = NO;
#endif
        }
    }

    return YES;
}


#pragma mark - Table Data Source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLOG(@"%s: ENTER",__func__);

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"GeoCodeTableCellID"
                                                            forIndexPath:indexPath];

    NSInteger row = indexPath.row;
    ForwardGeoResult* coder = nil;

    @try {
        if (indexPath.section == 0) {
            coder = _forwardGeoCoderResultsGoogle[row];
        } else {
            coder = _forwardGeoCoderResultsGNIS[row];
        }
    } @catch (NSException *exception) {
        DLOG(@"%s: exception: '%@'",__func__,exception);
    } @finally { }

    cell.textLabel.text = coder.address;

    // Show distance accessory
    //
    if (self.geoCoderDelegate != nil) {
        self.viewRegion = [self.geoCoderDelegate region];
    }

    if (self.viewRegionValid)
    {
        CLLocation *location = coder.location;
        CLLocation *locationMapCenter = [[CLLocation alloc] initWithLatitude:self.viewRegion.center.latitude longitude:self.viewRegion.center.longitude];
        double meters = [location distanceFromLocation:locationMapCenter];
        double value = meters * _unitsPerMeter;
        NSString* fmt = value >= 100.0 ? @"%.0F%@" : value >= 10 ? @"%.1F%@" : @"%.2F%@";
        UILabel* distLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, ceil(_headerFontSize * 2.7), self.frame.size.height)];
        distLabel.text = [NSString stringWithFormat:fmt,value,_unitsString];
        distLabel.font = [UIFont fontWithName:kFGEO_DIST_FONT size:_headerFontSize];
        distLabel.adjustsFontSizeToFitWidth = YES;
        distLabel.textColor = [UIColor purpleColor];
        distLabel.textAlignment = NSTextAlignmentRight;
#ifdef DEBUG
        //distLabel.backgroundColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.333];
#endif
        cell.accessoryView = distLabel;
    } else {
        cell.accessoryView = nil;
    }

    return cell;
}


-(UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        // Gooble

        if (self.headerViewGoogle == nil)
        {
            self.headerViewGoogle = [self makeHeaderViewForTable:tableView title:@"Google"];

            UIActivityIndicatorView* swirlView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            CGRect f = CGRectMake((tableView.bounds.size.width - self.headerViewHeight - 2)/2, 0, self.headerViewHeight - 2, self.headerViewHeight - 2);
            swirlView.frame = f;
            self.swirlGoogle = swirlView;
            [self.headerViewGoogle addSubview:swirlView];
        }
        return self.headerViewGoogle;
    }
    else
    {
        //GNIS

        if (self.headerViewGNIS == nil)
        {
            self.headerViewGNIS = [self makeHeaderViewForTable:tableView title:@"GNIS"];

            UIActivityIndicatorView* swirlView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            CGRect f = CGRectMake((tableView.bounds.size.width - self.headerViewHeight - 2)/2, 0, self.headerViewHeight - 2, self.headerViewHeight - 2);
            swirlView.frame = f;
            self.swirlGNIS = swirlView;
            [self.headerViewGNIS addSubview:swirlView];

        }
        return self.headerViewGNIS;
    }
}


-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    CGFloat hgt = 0;

    // Don't show headers if only one geoCoder running. Show header if its geocoder has data
    if ( self.geoCoder1 && self.geoCoder2 )
    {
        if (section == 0) {
            hgt = self.forwardGeoCoderResultsGoogle.count != 0 ? self.headerViewHeight : 0;
        }
        else {
            hgt = self.forwardGeoCoderResultsGNIS.count != 0 ? self.headerViewHeight : 0;
        }
    }

    return hgt;
}


-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    //NSInteger secs = (self.forwardGeoCoderResultsGNIS ? 1 : 0) + (self.forwardGeoCoderResultsGoogle ? 1 : 0);
    return 2;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSLOG(@"%s: ENTER rows:%ld",__func__,(long)_forwardGeoCoderResults.count);
    NSInteger rows = 0;
    if (section == 0) {
        // Google
        rows = self.forwardGeoCoderResultsGoogle.count;
    } else {
        // GNIS
        rows = self.forwardGeoCoderResultsGNIS.count;
    }
    return rows;
}


#pragma mark -

-(UIView*) makeHeaderViewForTable:(UITableView *)tableView title:(NSString*) title
{
    UIColor* bgColor = [UIColor lightGrayColor]; // static

    UILabel* headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 0, 0, 0)];
    headerLabel.text = title;
    headerLabel.font = [UIFont systemFontOfSize:self.headerFontSize weight:UIFontWeightLight];
    headerLabel.textColor = [UIColor blackColor];
    headerLabel.backgroundColor = bgColor;
    headerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // container view
    UIView *view = [[UIView alloc] init];
    [view addSubview:headerLabel];
    view.backgroundColor = bgColor;
    //view.userInteractionEnabled = NO;// leave default of YES so won't pass touch to table cell that is covered

    return view;
}


-(CGFloat) recommendedTable1Height
{
    CGFloat rowMax = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? kRowMaxiPad : kRowMaxiPhone;
    CGFloat height = MIN((CGFloat)(_forwardGeoCoderResultsGoogle.count + _forwardGeoCoderResultsGNIS.count),(CGFloat)rowMax) * self.rowHeight;
    height += _forwardGeoCoderResultsGoogle.count != 0 ? self.headerViewHeight : 0;
    height += _forwardGeoCoderResultsGNIS.count != 0 ? self.headerViewHeight : 0;

    // Clap height to keyboard top plus gap
    //
    if (_keyboardFrameVal != nil)
    {
        CGRect kbFrameRaw = [self.keyboardFrameVal CGRectValue];
        CGRect kbFrame = [self.table1 convertRect:kbFrameRaw fromView:nil/*nil is window*/];
        CGFloat kbMinY = CGRectGetMinY(kbFrame);
        CGFloat spaceY = kbMinY - kGCTF_keyboardTextfieldGap;

        // Shrink only if some gap larger that two cells and two header views
        if (spaceY > (self.rowHeight + self.headerViewHeight) * 2)
        {
            height = MIN(spaceY,height);
        }
    }

    return height;
}


-(void) updateTable1Height
{
    CGFloat height = [self recommendedTable1Height];

    if ( self.table1HeightConstraint.constant != height ) {
        self.table1HeightConstraint.constant = height;
        [self.superview setNeedsUpdateConstraints];
    }
}


-(void) updateTable
{
    NSLOG(@"%s: ENTER",__func__);

    if (self.table1)
    {
        [self updateTable1Height];
        [self.table1 reloadData];
    }
}


#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLOG(@"%s: ENTER",__func__);
    NSInteger row = indexPath.row;
    NSInteger sec = indexPath.section;
    
    if (sec == 0) {
        // google is section 0
        _selectedResult = _forwardGeoCoderResultsGoogle[row];
    }
    else {
        // GNIS is section 1
        _selectedResult = _forwardGeoCoderResultsGNIS[row];
    }
    
    if ([self.geoCoderDelegate respondsToSelector:@selector(geoCoder:hasResult:)]) {
        [self.geoCoderDelegate geoCoder:self hasResult:self.selectedResult];
    }

    [self resignFirstResponder];
}


#pragma mark - Geo Coder Delegate

- (void)forwardGeocodingDidSucceed:(ForwardGeocoder *)geocoder withResults:(NSArray<ForwardGeoResult*> *)results
{
    DLOG(@"%s: ENTER queryCount:%ld",__func__,(long)geocoder.queryCount);

    _connectionError = NO;

    [self.swirlGoogle performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];

    NSInteger tagThisThread = geocoder.queryCount;

    NSArray* sorted = geocoder.resultsAreSortedByDistance ? results : [self sortedForwardGeoCoderResultsByDistance:results];

    // Check that sorting delay is now same results after sorting
    //
    if (tagThisThread == self.geoCoder1.queryCount)
    {
        if (results.count)
        {
            [self performSelectorOnMainThread:@selector(setForwardGeoCoderResultsGoogle:) withObject:sorted waitUntilDone:YES];

            [self performSelectorOnMainThread:@selector(updateTable) withObject:nil waitUntilDone:YES];
        }

        _noBounds = NO;
    }
    else {
        // old query thread -- ignore
        DLOG(@"%s: Old thread tag was: %ld, now: %ld",__func__,(long)tagThisThread,(long)geocoder.queryCount);
    }
}


-(void) GNISGeocodingDidSucceed:(GNISGeocoder *)geocoder withResults:(NSArray<ForwardGeoResult *> *)results
{
    DLOG(@"%s: ENTER queryCount:%ld",__func__,(long)geocoder.queryCount);

    [self.swirlGNIS performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];

    if (geocoder.queryCount == geocoder.responseCount) {
        {
            //_forwardGeoCoderResultsGNIS = results;
            [self performSelectorOnMainThread:@selector(setForwardGeoCoderResultsGNIS:) withObject:results waitUntilDone:YES];
            [self performSelectorOnMainThread:@selector(updateTable) withObject:nil waitUntilDone:YES];
        }

        _noBounds = NO;
    }
    else { /* old response, drop */ }
}


- (void)forwardGeocoderConnectionDidFail:(ForwardGeocoder *)geocoder withError:(NSError *)error
{
    DLOG(@"%s: ENTER error: %@",__func__,error.localizedDescription);

    [self.swirlGoogle performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];

    if (error.code == -999 && [error.domain isEqualToString:NSURLErrorDomain]) {
        // Request had Cancel -- ignore; user still typing, this will cancel prior URL query request
    }
    else {
        _connectionError = YES;
        [self performSelectorOnMainThread:@selector(networkConnectedCheck) withObject:nil waitUntilDone:NO];
    }
}


- (void)forwardGeocodingDidFail:(ForwardGeocoder *)geocoder withErrorCode:(int)errorCode andErrorMessage:(NSString *)errorMessage
{
    DLOG(@"%s: ENTER error: %@",__func__,errorMessage);

    _connectionError = NO;

    if (_noBounds == NO)
    {
        _noBounds = YES;
        
        // Try again without map region bounds
        // yield(0.02)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];

        if ([NSThread isMainThread]) {
            [self.geoCoder1 forwardGeocodeWithQuery:_searchText];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.geoCoder1 forwardGeocodeWithQuery:_searchText];
            });
        }
    }
    else
    {
        // Nothing found, clear table
        [self.swirlGoogle performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
        if ([NSThread isMainThread]) {
            _forwardGeoCoderResultsGoogle = nil;
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                _forwardGeoCoderResultsGoogle = nil;
            });
        }
        [self performSelectorOnMainThread:@selector(updateTable) withObject:nil waitUntilDone:NO];
    }
}


-(void) GNISGeocodingDidFail:(GNISGeocoder *)geocoder withErrorCode:(int)errorCode andErrorMessage:(NSString *)errorMessage
{
    DLOG(@"%s: ENTER error: %@",__func__,errorMessage);
    [self.swirlGNIS performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];

    //_forwardGeoCoderResultsGNIS = nil;
    [self performSelectorOnMainThread:@selector(setForwardGeoCoderResultsGNIS:) withObject:nil waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(updateTable) withObject:nil waitUntilDone:NO];
}


- (NSArray*) sortedForwardGeoCoderResultsByDistance:(NSArray<ForwardGeoResult*>*) results;
{
    NSArray* newArray = nil;

    NSLOG(@"%s: ENTER",__func__);
    if (self.geoCoderDelegate)
    {
        self.viewRegion = [self.geoCoderDelegate region];
    }

    if (self.viewRegionValid)
    {
        CLLocation* locationMapCenter = [[CLLocation alloc] initWithLatitude:self.viewRegion.center.latitude longitude:self.viewRegion.center.longitude];

        newArray = [results sortedArrayUsingComparator:
         ^(ForwardGeoResult* obj1,ForwardGeoResult* obj2) {
            double meters1 = [locationMapCenter distanceFromLocation:[obj1 getLocation]];
            double meters2 = [locationMapCenter distanceFromLocation:[obj2 getLocation]];
            return meters1 > meters2 ? NSOrderedDescending : (meters1 < meters2 ? NSOrderedAscending : NSOrderedSame);
        }];
    }

    return newArray;
}

@end
