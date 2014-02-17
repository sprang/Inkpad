/*
     An Algorithm for Automatically Fitting Digitized Curves
     by Philip J. Schneider
     from "Graphics Gems", Academic Press, 1990
     
     This file is derived from https://github.com/erich666/GraphicsGems/blob/master/gems/FitCurves.c
     See also: http://www.graphicsgems.org
     
     This Source Code Form is subject to the terms of the Mozilla Public
     License, v. 2.0. If a copy of the MPL was not distributed with this
     file, You can obtain one at http://mozilla.org/MPL/2.0/.
     
     Inkpad modifications Copyright (c) 2014 Steve Sprang
 */

#import "FitCurves.h"
#import "WDUtilities.h"

// linear interpolation from l (when a=0) to h (when a=1)
// (equal to (a*h)+((1-a)*l)
#define LERP(a,l,h) ((l)+(((h)-(l))*(a)))

typedef struct {
    CGPoint pts[4];
} BezierCurve;


// forward declarations
//
static int          FitCubic(WDBezierSegment *segments, CGPoint *d, int first, int last, CGPoint tHat1, CGPoint tHat2, double error, int segCount);
static BezierCurve  GenerateBezier(CGPoint *d, int first, int last, double *uPrime, CGPoint tHat1, CGPoint tHat2);
static double *     Reparameterize(CGPoint *d, int first, int last, double *u, BezierCurve bezCurve);
static double       NewtonRaphsonRootFind(BezierCurve Q, CGPoint P, double u);
static CGPoint      BezierII(int degree, CGPoint *V, double t);
static double       B0(double u);
static double       B1(double u);
static double       B2(double u);
static double       B3(double u);
static CGPoint      ComputeLeftTangent(CGPoint *d, int end);
static CGPoint      ComputeRightTangent(CGPoint *d, int end);
static CGPoint      ComputeCenterTangent(CGPoint *d, int center);
static double *     ChordLengthParameterize(CGPoint *d, int first, int last);
static double       ComputeMaxError(CGPoint *d, int first, int last, BezierCurve bezCurve, double *u, int *splitPoint);
static double       V2SquaredLength(CGPoint a);
static double       V2Dot(CGPoint a, CGPoint b);
static void         AddBezierSegment(WDBezierSegment *segments, BezierCurve curve, int ix);


//  FitCurve : Fit a Bezier curve to a set of digitized points
//
int FitCurve(WDBezierSegment *segments, CGPoint *d, int nPts, double error)
{
    CGPoint tHat1, tHat2; // Unit tangent vectors at endpoints
    
    tHat1 = ComputeLeftTangent(d, 0);
    tHat2 = ComputeRightTangent(d, nPts - 1);
    return FitCubic(segments, d, 0, nPts - 1, tHat1, tHat2, error, 0);
}

