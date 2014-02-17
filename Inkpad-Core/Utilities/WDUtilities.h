//
//  WDUtilities.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2008-2013 Steve Sprang
//

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#if WD_DEBUG
#define WDLog NSLog
#else
#define WDLog(...)
#endif

#import "WDPickResult.h"

@class WDStrokeStyle;

//
// Color Conversion
//

void HSVtoRGB(float h, float s, float v, float *r, float *g, float *b);
void RGBtoHSV(float r, float g, float b, float *h, float *s, float *v);

//
// Drawing Functions
//

void WDDrawCheckersInRect(CGContextRef ctx, CGRect dest, int size);
void WDDrawTransparencyDiamondInRect(CGContextRef ctx, CGRect dest);
void WDContextDrawImageToFill(CGContextRef ctx, CGRect bounds, CGImageRef imageRef);

//
// Mathy Stuff
//

// random value in the range [0.0, 1.0]
float WDRandomFloat();

// remap [0.0, 1.0] to a sine curve
float WDSineCurve(float input);

NSData * WDSHA1DigestForData(NSData *data);

//
// Geometry
//

CGSize WDSizeOfRectWithAngle(CGRect rect, float angle, CGPoint *upperLeft, CGPoint *upperRight);

// return point with unit length from the origin
CGPoint WDNormalizePoint(CGPoint vector);

// expand the passed rectangle to include the passed point
CGRect WDGrowRectToPoint(CGRect rect, CGPoint pt);

CGPoint WDSharpPointInContext(CGPoint pt, CGContextRef ctx);

// keep point at 90 degree angles
CGPoint WDConstrainPoint(CGPoint pt);

CGRect WDRectFromPoint(CGPoint a, float width, float height);

BOOL WDCollinear(CGPoint a, CGPoint b, CGPoint c);

BOOL WDLineSegmentsIntersectWithValues(CGPoint A, CGPoint B, CGPoint C, CGPoint D, float *r, float *s);
BOOL WDLineSegmentsIntersect(CGPoint A, CGPoint B, CGPoint C, CGPoint D);

CGRect WDShrinkRect(CGRect rect, float percentage);

CGSize WDClampSize(CGSize size, float maximumDimension);

//
// Paths
//

CGPathRef WDCreateCubicPathFromQuadraticPath(CGPathRef pathRef);

void WDPathApplyAccumulateElement(void *info, const CGPathElement *element);
CGRect WDStrokeBoundsForPath(CGPathRef pathRef, WDStrokeStyle *strokeStyle);

CGPathRef WDCreateTransformedCGPathRef(CGPathRef pathRef, CGAffineTransform transform);

//
// Misc
//

NSString * WDSVGStringForCGAffineTransform(CGAffineTransform transform);

WDPickResult * WDSnapToRectangle(CGRect rect, CGAffineTransform *transform, CGPoint pt, float viewScale, int snapFlags);

//
// WDQuad
//
// This stuff is used for placing text on a path

typedef struct {
    CGPoint     corners[4];
} WDQuad;

WDQuad WDQuadNull();
WDQuad WDQuadMake(CGPoint a, CGPoint b, CGPoint c, CGPoint d);
WDQuad WDQuadWithRect(CGRect rect, CGAffineTransform transform);
BOOL WDQuadEqualToQuad(WDQuad a, WDQuad b);
BOOL WDQuadIntersectsQuad(WDQuad a, WDQuad b);
CGPathRef WDCreateQuadPathRef(WDQuad q);
NSString * NSStringFromWDQuad(WDQuad quad);

//
// Static Inline Functions (Geometry)
//

static inline float WDIntDistance(int x1, int y1, int x2, int y2) {
    int xd = (x1-x2), yd = (y1-y2);
    return sqrt(xd * xd + yd * yd);
}

static inline CGPoint WDAddPoints(CGPoint a, CGPoint b) {
    return CGPointMake(a.x + b.x, a.y + b.y);
}

static inline CGPoint WDSubtractPoints(CGPoint a, CGPoint b) {
    return CGPointMake(a.x - b.x, a.y - b.y);
}

static inline float WDDistance(CGPoint a, CGPoint b) {
    float xd = (a.x - b.x);
    float yd = (a.y - b.y);
    
    return sqrt(xd * xd + yd * yd);
}

static inline float WDClamp(float min, float max, float value) {
    return (value < min) ? min : (value > max) ? max : value;
}

static inline CGPoint WDCenterOfRect(CGRect rect) {
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

static inline CGRect WDMultiplyRectScalar(CGRect r, float s) {
    return CGRectMake(r.origin.x * s, r.origin.y * s, r.size.width * s, r.size.height * s);
}

static inline CGSize WDMultiplySizeScalar(CGSize size, float s) {
    return CGSizeMake(size.width * s, size.height * s);
}

static inline CGPoint WDMultiplyPointScalar(CGPoint p, float s) {
    return CGPointMake(p.x * s, p.y * s);
}

static inline CGRect WDRectWithPoints(CGPoint a, CGPoint b) {
    float minx = MIN(a.x, b.x);
    float maxx = MAX(a.x, b.x);
    float miny = MIN(a.y, b.y);
    float maxy = MAX(a.y, b.y);
    
    return CGRectMake(minx, miny, maxx - minx, maxy - miny);
}

static inline CGRect WDRectWithPointsConstrained(CGPoint a, CGPoint b, BOOL constrained) {
    float minx = MIN(a.x, b.x);
    float maxx = MAX(a.x, b.x);
    float miny = MIN(a.y, b.y);
    float maxy = MAX(a.y, b.y);
    float dimx = maxx - minx;
    float dimy = maxy - miny;
    
    if (constrained) {
        dimx = dimy = MAX(dimx, dimy);
    }
    
    return CGRectMake(minx, miny, dimx, dimy);
}

static inline CGRect WDFlipRectWithinRect(CGRect src, CGRect dst)
{
    src.origin.y = CGRectGetMaxY(dst) - CGRectGetMaxY(src);
    return src;
}

static inline CGRect WDRectFromSize(CGSize size)
{
    CGRect rect = CGRectZero;
    rect.size = size;
    return rect;
}

static inline CGPoint WDFloorPoint(CGPoint pt)
{
    return CGPointMake(floor(pt.x), floor(pt.y));
}

static inline CGPoint WDRoundPoint(CGPoint pt)
{
    return CGPointMake(round(pt.x), round(pt.y));
}

static inline CGPoint WDAveragePoints(CGPoint a, CGPoint b)
{
    return WDMultiplyPointScalar(WDAddPoints(a, b), 0.5f);    
}

static inline CGSize WDRoundSize(CGSize size)
{
    return CGSizeMake(round(size.width), round(size.height));
}

static inline float WDMagnitude(CGPoint point)
{
    return WDDistance(point, CGPointZero);
}

static inline CGPoint WDScaleVector(CGPoint v, float toLength)
{
    float fromLength = WDMagnitude(v);
    float scale = 1.0;
    
    if (fromLength != 0.0) {
        scale = toLength / fromLength;
    }
    
    return CGPointMake(v.x * scale, v.y * scale);
}

