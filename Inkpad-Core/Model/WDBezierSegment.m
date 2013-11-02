//
//  WDBezierSegment.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import "WDBezierSegment.h"
#import "WDBezierNode.h"
#import "WDUtilities.h"

const float kDefaultFlatness = 6;

static CGPoint      *vertices = NULL;
static NSUInteger   size = 128;

float firstDerivative(float A, float B, float C, float D, float t);
float secondDerivative(float A, float B, float C, float D, float t);
float base3(double t, double p1, double p2, double p3, double p4);
float cubicF(double t, WDBezierSegment seg);

WDBezierSegment WDBezierSegmentMake(WDBezierNode *a, WDBezierNode *b)
{
    WDBezierSegment segment;
    
    segment.a_ = a.anchorPoint;
    segment.out_ = a.outPoint;
    segment.in_ = b.inPoint;
    segment.b_ = b.anchorPoint;
    
    return segment;
}

inline BOOL WDBezierSegmentIsFlat(WDBezierSegment seg, float tolerance)
{
    float scaledTolerance = tolerance / [UIScreen mainScreen].scale;
    
    if (CGPointEqualToPoint(seg.a_, seg.out_) && CGPointEqualToPoint(seg.in_, seg.b_)) {
        return YES;
    }
    
    float dx = seg.b_.x - seg.a_.x;
    float dy = seg.b_.y - seg.a_.y;
    
    float d2 = fabs((seg.out_.x - seg.b_.x) * dy - (seg.out_.y - seg.b_.y) * dx);
    float d3 = fabs((seg.in_.x - seg.b_.x) * dy - (seg.in_.y - seg.b_.y) * dx);

    if ((d2 + d3) * (d2 + d3) <= scaledTolerance * (dx * dx + dy * dy)) {
        return YES;
    }
    
    return NO;
}

BOOL WDBezierSegmentIsDegenerate(WDBezierSegment seg)
{
    if (isnan(seg.a_.x) || isnan(seg.out_.x) || isnan(seg.in_.x) || isnan(seg.b_.x) ||
        isnan(seg.a_.y) || isnan(seg.out_.y) || isnan(seg.in_.y) || isnan(seg.b_.y))
    {
        return YES;
    }

    return NO;
}

inline CGPoint WDBezierSegmentSplit(WDBezierSegment seg, WDBezierSegment *L, WDBezierSegment *R)
{
    return WDBezierSegmentSplitAtT(seg, L, R, 0.5f);
}

/*
 http://www.planetclegg.com/projects/WarpingTextToSplines.html
 
 coefficients:
 
 A = x3 - 3 * x2 + 3 * x1 - x0
 B = 3 * x2 - 6 * x1 + 3 * x0
 C = 3 * x1 - 3 * x0
 D = x0
 
 E = y3 - 3 * y2 + 3 * y1 - y0
 F = 3 * y2 - 6 * y1 + 3 * y0
 G = 3 * y1 - 3 * y0
 H = y0
 
 tangent:
 
 Vx = 3At2 + 2Bt + C 
 Vy = 3Et2 + 2Ft + G 
 
*/

inline CGPoint WDBezierSegmentTangetAtT(WDBezierSegment seg, float t)
{
    float A, B, C, E, F, G;
    
    A = seg.b_.x - 3 * seg.in_.x + 3 * seg.out_.x - seg.a_.x;
    B = 3 * seg.in_.x - 6 * seg.out_.x + 3 * seg.a_.x;
    C = 3 * seg.out_.x - 3 * seg.a_.x;
    
    E = seg.b_.y - 3 * seg.in_.y + 3 * seg.out_.y - seg.a_.y;
    F = 3 * seg.in_.y - 6 * seg.out_.y + 3 * seg.a_.y;
    G = 3 * seg.out_.y - 3 * seg.a_.y;
    
    float x = 3 * A * t * t + 2 * B * t + C;
    float y = 3 * E * t * t + 2 * F * t + G;
    
    return CGPointMake(x,y);
}