//  FitCubic : Fit a Bezier curve to a (sub)set of digitized points
//
static int FitCubic(WDBezierSegment *segments, CGPoint *d, int first, int last, CGPoint tHat1, CGPoint tHat2, double error, int segCount)
{
    BezierCurve     bezCurve;
    double          *u, *uPrime;
    double          maxError;
    int             i, splitPoint;
    int             nPts = last - first + 1;
    double          iterationError = error * error;
    int             maxIterations = 5;
    CGPoint         tHatCenter;
    
    //  Use heuristic if region only has two points in it
    if (nPts == 2) {
        double dist = WDDistance(d[last], d[first]) / 3.0;
        
        bezCurve.pts[0] = d[first];
        bezCurve.pts[3] = d[last];
        bezCurve.pts[1] = WDAddPoints(bezCurve.pts[0], WDScaleVector(tHat1, dist));
        bezCurve.pts[2] = WDAddPoints(bezCurve.pts[3], WDScaleVector(tHat2, dist));
        
        AddBezierSegment(segments, bezCurve, segCount++);
        return segCount;
    }
    
    //  Parameterize points, and attempt to fit curve
    u = ChordLengthParameterize(d, first, last);
    bezCurve = GenerateBezier(d, first, last, u, tHat1, tHat2);
    
    //  Find max deviation of points to fitted curve
    maxError = ComputeMaxError(d, first, last, bezCurve, u, &splitPoint);
    if (maxError < error) {
        AddBezierSegment(segments, bezCurve, segCount++);
        free(u);
        return segCount;
    }
    
    //  If error not too large, try some reparameterization and iteration
    if (maxError < iterationError) {
        for (i = 0; i < maxIterations; i++) {
            uPrime = Reparameterize(d, first, last, u, bezCurve);
            bezCurve = GenerateBezier(d, first, last, uPrime, tHat1, tHat2);
            maxError = ComputeMaxError(d, first, last, bezCurve, uPrime, &splitPoint);
            if (maxError < error) {
                AddBezierSegment(segments, bezCurve, segCount++);
                free(u);
                free(uPrime);
                return segCount;
            }
            free(u);
            u = uPrime;
        }
    }
    
    // Fitting failed -- split at max error point and fit recursively
    free(u);
    tHatCenter = ComputeCenterTangent(d, splitPoint);
    segCount = FitCubic(segments, d, first, splitPoint, tHat1, tHatCenter, error, segCount);
    tHatCenter = WDMultiplyPointScalar(tHatCenter, -1); // negate
    segCount = FitCubic(segments, d, splitPoint, last, tHatCenter, tHat2, error, segCount);
    
    return segCount;
}

//  GenerateBezier : Use least-squares method to find Bezier control points for region.
//
static BezierCurve GenerateBezier(CGPoint *d, int first, int last, double *uPrime, CGPoint tHat1, CGPoint tHat2)
{
    BezierCurve     bezCurve;
    CGPoint         A[last-first + 1][2];
    int             i, nPts;
    double          C[2][2] = {0};
    double          X[2] = {0};
    double          det_C0_C1, det_C0_X, det_X_C1;
    double          alpha_l, alpha_r;
    CGPoint         tmp;
    
    nPts = last - first + 1;
    
    // Compute the A's
    for (i = 0; i < nPts; i++) {
        A[i][0] = WDScaleVector(tHat1, B1(uPrime[i]));
        A[i][1] = WDScaleVector(tHat2, B2(uPrime[i]));
    }
    
    for (i = 0; i < nPts; i++) {
        C[0][0] += V2Dot(A[i][0], A[i][0]);
        C[0][1] += V2Dot(A[i][0], A[i][1]);
        C[1][0] = C[0][1];
        C[1][1] += V2Dot(A[i][1], A[i][1]);
        
        tmp = WDMultiplyPointScalar(d[last], B3(uPrime[i]));
        tmp = WDAddPoints(WDMultiplyPointScalar(d[last], B2(uPrime[i])), tmp);
        tmp = WDAddPoints(WDMultiplyPointScalar(d[first], B1(uPrime[i])), tmp);
        tmp = WDAddPoints(WDMultiplyPointScalar(d[first], B0(uPrime[i])), tmp);
        tmp = WDSubtractPoints(d[first + i], tmp);
        
        X[0] += V2Dot(A[i][0], tmp);
        X[1] += V2Dot(A[i][1], tmp);
    }
    
    // Compute the determinants of C and X
    det_C0_C1 = C[0][0] * C[1][1] - C[1][0] * C[0][1];
    det_C0_X  = C[0][0] * X[1]    - C[1][0] * X[0];
    det_X_C1  = X[0]    * C[1][1] - X[1]    * C[0][1];
    
    // Finally, derive alpha values
    alpha_l = (det_C0_C1 == 0) ? 0.0 : det_X_C1 / det_C0_C1;
    alpha_r = (det_C0_C1 == 0) ? 0.0 : det_C0_X / det_C0_C1;
    
    // If alpha negative, use the Wu/Barsky heuristic (see text)
    // If alpha is 0, you get coincident control points that lead to divide by zero in any subsequent NewtonRaphsonRootFind() call.
    double segLength = WDDistance(d[last], d[first]);
    double epsilon = 1.0e-6 * segLength;
    if (alpha_l < epsilon || alpha_r < epsilon) {
        // fall back on standard (probably inaccurate) formula, and subdivide further if needed.
        double dist = segLength / 3.0;
        bezCurve.pts[0] = d[first];
        bezCurve.pts[3] = d[last];
        bezCurve.pts[1] = WDAddPoints(bezCurve.pts[0], WDScaleVector(tHat1, dist));
        bezCurve.pts[2] = WDAddPoints(bezCurve.pts[3], WDScaleVector(tHat2, dist));
        
        return bezCurve;
    }
    
    // First and last control points of the Bezier curve are positioned exactly at the first and last data points.
    // Control points 1 and 2 are positioned an alpha distance out on the tangent vectors, left and right, respectively.
    bezCurve.pts[0] = d[first];
    bezCurve.pts[3] = d[last];
    bezCurve.pts[1] = WDAddPoints(bezCurve.pts[0], WDScaleVector(tHat1, alpha_l));
    bezCurve.pts[2] = WDAddPoints(bezCurve.pts[3], WDScaleVector(tHat2, alpha_r));
    
    return bezCurve;
}

