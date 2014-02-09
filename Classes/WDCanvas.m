//
//  WDCanvas.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import "UIView+Additions.h"
#import "WDCanvas.h"
#import "WDCanvasController.h"
#import "WDDrawingController.h"
#import "WDColor.h"
#import "WDEraserPreviewView.h"
#import "WDEtchedLine.h"
#import "WDEyedropper.h"
#import "WDLayer.h"
#import "WDPalette.h"
#import "WDPath.h"
#import "WDPenTool.h"
#import "WDRulerView.h"
#import "WDSelectionView.h"
#import "WDToolButton.h"
#import "WDToolView.h"
#import "WDToolManager.h"
#import "WDUtilities.h"

#define kFitBuffer                  30
#define kPrintSizeFactor            (72.0f / 132.0f)
#define kHundredPercentScale        (132.0f / 72.0f)
#define kMaxZoom                    (64 * kHundredPercentScale)
#define kMessageFadeDelay           1
#define kDropperRadius              80
#define kDropperAnimationDuration   0.2f
#define DEBUG_DIRTY_RECTS           NO

NSString *WDCanvasBeganTrackingTouches = @"WDCanvasBeganTrackingTouches";

@interface WDCanvas (Private)
- (void) setTrueViewScale_:(float)scale;
- (void) rebuildViewTransform_;
@end

@implementation WDCanvas

@synthesize selectionView = selectionView_;
@synthesize eraserPreview = eraserPreview_;
@synthesize canvasTransform = transform_;
@synthesize selectionTransform = selectionTransform_;
@synthesize viewScale = viewScale_;
@synthesize drawing = drawing_;
@synthesize transforming = transforming_;
@synthesize transformingNode = transformingNode_;
@synthesize pivot = pivot_;
@synthesize showingPivot = showingPivot_;
@synthesize marquee = marquee_;
@synthesize shapeUnderConstruction = shapeUnderConstruction_;
@synthesize eraserPath = eraserPath_;
@synthesize controller = controller_;
@synthesize toolPalette = toolPalette_;
@synthesize eyedropper = eyedropper_;
@synthesize horizontalRuler = horizontalRuler_;
@synthesize verticalRuler = verticalRuler_;
@synthesize toolOptionsView = toolOptionsView_;
@synthesize activityView = activityView_;
@synthesize dynamicGuides = dynamicGuides_;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    selectionView_ = [[WDSelectionView alloc] initWithFrame:self.bounds];
    [self addSubview:selectionView_];
    selectionView_.canvas = self;
    
    self.multipleTouchEnabled = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contentMode = UIViewContentModeCenter;
    self.exclusiveTouch = YES;
    self.clearsContextBeforeDrawing = YES;
    
    selectionTransform_ = CGAffineTransformIdentity;
    transform_ = CGAffineTransformIdentity;
    
    self.backgroundColor = [UIColor whiteColor];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    return self;
}

- (void) registerInvalidateNotifications:(NSArray *)array
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    for (NSString *name in array) {
        [nc addObserver:self
               selector:@selector(invalidateFromNotification:)
                   name:name
                 object:drawing_];
    }
}

- (void) setDrawing:(WDDrawing *)drawing
{
    if (drawing_ == drawing) {
        return;
    }
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    if (drawing_) {
        // stop listening to old drawing
        [nc removeObserver:self name:nil object:drawing_];
        [nc removeObserver:self name:WDSelectionChangedNotification object:nil];
    }
    
    // assign the new drawing
    drawing_ = drawing;
    
    // register for notifications
    NSArray *invalidations = @[WDElementChanged,
                                  WDDrawingChangedNotification,
                                  WDLayersReorderedNotification,
                                  WDLayerAddedNotification, 
                                  WDLayerDeletedNotification, 
                                  WDIsolateActiveLayerSettingChangedNotification,
                                  WDOutlineModeSettingChangedNotification,
                                  WDLayerContentsChangedNotification,
                                  WDLayerVisibilityChanged,
                                  WDLayerOpacityChanged];
    
    [self registerInvalidateNotifications:invalidations];
    
    [nc addObserver:self
           selector:@selector(unitsChanged:)
               name:WDUnitsChangedNotification
             object:drawing_];
    
    [nc addObserver:self
           selector:@selector(drawingDimensionsChanged:)
               name:WDDrawingDimensionsChanged
             object:drawing_];
    
    [nc addObserver:self
           selector:@selector(gridSpacingChanged:)
               name:WDGridSpacingChangedNotification
             object:drawing_];
    
    [nc addObserver:self
           selector:@selector(selectionChanged:)
               name:WDSelectionChangedNotification
             object:self.drawingController];
    
    [self showRulers:drawing_.rulersVisible];
    [self showTools];
    
    [self scaleDocumentToFit];
}