inline BOOL WDBezierSegmentIsStraight(WDBezierSegment segment)
{
    // true if the control points coincide with their anchors...
    return CGPointEqualToPoint(segment.a_, segment.out_) && CGPointEqualToPoint(segment.in_, segment.b_);
}

inline CGPoint WDBezierSegmentSplitAtT(WDBezierSegment seg, WDBezierSegment *L, WDBezierSegment *R, float t)
{
    if (WDBezierSegmentIsStraight(seg)) {
        CGPoint point = WDMultiplyPointScalar(WDSubtractPoints(seg.b_, seg.a_), t);
        point = WDAddPoints(seg.a_, point);
        
        if (L) {
            L->a_ = seg.a_;
            L->out_ = seg.a_;
            L->in_ = point;
            L->b_ = point;
        }
        
        if (R) {
            R->a_ = point;
            R->out_ = point;
            R->in_ = seg.b_;
            R->b_ = seg.b_;
        }
        
        return point;
    }
    
    CGPoint A, B, C, D, E, F;
    
    //A = WDAddPoints(seg.a_, WDMultiplyPointScalar(WDSubtractPoints(seg.out_, seg.a_), t));
    //B = WDAddPoints(seg.out_, WDMultiplyPointScalar(WDSubtractPoints(seg.in_, seg.out_), t));
    //C = WDAddPoints(seg.in_, WDMultiplyPointScalar(WDSubtractPoints(seg.b_, seg.in_), t));
    //
    //D = WDAddPoints(A, WDMultiplyPointScalar(WDSubtractPoints(B, A), t));
    //E = WDAddPoints(B, WDMultiplyPointScalar(WDSubtractPoints(C, B), t));
    //F = WDAddPoints(D, WDMultiplyPointScalar(WDSubtractPoints(E, D), t));
    
    // expand out the function calls above for better performance
    A.x = seg.a_.x + (seg.out_.x - seg.a_.x) * t;
    A.y = seg.a_.y + (seg.out_.y - seg.a_.y) * t;
    
    B.x = seg.out_.x + (seg.in_.x - seg.out_.x) * t;
    B.y = seg.out_.y + (seg.in_.y - seg.out_.y) * t;
    
    C.x = seg.in_.x + (seg.b_.x - seg.in_.x) * t;
    C.y = seg.in_.y + (seg.b_.y - seg.in_.y) * t;
    
    D.x = A.x + (B.x - A.x) * t;
    D.y = A.y + (B.y - A.y) * t;
    
    E.x = B.x + (C.x - B.x) * t;
    E.y = B.y + (C.y - B.y) * t;
    
    F.x = D.x + (E.x - D.x) * t;
    F.y = D.y + (E.y - D.y) * t;
    
    if (L) {
        L->a_ = seg.a_;
        L->out_ = A;
        L->in_ = D;
        L->b_ = F;
    }
    
    if (R) {
        R->a_ = F;
        R->out_ = E;
        R->in_ = C;
        R->b_ = seg.b_;
    }
    
    return F;
}

inline float firstDerivative(float A, float B, float C, float D, float t)
{
    return -3*A*(1-t)*(1-t) + 3*B*(1-t)*(1-t) - 6*B*(1-t)*t + 6*C*(1-t)*t - 3*C*t*t + 3*D*t*t;
}

inline  float secondDerivative(float A, float B, float C, float D, float t)
{
    return 6*A*(1-t) - 12*B*(1-t) + 6*C*(1-t) + 6*B*t - 12*C*t + 6*D*t;
}