//  Reparameterize: Given set of points and their parameterization, try to find a better parameterization.
//
static double * Reparameterize(CGPoint *d, int first, int last, double *u, BezierCurve bezCurve)
{
    int  nPts = last-first+1;
    double *uPrime; // New parameter values
    
    uPrime = malloc(nPts * sizeof(double));
    for (int i = first; i <= last; i++) {
        uPrime[i-first] = NewtonRaphsonRootFind(bezCurve, d[i], u[i-first]);
    }
    return (uPrime);
}

//  NewtonRaphsonRootFind : Use Newton-Raphson iteration to find better root.
//
static double NewtonRaphsonRootFind(BezierCurve Q, CGPoint P, double u)
{
    double  numerator, denominator;
    CGPoint Q1[3], Q2[2];       // Q' and Q''
    CGPoint Q_u, Q1_u, Q2_u;    // u evaluated at Q, Q', & Q''
    double  uPrime;             // Improved u
    int     i;
    
    // Compute Q(u)
    Q_u = BezierII(3, Q.pts, u);
    
    // Generate control vertices for Q'
    for (i = 0; i <= 2; i++) {
        Q1[i].x = (Q.pts[i+1].x - Q.pts[i].x) * 3.0;
        Q1[i].y = (Q.pts[i+1].y - Q.pts[i].y) * 3.0;
    }
    
    // Generate control vertices for Q''
    for (i = 0; i <= 1; i++) {
        Q2[i].x = (Q1[i+1].x - Q1[i].x) * 2.0;
        Q2[i].y = (Q1[i+1].y - Q1[i].y) * 2.0;
    }
    
    // Compute Q'(u) and Q''(u)
    Q1_u = BezierII(2, Q1, u);
    Q2_u = BezierII(1, Q2, u);
    
    // Compute f(u)/f'(u)
    numerator = (Q_u.x - P.x) * (Q1_u.x) + (Q_u.y - P.y) * (Q1_u.y);
    denominator = (Q1_u.x) * (Q1_u.x) + (Q1_u.y) * (Q1_u.y) +
        (Q_u.x - P.x) * (Q2_u.x) + (Q_u.y - P.y) * (Q2_u.y);
    
    if (denominator == 0.0f) {
        return u;
    }
    
    // u = u - f(u)/f'(u)
    uPrime = u - (numerator / denominator);
    return uPrime;
}

