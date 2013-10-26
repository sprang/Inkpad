//
//  WDBezierSegment.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

extern const float kDefaultFlatness;

@class WDBezierNode;

enum {
    TOP = 0x1, 
    BOTTOM = 0x2, 
    RIGHT = 0x4, 
    LEFT = 0x8
};

typedef struct {
    CGPoint a_, out_, in_, b_;
} WDBezierSegment;


WDBezierSegment WDBezierSegmentMake(WDBezierNode *a, WDBezierNode *b);
BOOL WDBezierSegmentIsDegenerate(WDBezierSegment seg);

BOOL WDBezierSegmentIntersectsRect(WDBezierSegment seg, CGRect rect);
BOOL WDLineInRect(CGPoint a, CGPoint b, CGRect test);

BOOL WDBezierSegmentIsStraight(WDBezierSegment segment);
BOOL WDBezierSegmentIsFlat(WDBezierSegment seg, float tolerance);
void WDBezierSegmentFlatten(WDBezierSegment seg, CGPoint **vertices, NSUInteger *size, NSUInteger *index);
CGPoint WDBezierSegmentSplit(WDBezierSegment seg, WDBezierSegment *L, WDBezierSegment *R);
CGPoint WDBezierSegmentSplitAtT(WDBezierSegment seg, WDBezierSegment *L, WDBezierSegment *R, float t);
CGPoint WDBezierSegmentTangetAtT(WDBezierSegment seg, float t);

BOOL WDBezierSegmentFindPointOnSegment(WDBezierSegment seg, CGPoint testPoint, float tolerance, CGPoint *nearestPoint, float *split);

CGRect WDBezierSegmentBounds(WDBezierSegment seg);
CGRect WDBezierSegmentGetSimpleBounds(WDBezierSegment seg);

float WDBezierSegmentCurvatureAtT(WDBezierSegment seg, float t);
CGPoint WDBezierSegmentPointAndTangentAtDistance(WDBezierSegment seg, float distance, CGPoint *tangent, float *curvature);
float WDBezierSegmentLength(WDBezierSegment seg);

CGPoint WDBezierSegmentGetClosestPoint(WDBezierSegment seg, CGPoint test, float *error, float *distance);
BOOL WDBezierSegmentsFormCorner(WDBezierSegment a, WDBezierSegment b);

BOOL WDBezierSegmentGetIntersection(WDBezierSegment seg, CGPoint a, CGPoint b, float *tIntersect);

float WDBezierSegmentOutAngle(WDBezierSegment seg);
CGPoint WDBezierSegmentCalculatePointAtT(WDBezierSegment seg, float t);
BOOL WDBezierSegmentPointDistantFromPoint(WDBezierSegment segment, float distance, CGPoint pt, CGPoint *result, float *t);
