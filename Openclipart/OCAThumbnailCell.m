//
//  OCAThumbnailCell.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import "OCAThumbnailCell.h"
#import "OCAEntry.h"
#import "UIView+Additions.h"

@interface OCAThumbnailCell ()
@property (nonatomic) UIImageView   *selectedIndicator;
@property (nonatomic) UIImageView   *imageView;
@property (nonatomic) UILabel       *titleLabel;
@end

@implementation OCAThumbnailCell

@synthesize entry = entry_;
@synthesize selectedIndicator = selectedIndicator_;
@synthesize imageView = imageView_;
@synthesize titleLabel = titleLabel_;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    float width = CGRectGetWidth(self.frame);
    
    CGRect  imageFrame = CGRectInset(CGRectMake(0,0,width,width), 5, 5);
    self.imageView = [[UIImageView alloc] initWithFrame:imageFrame];
    self.imageView.backgroundColor = nil;
    self.imageView.opaque = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:self.imageView];
    
    CGRect labelRect = CGRectMake(0, width, width, CGRectGetHeight(self.bounds) - width);
    labelRect = CGRectInset(labelRect, 10, 0);
    self.titleLabel = [[UILabel alloc] initWithFrame:labelRect];
    self.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:12.0f];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.backgroundColor = nil;
    self.titleLabel.opaque = NO;
    [self.contentView addSubview:self.titleLabel];
    
    UIView *selectionView = [[UIView alloc] initWithFrame:self.bounds];
    selectionView.backgroundColor = [UIColor colorWithRed:(193.0f / 255) green:(220.0f / 255) blue:1.0f alpha:0.8f];
    selectionView.layer.cornerRadius = 13;
    self.selectedBackgroundView = selectionView;
    
    return self;
}

- (void) setSelected:(BOOL)flag
{
    [super setSelected:flag];
    
    if (flag) {
        if (!selectedIndicator_) {
            UIImage *checkmark = [UIImage imageNamed:@"checkmark.png"];
            selectedIndicator_ = [[UIImageView alloc] initWithImage:checkmark];
            [self addSubview:selectedIndicator_];
        }
        
        float inset = CGRectGetWidth(selectedIndicator_.frame) / 2 + 2;
        CGPoint center = CGPointMake(CGRectGetMaxX(self.bounds) - inset, inset);
        selectedIndicator_.sharpCenter = center;
    } else if (!flag && selectedIndicator_){
        [UIView animateWithDuration:0.1f
                         animations:^{ selectedIndicator_.alpha = 0; }
                         completion:^(BOOL finished){
                             [selectedIndicator_ removeFromSuperview];
                             selectedIndicator_ = nil;
                         }];
    }
}

- (void) setThumbnail:(UIImage *)thumbnail
{
    imageView_.image = thumbnail;
    
    if (!thumbnail) {
        imageView_.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
        imageView_.layer.cornerRadius = 13;
    } else {
        imageView_.backgroundColor = nil;
        imageView_.layer.cornerRadius = 0;
    }
}

- (void) setEntry:(OCAEntry *)entry
{
    entry_ = entry;
    
    [self setThumbnail:nil];
    self.titleLabel.text = entry.title;
    
    [[OCAThumbnailCache sharedInstance] registerForThumbnail:self url:entry.thumbURL];
}

@end
