//
//  WDMenu.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDMenu.h"
#import "WDUtilities.h"
#import "WDMenuItem.h"

#define kMenuHeight         40
#define kSeparatorHeight    5
#define kSeparatorInset     4
#define kInset              20
#define kFontSize           17
#define kImageBuffer        15
#define kMinimumMenuWidth   160

@interface WDMenu (Private)
- (void) createLabels_;
@end

@implementation WDMenu

@synthesize indexOfSelectedItem = selectedIndex_;
@synthesize items = items_;
@synthesize visible = visible_;
@synthesize origin = origin_;
@synthesize popover = popover_;
@synthesize delegate = delegate_;

- (id) initWithItems:(NSArray *)items
{
    float   maxWidth = 0;
    float   height = 0;
    
    for (WDMenuItem *item in items) {
        int imageWidth = [item imageWidth] ? [item imageWidth] + kImageBuffer : 0;
        
        NSDictionary *attrs = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:kFontSize]};
        maxWidth = MAX(maxWidth, [item.title sizeWithAttributes:attrs].width + imageWidth);
        height += (item.separator ? kSeparatorHeight : kMenuHeight);
    }
    
    maxWidth = MAX(kMinimumMenuWidth, maxWidth);
    CGRect frame = CGRectMake(0, 0, floor(maxWidth + kInset * 2), height);
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    selectedIndex_ = -1;
    
    self.opaque = NO;
    self.backgroundColor = nil;
    self.items = [items mutableCopy];
    
    return self;
}

- (void) setItems:(NSMutableArray *)array
{
    items_ = array;
    [self createLabels_];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    
    if (selectedIndex_ >= 0) {
        [[UIColor colorWithRed:(193.0f / 255) green:(220.0f / 255) blue:1.0f alpha:1.0f] set];
        CGContextFillRect(ctx, [rects_[selectedIndex_] CGRectValue]);
    }
}

- (void) setIndexOfSelectedItem:(int)index
{
    selectedIndex_ = index;
    [self setNeedsDisplay];
}

- (void) handlePoint:(CGPoint)pt
{
    int currentIndex = selectedIndex_;
    
    // stop tracking if the touch leaves the view entirely
    if (!CGRectContainsPoint(self.bounds, pt)) {
        selectedIndex_ = -1;
    } else {
        int ix = 0;
        for (NSValue *rect in rects_) {
            if (CGRectContainsPoint([rect CGRectValue], pt)) {
                WDMenuItem *item = items_[ix];
                selectedIndex_ = (item.separator || !item.enabled) ? -1 : (int) [rects_ indexOfObject:rect];
                break;
            }
            ix++;
        }
    }
        
    if (selectedIndex_ != currentIndex) {
        [self setNeedsDisplay];
    }
}

- (BOOL) beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint pt = [touch locationInView:self];
    [self handlePoint:pt];
    
    return [super beginTrackingWithTouch:touch withEvent:event];
}

- (BOOL) continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint pt = [touch locationInView:self];
    [self handlePoint:pt];
    
    return [super continueTrackingWithTouch:touch withEvent:event];
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint pt = [touch locationInView:self];
    [self handlePoint:pt];
    
    if (selectedIndex_ >= 0) {
        WDMenuItem *item = items_[selectedIndex_];
        if (!item.separator && item.enabled) {
            [[UIApplication sharedApplication] sendAction:item.action to:item.target from:item forEvent:event];
        }
    }
    
    [self dismiss];
    
    [super endTrackingWithTouch:touch withEvent:event];
}

- (void) dismiss
{
    [self setIndexOfSelectedItem:(-1)];

    [popover_ dismissPopoverAnimated:YES];
    
    [delegate_ popoverControllerDidDismissPopover:popover_];
}

@end

@implementation WDMenu (Private)

- (void) createLabels_
{
    rects_ = [[NSMutableArray alloc] init];
    
    CGRect  frame = self.bounds;
    frame.size.height = kMenuHeight;
    
    for (WDMenuItem *item in items_) {
        frame.size.height = (item.separator ? kSeparatorHeight : kMenuHeight);
        frame = CGRectIntegral(frame);
        
        if (!item.separator) {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectOffset(frame, kInset, 0.0f)];
            label.opaque = NO;
            label.backgroundColor = nil;
            label.textColor = [UIColor colorWithRed:0.0f green:(118.0f / 255.0f) blue:1.0f alpha:1.0f];
            label.textAlignment = NSTextAlignmentLeft;
            label.font = [UIFont systemFontOfSize:kFontSize];
            label.text = item.title;
            
            [self addSubview:label];
            item.label = label;
        } else {
            float scale = [UIScreen mainScreen].scale;
            CGRect lineRect = frame;
            
            lineRect.origin.x = 0.0f;
            lineRect.origin.y += lineRect.size.height / 2;
            lineRect = CGRectIntegral(lineRect);
            lineRect = CGRectInset(lineRect, kSeparatorInset, 0.0f);
            lineRect.size.height = 1.0f / scale;
            
            UIView *line = [[UIView alloc] initWithFrame:lineRect];
            line.opaque = NO;
            line.layer.borderColor = [UIColor colorWithWhite:0.25f alpha:0.25f].CGColor;
            line.layer.borderWidth = 1.0f / scale;
            [self addSubview:line];
        }
        
        CGRect highlightRect = frame;
        [rects_ addObject:[NSValue valueWithCGRect:highlightRect]];
        frame.origin.y += frame.size.height;
        
        if (item.image) {
            UIImage *templateImage = [item.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            UIImageView *imageView = [[UIImageView alloc] initWithImage:templateImage];
            CGRect imageFrame = imageView.frame;
            imageFrame.origin.x = CGRectGetMaxX(highlightRect) - CGRectGetWidth(imageFrame) - kImageBuffer;
            imageFrame.origin.y = CGRectGetMidY(highlightRect) - CGRectGetHeight(imageFrame) / 2;
            imageFrame.origin = WDRoundPoint(imageFrame.origin);
            imageView.frame = imageFrame;
            [self addSubview:imageView];
            item.imageView = imageView;
            imageView.tintColor = [UIColor colorWithRed:0.0f green:(118.0f / 255.0f) blue:1.0f alpha:1.0f];
        }
    }
}

@end
