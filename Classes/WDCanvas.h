//
//  WDCanvas.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@class WDCanvas;
@class WDCanvasController;
@class WDDrawing;
@class WDDrawingController;
@class WDEraserPreviewView;
@class WDEyedropper;
@class WDPalette;
@class WDPath;
@class WDRulerCornerView;
@class WDRulerView;
@class WDSelectionView;

@interface WDCanvas : UIView {
    WDSelectionView         *selectionView_;
    WDEraserPreviewView     *eraserPreview_;
    
    BOOL                    controlGesture_;
    BOOL                    moved_;
    BOOL                    transforming_;
    BOOL                    transformingNode_;
    BOOL                    showingPivot_;
    CGAffineTransform       selectionTransform_;
    CGPoint                 pivot_;
    UIColor                 *isolationColor_;
    
    NSValue                 *marquee_;
    WDPath                  *shapeUnderConstruction_;
    WDPath                  *eraserPath_;
    
    // managing the view scale and visible area
    float                   trueViewScale_;
    float                   viewScale_;
    CGAffineTransform       transform_;
    CGPoint                 userSpacePivot_;
    CGPoint                 deviceSpacePivot_;
    CGPoint                 oldDeviceSpacePivot_;
    
    // adornments
    UIImageView             *pivotView_;
    WDEyedropper            *eyedropper_;
    
    // rulers
    WDRulerView             *horizontalRuler_;
    WDRulerView             *verticalRuler_;
    WDRulerCornerView       *cornerView_;
    
    WDPalette               *toolPalette_;
    CGPoint                 cachedCenter_;
    
    UILabel                 *messageLabel_;
    NSTimer                 *messageTimer_;
}

@property (nonatomic, weak) WDDrawing *drawing;
@property (nonatomic) WDSelectionView *selectionView;
@property (nonatomic) WDEraserPreviewView *eraserPreview;
@property (nonatomic, readonly) CGAffineTransform canvasTransform;
@property (nonatomic, readonly) CGAffineTransform selectionTransform;
@property (nonatomic, readonly) CGRect visibleRect;
@property (nonatomic, readonly) BOOL isZooming;
@property (nonatomic, assign) float viewScale;
@property (nonatomic, readonly) float displayableScale;
@property (nonatomic, assign) BOOL transforming;
@property (nonatomic, assign) BOOL transformingNode;
@property (nonatomic, assign) CGPoint pivot;
@property (nonatomic, assign) BOOL showingPivot;
@property (nonatomic, strong) NSValue *marquee;
@property (nonatomic, strong) WDPath *shapeUnderConstruction;
@property (nonatomic, strong) WDPath *eraserPath;
@property (nonatomic, weak) WDCanvasController *controller;
@property (weak, nonatomic, readonly) WDDrawingController *drawingController;
@property (nonatomic, strong, readonly) WDPalette *toolPalette;
@property (nonatomic, readonly) WDEyedropper *eyedropper;
@property (nonatomic, readonly) WDRulerView *horizontalRuler;
@property (nonatomic, readonly) WDRulerView *verticalRuler;
@property (nonatomic, weak) UIView *toolOptionsView;
@property (nonatomic, readonly) float thinWidth;
@property (nonatomic, strong) IBOutlet UIView *activityView;

- (CGRect) convertRectToView:(CGRect)rect;
- (CGPoint) convertPointToDocumentSpace:(CGPoint)pt;
- (CGPoint) convertPointFromDocumentSpace:(CGPoint)pt;
- (void) transformSelection:(CGAffineTransform)transform;
- (void) setShowsPivot:(BOOL)showsPivot;

- (void) offsetByDelta:(CGPoint)delta;
- (void) scaleBy:(double)scale;
- (void) scaleDocumentToFit;
- (void) rotateToInterfaceOrientation;
- (void) offsetUserSpacePivot:(CGPoint)delta;

- (void) hideAccessoryViews;
- (void) showAccessoryViews;

- (void) hideTools;
- (void) showTools;

- (void) showRulers:(BOOL)flag;
- (void) showRulers:(BOOL)flag animated:(BOOL)animated;

- (void) startActivity;
- (void) stopActivity;

- (void) invalidateSelectionView;

//orientation support
- (void) cacheVisibleRectCenter;
- (void) setVisibleRectCenterFromCached;
- (void) ensureToolPaletteIsOnScreen;

// displaying messages to the user
- (void) showMessage:(NSString *)message;
- (void) nixMessageLabel;

// eyedropper

- (void) displayEyedropperAtPoint:(CGPoint)pt;
- (void) moveEyedropperToPoint:(CGPoint)pt;
- (void) dismissEyedropper;

// tool options view
- (void) positionToolOptionsView;

- (float) effectiveBackgroundGray;

@end

extern NSString *WDCanvasBeganTrackingTouches;
