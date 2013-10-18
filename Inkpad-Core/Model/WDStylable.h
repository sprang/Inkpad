//
//  WDStylable.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>
#import "WDElement.h"

@class WDFillTransform;
@class WDStrokeStyle;
@class WDXMLElement;

@protocol WDPathPainter;

@interface WDStylable : WDElement <NSCoding, NSCopying>

@property (nonatomic, strong) id<WDPathPainter> fill;
@property (nonatomic, strong) WDFillTransform *fillTransform;
@property (nonatomic, strong) WDStrokeStyle *strokeStyle;
@property (nonatomic, strong) NSArray *maskedElements;

// to simplify rendering
@property (nonatomic, strong) WDFillTransform *displayFillTransform;

// cache for color adjustments
@property (nonatomic, strong) id initialFill;
@property (nonatomic, strong) WDStrokeStyle *initialStroke;

@property (nonatomic, readonly) BOOL isMasking;

- (NSSet *) changedStrokePropertiesFrom:(WDStrokeStyle *)from to:(WDStrokeStyle *)to;
- (void) strokeStyleChanged;

- (void) takeStylePropertiesFrom:(WDStylable *)obj;

- (void) addSVGFillAndStrokeAttributes:(WDXMLElement *)element;
- (void) addSVGFillAttributes:(WDXMLElement *)element;

- (void) setFillQuiet:(id<WDPathPainter>)fill;
- (void) setStrokeStyleQuiet:(WDStrokeStyle *)strokeStyle;

@end
