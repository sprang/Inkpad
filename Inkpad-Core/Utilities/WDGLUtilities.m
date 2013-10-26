//
//  WDGLUtilities.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDGLUtilities.h"
#import "WDUtilities.h"

typedef struct {
    GLfloat     *vertices;
    NSUInteger  size;
    NSUInteger  index;
} glPathRenderData;

void renderPathElement(void *info, const CGPathElement *element);

inline void WDGLFillRect(CGRect rect)
{
    rect.origin = WDRoundPoint(rect.origin);
    rect.size = WDRoundSize(rect.size);
    
    const GLfloat quadVertices[] = {
        CGRectGetMinX(rect), CGRectGetMinY(rect),
        CGRectGetMaxX(rect), CGRectGetMinY(rect),
        CGRectGetMinX(rect), CGRectGetMaxY(rect),
        CGRectGetMaxX(rect), CGRectGetMaxY(rect)
    };
    
#if TARGET_OS_IPHONE
    glVertexPointer(2, GL_FLOAT, 0, quadVertices);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
#else
    glBegin(GL_QUADS); 
    glVertex2d(quadVertices[0], quadVertices[1]);
    glVertex2d(quadVertices[2], quadVertices[3]);
    glVertex2d(quadVertices[6], quadVertices[7]);
    glVertex2d(quadVertices[4], quadVertices[5]);
    glEnd();
#endif
}

inline void WDGLStrokeRect(CGRect rect)
{
    rect.origin = WDRoundPoint(rect.origin);
    rect.size = WDRoundSize(rect.size);
    
    const GLfloat lineVertices[] = {
        CGRectGetMinX(rect), CGRectGetMinY(rect),
        CGRectGetMaxX(rect), CGRectGetMinY(rect),
        
        CGRectGetMinX(rect), CGRectGetMaxY(rect),
        CGRectGetMaxX(rect), CGRectGetMaxY(rect),
        
        CGRectGetMinX(rect), CGRectGetMinY(rect),
        CGRectGetMinX(rect), CGRectGetMaxY(rect) + 1 / [UIScreen mainScreen].scale,
        
        CGRectGetMaxX(rect), CGRectGetMinY(rect),
        CGRectGetMaxX(rect), CGRectGetMaxY(rect)
    };
    
#if TARGET_OS_IPHONE
    glVertexPointer(2, GL_FLOAT, 0, lineVertices);
    glDrawArrays(GL_LINES, 0, 8);
#else
    glBegin(GL_LINES); 
    for (int i = 0; i < 8; i++) {
        glVertex2D(lineVertices[i*2], lineVertices[i*2+1]);
    }
    glEnd();
#endif
}

inline void WDGLFillCircle(CGPoint center, float radius, int sides)
{
    GLfloat *vertices = calloc(sizeof(GLfloat), (sides+1) * 4);
    float   step = M_PI * 2 / sides;
    
    for (int i=0; i <= sides; i++) {
        float angle = i*step;
        vertices[i*4] = center.x + cos(angle)*radius;
        vertices[i*4+1] = center.y + sin(angle)*radius;
        vertices[i*4+2] = center.x;
        vertices[i*4+3] = center.y;
    }
    
#if TARGET_OS_IPHONE
    glVertexPointer(2, GL_FLOAT, 0, vertices);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, (sides+1)*2);
#else
    glBegin(GL_TRIANGLE_STRIP); 
    for (int i = 0; i < (sides+1)*4; i+=2) {
        glVertex2d(vertices[i], vertices[i+1]);
    }
    glEnd();
#endif
    
    free(vertices);
}

inline void WDGLStrokeCircle(CGPoint center, float radius, int sides)
{
    GLfloat *vertices = calloc(sizeof(GLfloat), (sides+1) * 2);
    float   step = M_PI * 2 / sides;
    
    for (int i=0; i <= sides; i++) {
        float angle = i*step;
        vertices[i*2] = center.x + cos(angle)*radius;
        vertices[i*2+1] = center.y + sin(angle)*radius;
    }
    
#if TARGET_OS_IPHONE
    glVertexPointer(2, GL_FLOAT, 0, vertices);
    glDrawArrays(GL_LINE_LOOP, 0, (sides+1));
#else
    glBegin(GL_LINE_LOOP); 
    for (int i = 0; i < (sides+1)*2; i+=2) {
        glVertex2d(vertices[i], vertices[i+1]);
    }
    glEnd();
#endif
    
    free(vertices);
}

inline void WDGLLineFromPointToPoint(CGPoint a, CGPoint b)
{
    const GLfloat lineVertices[] = {
        a.x, a.y, b.x, b.y
    };
    
#if TARGET_OS_IPHONE
    glVertexPointer(2, GL_FLOAT, 0, lineVertices);
    glDrawArrays(GL_LINE_STRIP, 0, 2);
#else
    glBegin(GL_LINE_STRIP); 
    glVertex2d(lineVertices[0], lineVertices[1]);
    glVertex2d(lineVertices[2], lineVertices[3]);
    glEnd();
#endif
}

