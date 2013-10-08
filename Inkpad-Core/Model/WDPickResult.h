//
//  WDPickResult.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

enum {
    kWDSnapNodes            = 1 << 0,
    kWDSnapEdges            = 1 << 1,
    kWDSnapGrid             = 1 << 2,
    kWDSnapFills            = 1 << 3,
    kWDSnapLocked           = 1 << 4,
    kWDSnapSelectedOnly     = 1 << 5,
    kWDSnapSubelement       = 1 << 6
};

typedef enum {
    kWDEther,
    kWDInPoint,
    kWDAnchorPoint,
    kWDOutPoint,
    kWDObjectFill,
    kWDEdge,
    kWDLeftTextKnob,
    kWDRightTextKnob,
    kWDFillStartPoint,
    kWDFillEndPoint,
    kWDRectCorner,
    kWDRectEdge,
    kWDTextPathStartKnob
} WDPickResultType;

enum {
    kWDMiddleNode,
    kWDFirstNode,
    kWDLastNode
};

extern const float kNodeSelectionTolerance;

@class WDElement;
@class WDBezierNode;

@interface WDPickResult : NSObject

@property (nonatomic, weak) WDElement *element;         // the element in which the tap occurred
@property (nonatomic, weak) WDBezierNode *node;         // the node hit by the tap -- could be nil
@property (nonatomic, assign) CGPoint snappedPoint;
@property (nonatomic, assign) WDPickResultType type;
@property (nonatomic, assign) NSUInteger nodePosition;
@property (nonatomic, readonly) BOOL snapped;

+ (WDPickResult *) pickResult;

@end