inline float WDBezierSegmentCurvatureAtT(WDBezierSegment seg, float t)
{
    float xPrime = firstDerivative(seg.a_.x, seg.out_.x, seg.in_.x, seg.b_.x, t);
    float yPrime = firstDerivative(seg.a_.y, seg.out_.y, seg.in_.y, seg.b_.y, t);
    
    float xPrime2 = secondDerivative(seg.a_.x, seg.out_.x, seg.in_.x, seg.b_.x, t);
    float yPrime2 = secondDerivative(seg.a_.y, seg.out_.y, seg.in_.y, seg.b_.y, t);
    
    float num = xPrime * yPrime2 - yPrime * xPrime2;
    float denom =  pow(xPrime * xPrime + yPrime * yPrime, 3.0f / 2);
    
    return -num/denom;
}

BOOL WDBezierSegmentIntersectsRect(WDBezierSegment seg, CGRect test)
{
    WDBezierSegment L, R;
    
    if(WDBezierSegmentIsFlat(seg, kDefaultFlatness)) {
        return WDLineInRect(seg.a_, seg.b_, test);
    } else {
        WDBezierSegmentSplit(seg, &L, &R);
        
        if(WDBezierSegmentIntersectsRect(L, test)) {
            return YES;
        }
        if(WDBezierSegmentIntersectsRect(R, test)) {
            return YES;
        }
    }
    
    return NO;
}

BOOL WDLineInRect(CGPoint a, CGPoint b, CGRect test)
{
    int			acode = 0, bcode = 0;
    float		ymin, ymax, xmin, xmax;
    
    xmin = CGRectGetMinX(test);
    ymin = CGRectGetMinY(test);
    xmax = CGRectGetMaxX(test);
    ymax = CGRectGetMaxY(test);
    
    if(a.y > ymax) {
        acode |= TOP;
    } else if(a.y < ymin) {
        acode |= BOTTOM;
    }
    
    if(a.x > xmax) {
        acode |= RIGHT;
    } else if(a.x < xmin) {
        acode |= LEFT;
    }
    
    if(b.y > ymax) {
        bcode |= TOP;
    } else if(b.y < ymin) {
        bcode |= BOTTOM;
    }
    
    if(b.x > xmax) {
        bcode |= RIGHT;
    } else if(b.x < xmin) {
        bcode |= LEFT;
    }
    
    if(acode == 0 || bcode == 0) { // one or both endpoints within rect
        return YES;
    } else if(acode & bcode) { // completely outside of rectangle
        return NO;
    } else { // special case
        CGPoint		middle;
        // split line and test each half recursively
        middle.x = (a.x + b.x) / 2.0f;
        middle.y = (a.y + b.y) / 2.0f;
        
        if (WDLineInRect(a, middle, test)) {
            return YES;
        }
        
        if (WDLineInRect(middle, b, test)) {
            return YES;
        }
        return NO;
    }
}

/*
 * WDBezierSegmentFindPointOnSegment_R()
 *
 * Performs a binary search on the path, subdividing it until a
 * sufficiently small section is found that contains the test point.
 */
