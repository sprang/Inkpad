//
//  WDSVGParserState.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Original implementation by Scott Vachalek
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDSVGParserState.h"


@implementation WDSVGParserState

@synthesize svgElement = svgElement_;
@synthesize wdElement = wdElement_;
@synthesize group = group_;
@synthesize transform = transform_;
@synthesize viewBoxTransform = viewBoxTransform_;
@synthesize viewport = viewport_;

- (id) init
{
    return [self initWithElement:nil];
}

- (id) initWithElement:(WDSVGElement *)element
{
    self = [super init];
    if (!self) {
        return nil;
    }

    svgElement_ = element;
    group_ = [[NSMutableArray alloc] init];

    return self;
}

- (NSString *) description
{
    NSMutableString *buf = [NSMutableString string];
    if (svgElement_) {
        [buf appendString:[svgElement_ description]];
    } else {
        [buf appendString:@"<nil>"];
    }
    [buf appendString:@" "];
    if (wdElement_) {
        [buf appendString:[wdElement_ description]];
    } else {
        [buf appendString:@"(nil)"];
    }
    [buf appendFormat:@" vp=(%g,%g)(%gx%g) vbt=(%g,%g,%g,%g)(%g,%g) t=(%g,%g,%g,%g)(%g,%g)", viewport_.origin.x, viewport_.origin.y, viewport_.size.width, viewport_.size.height, viewBoxTransform_.a, viewBoxTransform_.b, viewBoxTransform_.c, viewBoxTransform_.d, viewBoxTransform_.tx, viewBoxTransform_.ty, transform_.a, transform_.b, transform_.c, transform_.d, transform_.tx, transform_.ty];
    return buf;
}

@end