- (WDDrawingController *) drawingController
{
    return controller_.drawingController;
}

- (void) drawingDimensionsChanged:(NSNotification *)aNotification
{
    [self scaleDocumentToFit];
}

- (void) unitsChanged:(NSNotification *)aNotification
{
    horizontalRuler_.units = drawing_.units;
    verticalRuler_.units = drawing_.units;
    
    [controller_ updateTitle];
}

- (void) gridSpacingChanged:(NSNotification *)aNotification
{
    [self setNeedsDisplay];
}

- (void) setRulerAlpha:(float)alpha
{    
    horizontalRuler_.alpha = alpha;
    verticalRuler_.alpha = alpha;
    cornerView_.alpha = alpha;
}

- (void) showRulers:(BOOL)flag
{
    [self showRulers:flag animated:YES];
}

- (void) showRulers:(BOOL)flag animated:(BOOL)animated
{
    if (flag && !horizontalRuler_) {
        CGRect horizontalFrame = self.frame;
        horizontalFrame.origin.y = 0;
        horizontalFrame.size.height = kWDRulerThickness;
        horizontalFrame.origin.x = kWDRulerThickness;
        horizontalFrame.size.width -= kWDRulerThickness;
        horizontalRuler_ = [[WDRulerView alloc] initWithFrame:horizontalFrame];
        horizontalRuler_.clientView = self;
        horizontalRuler_.orientation = WDHorizontalRuler;
        horizontalRuler_.units = drawing_.units;
        
        if (toolPalette_) {
            [self insertSubview:horizontalRuler_ belowSubview:toolPalette_];
        } else {
            [self addSubview:horizontalRuler_];
        }
        
        CGRect verticalFrame = self.frame;
        verticalFrame.origin.y = kWDRulerThickness;
        verticalFrame.size.height -= kWDRulerThickness;
        verticalFrame.origin.x = 0;
        verticalFrame.size.width = kWDRulerThickness;
        verticalRuler_ = [[WDRulerView alloc] initWithFrame:verticalFrame];
        verticalRuler_.clientView = self;
        verticalRuler_.orientation = WDVerticalRuler;
        verticalRuler_.units = drawing_.units;
        
        if (toolPalette_) {
            [self insertSubview:verticalRuler_ belowSubview:toolPalette_];
        } else {
            [self addSubview:verticalRuler_];
        }
        
        cornerView_ = [[WDRulerCornerView alloc] initWithFrame:CGRectMake(0,0,kWDRulerThickness,kWDRulerThickness)];
        if (toolPalette_) {
            [self insertSubview:cornerView_ belowSubview:toolPalette_];
        } else {
            [self addSubview:cornerView_];
        }
        
        if (animated) {
            [self setRulerAlpha:0.0f]; // to animate, start transparent
            [UIView animateWithDuration:0.2f animations:^{ [self setRulerAlpha:0.5f]; }];
        }
    } else if (!flag) {
        if (animated) {
            [UIView animateWithDuration:0.2f
                             animations:^{ [self setRulerAlpha:0.0f]; }
                             completion:^(BOOL finished) { 
                                 [horizontalRuler_ removeFromSuperview];
                                 [verticalRuler_ removeFromSuperview];
                                 [cornerView_ removeFromSuperview]; 
                                 
                                 horizontalRuler_ = nil;
                                 verticalRuler_ = nil;
                                 cornerView_ = nil;
                             }];
        } else {
            [horizontalRuler_ removeFromSuperview];
            [verticalRuler_ removeFromSuperview];
            [cornerView_ removeFromSuperview];
            
            horizontalRuler_ = nil;
            verticalRuler_ = nil;
            cornerView_ = nil;
        }
        
    }
}

- (void) displayEyedropperAtPoint:(CGPoint)pt 
{
    if (eyedropper_) {
        return;
    }
    
    eyedropper_ = [[WDEyedropper alloc] initWithFrame:CGRectMake(0, 0, kDropperRadius * 2, kDropperRadius * 2)];
    
    pt = [self convertPointFromDocumentSpace:pt];
    eyedropper_.center = WDRoundPoint(pt);
    [eyedropper_ setBorderWidth:20];
    
    [self insertSubview:eyedropper_ belowSubview:toolPalette_];
}

- (void) moveEyedropperToPoint:(CGPoint)pt
{
    pt = [self convertPointFromDocumentSpace:pt];
    eyedropper_.center = WDRoundPoint(pt);
}

