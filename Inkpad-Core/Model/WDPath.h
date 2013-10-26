//
//  WDPath.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import "WDAbstractPath.h"
#import "WDPickResult.h"

@class WDBezierNode;
@class WDColor;
@class WDCompoundPath;
@class WDFillTransform;

@interface WDPath : WDAbstractPath <NSCoding, NSCopying> {
    NSMutableArray      *nodes_;
    BOOL                closed_;
    BOOL                reversed_;
    
    CGMutablePathRef    pathRef_;
    CGMutablePathRef    strokePathRef_;
    CGRect              bounds_;
    BOOL                boundsDirty_;
    
    // arrowheads
    CGPoint             arrowStartAttachment_;
    float               arrowStartAngle_;
    BOOL                canFitStartArrow_;
    CGPoint             arrowEndAttachment_;
    float               arrowEndAngle_;
    BOOL                canFitEndArrow_;
    
    // to simplify rendering
    NSMutableArray      *displayNodes_;
    UIColor             *displayColor_;
    BOOL                displayClosed_;
}

@property (nonatomic, assign) BOOL closed;
@property (nonatomic, assign) BOOL reversed;
@property (nonatomic, strong) NSMutableArray *nodes;
@property (weak, nonatomic, readonly) NSMutableArray *reversedNodes;
@property (nonatomic, weak) WDCompoundPath *superpath;

// to simplify rendering
@property (nonatomic, strong) NSMutableArray *displayNodes;
@property (nonatomic, strong) UIColor *displayColor;
@property (nonatomic, assign) BOOL displayClosed;

+ (WDPath *) pathWithRect:(CGRect)rect;
+ (WDPath *) pathWithRoundedRect:(CGRect)rect cornerRadius:(float)radius;
+ (WDPath *) pathWithOvalInRect:(CGRect)rect;
+ (WDPath *) pathWithStart:(CGPoint)start end:(CGPoint)end;

- (id) initWithRect:(CGRect)rect;
- (id) initWithRoundedRect:(CGRect)rect cornerRadius:(float)radius;
- (id) initWithOvalInRect:(CGRect)rect;
- (id) initWithStart:(CGPoint)start end:(CGPoint)end;
- (id) initWithNode:(WDBezierNode *)node;

- (void) invalidatePath;
- (void) reversePathDirection;

- (BOOL) canDeleteAnchors;
- (void) deleteAnchor:(WDBezierNode *)node;
- (NSArray *) selectedNodes;
- (BOOL) anyNodesSelected;
- (BOOL) allNodesSelected;

- (NSDictionary *) splitAtNode:(WDBezierNode *)node;
- (NSDictionary *) splitAtPoint:(CGPoint)pt viewScale:(float)viewScale;
- (WDBezierNode *) addAnchorAtPoint:(CGPoint)pt viewScale:(float)viewScale;
- (void) addAnchors;
- (void) appendPath:(WDPath *)path;

- (void) replaceFirstNodeWithNode:(WDBezierNode *)node;
- (void) replaceLastNodeWithNode:(WDBezierNode *)node;
- (BOOL) addNode:(WDBezierNode *)node scale:(float)scale;
- (void) addNode:(WDBezierNode *)node;

- (WDBezierNode *) firstNode;
- (WDBezierNode *) lastNode;
- (NSMutableArray *) reversedNodes;
- (NSSet *) nodesInRect:(CGRect)rect;

- (WDBezierNode *) convertNode:(WDBezierNode *)node whichPoint:(WDPickResultType)whichPoint;

- (CGRect) controlBounds;
- (void) computeBounds;

- (NSString *) nodeSVGRepresentation;

- (void) setClosedQuiet:(BOOL)closed;

- (WDStrokeStyle *) effectiveStrokeStyle;

@end

