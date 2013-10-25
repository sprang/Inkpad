//
//  WDArrowheadCell.m
//  Inkpad
//
//  Created by Steve Sprang on 10/16/13.
//  Copyright (c) 2013 Taptrix, Inc. All rights reserved.
//

#import "WDArrowhead.h"
#import "WDArrowheadCell.h"
#import "WDDrawingController.h"
#import "WDInspectableProperties.h"
#import "WDPropertyManager.h"

#define kArrowInset     15
#define kArrowWidth     72
#define kArrowHeight    46

@interface WDArrowSeparatorView : UIView
@end

@implementation WDArrowSeparatorView

- (void) drawRect:(CGRect)rect
{
    CGRect          frame = self.frame;
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    CGFloat         lengths[] = {2};
    float           y = floor(CGRectGetMidY(frame)) + 0.5f;
    
    [[[WDArrowheadCell tintColor] colorWithAlphaComponent:0.5f] set];
    
    CGContextSetLineWidth(ctx, 1.0);
    CGContextSetLineDash(ctx, 0, lengths, 1);
    CGContextMoveToPoint(ctx, 0, y);
    CGContextAddLineToPoint(ctx, CGRectGetWidth(frame), y);
    CGContextStrokePath(ctx);
}

@end

@implementation WDArrowheadCell

@synthesize startArrowButton = startArrowButton_;
@synthesize endArrowButton = endArrowButton_;
@synthesize arrowhead = arrowhead_;
@synthesize drawingController = drawingController_;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (!self) {
        return nil;
    }
    
    startArrowButton_ = [UIButton buttonWithType:UIButtonTypeCustom];
    startArrowButton_.frame = CGRectMake(0,0,kArrowWidth,kArrowHeight);
    [startArrowButton_ setBackgroundImage:[self selectedBackground] forState:UIControlStateSelected];
    startArrowButton_.tintColor = [WDArrowheadCell tintColor];
    [startArrowButton_ addTarget:self action:@selector(leftArrowTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:startArrowButton_];
    
    endArrowButton_ = [UIButton buttonWithType:UIButtonTypeCustom];
    endArrowButton_.frame = CGRectMake(self.contentView.frame.size.width - kArrowWidth,0,kArrowWidth,kArrowHeight);
    endArrowButton_.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [endArrowButton_ setBackgroundImage:[self selectedBackground] forState:UIControlStateSelected];
    endArrowButton_.tintColor = [WDArrowheadCell tintColor];
    [endArrowButton_ addTarget:self action:@selector(rightArrowTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:endArrowButton_];
    
    CGRect frame = CGRectInset(self.contentView.frame, kArrowWidth, 0);
    WDArrowSeparatorView *separator = [[WDArrowSeparatorView alloc] initWithFrame:frame];
    separator.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    separator.backgroundColor = nil;
    separator.opaque = NO;
    [self.contentView addSubview:separator];
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setDrawingController:(WDDrawingController *)drawingController
{
    drawingController_ = drawingController;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(invalidProperties:)
                                                 name:WDInvalidPropertiesNotification
                                               object:drawingController_.propertyManager];
}

- (void) invalidProperties:(NSNotification *)aNotification
{
    NSSet *properties = [aNotification.userInfo objectForKey:WDInvalidPropertiesKey];
    
    if ([properties intersectsSet:[NSSet setWithObjects:WDStartArrowProperty, WDEndArrowProperty, nil]]) {
        WDStrokeStyle   *strokeStyle = [drawingController_.propertyManager defaultStrokeStyle];
        
        self.startArrowButton.selected = [strokeStyle.startArrow isEqualToString:arrowhead_];
        self.endArrowButton.selected = [strokeStyle.endArrow isEqualToString:arrowhead_];
    }
}

- (void) leftArrowTapped:(UIButton *)sender
{
    [drawingController_ setValue:self.arrowhead forProperty:WDStartArrowProperty];
}

- (void) rightArrowTapped:(UIButton *)sender
{
    [drawingController_ setValue:self.arrowhead forProperty:WDEndArrowProperty];
}

- (void) setArrowhead:(NSString *)arrowhead
{
    if (arrowhead_ == arrowhead) {
        return;
    }
    
    arrowhead_ = arrowhead;
    
    UIImage *image = [self imageForArrow:arrowhead start:YES];
    [startArrowButton_ setImage:image forState:UIControlStateSelected];
    [startArrowButton_ setImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];

    image = [self imageForArrow:arrowhead start:NO];
    [endArrowButton_ setImage:image forState:UIControlStateSelected];
    [endArrowButton_ setImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
}

- (UIImage *) selectedBackground
{
    UIImage *selectedBackground_ = nil;
    
    if (!selectedBackground_) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(kArrowWidth,kArrowHeight), NO, 0);
        CGContextRef    ctx = UIGraphicsGetCurrentContext();
        
        [[UIColor colorWithRed:0.0f green:(118.0f / 255) blue:1.0f alpha:1.0f] set];
        CGContextFillRect(ctx, CGRectInset(CGRectMake(0, 0, kArrowWidth, kArrowHeight), 4, 4));
        
        selectedBackground_ = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    return selectedBackground_;
}

- (UIImage *) imageForArrow:(NSString *)arrowID start:(BOOL)isStart
{
    WDArrowhead     *arrow = [WDArrowhead arrowheads][arrowID];
    CGContextRef    ctx;
    float           scale = 3.0f;
    float           midY = floor(kArrowHeight / 2) + 0.5f;
    float           startX = kArrowInset + arrow.insetLength * scale;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kArrowWidth,kArrowHeight), NO, 0);
    ctx = UIGraphicsGetCurrentContext();
    
    [[UIColor whiteColor] set];
    CGContextSetLineWidth(ctx, scale);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    
    if (!arrow) {
        CGContextMoveToPoint(ctx, kArrowInset, midY);
        CGContextAddLineToPoint(ctx, kArrowWidth - kArrowInset, midY);
    } else if (isStart) {
        [arrow addArrowInContext:ctx position:CGPointMake(startX, midY) scale:scale angle:M_PI useAdjustment:NO];
        CGContextFillPath(ctx);
        CGContextMoveToPoint(ctx, startX, midY);
        CGContextAddLineToPoint(ctx, kArrowWidth - kArrowInset, midY);
    } else {
        [arrow addArrowInContext:ctx position:CGPointMake(kArrowWidth - startX, midY) scale:scale angle:0 useAdjustment:NO];
        CGContextFillPath(ctx);
        CGContextMoveToPoint(ctx, kArrowWidth - startX, midY);
        CGContextAddLineToPoint(ctx, kArrowInset, midY);
    }
    
    CGContextStrokePath(ctx);
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

+ (UIColor *) tintColor
{
    return [UIColor colorWithRed:(66.0f / 255) green:(102.0f / 255) blue:(151.0f / 255) alpha:1.0f];
}


@end