BOOL WDBezierSegmentFindPointOnSegment_R(WDBezierSegment seg, CGPoint testPoint, float tolerance,
                                         CGPoint *nearestPoint, float *split, double depth)
{
    CGRect  bbox = CGRectInset(WDBezierSegmentGetSimpleBounds(seg), -tolerance / 2, -tolerance / 2);
    
    if (!CGRectContainsPoint(bbox, testPoint)) {
        return NO;
    } else if (WDBezierSegmentIsStraight(seg)) {
        CGPoint s = WDSubtractPoints(seg.b_, seg.a_);
        CGPoint v = WDSubtractPoints(testPoint, seg.a_);
        float   n = v.x * s.x + v.y * s.y;
        float   d = s.x * s.x + s.y * s.y;
        float   t = n/d;
        BOOL    onSegment = NO;
        
        if (0.0f <= t && t <= 1.0f) {
            CGPoint delta = WDSubtractPoints(seg.b_, seg.a_);
            CGPoint p = WDAddPoints(seg.a_, WDMultiplyPointScalar(delta, t));
            
            if (WDDistance(p, testPoint) < tolerance) {
                if (nearestPoint) {
                    *nearestPoint = p;
                }
                if (split) {
                    *split += (t * depth);
                }
                onSegment = YES;
            }
        }
        
        return onSegment;
    } else if((CGRectGetWidth(bbox) < tolerance * 1.1) || (CGRectGetHeight(bbox) < tolerance * 1.1)) {
        // Close enough! This should be more or less a straight line now...
        CGPoint s = WDSubtractPoints(seg.b_, seg.a_);
        CGPoint v = WDSubtractPoints(testPoint, seg.a_);
        float n = v.x * s.x + v.y * s.y;
        float d = s.x * s.x + s.y * s.y;
        float t = WDClamp(0.0f, 1.0f, n/d);

        if (nearestPoint) {
            // make sure the found point is on the path and not just near it
            *nearestPoint = WDBezierSegmentSplitAtT(seg, NULL, NULL, t);
        }
        if (split) {
            *split += (t * depth);
        }
        
        return YES;
    }
    
    // We know the point is inside our bounding box, but our bounding box is not yet
    // small enough to consider it a hit. So, subdivide the path and recurse...
    
    WDBezierSegment L, R;
    BOOL            foundLeft = NO, foundRight = NO;
    CGPoint         nearestLeftPoint, nearestRightPoint;
    float           leftSplit = 0.0f, rightSplit = 0.0f;
    
    WDBezierSegmentSplit(seg, &L, &R);
    
    // look both ways before crossing
    if (WDBezierSegmentFindPointOnSegment_R(L, testPoint, tolerance, &nearestLeftPoint, &leftSplit, depth / 2.0f)) {
        foundLeft = YES;
    }
    if (WDBezierSegmentFindPointOnSegment_R(R, testPoint, tolerance, &nearestRightPoint, &rightSplit, depth / 2.0f)) {
        foundRight = YES;
    }

    if (foundLeft && foundRight) {
        // since both halves found the point, choose the one that's actually closest
        float leftDistance = WDDistance(nearestLeftPoint, testPoint);
        float rightDistance = WDDistance(nearestRightPoint, testPoint);
        
        foundLeft = (leftDistance <= rightDistance) ? YES : NO;
        foundRight = !foundLeft;
    }
    
    if (foundLeft) {
        if (nearestPoint) {
            *nearestPoint = nearestLeftPoint;
        }
        if (split) {
            *split += leftSplit;
        }
    } else if (foundRight) {
        if (nearestPoint) {
            *nearestPoint = nearestRightPoint;
        }
        if (split) {
            *split += 0.5 * depth + rightSplit;
        }
    }
    
    return (foundLeft || foundRight);
}

BOOL WDBezierSegmentFindPointOnSegment(WDBezierSegment seg, CGPoint testPoint, float tolerance, CGPoint *nearestPoint, float *split)
{
    if (split) {
        *split = 0.0f;
    }
    
    return WDBezierSegmentFindPointOnSegment_R(seg, testPoint, tolerance, nearestPoint, split, 1.0);
}

