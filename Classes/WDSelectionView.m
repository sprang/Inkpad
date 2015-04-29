//
//  WDSelectionView.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDBezierNode.h"
#import "WDCanvas.h"
#import "WDDrawingController.h"
#import "WDGLUtilities.h"
#import "WDLayer.h"
#import "WDPath.h"
#import "WDSelectionTool.h"
#import "WDSelectionView.h"
#import "WDToolManager.h"
#import "WDUtilities.h"
#import "UIColor+Additions.h"

@implementation WDSelectionView

@synthesize canvas = canvas_;
@synthesize context;

+ (Class) layerClass
{
    return [CAEAGLLayer class];
}

- (UIView *) hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    return self.superview;
}

- (id)initWithFrame:(CGRect)frame
{    
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    // Get the layer
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = NO;
    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @NO,
                                    kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
    
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];        
    if (!context || ![EAGLContext setCurrentContext:context]) {
        return nil;
    }
    
    // Create system framebuffer object. The backing will be allocated in -reshapeFramebuffer
    glGenFramebuffersOES(1, &defaultFramebuffer);
    glGenRenderbuffersOES(1, &colorRenderbuffer);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
    
    glClearColor(0, 0, 0, 0);
    glEnable(GL_BLEND);
    glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnableClientState(GL_VERTEX_ARRAY);
    
    self.userInteractionEnabled = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contentMode = UIViewContentModeCenter;
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    
    return self;
}

- (CGRect) convertRectFromCanvas:(CGRect)rect
{
    rect.origin = WDSubtractPoints(rect.origin, [canvas_ visibleRect].origin);
    rect = CGRectApplyAffineTransform(rect, self.canvas.canvasTransform);
    rect = WDFlipRectWithinRect(rect, self.frame);
    
    return rect;
}

- (void) renderMarquee
{
    CGRect marquee = [self.canvas.marquee CGRectValue];
    
    marquee = [canvas_ convertRectToView:marquee];
    marquee = CGRectIntegral(marquee);
    marquee = WDFlipRectWithinRect(marquee, self.frame);
    
    glColor4f(0, 0, 0, 0.333f);
    WDGLFillRect(marquee);
    
    glColor4f(0, 0, 0, 0.75f);
    WDGLStrokeRect(marquee);
}

