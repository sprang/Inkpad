//
//  WDColor.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2008-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import "WDPathPainter.h"

@interface WDColor : NSObject <NSCoding, NSCopying, WDPathPainter>

@property (nonatomic, readonly) CGFloat hue;
@property (nonatomic, readonly) CGFloat saturation;
@property (nonatomic, readonly) CGFloat brightness;
@property (nonatomic, readonly) CGFloat alpha;
@property (nonatomic, readonly) float red;
@property (nonatomic, readonly) float green;
@property (nonatomic, readonly) float blue;

+ (WDColor *) randomColor;
+ (WDColor *) colorWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha;
+ (WDColor *) colorWithWhite:(float)white alpha:(CGFloat)alpha;
+ (WDColor *) colorWithRed:(float)red green:(float)green blue:(float)blue alpha:(CGFloat)alpha;
- (WDColor *) initWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha;

+ (WDColor *) colorWithDictionary:(NSDictionary *)dict;
- (NSDictionary *) dictionary;

+ (WDColor *) colorWithData:(NSData *)data;
- (NSData *) colorData;

- (UIColor *) UIColor;
- (UIColor *) opaqueUIColor;

- (CGColorRef) CGColor;
- (CGColorRef) opaqueCGColor;

- (void) set;

- (WDColor *) adjustColor:(WDColor * (^)(WDColor *color))adjustment;
- (WDColor *) colorBalanceRed:(float)rShift green:(float)gShift blue:(float)bShift;
- (WDColor *) adjustHue:(float)hShift saturation:(float)sShift brightness:(float)bShift;
- (WDColor *) inverted;
- (WDColor *) colorWithAlphaComponent:(float)alpha;

+ (WDColor *) blackColor;
+ (WDColor *) grayColor;
+ (WDColor *) whiteColor;
+ (WDColor *) cyanColor;
+ (WDColor *) redColor;
+ (WDColor *) magentaColor;
+ (WDColor *) greenColor;
+ (WDColor *) yellowColor;
+ (WDColor *) blueColor;

- (NSString *) hexValue;

- (WDColor *) blendedColorWithFraction:(float)fraction ofColor:(WDColor *)color;

@end