CGPoint WDBezierSegmentPointAndTangentAtDistance(WDBezierSegment seg, float distance, CGPoint *tangent, float *curvature)
{
    float       delta = 1.0f / 200.0f;
    float       t2 ,t3, td2, td3, x,y;
    float       lastX = seg.a_.x, lastY = seg.a_.y;
    float       progress = 0;
    
    for (float t = 0; t < (1.0f + delta); t += delta) {
        t2 = t * t;
        t3 = t2 * t;
        
        td2 = (1-t) * (1-t);
        td3 = td2 * (1-t);
        
        x = td3 * seg.a_.x + 
        3 * t * td2 * seg.out_.x + 
        3 * t2 * (1-t) * seg.in_.x +
        t3 * seg.b_.x;
        
        y = td3 * seg.a_.y + 
        3 * t * td2 * seg.out_.y + 
        3 * t2 * (1-t) * seg.in_.y +
        t3 * seg.b_.y;
        
        float step = WDDistance(CGPointMake(lastX, lastY), CGPointMake(x, y));
        
        if (progress + step >= distance) {
            // it's between the current and last set of points          
            float factor = (distance - progress) / step;
            t = (t - delta) + factor * delta;
            
            *tangent = WDBezierSegmentTangetAtT(seg, t);
            if (curvature) {
                *curvature = WDBezierSegmentCurvatureAtT(seg, t);
            }
            return WDBezierSegmentSplitAtT(seg, NULL, NULL, t);
        }
        
        progress += step;
        lastX = x;
        lastY = y;
    }
    
    return CGPointZero;
}

void WDBezierSegmentFlatten(WDBezierSegment seg, CGPoint **vertices, NSUInteger *size, NSUInteger *index)
{
    if (*size < *index + 4) {
        *size *= 2;
        *vertices = realloc(*vertices, sizeof(CGPoint) * *size);
    }
    
    if (WDBezierSegmentIsFlat(seg, kDefaultFlatness)) {
        if (*index == 0) {
            (*vertices)[*index] = seg.a_;
            *index += 1;
        }
        
        (*vertices)[*index] = seg.b_;
        *index += 1;
    } else {
        WDBezierSegment L, R;
        WDBezierSegmentSplit(seg, &L, &R);
        
        WDBezierSegmentFlatten(L, vertices, size, index);
        WDBezierSegmentFlatten(R, vertices, size, index);
    }
}

CGRect WDBezierSegmentBounds(WDBezierSegment seg)
{
    NSUInteger  index = 0;
    
    if (!vertices) {
        vertices = calloc(sizeof(CGPoint), size);
    }
    
    WDBezierSegmentFlatten(seg, &vertices, &size, &index);
    
    float   minX, maxX, minY, maxY;
    
    minX = maxX = vertices[0].x;
    minY = maxY = vertices[0].y;
    
    for (int i = 1; i < index; i++) {
        minX = MIN(minX, vertices[i].x);
        maxX = MAX(maxX, vertices[i].x);
        minY = MIN(minY, vertices[i].y);
        maxY = MAX(maxY, vertices[i].y);
    }
    
    return CGRectMake(minX, minY, maxX - minX, maxY - minY);
}

float base3(double t, double p1, double p2, double p3, double p4)
{
    float t1 = -3*p1 + 9*p2 - 9*p3 + 3*p4;
    float t2 = t*t1 + 6*p1 - 12*p2 + 6*p3;
    return t*t2 - 3*p1 + 3*p2;
}

float cubicF(double t, WDBezierSegment seg)
{
    float xbase = base3(t, seg.a_.x, seg.out_.x, seg.in_.x, seg.b_.x);
    float ybase = base3(t, seg.a_.y, seg.out_.y, seg.in_.y, seg.b_.y);
    float combined = xbase*xbase + ybase*ybase;
    return sqrt(combined);
}

/**
 * Gauss quadrature for cubic Bezier curves
 * http://processingjs.nihongoresources.com/bezierinfo/
 *
 */
