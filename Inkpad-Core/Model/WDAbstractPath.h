//
//  WDAbstractPath.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>
#import "WDStylable.h"
#import "WDStrokeStyle.h"

@protocol WDPathPainter;

@class WDFillTransform;
@class WDStrokeStyle;

// the fill rule can be passed directly to functions that take a bool indicating EO fill
typedef enum {
    kWDNonZeroWindingFillRule   = 0, 
    kWDEvenOddFillRule          = 1
} WDFillRule;

@interface WDAbstractPath : WDStylable <NSCoding, NSCopying>

@property (nonatomic, assign) WDFillRule fillRule;
@property (nonatomic, readonly) CGPathRef pathRef;
@property (nonatomic, readonly) CGPathRef strokePathRef;

+ (WDAbstractPath *) pathWithCGPathRef:(CGPathRef)pathRef;

- (NSUInteger) subpathCount;
- (NSString *) nodeSVGRepresentation;
- (void) addSVGArrowheadsToGroup:(WDXMLElement *)group;

- (BOOL) canOutlineStroke;
- (WDAbstractPath *) outlineStroke;

// subclasses can override this to enhance the default outline
- (void) addElementsToOutlinedStroke:(CGMutablePathRef)pathRef;

- (NSArray *) erase:(WDAbstractPath *)erasePath;

- (void) simplify;
- (void) flatten;

- (WDAbstractPath *) pathByFlatteningPath;

// so subclasses can override
- (void) renderStrokeInContext:(CGContextRef)ctx;

@end