//  Bezier : Evaluate a Bezier curve at a particular parameter value
//
static CGPoint BezierII(int degree, CGPoint *V, double t)
{
    CGPoint Vtemp[degree+1]; // Local copy of control points
    int     i, j;
    
    for (i = 0; i <= degree; i++) {
        Vtemp[i] = V[i];
    }
    
    // Triangle computation
    for (i = 1; i <= degree; i++) {
        for (j = 0; j <= degree-i; j++) {
            Vtemp[j].x = (1.0 - t) * Vtemp[j].x + t * Vtemp[j+1].x;
            Vtemp[j].y = (1.0 - t) * Vtemp[j].y + t * Vtemp[j+1].y;
        }
    }
    
    return Vtemp[0]; // Q: Point on curve at parameter t
}

//  B0, B1, B2, B3 : Bezier multipliers
//
static double B0(double u) {
    double tmp = 1.0 - u;
    return (tmp * tmp * tmp);
}

static double B1(double u) {
    double tmp = 1.0 - u;
    return (3 * u * (tmp * tmp));
}

static double B2(double u) {
    return (3 * u * u * (1.0 - u));
}

static double B3(double u) {
    return (u * u * u);
}

// ComputeLeftTangent, ComputeRightTangent, ComputeCenterTangent :
// Approximate unit tangents at endpoints and "center" of digitized curve
//
static CGPoint ComputeLeftTangent(CGPoint *d, int end) {
    CGPoint tHat1 = WDSubtractPoints(d[end+1], d[end]);
    return WDNormalizePoint(tHat1);
}

static CGPoint ComputeRightTangent(CGPoint *d, int end) {
    CGPoint tHat2 = WDSubtractPoints(d[end-1], d[end]);
    return WDNormalizePoint(tHat2);
}

static CGPoint ComputeCenterTangent(CGPoint *d, int center)
{
    CGPoint V1 = WDSubtractPoints(d[center-1], d[center]);
    CGPoint V2 = WDSubtractPoints(d[center], d[center+1]);
    CGPoint tHatCenter = WDAveragePoints(V1, V2);
    
    return WDNormalizePoint(tHatCenter);
}

//  ChordLengthParameterize : Assign parameter values to digitized points using relative distances between points.
//
static double *ChordLengthParameterize(CGPoint *d, int first, int last)
{
    double *u = calloc((last-first+1), sizeof(double)); // init to 0
    
    for (int i = first+1; i <= last; i++) {
        u[i-first] = u[i-first-1] + WDDistance(d[i], d[i-1]);
    }
    
    for (int i = first + 1; i <= last; i++) {
        u[i-first] = u[i-first] / u[last-first];
    }
    
    return u;
}

//  ComputeMaxError : Find the maximum squared distance of digitized points to fitted curve.
//
static double ComputeMaxError(CGPoint *d, int first, int last, BezierCurve bezCurve, double *u, int *splitPoint)
{
    double maxDist = 0.0;  // Maximum error
    double dist;           // Current error
    CGPoint P;             // Point on curve
    CGPoint v;             // Vector from point to curve
    
    *splitPoint = (last - first + 1) / 2;
    
    for (int i = first + 1; i < last; i++) {
        P = BezierII(3, bezCurve.pts, u[i-first]);
        v = WDSubtractPoints(P, d[i]);
        dist = V2SquaredLength(v);
        if (dist >= maxDist) {
            maxDist = dist;
            *splitPoint = i;
        }
    }
    
    return maxDist;
}

// returns squared length of input vector
static double V2SquaredLength(CGPoint a) {
    return (a.x * a.x) + (a.y * a.y);
}

// return the dot product of vectors a and b
static double V2Dot(CGPoint a, CGPoint b) {
    return (a.x * b.x) + (a.y * b.y);
}

// populate the bezier segment at ix
static void AddBezierSegment(WDBezierSegment *segments, BezierCurve curve, int ix) {
    segments[ix].a_ = curve.pts[0];
    segments[ix].out_ = curve.pts[1];
    segments[ix].in_ = curve.pts[2];
    segments[ix].b_ = curve.pts[3];
}