- (void) dismissEyedropper
{
    [UIView animateWithDuration:kDropperAnimationDuration
                     animations:^{ eyedropper_.alpha = 0.0f; eyedropper_.transform = CGAffineTransformMakeScale(0.1f, 0.1f); }
                     completion:^(BOOL finished) {
                         [eyedropper_ removeFromSuperview];
                         eyedropper_ = nil;
                     }];
}

- (void) invalidateSelectionView
{
    [selectionView_ drawView];
}

- (void) scaleDocumentToFit
{
    if (!drawing_) {
        return;
    }
    
    float   documentAspect = drawing_.dimensions.width / drawing_.dimensions.height;
    float   boundsAspect = CGRectGetWidth(self.bounds) / CGRectGetHeight(self.bounds);
    float   scale;
    
    if (documentAspect > boundsAspect) {
        scale = (CGRectGetWidth(self.bounds) - (kFitBuffer * 2)) / drawing_.dimensions.width;
    } else {
        scale = (CGRectGetHeight(self.bounds) - (kFitBuffer * 2)) / drawing_.dimensions.height;
    }
    
    [self setTrueViewScale_:scale];
    
    userSpacePivot_ = CGPointMake(drawing_.dimensions.width / 2, drawing_.dimensions.height / 2);
    deviceSpacePivot_ = WDCenterOfRect(self.bounds);
    
    [self rebuildViewTransform_];
}

- (void) setViewScale:(float)scale
{
    viewScale_ = scale;
    [controller_ updateTitle];
}

- (CGSize) documentSize
{
    return drawing_.dimensions;
}

- (CGRect) visibleRect
{
    CGRect              rect = self.bounds;
    CGAffineTransform   invert = transform_;
    
    invert = CGAffineTransformInvert(invert);
    rect = CGRectApplyAffineTransform(rect, invert);
    
    return rect;
}

- (float) backgroundGrayLevel
{
    return 0.9f;
}

- (float) backgroundOpacity
{
    return 0.8f;
}

- (float) effectiveBackgroundGray
{
    // opaque version of the background gray blended over white
    return [self backgroundGrayLevel] * [self backgroundOpacity] + (1.0f - [self backgroundOpacity]);
}

- (void) drawDocumentBorder:(CGContextRef)ctx
{
    // draw the document border
    CGRect docBounds = CGRectMake(0, 0, drawing_.dimensions.width, drawing_.dimensions.height);
    docBounds = CGContextConvertRectToDeviceSpace(ctx, docBounds);
    docBounds = CGRectIntegral(docBounds);
    docBounds = CGRectInset(docBounds, 0.5f, 0.5f);
    docBounds = CGContextConvertRectToUserSpace(ctx, docBounds);
    
    CGContextAddRect(ctx, [self visibleRect]);
    CGContextAddRect(ctx, docBounds);
    CGContextSetGrayFillColor(ctx, [self backgroundGrayLevel], [self backgroundOpacity]);
    CGContextEOFillPath(ctx);
    
    CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 1);
    CGContextSetLineWidth(ctx, 1.0f / (viewScale_ * [UIScreen mainScreen].scale));
    CGContextStrokeRect(ctx, docBounds);
}    

// don't draw gridlines too close together
- (float) effectiveGridSpacing:(CGContextRef)ctx
{
    float   gridSpacing = drawing_.gridSpacing;
    CGRect  testRect = CGRectMake(0, 0, gridSpacing, gridSpacing);
    float   adjustmentFactor = 1;
    
    testRect = CGContextConvertRectToDeviceSpace(ctx, testRect);
    if (CGRectGetWidth(testRect) < 10) {
        adjustmentFactor = 10.0f / CGRectGetWidth(testRect);
    }
    
    return gridSpacing * adjustmentFactor;
}

- (void) drawGrid:(CGContextRef)ctx
{
    CGRect      docBounds = CGRectMake(0, 0, drawing_.dimensions.width, drawing_.dimensions.height);
    CGRect      visibleRect = self.visibleRect;
    float       gridSpacing = [self effectiveGridSpacing:ctx];
    CGPoint     pt;
    
    // just draw lines in the portion of the document that's actually visible
    visibleRect = CGRectIntersection(visibleRect, docBounds);
    if (CGRectEqualToRect(visibleRect, CGRectNull)) {
        // if there's no intersection, bail early
        return;
    }
    
    CGContextSaveGState(ctx);
    CGContextSetLineWidth(ctx, 1.0f / (viewScale_ * [UIScreen mainScreen].scale));
    
    float startY = floor(CGRectGetMinY(visibleRect) / gridSpacing);
    float startX = floor(CGRectGetMinX(visibleRect) / gridSpacing);
    
    startX *= gridSpacing;
    startY *= gridSpacing;
    
    for (float y = startY; y <= CGRectGetMaxY(visibleRect); y += gridSpacing) {
        pt = WDSharpPointInContext(CGPointMake(0, y), ctx);
        CGContextMoveToPoint(ctx, pt.x, pt.y);
        
        pt = WDSharpPointInContext(CGPointMake(CGRectGetWidth(docBounds), y), ctx);
        CGContextAddLineToPoint(ctx, pt.x, pt.y);
    }
    
    for (float x = startX; x <= CGRectGetMaxX(visibleRect); x += gridSpacing) {
        pt = WDSharpPointInContext(CGPointMake(x, 0), ctx);
        CGContextMoveToPoint(ctx, pt.x, pt.y);
        
        pt = WDSharpPointInContext(CGPointMake(x, CGRectGetHeight(docBounds)), ctx);
        CGContextAddLineToPoint(ctx, pt.x, pt.y);
    }
    
    CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 0.125);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
}

