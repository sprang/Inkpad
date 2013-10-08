//
//  WDSVGPathParser.m
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

#import "WDParseUtil.h"
#import "WDSVGParserStateStack.h"
#import "WDSVGPathParser.h"
#import "WDUtilities.h"

#define LOG_PATH 0


@implementation WDSVGPathParser

- (id) init
{
    return [self initWithErrorReporter:nil];
}

- (id) initWithErrorReporter:(id<WDErrorReporter>)reporter
{
    self = [super init];
    if (!self) {
        return nil;
    }

    reporter_ = reporter;
    path_ = CGPathCreateMutable();
    CGPathMoveToPoint(path_, NULL, 0, 0); // initialize location to origin
        
    return self;
}

- (void) dealloc
{
    CGPathRelease(path_);
}

#if LOG_PATH
#define pathLog NSLog
#else
#define pathLog(...)
#endif

static CGPoint getPoint(NSArray* arguments, NSInteger offset, CGPathRef path, BOOL absolute) 
{
    CGFloat x = [arguments[(0 + offset)] floatValue];
    CGFloat y = [arguments[(1 + offset)] floatValue];
    if (absolute) {
        return CGPointMake(x, y);
    } else {
        CGPoint prev = CGPathGetCurrentPoint(path);
        return CGPointMake(x + prev.x, y + prev.y);
    }
}

static CGPoint reflectPoint(CGPathRef path, CGPoint point) 
{
    CGPoint axis = CGPathGetCurrentPoint(path);
    CGPoint diff = WDSubtractPoints(axis, point);
    return WDAddPoints(axis, diff);
}

BOOL decomposeArcToCubic(CGMutablePathRef path, float angle, float rx, float ry, CGPoint point1, CGPoint point2, BOOL largeArcFlag, BOOL sweepFlag)
{
    // Check if the radii are big enough to draw the arc, scale radii if not.
    // http://www.w3.org/TR/SVG/implnote.html#ArcCorrectionOutOfRangeRadii
    CGPoint midpoint = CGPointMake((point1.x - point2.x) / 2, (point1.y - point2.y) / 2);
    CGAffineTransform transform = CGAffineTransformMakeRotation(-angle);
    CGPoint tmid = CGPointApplyAffineTransform(midpoint, transform);
    float radiiScale = (tmid.x * tmid.x) / (rx * rx) + (tmid.y * tmid.y) / (ry * ry);
    if (radiiScale > 1) {
        rx *= sqrtf(radiiScale);
        ry *= sqrtf(radiiScale);
    }

    // Transform points to rx/ry coordinate space
    transform = CGAffineTransformRotate(CGAffineTransformMakeScale(1 / rx, 1 / ry), -angle);
    point1 = CGPointApplyAffineTransform(point1, transform);
    point2 = CGPointApplyAffineTransform(point2, transform);

    // Find the center of the ellipse
    CGPoint delta = WDSubtractPoints(point2, point1);
    float d = delta.x * delta.x + delta.y * delta.y;
    float scaleFactor = sqrtf(MAX(1 / d - 0.25f, 0.f));
    if (sweepFlag == largeArcFlag) {
        scaleFactor = -scaleFactor;
    }
    delta.x *= scaleFactor;
    delta.y *= scaleFactor;
    CGPoint center = CGPointMake(0.5f * (point1.x + point2.x) - delta.y,
                                 0.5f * (point1.y + point2.y) + delta.x);

    // Find the angle to each point and the span of the arc
    float theta1 = atan2f(point1.y - center.y, point1.x - center.x);
    float theta2 = atan2f(point2.y - center.y, point2.x - center.x);
    float thetaArc = theta2 - theta1;
    if (thetaArc < 0 && sweepFlag) {
        thetaArc += 2 * M_PI;
    } else if (thetaArc > 0 && !sweepFlag) {
        thetaArc -= 2 * M_PI;
    }

    // Invert the transform for conversion back to user space
    transform = CGAffineTransformInvert(transform);

#if LOG_PATH
    CGPoint tdelta = CGPointApplyAffineTransform(delta, transform);
    CGPoint tcenter = CGPointApplyAffineTransform(center, transform);
    pathLog(@"Arc: d(%f, %f) c(%f, %f) th1(%f) th2(%f) arc(%f)", tdelta.x, tdelta.y, tcenter.x, tcenter.y, theta1 * 180 / M_PI, theta2 * 180 / M_PI, thetaArc * 180 / M_PI);
#endif

    // Some results of atan2 on some platform implementations are not exact enough. So that we get more
    // cubic curves than expected here. Adding 0.001f reduces the count of segments to the correct count.
    int segments = ceilf(fabsf(thetaArc / (M_PI_2 + 0.001f)));
    for (int i = 0; i < segments; ++i) {
        float startTheta = theta1 + i * thetaArc / segments;
        float endTheta = theta1 + (i + 1) * thetaArc / segments;

        float t = (4.f / 3.f) * tanf(0.25f * (endTheta - startTheta));
        if (!isfinite(t)) {
            return NO;
        }

        float sinStartTheta = sinf(startTheta);
        float cosStartTheta = cosf(startTheta);
        float sinEndTheta = sinf(endTheta);
        float cosEndTheta = cosf(endTheta);

        CGPoint cp1 = WDAddPoints(center, CGPointMake(cosStartTheta - t * sinStartTheta, sinStartTheta + t * cosStartTheta));
        CGPoint to = WDAddPoints(center, CGPointMake(cosEndTheta, sinEndTheta));
        CGPoint cp2 = WDAddPoints(to, CGPointMake(t * sinEndTheta, -t * cosEndTheta));

#if LOG_PATH
        CGPoint tcp1 = CGPointApplyAffineTransform(cp1, transform);
        CGPoint tcp2 = CGPointApplyAffineTransform(cp2, transform);
        CGPoint tto = CGPointApplyAffineTransform(to, transform);
        pathLog(@"Curve(A): cp1(%f, %f) cp2(%f, %f) to(%f, %f)", tcp1.x, tcp1.y, tcp2.x, tcp2.y, tto.x, tto.y);
#endif
        
        CGPathAddCurveToPoint(path, &transform, cp1.x, cp1.y, cp2.x, cp2.y, to.x, to.y);
    }
    return YES;
}