float WDBezierSegmentLength(WDBezierSegment seg)
{
    float  z = 1.0f;
    float  z2 = z / 2.0f;
    float  sum = 0.0f;
    
    // Legendre-Gauss abscissae (xi values, defined at i=n as the roots of the nth order Legendre polynomial Pn(x))
    static float Tvalues[] = {
        -0.06405689286260562997910028570913709, 0.06405689286260562997910028570913709,
        -0.19111886747361631067043674647720763, 0.19111886747361631067043674647720763,
        -0.31504267969616339684080230654217302, 0.31504267969616339684080230654217302,
        -0.43379350762604512725673089335032273, 0.43379350762604512725673089335032273,
        -0.54542147138883956269950203932239674, 0.54542147138883956269950203932239674,
        -0.64809365193697554552443307329667732, 0.64809365193697554552443307329667732,
        -0.74012419157855435791759646235732361, 0.74012419157855435791759646235732361,
        -0.82000198597390294708020519465208053, 0.82000198597390294708020519465208053,
        -0.88641552700440107148693869021371938, 0.88641552700440107148693869021371938,
        -0.93827455200273279789513480864115990, 0.93827455200273279789513480864115990,
        -0.97472855597130947380435372906504198, 0.97472855597130947380435372906504198,
        -0.99518721999702131064680088456952944, 0.99518721999702131064680088456952944
    };
    
    // Legendre-Gauss weights (wi values, defined by a function linked to in the Bezier primer article)
    static float Cvalues[] = {
        0.12793819534675215932040259758650790, 0.12793819534675215932040259758650790,
        0.12583745634682830250028473528800532, 0.12583745634682830250028473528800532,
        0.12167047292780339140527701147220795, 0.12167047292780339140527701147220795,
        0.11550566805372559919806718653489951, 0.11550566805372559919806718653489951,
        0.10744427011596563437123563744535204, 0.10744427011596563437123563744535204,
        0.09761865210411388438238589060347294, 0.09761865210411388438238589060347294,
        0.08619016153195327434310968328645685, 0.08619016153195327434310968328645685, 
        0.07334648141108029983925575834291521, 0.07334648141108029983925575834291521,
        0.05929858491543678333801636881617014, 0.05929858491543678333801636881617014,
        0.04427743881741980774835454326421313, 0.04427743881741980774835454326421313,
        0.02853138862893366337059042336932179, 0.02853138862893366337059042336932179,
        0.01234122979998720018302016399047715, 0.01234122979998720018302016399047715
    };
    
    for (int i = 0; i < 24; i++) {
        float corrected_t = z2 * Tvalues[i] + z2;
        sum += Cvalues[i] * cubicF(corrected_t, seg);
    }
    
    return z2 * sum;
}

CGPoint WDBezierSegmentGetClosestPoint(WDBezierSegment seg, CGPoint test, float *error, float *distance)
{
    float       delta = 0.001f;
    float       t2 ,t3, td2, td3, x,y;
    float       lastX = seg.a_.x, lastY = seg.a_.y;
    float       sum = 0;
    float       smallestDistance = MAXFLOAT;
    CGPoint     closest;
    
    for (float t = 0; t < (1.0f + delta); t += delta) {
        t2 = t * t;
        t3 = t2 * t;
        
        td2 = (1-t) * (1-t);
        td3 = td2 * (1-t);
        
        x = td3 * seg.a_.x + 
        3 * t * td2 * seg.out_.x + 
        3 * t2 * (1-t) * seg.in_.x +
        t3 * seg.b_.x;
        
        y = td3 * seg.a_.y + 
        3 * t * td2 * seg.out_.y + 
        3 * t2 * (1-t) * seg.in_.y +
        t3 * seg.b_.y;
        
        float step = WDDistance(CGPointMake(lastX, lastY), CGPointMake(x, y));
        sum += step;
        
        lastX = x;
        lastY = y;
        
        float testDistance = WDDistance(CGPointMake(x,y), test);
        if (testDistance < smallestDistance) {
            smallestDistance = testDistance;
            *error = testDistance;
            *distance = sum;
            closest = CGPointMake(x,y);
        }
    }
    
    return closest;
}

CGRect WDBezierSegmentGetSimpleBounds(WDBezierSegment seg)
{
    CGRect rect = WDRectWithPoints(seg.a_, seg.b_);
    rect = WDGrowRectToPoint(rect, seg.out_);
    rect = WDGrowRectToPoint(rect, seg.in_);
    
    return rect;
}