- (void) drawIsolationInContext:(CGContextRef)ctx rect:(CGRect)rect
{
    if (!isolationColor_) {
        isolationColor_ = [UIColor colorWithPatternImage:[UIImage imageNamed:@"isolate.png"]];
        isolationColor_ = [isolationColor_ colorWithAlphaComponent:0.9];
    }
    
    [isolationColor_ set];
    CGContextFillRect(ctx, rect);
}

- (float) thinWidth
{
    return 1.0f / (viewScale_ * [UIScreen mainScreen].scale);
}

- (void)drawRect:(CGRect)rect
{
    if (!drawing_) {
        CGContextRef    ctx = UIGraphicsGetCurrentContext();
        
        CGContextSetRGBFillColor(ctx, 0.941f, 0.941f, 0.941f, 1.0f);
        CGContextFillRect(ctx, self.bounds);

        return;
    }
    
    if (controlGesture_) {
        [self invalidateSelectionView];
        return;
    }
    
    CGContextRef    ctx = UIGraphicsGetCurrentContext();
    BOOL            drawingIsolatedLayer = (!controlGesture_ && drawing_.isolateActiveLayer);
    BOOL            outlineMode = drawing_.outlineMode;
    
#ifdef WD_DEBUG
    NSDate          *date = [NSDate date];
#endif
    
    if (DEBUG_DIRTY_RECTS) {
        [[WDColor randomColor] set];
        CGContextFillRect(ctx, rect);
    }
    
    // map the clip rect back into document space
    CGAffineTransform   invert = transform_;
    invert = CGAffineTransformInvert(invert);
    rect = CGRectApplyAffineTransform(rect, invert);
    
    CGContextSaveGState(ctx);
    CGContextConcatCTM(ctx, transform_);
    
    if (drawing_.showGrid && !drawingIsolatedLayer) {
        [self drawGrid:ctx];
    }
    
    if (outlineMode) {
        [[UIColor darkGrayColor] set];
        CGContextSetLineWidth(ctx, self.thinWidth);
    }
    
    WDLayer *activeLayer = drawing_.activeLayer;
    
    if (!controlGesture_) {
        CGContextSaveGState(ctx);
        
        // make sure blending modes behave correctly
        if (!outlineMode) {
            CGContextBeginTransparencyLayer(ctx, NULL);
        }
        
        for (WDLayer *layer in drawing_.layers) {
            if (layer.hidden || (drawingIsolatedLayer && (layer == activeLayer))) {
                continue;
            }
            
            [layer renderInContext:ctx
                          clipRect:rect
                          metaData:WDRenderingMetaDataMake(viewScale_, outlineMode ? WDRenderOutlineOnly : WDRenderDefault)];
        }
        
        if (drawingIsolatedLayer) {
            // gray out lower contents
            [self drawIsolationInContext:ctx rect:rect];
            
            if (drawing_.showGrid) {
                [self drawGrid:ctx];
            }
            
            // draw the active layer
            if (activeLayer.visible) {
                if (outlineMode) {
                    [[UIColor darkGrayColor] set];
                    CGContextSetLineWidth(ctx, self.thinWidth);
                }
                
                [activeLayer renderInContext:ctx
                                    clipRect:rect
                                    metaData:WDRenderingMetaDataMake(viewScale_, outlineMode ? WDRenderOutlineOnly : WDRenderDefault)];
            }
        }
        
        if (!outlineMode) {
            CGContextEndTransparencyLayer(ctx);
        }
        
        CGContextRestoreGState(ctx);
    }
    
    [self drawDocumentBorder:ctx];
    
    CGContextRestoreGState(ctx);

#ifdef WD_DEBUG
    NSLog(@"Canvas render time: %f", -[date timeIntervalSinceNow]);
#endif
    
    // this needs to redraw too... do it at the end of the runloop to avoid an occassional flash after pinch zooming
    [selectionView_ performSelector:@selector(drawView) withObject:nil afterDelay:0];
}

