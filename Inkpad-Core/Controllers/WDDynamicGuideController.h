//
//  WDDynamicGuideController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import <Foundation/Foundation.h>

@class WDDynamicGuide;
@class WDDrawingController;
@class WDCanvas;

@interface WDDynamicGuideController : NSObject

@property (nonatomic, readonly) BOOL generatedGuides;
@property (nonatomic, readonly) NSMutableArray *verticalGuides;
@property (nonatomic, readonly) NSMutableArray *horizontalGuides;
@property (nonatomic, weak, readonly) WDDrawingController *drawingController;

- (id) initWithDrawingController:(WDDrawingController *)drawingController;

// guide lifecyle
- (void) beginGuideOperation;
- (void) endGuideOperation;

// querying and adding guides
- (double) deltaForGuide:(WDDynamicGuide *)guide array:(NSArray *)guides;
- (WDDynamicGuide *) findCoincidentGuide:(WDDynamicGuide *)guide array:(NSArray *)guides;
- (void) insertGuide:(WDDynamicGuide *)guide array:(NSMutableArray *)guides;

// calculating offsets
- (CGPoint) adjustedPointForGuides:(CGPoint)pt viewScale:(float)viewScale;
- (CGPoint) offsetSelectionForGuides:(CGPoint)originalDelta viewScale:(float)viewScale;

// finding snapped guides
- (NSArray *) snappedGuidesForPoint:(CGPoint)pt;
- (NSArray *) snappedGuidesForRect:(CGRect)snapRect;

@end
