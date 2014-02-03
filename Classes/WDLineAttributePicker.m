//
//  WDLineAttributePicker.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDLineAttributePicker.h"

#define kIconDimension  36
#define kIconSpacing (kIconDimension + 12)

@implementation WDLineAttributePicker

@synthesize cap = cap_;
@synthesize join = join_;
@synthesize mode = mode_;

const CGFloat highlightComponents[] = {0.0f, 118.0f / 255.0f, 1.0f, 0.9f};
const CGFloat normalComponents[] = {125.0f / 255.0f, 147.0f / 255.0f, 178.0f / 255.0f, 0.8f};
const CGFloat highlightGray = 0.9f;
const CGFloat normalGray = 0.2f;
const float radius = 3.0f;

+ (UIImage *) joinImageWithSize:(CGSize)size join:(CGLineJoin)join highlight:(BOOL)highlight
{
    CGMutablePathRef pathRef = CGPathCreateMutable();
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // set this up so that we can set colors via component array
    CGColorSpaceRef strokeColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextSetStrokeColorSpace(ctx, strokeColorSpace);
    CGColorSpaceRelease(strokeColorSpace);
    
    float x = floor(size.width * 0.4f) + 0.5;
    float y = floor(size.width * 0.4f) + 0.5 - 1;
    int lineWidth = size.width * 0.6f;
    lineWidth += (lineWidth + 1) % 2;
    
    CGContextSetLineJoin(ctx, join);
    
    CGPathMoveToPoint(pathRef, NULL, x, size.height);
    CGPathAddLineToPoint(pathRef, NULL, x, y);
    CGPathAddLineToPoint(pathRef, NULL, size.width, y);
    
    CGContextAddPath(ctx, pathRef);
    CGContextSetLineWidth(ctx, lineWidth);
    CGContextSetStrokeColor(ctx, highlight ? highlightComponents : normalComponents);
    CGContextStrokePath(ctx);
    
    CGContextAddPath(ctx, pathRef);
    CGContextSetLineWidth(ctx, 1);
    CGContextSetGrayStrokeColor(ctx, highlight ? highlightGray : normalGray, 1);
    CGContextStrokePath(ctx);
    
    CGContextSetGrayFillColor(ctx, highlight ? highlightGray : normalGray, 1);
    CGContextAddEllipseInRect(ctx, CGRectMake(x - radius, y - radius, radius * 2, radius * 2));
    CGContextFillPath(ctx);
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGPathRelease(pathRef);
    
    return result;
}

+ (UIImage *) capImageWithSize:(CGSize)size cap:(CGLineCap)cap highlight:(BOOL)highlight
{
    CGMutablePathRef pathRef = CGPathCreateMutable();
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // set this up so that we can set colors via component array
    CGColorSpaceRef strokeColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextSetStrokeColorSpace(ctx, strokeColorSpace);
    CGColorSpaceRelease(strokeColorSpace);
    
    float x = (cap == kCGLineCapButt) ? floor(size.width * 0.25f) : floor(size.width * 0.5f);
    float y = floor(size.width * 0.5f) + 0.5;
    int lineWidth = size.width * 0.9f;
    lineWidth += (lineWidth + 1) % 2;
    
    CGContextSetLineCap(ctx, cap);
    
    CGPathMoveToPoint(pathRef, NULL, size.width, y);
    CGPathAddLineToPoint(pathRef, NULL, cap != kCGLineCapButt ? x - 0.5f : x, y);
    
    CGContextAddPath(ctx, pathRef);
    CGContextSetLineWidth(ctx, lineWidth);
    CGContextSetStrokeColor(ctx, highlight ? highlightComponents : normalComponents);
    CGContextStrokePath(ctx);
    
    CGContextAddPath(ctx, pathRef);
    CGContextSetLineWidth(ctx, 1);
    CGContextSetGrayStrokeColor(ctx, highlight ? highlightGray : normalGray, 1);
    CGContextStrokePath(ctx);
    
    CGContextSetGrayFillColor(ctx, highlight ? highlightGray : normalGray, 1);
    x = round(x) + 0.5f;
    y = round(y) - 0.5f;
    CGContextAddEllipseInRect(ctx, CGRectMake(x - radius, y - radius, radius * 2, radius * 2));
    CGContextFillPath(ctx);
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGPathRelease(pathRef);
    
    return result;
}

- (void) setCap:(CGLineCap)cap
{
    capButton_[cap_].selected = NO;
    cap_ = cap;
    capButton_[cap_].selected = YES;
}

- (void) setJoin:(CGLineJoin)join
{
    joinButton_[join_].selected = NO;
    join_ = join;
    joinButton_[join_].selected = YES;
}

- (void) takeJoinFrom:(id)sender
{
    UIButton *button = (UIButton *)sender;
    
    if (button.tag == join_) {
        return;
    }
    
    [self setJoin:(CGLineJoin)button.tag];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void) takeCapFrom:(id)sender
{
    UIButton *button = (UIButton *)sender;
    
    if (button.tag == cap_) {
        return;
    }
    
    [self setCap:(CGLineCap)button.tag];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void) setMode:(WDStrokeAttributes)mode
{
    UIImage *icon;
    CGRect  frame = CGRectMake(0, 0, kIconDimension, kIconDimension);
    
    mode_ = mode;
    
    if (mode_ == kStrokeJoinAttribute) {
        
        // create join buttons
        
        for (int i = 0; i < 3; i++) {
            joinButton_[i] = [UIButton buttonWithType:UIButtonTypeCustom];
            icon = [WDLineAttributePicker joinImageWithSize:CGSizeMake(kIconDimension, kIconDimension) join:i highlight:NO];
            [joinButton_[i] setImage:icon forState:UIControlStateNormal];
            
            icon = [WDLineAttributePicker joinImageWithSize:CGSizeMake(kIconDimension, kIconDimension) join:i highlight:YES];
            [joinButton_[i] setImage:icon forState:UIControlStateSelected];
            
            joinButton_[i].tag = i;
            joinButton_[i].selected = (i == join_);
            
            [joinButton_[i] addTarget:self action:@selector(takeJoinFrom:) forControlEvents:UIControlEventTouchUpInside];
            
            joinButton_[i].frame = frame;
            frame = CGRectOffset(frame, kIconSpacing, 0);
            [self addSubview:joinButton_[i]];
        }
    } else {
        
        // create cap buttons
        
        for (int i = 0; i < 3; i++) {
            capButton_[i] = [UIButton buttonWithType:UIButtonTypeCustom];
            icon = [WDLineAttributePicker capImageWithSize:CGSizeMake(kIconDimension, kIconDimension) cap:i highlight:NO];
            [capButton_[i] setImage:icon forState:UIControlStateNormal];
            
            icon = [WDLineAttributePicker capImageWithSize:CGSizeMake(kIconDimension, kIconDimension) cap:i highlight:YES];
            [capButton_[i] setImage:icon forState:UIControlStateSelected];
            
            capButton_[i].tag = i;
            capButton_[i].selected = (i == cap_);
            
            [capButton_[i] addTarget:self action:@selector(takeCapFrom:) forControlEvents:UIControlEventTouchUpInside];
            
            capButton_[i].frame = frame;
            frame = CGRectOffset(frame, kIconSpacing, 0);
            [self addSubview:capButton_[i]];
        }
    }
}

- (void) awakeFromNib
{
    self.backgroundColor = nil;
    self.opaque = NO;
}

@end