- (void) rotateToInterfaceOrientation
{
    if (!selectionView_) {
        selectionView_ = [[WDSelectionView alloc] initWithFrame:self.bounds];
        [self addSubview:selectionView_];
        [self sendSubviewToBack:selectionView_];
        selectionView_.canvas = self;
    }
    
    if (!eraserPreview_ && eraserPath_) {
        eraserPreview_ = [[WDEraserPreviewView alloc] initWithFrame:self.bounds];
        [self insertSubview:eraserPreview_ aboveSubview:selectionView_];
        eraserPreview_.canvas = self;
    }
    
    [self positionToolOptionsView];
    
    [self rebuildViewTransform_];
}

- (void) offsetUserSpacePivot:(CGPoint)delta
{
    userSpacePivot_ = WDAddPoints(userSpacePivot_, delta);
}

- (void) rebuildViewTransform_
{    
    transform_ = CGAffineTransformMakeTranslation(deviceSpacePivot_.x, deviceSpacePivot_.y);
    transform_ = CGAffineTransformScale(transform_, viewScale_, viewScale_);
    transform_ = CGAffineTransformTranslate(transform_, -userSpacePivot_.x, -userSpacePivot_.y);
    
    [horizontalRuler_ setNeedsDisplay];
    [verticalRuler_ setNeedsDisplay];
    
    [self setNeedsDisplay];
    
    if (pivotView_) {
        pivotView_.sharpCenter = CGPointApplyAffineTransform(pivot_, transform_);
    }
}

- (void) offsetByDelta:(CGPoint)delta
{
    deviceSpacePivot_ = WDAddPoints(deviceSpacePivot_, delta);
    [self rebuildViewTransform_];
}

- (float) displayableScale
{    
    float printSizeFactor = [drawing_.units isEqualToString:@"Pixels"] ? 1.0f : kPrintSizeFactor;
  
    return round(self.viewScale * 100 * printSizeFactor);
}

- (void) setTrueViewScale_:(float)scale
{
    trueViewScale_ = scale;
    
    float hundredPercentScale = [drawing_.units isEqualToString:@"Pixels"] ? 1.0f : kHundredPercentScale;
    
    if (trueViewScale_ > (hundredPercentScale * 0.95f) && trueViewScale_ < (hundredPercentScale * 1.05)) {
        self.viewScale = hundredPercentScale;
    } else {
        self.viewScale = trueViewScale_;
    }
}

- (void) scaleBy:(double)scale
{
    float   maxDimension = MAX(self.drawing.width, self.drawing.height);
    // at the minimum zoom, the drawing will be 200 effective screen pixels wide (or tall)
    double  minZoom = (200 / maxDimension);
    
    if (scale * viewScale_ > kMaxZoom) {
        scale = kMaxZoom / viewScale_;
    } else if (scale * viewScale_ < minZoom) {
        scale = minZoom / viewScale_;
    }
    
    [self setTrueViewScale_:trueViewScale_ * scale];
    [self rebuildViewTransform_];
}

/*
 * called from within touchesMoved:withEvent:
 */
- (void) gestureMovedWithEvent:(UIEvent *)event
{
    UIView  *superview = self.superview;
    NSSet   *touches = [event allTouches];
    
    if ([touches count] == 1) {
        // with 1 finger down, pan only
        UITouch *touch = [touches anyObject];
        
        CGPoint delta = WDSubtractPoints([touch locationInView:superview], [touch previousLocationInView:superview]);
        [self offsetByDelta:delta];
        
        return;
    }
    
    NSArray *allTouches = [touches allObjects];
    UITouch *first = allTouches[0];
    UITouch *second = allTouches[1];
    
    // compute the scaling
    double oldDistance = WDDistance([first previousLocationInView:superview], [second previousLocationInView:superview]);
    double distance = WDDistance([first locationInView:superview], [second locationInView:superview]);
    
    // ignore touches that are too close together -- seems to confuse the phone
    if (distance > 80 && oldDistance > 80) {
        deviceSpacePivot_ = WDAveragePoints([first locationInView:self], [second locationInView:self]);
        [self scaleBy:(distance / oldDistance)]; 
    }
}

- (CGRect) convertRectToView:(CGRect)rect
{
    return CGRectApplyAffineTransform(rect, transform_);
}

- (CGPoint) convertPointToDocumentSpace:(CGPoint)pt
{
    CGAffineTransform invert = transform_;
    invert = CGAffineTransformInvert(invert);
    return CGPointApplyAffineTransform(pt, invert); 
}
          
