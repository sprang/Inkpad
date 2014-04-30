//
//  WDPenTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDBezierNode.h"
#import "WDCanvas.h"
#import "WDDrawingController.h"
#import "WDFillTransform.h"
#import "WDInspectableProperties.h"
#import "WDPath.h"
#import "WDPathPainter.h"
#import "WDPenTool.h"
#import "WDPropertyManager.h"
#import "WDUtilities.h"

@implementation WDPenTool

@synthesize replacementNode = replacementNode_;

- (NSString *) iconName {
    return @"pen.png";
}

- (BOOL) createsObject {
    return YES;
}

- (BOOL) optionKeyDown
{
    return (self.flags & WDToolOptionKey) || (self.flags & WDToolSecondaryTouch);
}

- (void) beginWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas;
{
    CGPoint tap = event.snappedLocation;
    
    WDPath *activePath = canvas.drawingController.activePath;
    
    updatingOldNode_ = NO;
    closingPath_ = NO;
    
    if (activePath && WDDistance([activePath lastNode].anchorPoint, tap) < (25.0f / canvas.viewScale)) {
        if (event.count == 2) {
            canvas.drawingController.activePath = nil;
        } else {
            self.replacementNode = [[activePath lastNode] chopOutHandle];
            updatingOldNode_ = YES;
            oldNodeMode_ = [activePath lastNode].reflectionMode;
        }
    } else if (activePath && WDDistance([activePath firstNode].anchorPoint, tap) < (25.0f / canvas.viewScale)) {
        oldNodeMode_ = [activePath firstNode].reflectionMode;
        self.replacementNode = [activePath firstNode];
        closingPath_ = YES;
        activePath.displayClosed = YES;
    } else {
        self.replacementNode = [WDBezierNode bezierNodeWithAnchorPoint:tap];
        self.replacementNode.selected = YES;
        
        if (activePath) {
            [canvas.drawingController deselectAllNodes];
            
            NSMutableArray *displayNodes = [activePath.nodes mutableCopy];
            [displayNodes addObject:self.replacementNode];
            activePath.displayNodes = displayNodes;
        } else {
            WDPickResult *result = [canvas.drawingController snappedPoint:event.location
                                                                viewScale:canvas.viewScale
                                                                snapFlags:(kWDSnapNodes | kWDSnapSelectedOnly)];
            
            if (result.type == kWDAnchorPoint && result.nodePosition != kWDMiddleNode && [canvas.drawingController isSelected:result.element]) {
                WDPath *path = (WDPath *) result.element;
                
                if (result.nodePosition == kWDFirstNode) {
                    path.nodes = [path reversedNodes];
                    [path reversePathDirection];
                }
                
                [canvas.drawingController selectNone:nil];
                canvas.drawingController.activePath = path;
                activePath = path;
                
                updatingOldNode_ = YES;
                oldNodeMode_ = [path lastNode].reflectionMode;
                self.replacementNode = [[path lastNode] chopOutHandle];
            } else {
                [canvas.drawingController selectNone:nil];
                canvas.drawingController.tempDisplayNode = self.replacementNode;
            }
        }
    }

    // we should only reset the active path's fill transform if it is the default fill transform for the shape
    BOOL centered = [activePath.fill wantsCenteredFillTransform];
    shouldResetFillTransform_ = activePath.fillTransform && [activePath.fillTransform isDefaultInRect:activePath.bounds centered:centered];
}

- (void) moveWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{
    canvas.transforming = canvas.transformingNode = YES;
    
    CGPoint tap = event.snappedLocation;

    WDPath *activePath = canvas.drawingController.activePath;
    
    if (closingPath_) {
        WDBezierNodeReflectionMode mode = [self optionKeyDown] ? WDIndependent : oldNodeMode_;
        self.replacementNode = [self.replacementNode setInPoint:tap reflectionMode:mode];
    } else {
        WDBezierNodeReflectionMode mode = [self optionKeyDown] ? WDIndependent : (updatingOldNode_ ? oldNodeMode_ : WDReflect);
        self.replacementNode = [self.replacementNode moveControlHandle:kWDOutPoint toPoint:tap reflectionMode:mode];
    }
    
    if (activePath) {
        self.replacementNode.selected = YES;
        NSMutableArray *displayNodes = [activePath.nodes mutableCopy];
        
        if (updatingOldNode_) {
            displayNodes[(displayNodes.count - 1)] = self.replacementNode;
        } else if (closingPath_) {
            displayNodes[0] = self.replacementNode;
        } else {
            [displayNodes addObject:self.replacementNode];
        }
        
        activePath.displayNodes = displayNodes;
    } else {
        canvas.drawingController.tempDisplayNode = self.replacementNode;
    }
    
    [canvas invalidateSelectionView];
}

- (void) endWithEvent:(WDEvent *)event inCanvas:(WDCanvas *)canvas
{
    WDPath *activePath = canvas.drawingController.activePath;
    
    activePath.displayNodes = nil;
    activePath.displayClosed = NO;
    activePath.displayColor = nil;
    
    if (!activePath && self.replacementNode) {
        [canvas.drawingController selectNode:self.replacementNode];
        WDPath *path = [[WDPath alloc] initWithNode:self.replacementNode];
        
        path.fill = [canvas.drawingController.propertyManager activeFillStyle];
        path.strokeStyle = [[canvas.drawingController.propertyManager activeStrokeStyle] strokeStyleSansArrows];
        path.opacity = [[canvas.drawingController.propertyManager defaultValueForProperty:WDOpacityProperty] floatValue];
        path.shadow = [canvas.drawingController.propertyManager activeShadow];
        
        canvas.drawingController.tempDisplayNode = nil;
        [canvas.drawing addObject:path];
        
        // do this last, so that it's part of the redo selection state
        canvas.drawingController.activePath = path;
        
    } else if (self.replacementNode) {
        self.replacementNode.selected = NO;
        
        if (closingPath_) {
            [activePath replaceFirstNodeWithNode:self.replacementNode];
            activePath.closed = YES;
            
            canvas.drawingController.activePath = nil;
        } else if (updatingOldNode_) {
            [activePath replaceLastNodeWithNode:self.replacementNode];
        } else {
            [canvas.drawingController selectNode:[activePath lastNode]];
            [activePath addNode:self.replacementNode];
        }
        
        if (shouldResetFillTransform_) {
            BOOL centered = [activePath.fill wantsCenteredFillTransform];
            activePath.fillTransform = [WDFillTransform fillTransformWithRect:activePath.bounds centered:centered];
        }
        
        [canvas.drawingController deselectAllNodes];
        [canvas.drawingController selectNode:self.replacementNode];
    }
    
    self.replacementNode = nil;
    
    canvas.transforming = canvas.transformingNode = NO;
}

@end
