//
//  GeoCodeTableViewCell.m
//  GNISGeoCoder
//
//  Created by Dennis on 9/16/14.
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

#import "GeoCodeTableViewCell.h"


// Class bg color
static UIColor* bgColor_;


@implementation GeoCodeTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self doInit];
    }
    return self;
}


- (void)awakeFromNib
{
    [super awakeFromNib];
    [self doInit];
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void) doInit
{
    self.textLabel.textAlignment = NSTextAlignmentLeft;
    CGFloat fontsize = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline].pointSize;
    self.textLabel.font = [UIFont boldSystemFontOfSize:fontsize];

    if (bgColor_ == nil) {
        bgColor_ = [UIColor colorWithRed:204.0f/255 green:203.0f/255 blue:184.0f/255 alpha:0.8];
    }

    self.backgroundColor = bgColor_;
}

@end