- (CGPoint) convertPointFromDocumentSpace:(CGPoint)pt
{
    return CGPointApplyAffineTransform(pt, transform_); 
}

- (BOOL) canSendTouchToActiveTool
{
    WDTool *activeTool = [WDToolManager sharedInstance].activeTool;
    BOOL    locked = drawing_.activeLayer.locked;
    BOOL    hidden = drawing_.activeLayer.hidden;
    
    if (activeTool.createsObject && (locked || hidden)) {
        if (locked && hidden) {
            [self showMessage:NSLocalizedString(@"The active layer is locked and hidden.", @"The active layer is locked and hidden.")];
        } else if (locked) {
            [self showMessage:NSLocalizedString(@"The active layer is locked.", @"The active layer is locked.")];
        } else {
            [self showMessage:NSLocalizedString(@"The active layer is hidden.", @"The active layer is hidden.")];
        }
        
        return NO;
    }
    
    return YES;
}

- (void) touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    NSSet *eventTouches = [event allTouches];
    
    [controller_ hidePopovers];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WDCanvasBeganTrackingTouches object:self];
    
    BOOL resetPivots = NO;
    
    if (!moved_ && [eventTouches count] == 2) {
        controlGesture_ = YES;
        resetPivots = YES;
        
        [self setNeedsDisplay];
    } else if (controlGesture_ && [eventTouches count] == 2) {
        resetPivots = YES;
    } else if (!controlGesture_ && moved_ && [self canSendTouchToActiveTool]) {
        [[WDToolManager sharedInstance].activeTool touchesBegan:touches withEvent:event inCanvas:self];
    }
    
    if (resetPivots) {
        NSArray *allTouches = [eventTouches allObjects];
        UITouch *first = allTouches[0];
        UITouch *second = allTouches[1];
        
        deviceSpacePivot_ = WDAveragePoints([first locationInView:self], [second locationInView:self]);
        CGAffineTransform invert = transform_;
        invert = CGAffineTransformInvert(invert);
        userSpacePivot_ = CGPointApplyAffineTransform(deviceSpacePivot_, invert);
    }
}

- (void) touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
    if (!moved_) {
        moved_ = YES;
        
        if (!controlGesture_ && [self canSendTouchToActiveTool]) {
            if (![[WDToolManager sharedInstance].activeTool isKindOfClass:[WDPenTool class]]) {
                self.drawingController.activePath = nil;
            }
            
            [[WDToolManager sharedInstance].activeTool touchesBegan:touches withEvent:event inCanvas:self];
            return;
        }
    }
    
    if (controlGesture_) {
        [self gestureMovedWithEvent:event];
    } else if ([self canSendTouchToActiveTool]) {
        [[WDToolManager sharedInstance].activeTool touchesMoved:touches withEvent:event inCanvas:self];
    }
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    BOOL allTouchesAreEnding = YES;
    
    for (UITouch *touch in event.allTouches) {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) {
            allTouchesAreEnding = NO;
            break;
        }
    }
    
    if (!controlGesture_ && [self canSendTouchToActiveTool]) {
        if (!moved_) {
            [[WDToolManager sharedInstance].activeTool touchesBegan:touches withEvent:event inCanvas:self];
        }
        [[WDToolManager sharedInstance].activeTool touchesEnded:touches withEvent:event inCanvas:self];
    }
    
    if (allTouchesAreEnding) {
        if (controlGesture_) {
            controlGesture_ = NO;
            [self setNeedsDisplay];
        }
        
        moved_ = NO;
    }
}
    
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self nixMessageLabel];
}

- (BOOL) isZooming
{
    return controlGesture_;
}

- (void) hideAccessoryViews
{
    [self hideTools];
    toolOptionsView_.hidden = YES;
    pivotView_.hidden = YES;
}

- (void) showAccessoryViews
{
    [self showTools];
    toolOptionsView_.hidden = NO;
    pivotView_.hidden = NO;
}

- (void) hideTools
{
    if (!toolPalette_) {
        return;
    }
    
    toolPalette_.hidden = YES;
}