- (void) renderDocumentBorder
{
    CGRect docBounds = CGRectMake(0, 0, canvas_.drawing.dimensions.width, canvas_.drawing.dimensions.height);
    
    docBounds = [canvas_ convertRectToView:docBounds];
    docBounds = WDFlipRectWithinRect(docBounds, self.frame);
    
    float gray = [canvas_ effectiveBackgroundGray];
    glClearColor(gray, gray, gray, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(0, 0, 0, 0);
    
    glColor4f(1, 1, 1, 1);
    WDGLFillRect(docBounds);
    
    glColor4f(0, 0, 0, 1);
    WDGLStrokeRect(docBounds);
}

- (float) effectiveGridSpacing
{
    float   gridSpacing = self.drawing.gridSpacing;
    CGRect  testRect = CGRectMake(0, 0, gridSpacing, gridSpacing);
    float   adjustmentFactor = 1;
    
    testRect = [canvas_ convertRectToView:testRect];
    
    float minSpacing = 10.0f / [UIScreen mainScreen].scale;
    
    if (CGRectGetWidth(testRect) < minSpacing) {
        adjustmentFactor = minSpacing / CGRectGetWidth(testRect);
    }
    
    return gridSpacing * adjustmentFactor;
}

- (void) renderGrid
{
    WDDrawing   *drawing = self.drawing;
    CGRect      docBounds = CGRectMake(0, 0, drawing.dimensions.width, drawing.dimensions.height);
    CGRect      visibleRect = canvas_.visibleRect;
    float       gridSpacing = [self effectiveGridSpacing];
    CGPoint     a, b;
    
    // just draw lines in the portion of the document that's actually visible
    visibleRect = CGRectIntersection(visibleRect, docBounds);
    if (CGRectEqualToRect(visibleRect, CGRectNull)) {
        // if there's no intersection, bail early
        return;
    }
    
    float startY = floor(CGRectGetMinY(visibleRect) / gridSpacing);
    float startX = floor(CGRectGetMinX(visibleRect) / gridSpacing);
    
    startX *= gridSpacing;
    startY *= gridSpacing;
    
    glColor4f(0, 0, 0, 0.333f);
    
    for (float y = startY; y <= CGRectGetMaxY(visibleRect); y += gridSpacing) {
        a = CGPointMake(0, y);
        b = CGPointMake(CGRectGetWidth(docBounds), y);
        
        a = [canvas_ convertPointFromDocumentSpace:a];
        b = [canvas_ convertPointFromDocumentSpace:b];

        a = WDRoundPoint(a);
        b = WDRoundPoint(b);
        
        a.y = CGRectGetHeight(self.frame) - a.y;
        b.y = CGRectGetHeight(self.frame) - b.y;
        
        WDGLLineFromPointToPoint(a, b);
    }
    
    for (float x = startX; x <= CGRectGetMaxX(visibleRect); x += gridSpacing) {
        a = CGPointMake(x, 0);
        b = CGPointMake(x, CGRectGetHeight(docBounds));
                
        a = [canvas_ convertPointFromDocumentSpace:a];
        b = [canvas_ convertPointFromDocumentSpace:b];
        
        a = WDRoundPoint(a);
        b = WDRoundPoint(b);
        
        a.y = CGRectGetHeight(self.frame) - a.y;
        b.y = CGRectGetHeight(self.frame) - b.y;

        WDGLLineFromPointToPoint(a, b);
    }
}

// Replace the implementation of this method to do your own custom drawing
- (void) drawView
{
    [EAGLContext setCurrentContext:context];
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    
    glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
    
    float scale = [UIScreen mainScreen].scale;
    glOrthof(0, backingWidth / scale, 0, backingHeight / scale, -1, 1);
    
    glClear(GL_COLOR_BUFFER_BIT);
    
    // draw the selection highlights
    CGAffineTransform flip = CGAffineTransformMakeTranslation(0, self.bounds.size.height);
    flip = CGAffineTransformScale(flip, 1.0, -1.0);
    
    CGAffineTransform effective = self.canvas.canvasTransform;
    effective = CGAffineTransformConcat(effective, flip);
    
    if (canvas_.isZooming) {
        [self renderDocumentBorder];
        
        if (self.canvas.drawing.showGrid) {
            [self renderGrid];
        }
        
        CGRect visibleRect = self.canvas.visibleRect;
        for (WDLayer *l in self.canvas.drawing.layers) {
            if (l.hidden) {
                continue;
            }
            
            [l.highlightColor openGLSet];
            
            for (WDElement *e in [l elements]) {
                [e drawOpenGLZoomOutlineWithViewTransform:effective visibleRect:visibleRect];
            }
        }
        
        [context presentRenderbuffer:GL_RENDERBUFFER_OES];
        return;
    }
    
    // marquee?
    if (self.canvas.marquee) {
        [self renderMarquee];
    }   
    
    WDDrawingController *controller = self.canvas.drawingController;
    WDElement           *singleSelection = [controller singleSelection];
    
    if (singleSelection && !self.canvas.transforming && !self.canvas.transformingNode) {
        if ([[WDToolManager sharedInstance].activeTool isKindOfClass:[WDSelectionTool class]]) {
            [singleSelection drawTextPathControlsWithViewTransform:effective viewScale:self.canvas.viewScale];
        }
    }
    
    // draw all object outlines, using the selection transform if applicable
    for (WDElement *e in controller.selectedObjects) {
        [e drawOpenGLHighlightWithTransform:self.canvas.selectionTransform viewTransform:effective];
    }
    
    // if we're not transforming, draw filled anchors on all paths
    if (!self.canvas.transforming && !singleSelection) {        
        for (WDElement *e in controller.selectedObjects) {
            [e drawOpenGLAnchorsWithViewTransform:effective];
        }
    }
    
    if (controller.tempDisplayNode) {
        [controller.tempDisplayNode drawGLWithViewTransform:effective color:controller.drawing.activeLayer.highlightColor mode:kWDBezierNodeRenderSelected];
    }
    
    if ((!self.canvas.transforming || self.canvas.transformingNode) && singleSelection) {
        [singleSelection drawOpenGLHandlesWithTransform:self.canvas.selectionTransform viewTransform:effective];
        
        if ([[WDToolManager sharedInstance].activeTool isKindOfClass:[WDSelectionTool class]]) {
            [singleSelection drawGradientControlsWithViewTransform:effective];
        }
    }
    
    if (self.canvas.shapeUnderConstruction) {
        [self.canvas.shapeUnderConstruction drawOpenGLHighlightWithTransform:CGAffineTransformIdentity viewTransform:effective];
    }
    
    if (self.canvas.dynamicGuides && self.canvas.dynamicGuides.count) {
        [self.canvas.dynamicGuides makeObjectsPerformSelector:@selector(render:) withObject:canvas_];
    }
    
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)reshapeFramebuffer
{
	// Allocate color buffer backing based on the current layer size
    [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, colorRenderbuffer);
    
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    
    [EAGLContext setCurrentContext:context];
    glViewport(0, 0, backingWidth, backingHeight);
}

- (void)layoutSubviews
{
    [self reshapeFramebuffer];
    [self drawView];
}

- (void)dealloc
{        
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (WDDrawing *) drawing
{
    return self.canvas.drawing;
}

@end
