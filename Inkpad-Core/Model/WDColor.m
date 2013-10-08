//
//  WDColor.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2008-2013 Steve Sprang
//

#if !TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#import "WDColor.h"
#import "WDPath.h"
#import "WDUtilities.h"

NSString *WDHueKey = @"WDHueKey";
NSString *WDSaturationKey = @"WDSaturationKey";
NSString *WDBrightnessKey = @"WDBrightnessKey";
NSString *WDAlphaKey = @"WDAlphaKey";

@implementation WDColor

@synthesize hue = hue_;
@synthesize saturation = saturation_;
@synthesize brightness = brightness_;
@synthesize alpha = alpha_;

+ (WDColor *) randomColor
{
   float components[4];
    
    for (int i = 0; i < 4; i++) {
        components[i] = WDRandomFloat();
    }
    components[3] = 0.5 + (components[3] * 0.5);
    
    return [[WDColor alloc] initWithHue:components[0] saturation:components[1] brightness:components[2] alpha:components[3]];
}

+ (WDColor *) colorWithWhite:(float)white alpha:(CGFloat)alpha
{
    return [[WDColor alloc] initWithHue:0 saturation:0 brightness:white alpha:alpha];
}

+ (WDColor *) colorWithRed:(float)red green:(float)green blue:(float)blue alpha:(CGFloat)alpha
{
    float hue, saturation, brightness;
    
    RGBtoHSV(red, green, blue, &hue, &saturation, &brightness);
    
    return [[WDColor alloc] initWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}
    
+ (WDColor *) colorWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha
{
    return [[WDColor alloc] initWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

- (WDColor *) initWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    hue_ = hue;
    saturation_ = saturation;
    brightness_ = brightness;
    alpha_ = alpha;
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeFloat:hue_ forKey:WDHueKey];
    [coder encodeFloat:saturation_ forKey:WDSaturationKey]; 
    [coder encodeFloat:brightness_ forKey:WDBrightnessKey]; 
    [coder encodeFloat:alpha_ forKey:WDAlphaKey]; 
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    hue_ = [coder decodeFloatForKey:WDHueKey]; 
    saturation_ = [coder decodeFloatForKey:WDSaturationKey]; 
    brightness_ = [coder decodeFloatForKey:WDBrightnessKey]; 
    alpha_ = [coder decodeFloatForKey:WDAlphaKey]; 
    
    return self; 
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@: H: %f, S: %f, V:%f, A: %f", [super description], hue_, saturation_, brightness_, alpha_];
}

- (BOOL) isEqual:(WDColor *)color
{
    if (color == self) {
        return YES;
    }
    
    if (![color isKindOfClass:[WDColor class]]) {
        return NO;
    }
    
    return (hue_ == color.hue &&
            saturation_ == color.saturation &&
            brightness_ == color.brightness &&
            alpha_ == color.alpha);
}

+ (WDColor *) colorWithDictionary:(NSDictionary *)dict
{
    float hue = [dict[@"hue"] floatValue];
    float saturation = [dict[@"saturation"] floatValue];
    float brightness = [dict[@"brightness"] floatValue];
    float alpha = [dict[@"alpha"] floatValue];
    
    return [WDColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

- (NSDictionary *) dictionary
{
    return @{@"hue": @(hue_), @"saturation": @(saturation_), @"brightness": @(brightness_), @"alpha": @(alpha_)};
}

+ (WDColor *) colorWithData:(NSData *)data
{
    UInt16  *values = (UInt16 *) [data bytes];
    float   components[4];
    
    for (int i = 0; i < 4; i++) {
        components[i] = CFSwapInt16LittleToHost(values[i]);
        components[i] /= USHRT_MAX;
    }
    
    return [WDColor colorWithHue:components[0] saturation:components[1] brightness:components[2] alpha:components[3]];
}
    
- (NSData *) colorData
{
    UInt16 data[4];
    
    data[0] = hue_ * USHRT_MAX;
    data[1] = saturation_ * USHRT_MAX;
    data[2] = brightness_ * USHRT_MAX;
    data[3] = alpha_ * USHRT_MAX;
    
    for (int i = 0; i < 4; i++) {
        data[i] = CFSwapInt16HostToLittle(data[i]);
    }
    
    return [NSData dataWithBytes:data length:8];
}

- (void) set
{
    [[self UIColor] set];
}

- (UIColor *) UIColor
{
    return [UIColor colorWithHue:hue_ saturation:saturation_ brightness:brightness_ alpha:alpha_];
}

- (UIColor *) opaqueUIColor
{
    return [UIColor colorWithHue:hue_ saturation:saturation_ brightness:brightness_ alpha:1.0];
}

- (CGColorRef) CGColor
{
    return [[self UIColor] CGColor];
}

- (CGColorRef) opaqueCGColor
{
    return [[self opaqueUIColor] CGColor];
}

- (WDColor *) colorWithAlphaComponent:(float)alpha
{
    return [WDColor colorWithHue:hue_ saturation:saturation_ brightness:brightness_ alpha:alpha];
}

- (WDColor *) adjustColor:(WDColor * (^)(WDColor *color))adjustment
{
    return adjustment(self);
}

- (float) red
{
    float   r, g, b;
    
    HSVtoRGB(hue_, saturation_, brightness_, &r, &g, &b);

    return r;
}

- (float) green
{
    float   r, g, b;
    
    HSVtoRGB(hue_, saturation_, brightness_, &r, &g, &b);
    
    return g;
}

- (float) blue
{
    float   r, g, b;
    
    HSVtoRGB(hue_, saturation_, brightness_, &r, &g, &b);
    
    return b;
}

- (WDColor *) colorBalanceRed:(float)rShift green:(float)gShift blue:(float)bShift
{
    float   r, g, b;
    float   h, s, v;
    
    HSVtoRGB(hue_, saturation_, brightness_, &r, &g, &b);
    
    r = WDClamp(0, 1, r + rShift);
    g = WDClamp(0, 1, g + gShift);
    b = WDClamp(0, 1, b + bShift);
    
    RGBtoHSV(r, g, b, &h, &s, &v);
    return [WDColor colorWithHue:h saturation:s brightness:v alpha:alpha_];
}

- (WDColor *) adjustHue:(float)hShift saturation:(float)sShift brightness:(float)bShift
{
    float h = hue_ + hShift;
    BOOL negative = (h < 0);
    h = fmodf(fabs(h), 1.0f);
    if (negative) {
        h = 1.0f - h;
    }
    
    sShift = 1 + sShift;
    bShift = 1 + bShift;
    float s = WDClamp(0, 1, saturation_ * sShift);
    float b = WDClamp(0, 1, brightness_ * bShift);
    
    return [WDColor colorWithHue:h saturation:s brightness:b alpha:alpha_];
}

- (WDColor *) inverted
{
    float   r, g, b;
    
    HSVtoRGB(hue_, saturation_, brightness_, &r, &g, &b);
    
    return [WDColor colorWithRed:(1.0f - r) green:(1.0f - g) blue:(1.0f - b) alpha:alpha_];
}

+ (WDColor *) blackColor
{
    return [WDColor colorWithHue:0.0f saturation:0.0f brightness:0.0f alpha:1.0f];
}

+ (WDColor *) grayColor
{
    return [WDColor colorWithHue:0.0f saturation:0.0f brightness:0.25f alpha:1.0f];
}

+ (WDColor *) whiteColor
{
    return [WDColor colorWithHue:0.0f saturation:0.0f brightness:1.0f alpha:1.0f];
}

+ (WDColor *) cyanColor
{
    return [WDColor colorWithRed:0 green:1 blue:1 alpha:1];
}

+ (WDColor *) redColor
{
    return [WDColor colorWithRed:1 green:0 blue:0 alpha:1];
}

+ (WDColor *) magentaColor
{
    return [WDColor colorWithRed:1 green:0 blue:1 alpha:1];
}

+ (WDColor *) greenColor
{
    return [WDColor colorWithRed:0 green:1 blue:0 alpha:1];
}

+ (WDColor *) yellowColor
{
    return [WDColor colorWithRed:1 green:1 blue:0 alpha:1];
}

+ (WDColor *) blueColor
{
    return [WDColor colorWithRed:0 green:0 blue:1 alpha:1];
}

- (WDColor *) blendedColorWithFraction:(float)blend ofColor:(WDColor *)color
{
    float       inR, inG, inB;
    float       selfR, selfG, selfB;
    
    HSVtoRGB(color.hue, color.saturation, color.brightness, &inR, &inG, &inB);
    HSVtoRGB(hue_, saturation_, brightness_, &selfR, &selfG, &selfB);
    
    float r = (blend * inR) + (1.0f - blend) * selfR;
    float g = (blend * inG) + (1.0f - blend) * selfG;
    float b = (blend * inB) + (1.0f - blend) * selfB;
    float a = (blend * color.alpha) + (1.0f - blend) * self.alpha;
    
    return [WDColor colorWithRed:r green:g blue:b alpha:a];
}

- (NSString *) hexValue
{   
    float       r, g, b;

    HSVtoRGB(hue_, saturation_, brightness_, &r, &g, &b);
    return [NSString stringWithFormat:@"#%.2x%.2x%.2x", (int) (r*255 + 0.5f), (int) (g*255 + 0.5f), (int) (b*255 + 0.5f)];
}

- (void) paintPath:(WDPath *)path inContext:(CGContextRef)ctx
{    
    CGContextAddPath(ctx, path.pathRef);
    CGContextSetFillColorWithColor(ctx, self.CGColor);
    
    if (path.fillRule == kWDEvenOddFillRule) {
        CGContextEOFillPath(ctx);
    } else {
        CGContextFillPath(ctx);
    }
}

- (void) drawSwatchInRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    WDDrawTransparencyDiamondInRect(ctx, rect);
    
    [self set];
    CGContextFillRect(ctx, rect);
}

- (void) drawEyedropperSwatchInRect:(CGRect)rect
{
    [self drawSwatchInRect:rect];
}

- (BOOL) transformable
{
    return NO;
}

- (BOOL) canPaintStroke
{
    return YES;
}

- (void) paintText:(id<WDTextRenderer>)text inContext:(CGContextRef)ctx
{
    [self set];
    [text drawTextInContext:ctx drawingMode:kCGTextFill];
}

- (id) copyWithZone:(NSZone *)zone
{
    // this object is immutable
    return self;
}

@end