- (void) processCommand:(NSString *)command withArgs:(NSArray *)arguments andRange:(NSRange)range
{
    char c = [command characterAtIndex:0];
    BOOL absolute = (c >= 'A' && c <= 'Z');
    CGPoint to, cp1, cp2;
    NSInteger last = NSMaxRange(range);
    switch (c) {
        case 'M':
        case 'm':
            to = getPoint(arguments, range.location, path_, absolute);
            CGPathMoveToPoint(path_, NULL, to.x, to.y);
            pathLog(@"Move: to(%f, %f)", to.x, to.y);
            for (NSInteger i = range.location + 2; i < last; i += 2) {
                // additional arguments to move are implicit lineto segments
                to = getPoint(arguments, i, path_, absolute);
                pathLog(@"Line(M): to(%f, %f)", to.x, to.y);
                CGPathAddLineToPoint(path_, NULL, to.x, to.y);
            }
            lastCurveControl_ = lastQuadCurveControl_ = to;
            break;
        case 'Z':
        case 'z':
            pathLog(@"Close(Z)");
            CGPathCloseSubpath(path_);
            lastCurveControl_ = lastQuadCurveControl_ = to;
            break;
        case 'L':
        case 'l':
            for (NSInteger i = range.location; i < last; i += 2) {
                to = getPoint(arguments, i, path_, absolute);
                pathLog(@"Line(L): to(%f, %f)", to.x, to.y);
                CGPathAddLineToPoint(path_, NULL, to.x, to.y);
            }
            lastCurveControl_ = lastQuadCurveControl_ = to;
            break;
        case 'H':
        case 'h':
            for (NSInteger i = range.location; i < last; i++) {
                to = CGPathGetCurrentPoint(path_);
                if (absolute) {
                    to.x = [arguments[i] floatValue];
                } else {
                    to.x += [arguments[i] floatValue];
                }
                pathLog(@"Line(H): to(%f, %f)", to.x, to.y);
                CGPathAddLineToPoint(path_, NULL, to.x, to.y);
            }
            lastCurveControl_ = lastQuadCurveControl_ = to;
            break;
        case 'V':
        case 'v':
            for (NSInteger i = range.location; i < last; i++) {
                to = CGPathGetCurrentPoint(path_);
                if (absolute) {
                    to.y = [arguments[i] floatValue];
                } else {
                    to.y += [arguments[i] floatValue];
                }
                pathLog(@"Line(V): to(%f, %f)", to.x, to.y);
                CGPathAddLineToPoint(path_, NULL, to.x, to.y);
            }
            lastCurveControl_ = lastQuadCurveControl_ = to;
            break;
        case 'C':
        case 'c':
            for (NSInteger i = range.location; i < last; i += 6) {
                cp1 = getPoint(arguments, i, path_, absolute);
                cp2 = getPoint(arguments, i + 2, path_, absolute);
                to = getPoint(arguments, i + 4, path_, absolute);
                pathLog(@"Curve(C): cp1(%f, %f) cp2(%f, %f) to(%f, %f)", cp1.x, cp1.y, cp2.x, cp2.y, to.x, to.y);
                CGPathAddCurveToPoint(path_, NULL, cp1.x, cp1.y, cp2.x, cp2.y, to.x, to.y);
            }
            lastCurveControl_ = cp2;
            lastQuadCurveControl_ = CGPathGetCurrentPoint(path_);
            break;
        case 'S':
        case 's':
            for (NSInteger i = range.location; i < last; i += 4) {
                cp1 = reflectPoint(path_, lastCurveControl_);
                cp2 = getPoint(arguments, i, path_, absolute);
                to = getPoint(arguments, i + 2, path_, absolute);
                pathLog(@"Curve(S): cp1(%f, %f) cp2(%f, %f) to(%f, %f)", cp1.x, cp1.y, cp2.x, cp2.y, to.x, to.y);
                CGPathAddCurveToPoint(path_, NULL, cp1.x, cp1.y, cp2.x, cp2.y, to.x, to.y);
            }
            lastCurveControl_ = cp2;
            lastQuadCurveControl_ = CGPathGetCurrentPoint(path_);
            break;
        case 'Q':
        case 'q':
            for (NSInteger i = range.location; i < last; i += 4) {
                cp1 = getPoint(arguments, i, path_, absolute);
                to = getPoint(arguments, i + 2, path_, absolute);
                pathLog(@"Curve(Q): cp(%f, %f) to(%f, %f)", cp1.x, cp1.y, to.x, to.y);
                CGPathAddQuadCurveToPoint(path_, NULL, cp1.x, cp1.y, to.x, to.y);
            }
            lastCurveControl_ = CGPathGetCurrentPoint(path_);
            lastQuadCurveControl_ = cp1;
            break;
        case 'T':
        case 't':
            for (NSInteger i = range.location; i < last; i += 2) {
                cp1 = reflectPoint(path_, lastQuadCurveControl_);
                to = getPoint(arguments, i, path_, absolute);
                pathLog(@"Curve(T): cp(%f, %f) to(%f, %f)", cp1.x, cp1.y, to.x, to.y);
                CGPathAddQuadCurveToPoint(path_, NULL, cp1.x, cp1.y, to.x, to.y);
            }
            lastCurveControl_ = CGPathGetCurrentPoint(path_);
            lastQuadCurveControl_ = cp1;
            break;
        case 'A':
        case 'a':
            lastCurveControl_ = lastQuadCurveControl_ = CGPathGetCurrentPoint(path_);
            for (NSInteger i = range.location; i < last; i += 7) {
                CGPoint r = getPoint(arguments, i, path_, YES);
                to = getPoint(arguments, i + 5, path_, absolute);
                if (r.x || r.y) {
                    CGFloat xAxisRotation = [arguments[(2 + i)] floatValue] * M_PI / 180;
                    CGFloat largeArcFlag = [arguments[(3 + i)] floatValue];
                    CGFloat sweepFlag = [arguments[(4 + i)] floatValue];
                    CGPoint from = CGPathGetCurrentPoint(path_);
                    decomposeArcToCubic(path_, xAxisRotation, r.x, r.y, from, to, largeArcFlag, sweepFlag);
                } else {
                    pathLog(@"Line(A): to(%f, %f)", to.x, to.y);
                    CGPathAddLineToPoint(path_, NULL, to.x, to.y);
                }
            }
            lastCurveControl_ = lastQuadCurveControl_ = to;
            break;
        default:
            [reporter_ reportError:@"unknown path command: %@ %@", command, arguments];
            break;
    }
}

- (CGPathRef) parse:(NSString *)source
{
    // reset curve control points
    lastCurveControl_ = lastQuadCurveControl_ = CGPathGetCurrentPoint(path_);
    
    NSString *command = nil;
    unichar *buf = malloc([source length] * sizeof(unichar));
    NSArray *pathTokens = tokenize(source, buf);
    NSRange arguments = NSMakeRange(0, 0);
    for (int i = 0; i < [pathTokens count]; ++i) {
        NSString *token = pathTokens[i];
        switch ([token characterAtIndex:0]) {
            case '0':
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
            case '.':
            case '-':
            case '+':
                // save argument until next command is found
                arguments.length++;
                break;
            default:
                if (command != nil) {
                    // process previous command with all accumulated arguments
                    [self processCommand:command withArgs:pathTokens andRange:arguments];
                }
                command = token;
                arguments = NSMakeRange(i + 1, 0);
        }
    }
    if (command) {
        [self processCommand:command withArgs:pathTokens andRange:arguments];
    }
    free(buf);
    return path_;
}

@end
