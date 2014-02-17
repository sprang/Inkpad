//
//  WDDrawingController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "WDElement.h"

@class WDAbstractPath;
@class WDBezierNode;
@class WDColor;
@class WDDrawing;
@class WDDynamicGuideController;
@class WDElement;
@class WDLayer;
@class WDPath;
@class WDPickResult;
@class WDPropertyManager;
@class WDText;
@class WDTextPath;

@interface WDDrawingController : NSObject

@property (nonatomic, strong) WDDrawing *drawing;
@property (nonatomic, readonly) NSMutableSet *selectedObjects;
@property (weak, nonatomic, readonly) NSMutableSet *selectedPaths;
@property (nonatomic, readonly) NSMutableSet *selectedNodes;
@property (nonatomic, strong) WDPath *activePath;
@property (nonatomic, strong) WDBezierNode *tempDisplayNode;
@property (nonatomic, strong) WDPropertyManager *propertyManager;
@property (nonatomic, assign) CGAffineTransform lastAppliedTransform;
@property (nonatomic, strong) NSMutableArray *undoSelectionStack;
@property (nonatomic, strong) NSMutableArray *redoSelectionStack;
@property (nonatomic, readonly) WDDynamicGuideController *dynamicGuideController;

// node selection
- (void) selectNode:(WDBezierNode *)node;
- (void) deselectNode:(WDBezierNode *)node;
- (void) deselectAllNodes;
- (BOOL) isNodeSelected:(WDBezierNode *)node;

// querying selection state
- (WDElement *) singleSelection;
- (NSMutableArray *) orderedSelectedObjects;
- (NSArray *) sortedSelectionForLayer:(WDLayer *)layer;
- (NSArray *) guideGeneratingObjects;

- (BOOL) isSelected:(WDElement *)element;
- (BOOL) isSelectedOrSubelementIsSelected:(WDElement *)element;

- (CGRect) selectionBounds;
- (CGRect) selectionStyleBounds;

- (NSSet *) selectedPaths;
- (BOOL) allSelectedObjectsAreRootObjects;

// selection
- (void) notifySelectionChanged;

// actions
- (void) selectObject:(WDElement *)element;
- (void) selectObjects:(NSArray *)elements;
- (void) deselectObject:(WDElement *)element;
- (void) deselectObjectAndSubelements:(WDElement *)element;
- (void) selectObjectsInRect:(CGRect)rect;

- (void) selectNone:(id)sender;
- (void) selectAll:(id)sender;
- (void) selectAllOnActiveLayer:(id)sender;
- (void) delete:(id)sender;

// pasteboard
- (void) cut:(id)sender;
- (void) copy:(id)sender;
- (void) duplicateInPlace:(id)sender;
- (void) duplicate:(id)sender;
- (void) duplicateAndTransformAgain:(id)sender;
- (void) paste:(id)sender;

// path actions
- (void) addAnchors:(id)sender;
- (void) deleteAnchors:(id)sender;
- (void) reversePathDirection:(id)sender;
- (void) outlineStroke:(id)sender;
- (void) joinPaths:(id)sender;
- (void) setActivePath:(WDPath *)path;

// grouping
- (void) group:(id)sender;
- (void) ungroup:(id)sender;

// compound paths
- (void) makeCompoundPath:(id)sender;
- (void) releaseCompoundPath:(id)sender;

// masking
- (void) makeMask:(id)sender;
- (void) releaseMask:(id)sender;

// boolean path operations
- (void) unitePaths:(id)sender;
- (void) intersectPaths:(id)sender;
- (void) subtractPaths:(id)sender;
- (void) eraseWithPath:(WDAbstractPath *)erasePath;
- (void) excludePaths:(id)sender;

// image placement
- (void) placeImage:(UIImage *)image;

// styles
- (void) setValue:(id)value forProperty:(NSString *)property;

// arrange
- (void) bringForward:(id)sender;
- (void) bringToFront:(id)sender;
- (void) sendBackward:(id)sender;
- (void) sendToBack:(id)sender;

// transform
- (void) transformSelection:(CGAffineTransform)transform;
- (void) transformAgain:(id)sender;

- (void) align:(WDAlignment)alignment;

- (void) flipHorizontally:(id)sender;
- (void) flipVertically:(id)sender;

- (void) distributeHorizontally:(id)sender;
- (void) distributeVertically:(id)sender;

- (void) nudge:(unichar)arrowKey;

// text
- (WDText *) createTextObjectInRect:(CGRect)rect;
- (void) createTextObjectWithText:(NSString *)string;
- (WDTextPath *) placeTextOnPath:(id)sender shouldStartEditing:(BOOL *)startEditing;
- (void) createTextOutlines:(id)sender;
- (void) resetTextTransform:(id)sender;

// color operations
- (void) tossCachedColorAdjustmentData;
- (void) restoreCachedColorAdjustmentData;
- (void) registerUndoWithCachedColorAdjustmentData;
- (void) adjustColor:(WDColor * (^)(WDColor *color))adjustment scope:(WDColorAdjustmentScope)scope;

- (NSArray *) blendables;
- (void) blendColorBackToFront:(id)sender;
- (void) blendColorHorizontally:(id)sender;
- (void) blendColorVertically:(id)sender;
- (void) desaturate:(id)sender;
- (void) invertColors:(id)sender;

// hit testing
- (WDPickResult *) snappedPoint:(CGPoint)pt viewScale:(float)viewScale snapFlags:(int)flags;
- (WDPickResult *) inspectableUnderPoint:(CGPoint)pt viewScale:(float)viewScale;
- (WDPickResult *) objectUnderPoint:(CGPoint)pt viewScale:(float)viewScale;

// can do methods
- (BOOL) canPaste;
- (BOOL) canJoinPaths;
- (BOOL) canMakeCompoundPath;
- (BOOL) canReleaseCompoundPath;
- (BOOL) canMakeMask;
- (BOOL) canReleaseMask;
- (BOOL) canGroup;
- (BOOL) canUngroup;
- (BOOL) canAddAnchors;
- (BOOL) canDeleteAnchors;
- (BOOL) canReversePathDirection;
- (BOOL) canOutlineStroke;
- (BOOL) canCreateTextOutlines;
- (BOOL) canPlaceTextOnPath;
- (BOOL) canAdjustColor;

@end

// notifications
extern NSString *WDPasteboardDataType;
extern NSString *WDSelectionChangedNotification;
