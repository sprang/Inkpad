//
//  WDGradientStop.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2000-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@class WDColor;
@class WDXMLElement;

@interface WDGradientStop : NSObject <NSCoding, NSCopying>

@property (nonatomic, readonly) float ratio;    // [0.0 - 1.0]
@property (nonatomic, readonly) WDColor *color; // can include transparency

+ (WDGradientStop *) stopWithColor:(WDColor *)color andRatio:(float)ratio;
- (id) initWithColor:(WDColor *)color andRatio:(float)ratio;

- (WDGradientStop *) stopWithRatio:(float)ratio;
- (WDGradientStop *) stopWithColor:(WDColor *)color;

- (WDXMLElement *) SVGXMLElement;

@end