- (void) showTools
{
    if (toolPalette_) {
        toolPalette_.hidden = NO;
        return;
    }
    
    WDToolView *tools = [[WDToolView alloc] initWithTools:[WDToolManager sharedInstance].tools];
    tools.canvas = self;
    
    CGRect frame = tools.frame;
    frame.size.height += [WDToolButton dimension] + 4;
    float bottom = CGRectGetHeight(tools.frame);
    
    // create a base view for all the palette elements
    UIView *paletteView = [[UIView alloc] initWithFrame:frame];
    [paletteView addSubview:tools];
    
    // add a separator
    WDEtchedLine *line = [[WDEtchedLine alloc] initWithFrame:CGRectMake(2, bottom + 1, CGRectGetWidth(frame) - 4, 2)];
    [paletteView addSubview:line];
    
    // add a "delete" buttton
    deleteButton_ = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *icon = [[UIImage imageNamed:@"trash.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    deleteButton_.frame = CGRectMake(0, bottom + 3, [WDToolButton dimension], [WDToolButton dimension]);
    [deleteButton_ setImage:icon forState:UIControlStateNormal];
    deleteButton_.tintColor = [UIColor colorWithRed:(166.0f / 255.0f) green:(51.0f / 255.0f) blue:(51.0 / 255.0f) alpha:1.0f];
    [deleteButton_ addTarget:self.controller action:@selector(delete:) forControlEvents:UIControlEventTouchUpInside];
    deleteButton_.enabled = NO;
    [paletteView addSubview:deleteButton_];
    
    toolPalette_ = [WDPalette paletteWithBaseView:paletteView defaultsName:@"tools palette"];
    [self addSubview:toolPalette_];
    
    [self ensureToolPaletteIsOnScreen];
}

- (void) transformSelection:(CGAffineTransform)transform
{
    selectionTransform_ = transform;
    [self invalidateSelectionView];
}

- (void) setTransforming:(BOOL)transforming
{
    transforming_ = transforming;
}

- (void) selectionChanged:(NSNotification *)aNotification
{
    deleteButton_.enabled = (self.drawingController.selectedObjects.count > 0) ? YES : NO;
    
    [self setShowsPivot:[WDToolManager sharedInstance].activeTool.needsPivot];
    [self invalidateSelectionView];
}

- (void) invalidateFromNotification:(NSNotification *)aNotification
{
    NSValue     *rectValue = [aNotification userInfo][@"rect"];
    NSArray     *rects = [aNotification userInfo][@"rects"];
    CGRect      dirtyRect;
    float       fudge = (-1.0f) / viewScale_;
    
    if (rectValue) {
        dirtyRect = [rectValue CGRectValue];
        
        if (!CGRectEqualToRect(dirtyRect, CGRectNull)) {
            dirtyRect = CGRectApplyAffineTransform(dirtyRect, self.canvasTransform);
            if (drawing_.outlineMode) {
                dirtyRect = CGRectInset(dirtyRect, fudge, fudge);
            }
            [self setNeedsDisplayInRect:dirtyRect];
        }
    } else if (rects) {
        for (NSValue *rectValue in rects) {
            dirtyRect = [rectValue CGRectValue];
            
            if (!CGRectEqualToRect(dirtyRect, CGRectNull)) {
                dirtyRect = CGRectApplyAffineTransform(dirtyRect, self.canvasTransform);
                if (drawing_.outlineMode) {
                    dirtyRect = CGRectInset(dirtyRect, fudge, fudge);
                }
                [self setNeedsDisplayInRect:dirtyRect];
            }
        }
    } else {
        [self setNeedsDisplay];
    }
}

- (void) setPivot:(CGPoint)pivot
{
    if (self.drawingController.selectedObjects.count == 0) {
        return;
    }
    
    pivot_ = pivot;
    
    if (!pivotView_) {
        pivotView_ = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pivot.png"]];
        [self insertSubview:pivotView_ atIndex:0];
    }
    
    pivotView_.sharpCenter = CGPointApplyAffineTransform(pivot, transform_);
}

- (void) setShowsPivot:(BOOL)showsPivot
{
    if (self.drawingController.selectedObjects.count == 0) {
        showsPivot = NO;
    }
        
    if (showsPivot == showingPivot_) {
        return;
    }
    
    showingPivot_ = showsPivot;
    
    if (showsPivot) {
        [self setPivot:WDCenterOfRect([self.drawingController selectionBounds])];
    } else if (pivotView_) {
        [pivotView_ removeFromSuperview];
        pivotView_ = nil;
    }
}

- (void) positionToolOptionsView
{
    toolOptionsView_.sharpCenter = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMaxY(self.bounds) - (CGRectGetHeight(toolOptionsView_.frame) / 2) - 15);
}

- (void) setToolOptionsView:(UIView *)toolOptionsView
{
    [toolOptionsView_ removeFromSuperview];
    
    toolOptionsView_ = toolOptionsView;
    [self positionToolOptionsView];
    
    [self insertSubview:toolOptionsView_ belowSubview:toolPalette_];
}

- (void) setMarquee:(NSValue *)marquee
{
    marquee_ = marquee;
    [self invalidateSelectionView];
}

- (void) setDynamicGuides:(NSArray *)dynamicGuides
{
    dynamicGuides_ = dynamicGuides;
    [self invalidateSelectionView];
}

- (void) setShapeUnderConstruction:(WDPath *)path
{
    shapeUnderConstruction_ = path;
    
    path.layer = drawing_.activeLayer;
    [self invalidateSelectionView];
}

- (void) setEraserPath:(WDPath *)eraserPath
{
    eraserPath_ = eraserPath;
    
    if (eraserPath && !eraserPreview_) {
        eraserPreview_ = [[WDEraserPreviewView alloc] initWithFrame:self.bounds];
        [self insertSubview:eraserPreview_ aboveSubview:selectionView_];
        eraserPreview_.canvas = self;
    }
    
    if (!eraserPath && eraserPreview_) {
        [eraserPreview_ removeFromSuperview];
        eraserPreview_ = nil;
    }
    
    [eraserPreview_ setNeedsDisplay];
}

- (void) startActivity
{
    if (!activityView_) {
        [[NSBundle mainBundle] loadNibNamed:@"Activity" owner:self options:nil];
    }
    
    activityView_.sharpCenter = WDCenterOfRect(self.bounds);
    [self addSubview:activityView_];
    
    CALayer *layer = activityView_.layer;
    layer.cornerRadius = CGRectGetWidth(activityView_.frame) / 2;
}

- (void) stopActivity
{
    if (activityView_) {
        [activityView_ removeFromSuperview];
        activityView_ = nil;
    }
}

- (void) cacheVisibleRectCenter
{
    cachedCenter_ = WDCenterOfRect(self.visibleRect);
}

- (void) setVisibleRectCenterFromCached
{
    CGPoint delta = WDSubtractPoints(cachedCenter_, WDCenterOfRect(self.visibleRect));
    [self offsetUserSpacePivot:delta];
}

- (void) ensureToolPaletteIsOnScreen
{
    [toolPalette_ bringOnScreen];
}

- (void) keyboardWillShow:(NSNotification *)aNotification
{
    NSValue *endFrame = [aNotification userInfo][UIKeyboardFrameEndUserInfoKey];
    CGRect frame = [endFrame CGRectValue];
    
    frame = [self convertRect:frame fromView:nil];
    
    if (self.drawingController.selectedObjects.count == 1) {
        WDElement *selectedObject = [self.drawingController.selectedObjects anyObject];
        
        if ([selectedObject hasEditableText]) {
            CGPoint top = WDCenterOfRect(selectedObject.bounds);
            top = CGPointApplyAffineTransform(top, transform_);
            
            if (top.y > CGRectGetMinY(frame)) {
                float offset = (CGRectGetMinY(frame) - top.y);
                deviceSpacePivot_.y += offset;
                [self rebuildViewTransform_];
            }
        }
    }
}

- (void) nixMessageLabel
{
    if (messageTimer_) {
        [messageTimer_ invalidate];
        messageTimer_ = nil;
    }
    
    if (messageLabel_) {
        [messageLabel_ removeFromSuperview];
        messageLabel_ = nil;
    }
}

- (void) hideMessage:(NSTimer *)timer
{
    [self nixMessageLabel];
}

- (void) showMessage:(NSString *)message
{
    if (!messageLabel_) {
        messageLabel_ = [[UILabel alloc] init];
        messageLabel_.textColor = [UIColor blackColor];
        messageLabel_.font = [UIFont systemFontOfSize:32];
        messageLabel_.textAlignment = NSTextAlignmentCenter;
        messageLabel_.backgroundColor = [UIColor colorWithHue:0.0f saturation:0.4f brightness:1.0f alpha:0.8f];
        messageLabel_.shadowColor = [UIColor whiteColor];
        messageLabel_.shadowOffset = CGSizeMake(0, 1);
        messageLabel_.layer.cornerRadius = 16;
    }
    
    messageLabel_.text = message;
    [messageLabel_ sizeToFit];
    
    CGRect frame = messageLabel_.frame;
    frame = CGRectInset(frame, -20, -15);
    messageLabel_.frame = frame;
    
    messageLabel_.sharpCenter = WDCenterOfRect(self.bounds);
    
    if (messageLabel_.superview != self) {
        [self insertSubview:messageLabel_ belowSubview:toolPalette_];
    }
    
    // start message dismissal timer
    
    if (messageTimer_) {
        [messageTimer_ invalidate];
    }
    
    messageTimer_ = [NSTimer scheduledTimerWithTimeInterval:kMessageFadeDelay
                                                     target:self
                                                   selector:@selector(hideMessage:)
                                                   userInfo:nil
                                                    repeats:NO];
}

@end
