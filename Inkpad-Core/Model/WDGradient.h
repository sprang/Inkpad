//
//  WDGradient.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2000-2013 Steve Sprang
//

#import <Foundation/Foundation.h>
#import "WDPathPainter.h"

typedef enum {
    kWDLinearGradient,
    kWDRadialGradient
} WDGradientType;

@class WDColor;
@class WDGradientStop;
@class WDFillTransform;
@class WDXMLElement;

@interface WDGradient : NSObject <NSCopying, NSCoding, WDPathPainter> {
    CGGradientRef       gradientRef_; // for rendering
}

@property (nonatomic, readonly) WDGradientType type;
@property (nonatomic, readonly) NSArray *stops;

+ (WDGradient *) randomGradient;
+ (WDGradient *) defaultGradient;
+ (WDGradient *) gradientWithStart:(WDColor *)start andEnd:(WDColor*)end;
+ (WDGradient *) gradientWithType:(WDGradientType)type stops:(NSArray *)stops;
- (id) initWithType:(WDGradientType)type stops:(NSArray *)stops;

- (WDGradient *) gradientByReversing;
- (WDGradient *) gradientByDistributingEvenly;

- (WDGradient *) gradientWithStops:(NSArray *)stops;
- (WDGradient *) gradientWithType:(WDGradientType)type;
- (WDGradient *) gradientWithStop:(WDGradientStop *)stop substitutedForStop:(WDGradientStop *)replace;
- (WDGradient *) gradientByRemovingStop:(WDGradientStop *)stop;
- (WDGradient *) gradientByAddingStop:(WDGradientStop *)stop;
- (WDGradient *) gradientWithStopAtRatio:(float)ratio;

- (WDGradient *) adjustColor:(WDColor * (^)(WDColor *color))adjustment;

- (WDColor *) colorAtRatio:(float)ratio;

- (CGGradientRef) gradientRef;
- (void) drawSwatchInRect:(CGRect)rect;

- (WDXMLElement *) SVGElementWithID:(NSString *)unique fillTransform:(WDFillTransform *)fT;

@end