void WDGLFlattenBezierSegment(WDBezierSegment seg, GLfloat **vertices, NSUInteger *size, NSUInteger *index)
{
    if (*size < *index + 4) {
        *size *= 2;
        *vertices = realloc(*vertices, sizeof(GLfloat) * *size);
    }
        
    if (WDBezierSegmentIsFlat(seg, kDefaultFlatness)) {
        if (*index == 0) {
            (*vertices)[*index] = seg.a_.x;
            (*vertices)[*index + 1] = seg.a_.y;
            *index += 2;
        }
        
        (*vertices)[*index] = seg.b_.x;
        (*vertices)[*index + 1] = seg.b_.y;
        *index += 2;
    } else {
        WDBezierSegment L, R;
        WDBezierSegmentSplit(seg, &L, &R);
        
        WDGLFlattenBezierSegment(L, vertices, size, index);
        WDGLFlattenBezierSegment(R, vertices, size, index);
    }
}

void WDGLRenderBezierSegment(WDBezierSegment seg)
{
    static GLfloat      *vertices = NULL;
    static NSUInteger   size = 128;
    NSUInteger          index = 0;
    
    if (!vertices) {
        vertices = calloc(sizeof(GLfloat), size);
    }
    
    WDGLFlattenBezierSegment(seg, &vertices, &size, &index);
    WDGLDrawLineStrip(vertices, index);
}

void renderPathElement(void *info, const CGPathElement *element)
{
    glPathRenderData    *renderData = (glPathRenderData *) info;
    WDBezierSegment     segment;
    CGPoint             inPoint, outPoint;
    static CGPoint      prevPt, moveTo;
    
    switch (element->type) {
        case kCGPathElementMoveToPoint:
            if (renderData->index) {
                // starting a new subpath, so draw the current one
                WDGLDrawLineStrip(renderData->vertices, renderData->index);
                renderData->index = 0;
            }
            
            prevPt = moveTo = element->points[0];
            break;
        case kCGPathElementAddLineToPoint:
            if (renderData->index == 0) {
                // index is 0, so we need to add the original moveTo
                (renderData->vertices)[0] = prevPt.x;
                (renderData->vertices)[1] = prevPt.y;
                renderData->index = 2;
            }
            
            // make sure we're not over-running the buffer
            if (renderData->size < renderData->index + 2) {
                renderData->size *= 2;
                renderData->vertices = realloc(renderData->vertices, sizeof(GLfloat) * renderData->size);
            }
            
            prevPt = element->points[0];
            (renderData->vertices)[renderData->index] = prevPt.x;
            (renderData->vertices)[renderData->index + 1] = prevPt.y;
            renderData->index += 2;
            break;
        case kCGPathElementAddQuadCurveToPoint:
            // convert quadratic to cubic: http://fontforge.sourceforge.net/bezier.html
            outPoint.x = prevPt.x + (element->points[0].x - prevPt.x) * (2.0f / 3);
            outPoint.y = prevPt.y + (element->points[0].y - prevPt.y) * (2.0f / 3);
            
            inPoint.x = element->points[1].x + (element->points[0].x - element->points[1].x) * (2.0f / 3);
            inPoint.y = element->points[1].y + (element->points[0].y - element->points[1].y) * (2.0f / 3);
            
            segment.a_ = prevPt;
            segment.out_ = outPoint;
            segment.in_ = inPoint;
            segment.b_ = element->points[1];
            
            WDGLFlattenBezierSegment(segment, &(renderData->vertices), &(renderData->size), &(renderData->index));
            prevPt = element->points[1];
            break;
        case kCGPathElementAddCurveToPoint:
            segment.a_ = prevPt;
            segment.out_ = element->points[0];
            segment.in_ = element->points[1];
            segment.b_ = element->points[2];
            
            WDGLFlattenBezierSegment(segment, &(renderData->vertices), &(renderData->size), &(renderData->index));
            prevPt = element->points[2];
            break;
        case kCGPathElementCloseSubpath:
            // make sure we're not over-running the buffer
            if (renderData->size < renderData->index + 2) {
                renderData->size *= 2;
                renderData->vertices = realloc(renderData->vertices, sizeof(GLfloat) * renderData->size);
            }
            
            (renderData->vertices)[renderData->index] = moveTo.x;
            (renderData->vertices)[renderData->index + 1] = moveTo.y;
            renderData->index += 2;                          
            break;
    }
}

void WDGLRenderCGPathRef(CGPathRef pathRef)
{
    static glPathRenderData renderData = { NULL, 128, 0 };
    
    if (renderData.vertices == NULL) {
        renderData.vertices = calloc(sizeof(GLfloat), renderData.size);
    }
    
    renderData.index = 0;
    CGPathApply(pathRef, &renderData, &renderPathElement);

    WDGLDrawLineStrip(renderData.vertices, renderData.index);
}

inline void WDGLFillDiamond(CGPoint center, float dimension)
{
    const GLfloat vertices[] = {
        center.x, center.y + dimension,
        center.x + dimension, center.y,
        center.x, center.y - dimension,
        center.x, center.y + dimension,
        center.x - dimension, center.y
    };
    
#if TARGET_OS_IPHONE
    glVertexPointer(2, GL_FLOAT, 0, vertices);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 5);
#else
    glBegin(GL_TRIANGLE_STRIP);
    for (int i = 0; i < 5; i++) {
        glVertex2f(vertices[i*2], vertices[i*2+1]);
    }
    glEnd();
#endif
}

void WDGLDrawLineStrip(GLfloat *vertices, NSUInteger count)
{
#if TARGET_OS_IPHONE
    glVertexPointer(2, GL_FLOAT, 0, vertices);
    glDrawArrays(GL_LINE_STRIP, 0, (int) count / 2);
#else 
    glBegin(GL_LINE_STRIP);
    for (int i = 0; i < count; i+=2) {
        glVertex2d(vertices[i], vertices[i+1]);
    }
    glEnd();
#endif
}