BOOL WDBezierSegmentGetIntersection(WDBezierSegment seg, CGPoint a, CGPoint b, float *tIntersect)
{
    if (!CGRectIntersectsRect(WDBezierSegmentGetSimpleBounds(seg), WDRectWithPoints(a, b))) {
        return NO;
    }
    
    float           delta = 0.01f;
    float           r, t2 ,t3, td2, td3;
    CGPoint         current, last = seg.a_;

    for (float t = 0; t < (1.0f + delta); t += delta) {
        t2 = t * t;
        t3 = t2 * t;
        
        td2 = (1-t) * (1-t);
        td3 = td2 * (1-t);
        
        current.x = td3 * seg.a_.x + 
        3 * t * td2 * seg.out_.x + 
        3 * t2 * (1-t) * seg.in_.x +
        t3 * seg.b_.x;
        
        current.y = td3 * seg.a_.y + 
        3 * t * td2 * seg.out_.y + 
        3 * t2 * (1-t) * seg.in_.y +
        t3 * seg.b_.y;
    
        if (WDLineSegmentsIntersectWithValues(last, current, a, b, &r, NULL)) {
            *tIntersect = WDClamp(0, 1, (t-delta) + delta * r);
            return YES;
        }

        last = current;
    }
    
    return NO;
}

BOOL WDBezierSegmentsFormCorner(WDBezierSegment a, WDBezierSegment b)
{
    CGPoint p, q, r;
    
    if (!CGPointEqualToPoint(a.b_, a.in_)) {
        p = a.in_;
    } else {
        p = a.out_;
    }
    
    if (!CGPointEqualToPoint(b.a_, b.out_)) {
        r = b.out_;
    } else {
        r = b.in_;
    }
        
    q = b.a_;
    
    return !WDCollinear(p, q, r);    
}

float WDBezierSegmentOutAngle(WDBezierSegment seg)
{
    CGPoint a;
    
    if (!CGPointEqualToPoint(seg.b_, seg.in_)) {
        a = seg.in_;
    } else {
        a = seg.out_;
    }
    
    CGPoint delta = WDSubtractPoints(seg.b_, a);
    
    return atan2f(delta.y, delta.x);
}

inline CGPoint WDBezierSegmentCalculatePointAtT(WDBezierSegment seg, float t)
{
    float   t2 ,t3, td2, td3;
    CGPoint result;
    
    t2 = t * t;
    t3 = t2 * t;
    
    td2 = (1-t) * (1-t);
    td3 = td2 * (1-t);
    
    result.x = td3 * seg.a_.x +
    3 * t * td2 * seg.out_.x +
    3 * t2 * (1-t) * seg.in_.x +
    t3 * seg.b_.x;
    
    result.y = td3 * seg.a_.y +
    3 * t * td2 * seg.out_.y +
    3 * t2 * (1-t) * seg.in_.y +
    t3 * seg.b_.y;
    
    return result;
}

BOOL WDBezierSegmentPointDistantFromPoint(WDBezierSegment seg, float distance, CGPoint pt, CGPoint *result, float *tResult)
{
    CGPoint     current, last = seg.a_;
    float       start = 0.0f, end = 1.0f, step = 0.1f;
    
    for (float t = start; t < (end + step); t += step) {
        current = WDBezierSegmentCalculatePointAtT(seg, t);
        
        if (WDDistance(current, pt) >= distance) {
            start = (t - step); // back up one iteration
            end = t;

            // it's between the last and current point, let's get more precise
            step = 0.0001f;
            
            for (float t = start; t < (end + step); t += step) {
                current = WDBezierSegmentCalculatePointAtT(seg, t);
                
                if (WDDistance(current, pt) >= distance) {
                    *tResult = t - (step / 2);
                    *result = WDBezierSegmentCalculatePointAtT(seg, t);
                    return YES;
                }
            }
        }
        
        last = current;
    }
    
    return NO;
}
