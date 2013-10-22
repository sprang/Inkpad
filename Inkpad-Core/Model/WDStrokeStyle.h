//
//  WDStrokeStyle.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@class WDColor;
@class WDXMLElement;

typedef enum {
    kStrokeWidthAttribute  = 1 << 0,
    kStrokeCapAttribute    = 1 << 1,
    kStrokeJoinAttribute   = 1 << 2,
    kStrokeColorAttribute  = 1 << 3,
    kStrokeAllAttributes   = 0xffff
} WDStrokeAttributes;

@interface WDStrokeStyle : NSObject <NSCoding, NSCopying>

@property (nonatomic, readonly) float width;
@property (nonatomic, readonly) CGLineCap cap;
@property (nonatomic, readonly) CGLineJoin join;
@property (nonatomic, readonly) WDColor *color;
@property (nonatomic, readonly) NSArray *dashPattern;
@property (nonatomic, readonly) NSString *startArrow;
@property (nonatomic, readonly) NSString *endArrow;

+ (WDStrokeStyle *) strokeStyleWithWidth:(float)width
                                     cap:(CGLineCap)cap
                                    join:(CGLineJoin)join
                                   color:(WDColor *)color
                             dashPattern:(NSArray *)dashPattern;

+ (WDStrokeStyle *) strokeStyleWithWidth:(float)width
                                     cap:(CGLineCap)cap
                                    join:(CGLineJoin)join
                                   color:(WDColor *)color
                             dashPattern:(NSArray *)dashPattern
                              startArrow:(NSString *)startArrow
                                endArrow:(NSString *)endArrow;

- (id) initWithWidth:(float)width
                 cap:(CGLineCap)cap
                join:(CGLineJoin)join
               color:(WDColor *)color
         dashPattern:(NSArray *)dashPattern
          startArrow:(NSString *)startArrow
            endArrow:(NSString *)endArrow;

- (BOOL) isNullStroke;
- (BOOL) hasPattern;
- (BOOL) willRender;
- (BOOL) hasArrow;
- (BOOL) hasStartArrow;
- (BOOL) hasEndArrow;

- (void) applyInContext:(CGContextRef)ctx;

- (void) randomize;

- (WDStrokeStyle *) strokeStyleWithSwappedArrows;
- (WDStrokeStyle *) adjustColor:(WDColor * (^)(WDColor *color))adjustment;
- (WDStrokeStyle *) strokeStyleSansArrows;

- (void) addSVGAttributes:(WDXMLElement *)element;

@end

extern NSString *WDStrokeArrowNone;
