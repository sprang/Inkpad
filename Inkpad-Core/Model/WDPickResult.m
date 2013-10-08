//
//  WDPickResult.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDBezierNode.h"

@implementation WDPickResult

@synthesize element = element_;
@synthesize node = node_;
@synthesize snappedPoint = snappedPoint_;
@synthesize type = type_;
@synthesize snapped = snapped_;
@synthesize nodePosition = nodePosition_;

const float kNodeSelectionTolerance = 25;
    
+ (WDPickResult *) pickResult
{
    WDPickResult *pickResult = [[WDPickResult alloc] init];
    
    return pickResult;
}

- (void) setSnappedPoint:(CGPoint)pt
{
    snappedPoint_ = pt;
    snapped_ = YES;
}

@end
