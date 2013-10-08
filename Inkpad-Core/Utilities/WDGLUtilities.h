//
//  WDGLUtilities.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#if TARGET_OS_IPHONE
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#else 
#import <OpenGL/gl.h>
#endif

#import "WDBezierSegment.h"

void WDGLFillRect(CGRect rect);
void WDGLStrokeRect(CGRect rect);
void WDGLFillCircle(CGPoint center, float radius, int sides);
void WDGLStrokeCircle(CGPoint center, float radius, int sides);
void WDGLLineFromPointToPoint(CGPoint a, CGPoint b);
void WDGLFillDiamond(CGPoint center, float dimension);

void WDGLFlattenBezierSegment(WDBezierSegment seg, GLfloat **vertices, NSUInteger *size, NSUInteger *index);
void WDGLRenderBezierSegment(WDBezierSegment seg);
void WDGLRenderCGPathRef(CGPathRef pathRef);

void WDGLDrawLineStrip(GLfloat *vertices, NSUInteger count);
