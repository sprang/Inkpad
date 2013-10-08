//
//  WDHueShifter.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDColor.h"
#import "WDHueShifter.h"
#import "WDUtilities.h"
#import "UIView+Additions.h"

#define kHueImageHeight 15

@implementation WDHueIndicatorOverlay

@synthesize indicator;

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    self.opaque = NO;
    self.backgroundColor = nil;
    
    self.layer.shadowOpacity = 0.5f;
    self.layer.shadowRadius = 1;
    self.layer.shadowOffset = CGSizeMake(0, 0);
    
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef        ctx = UIGraphicsGetCurrentContext();
    CGRect              colorRect = [indicator colorRect];
    CGMutablePathRef    pathRef = CGPathCreateMutable();
    CGRect              outsideRect = CGRectInset(colorRect, -2, -2);
    
    outsideRect.size.height -= 1;

    CGPathMoveToPoint(pathRef, NULL, CGRectGetMinX(outsideRect), CGRectGetMinY(outsideRect));
    CGPathAddLineToPoint(pathRef, NULL, CGRectGetMaxX(outsideRect), CGRectGetMinY(outsideRect));
    
    CGPathAddLineToPoint(pathRef, NULL, CGRectGetMaxX(outsideRect), CGRectGetMaxY(outsideRect));
    CGPathAddLineToPoint(pathRef, NULL, CGRectGetMidX(outsideRect), CGRectGetMaxY(self.bounds));
    CGPathAddLineToPoint(pathRef, NULL, CGRectGetMinX(outsideRect), CGRectGetMaxY(outsideRect));
    
    CGPathCloseSubpath(pathRef);
    
    CGPathAddRect(pathRef, NULL, CGRectInset(colorRect, 1, 1));
    
    [[UIColor whiteColor] set];
    CGContextAddPath(ctx, pathRef);
    CGContextEOFillPath(ctx);
    
    CGPathRelease(pathRef);
}

@end

@implementation WDHueIndicator
@synthesize color = color_;

+ (WDHueIndicator *) hueIndicator
{
    CGRect frame = CGRectZero;
    frame.size = CGSizeMake(32, 32);
    
    WDHueIndicator *indicator = [[WDHueIndicator alloc] initWithFrame:frame];
    indicator.color = [WDColor whiteColor];
    
    return indicator;
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    self.opaque = NO;
    self.backgroundColor = nil;
    self.userInteractionEnabled = NO;
    
    WDHueIndicatorOverlay *overlay = [[WDHueIndicatorOverlay alloc] initWithFrame:self.bounds];
    overlay.indicator = self;
    [self addSubview:overlay];
    
    return self;
}

- (void) setColor:(WDColor *)color
{
    color_ = color;
    [self setNeedsDisplay];
}

- (CGRect) colorRect
{
    return CGRectMake(7,5,17,17);
}

- (void) drawRect:(CGRect)rect
{
    [color_ set];
    UIRectFill([self colorRect]);
}

@end

@interface WDHueShifter (Private)
- (CGImageRef) p_hueImage;
- (void) p_buildHueImage;
@end

@implementation WDHueShifter

@synthesize floatValue = value_;

- (BOOL) pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGRect bounds = CGRectInset(self.bounds, -10, -10);
    return CGRectContainsPoint(bounds, point);
}

- (void) positionIndicator
{
    float x = (value_ / 2) + 0.5;
    float value = WDClamp(1, CGRectGetMaxX(self.bounds), x * (CGRectGetWidth(self.bounds)));
    indicator_.sharpCenter = CGPointMake(value, 10);
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (!self) {
        return nil;
    }
    
    self.opaque = NO;
    self.backgroundColor = nil;
    self.clearsContextBeforeDrawing = YES;
    
    indicator_ = [WDHueIndicator hueIndicator];
    [self addSubview:indicator_];
    
    indicator_.color = [WDColor colorWithHue:0.5 saturation:1 brightness:1 alpha:1];
    [self positionIndicator];
    
    return self;
}

- (void) setFloatValue:(float)floatValue
{
    value_ = floatValue;
    [self positionIndicator];
    
    [self setNeedsDisplay];
}

- (void) drawRect:(CGRect)rect
{
    UIImage *image = [UIImage imageWithCGImage:[self p_hueImage]];
    UIImage *overlay = [[UIImage imageNamed:@"hue_shifter_overlay.png"] stretchableImageWithLeftCapWidth:10 topCapHeight:0];
    
    float x = (value_ / 2);
    float width = self.bounds.size.width;
    [image drawAtPoint:CGPointMake(width * x, 0)];
    [image drawAtPoint:CGPointMake(width * x - width, 0)];
    [image drawAtPoint:CGPointMake(width * x + width, 0)];
    
    // stationary hue bar
    [image drawAtPoint:CGPointMake(0, self.bounds.size.height - kHueImageHeight)];
    
    CGRect border = self.bounds;
    border.size.height = kHueImageHeight;
    [overlay drawInRect:border blendMode:kCGBlendModeMultiply alpha:0.4f];
    
    border.origin.y = self.bounds.size.height - kHueImageHeight;
    [overlay drawInRect:border blendMode:kCGBlendModeMultiply alpha:0.4f];
}

- (void) computeValue_:(CGPoint)pt
{
    CGRect  trackRect = self.bounds;
    float   percentage;
    
    percentage = (pt.x - CGRectGetMinX(trackRect)) / CGRectGetWidth(trackRect);
    percentage = WDClamp(0.0f, 1.0f, percentage);
    value_ = (percentage - 0.5f) * 2;
    
    [self setNeedsDisplay];
}

- (BOOL) beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint pt = [touch locationInView:self];
    
    initialPt_ = pt;
    initialValue_ = value_;
    
    [self computeValue_:pt];
    [self setNeedsDisplay];
    
    [self positionIndicator];
    
    return [super beginTrackingWithTouch:touch withEvent:event];
}

- (BOOL) continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint pt = [touch locationInView:self];
    
    [self computeValue_:pt];
    [self setNeedsDisplay];
    
    [self positionIndicator];
    
    return [super continueTrackingWithTouch:touch withEvent:event];
}

@end

@implementation WDHueShifter (Private)

- (CGImageRef) p_hueImage
{
    if (!hueImage_) {
        [self p_buildHueImage];
    }
    
    return hueImage_;
}

- (void) p_buildHueImage
{
    int             x, y;
    float           r,g,b;
    int             width = CGRectGetWidth(self.bounds);
    int             height = kHueImageHeight;
    int             bpr = width * 4;
    UInt8           *data, *ptr;
    
    ptr = data = calloc(1, sizeof(unsigned char) * height * bpr);
    
    for (x = 0; x < width; x++) {
        float angle = ((float) x) / width;
        HSVtoRGB(angle, 1.0f, 1.0f, &r, &g, &b);
        
        for (y = 0; y < height; y++) {
            ptr[y * bpr + x*4] = 255;
            ptr[y * bpr + x*4+1] = r * 255;
            ptr[y * bpr + x*4+2] = g * 255;
            ptr[y * bpr + x*4+3] = b * 255;
        }
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(data, width, height, 8, bpr, colorSpace, kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    hueImage_ = CGBitmapContextCreateImage(ctx);
    
    // clean up
    free(data);
    CGContextRelease(ctx);
}

@end
