//
//  WDDrawingController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#endif

#import "NSArray+Additions.h"
#import "NSString+Additions.h"
#import "UIImage+Additions.h"
#import "WDAbstractPath.h"
#import "WDBezierNode.h"
#import "WDColor.h"
#import "WDCompoundPath.h"
#import "WDDrawing.h"
#import "WDDrawingController.h"
#import "WDFontManager.h"
#import "WDGroup.h"
#import "WDImage.h"
#import "WDInspectableProperties.h"
#import "WDLayer.h"
#import "WDPath.h"
#import "WDPathfinder.h"
#import "WDPropertyManager.h"
#import "WDText.h"
#import "WDTextPath.h"
#import "WDUtilities.h"

const float kDuplicateOffset = 20.0f;

NSString *WDPasteboardDataType = @"WDPasteboardDataType";
NSString *WDSelectionChangedNotification = @"WDSelectionChangedNotification";

@implementation WDDrawingController

@synthesize drawing = drawing_;
@synthesize selectedObjects = selectedObjects_;
@synthesize selectedPaths = selectedPaths_;
@synthesize selectedNodes = selectedNodes_;
@synthesize activePath = activePath_;
@synthesize tempDisplayNode = tempDisplayNode_;
@synthesize propertyManager = propertyManager_;
@synthesize lastAppliedTransform = lastAppliedTransform_;
@synthesize undoSelectionStack = undoSelectionStack_;
@synthesize redoSelectionStack = redoSelectionStack_;

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    selectedObjects_ = [[NSMutableSet alloc] init];
    selectedNodes_ = [[NSMutableSet alloc] init];
    undoSelectionStack_ = [[NSMutableArray alloc] init];
    redoSelectionStack_ = [[NSMutableArray alloc] init];
    
    propertyManager_ = [[WDPropertyManager alloc] init];
    propertyManager_.drawingController = self;
    
    lastAppliedTransform_ = CGAffineTransformIdentity;
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setDrawing:(WDDrawing *)drawing
{
    if (drawing == drawing_) {
        return;
    }
    
    drawing_ = drawing;
    
    NSNotificationCenter    *nc = [NSNotificationCenter defaultCenter];
    NSUndoManager           *undoManager = drawing.undoManager;
    
    // undo notifications
    [nc addObserver:self
           selector:@selector(undoGroupOpened:)
               name:NSUndoManagerDidOpenUndoGroupNotification
             object:undoManager];
    
    [nc addObserver:self
           selector:@selector(undoGroupClosed:)
               name:NSUndoManagerDidCloseUndoGroupNotification
             object:undoManager];
    
    [nc addObserver:self
           selector:@selector(didUndo:)
               name:NSUndoManagerDidUndoChangeNotification
             object:undoManager];
    
    [nc addObserver:self
           selector:@selector(didRedo:)
               name:NSUndoManagerDidRedoChangeNotification
             object:undoManager];
    
    // drawing notifications
    [nc addObserver:self
           selector:@selector(layerLockedStatusChanged:)
               name:WDLayerLockedStatusChanged
             object:drawing_];
    
    [nc addObserver:self
           selector:@selector(layerVisibilityChanged:)
               name:WDLayerVisibilityChanged
             object:drawing_];
    
    [nc addObserver:self
           selector:@selector(layerDeleted:)
               name:WDLayerDeletedNotification
             object:drawing_];
    
    [nc addObserver:self
           selector:@selector(activeLayerChanged:)
               name:WDActiveLayerChanged
             object:drawing_];
    
    [nc addObserver:self
           selector:@selector(isolateActiveLayerSettingChanged:)
               name:WDIsolateActiveLayerSettingChangedNotification
             object:drawing];
}

#pragma mark -
#pragma mark Undo

- (void) undo:(id)sender
{
    [drawing_.undoManager undo];
}

- (void) redo:(id)sender
{
    [drawing_.undoManager redo];
}

- (NSDictionary *) selectionState
{
    NSSet *currentSelection = [selectedObjects_ copy];
    NSSet *currentNodeSelection = [selectedNodes_ copy];
    
    NSDictionary *selectionState = @{@"selection": currentSelection,
                                     @"node selection": currentNodeSelection,
                                     @"active path": (self.activePath ? self.activePath : (WDPath *) [NSNull null]),
                                     @"active layer": drawing_.activeLayer};
    
    return selectionState;
}

- (void) undoGroupOpened:(NSNotification *)aNotification
{
    if (!drawing_.undoManager.isUndoing  && !drawing_.undoManager.isRedoing) {
        [redoSelectionStack_ removeAllObjects];
        
        NSMutableDictionary *restoreState = [NSMutableDictionary dictionaryWithObject:[self selectionState] forKey:@"undo"];
        [undoSelectionStack_ addObject:restoreState];
    }
}

- (void) undoGroupClosed:(NSNotification *)aNotification
{
    if (!drawing_.undoManager.isUndoing  && !drawing_.undoManager.isRedoing) {
        [undoSelectionStack_ lastObject][@"redo"] = [self selectionState];
    }
}

- (void) didUndo:(NSNotification *)aNotification
{
    NSDictionary  *restoreState = [undoSelectionStack_ lastObject][@"undo"];
    
    [selectedObjects_ setSet:restoreState[@"selection"]];
    [self setSelectedNodesFromSet:restoreState[@"node selection"]];
    self.activePath = restoreState[@"active path"];
    [self notifySelectionChanged];
    [drawing_ activateLayerAtIndex:[drawing_.layers indexOfObject:restoreState[@"active layer"]]];
    
    [redoSelectionStack_ addObject:[undoSelectionStack_ lastObject]];
    [undoSelectionStack_ removeLastObject];
}

- (void) didRedo:(NSNotification *)aNotification
{
    NSDictionary  *restoreState = [redoSelectionStack_ lastObject][@"redo"];
    
    [selectedObjects_ setSet:restoreState[@"selection"]];
    [self setSelectedNodesFromSet:restoreState[@"node selection"]];
    self.activePath = restoreState[@"active path"];
    [self notifySelectionChanged];
    [drawing_ activateLayerAtIndex:[drawing_.layers indexOfObject:restoreState[@"active layer"]]];
    
    [undoSelectionStack_ addObject:[redoSelectionStack_ lastObject]];
    [redoSelectionStack_ removeLastObject];
}

#pragma mark -
#pragma mark Drawing Notifications

- (void) layerDeleted:(NSNotification *)aNotification
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    WDLayer *layer = (WDLayer *) [aNotification userInfo][@"layer"];
    [selectedObjects_ minusSet:[NSSet setWithArray:layer.elements]];
    [self notifySelectionChanged];
}

- (void) layerLockedStatusChanged:(NSNotification *)aNotification
{
    WDLayer *layer = (WDLayer *) (aNotification.userInfo)[@"layer"];
    
    // be sure to end any active path editing
    self.activePath = nil;
    
    if (layer.locked) {
        [selectedObjects_ minusSet:[NSSet setWithArray:layer.elements]];
        [self notifySelectionChanged];
    }
}

- (void) layerVisibilityChanged:(NSNotification *)aNotification
{
    WDLayer *layer = (WDLayer *) (aNotification.userInfo)[@"layer"];
    
    // be sure to end any active path editing
    self.activePath = nil;
    
    if (layer.hidden) {
        [selectedObjects_ minusSet:[NSSet setWithArray:layer.elements]];
        [self notifySelectionChanged];
    }
}

- (void) isolateActiveLayerSettingChanged:(NSNotification *)aNotification
{
    if (drawing_.isolateActiveLayer) {
        // deselect anything from non-active layers
        [self deselectNonActiveLayerContents];
    }
}

- (void) activeLayerChanged:(NSNotification *)aNotification
{
    if (drawing_.isolateActiveLayer) {
        [self deselectNonActiveLayerContents];
    }
}

#pragma mark -
#pragma mark Node selection

- (void) selectNode:(WDBezierNode *)node
{
    node.selected = YES;
    [selectedNodes_ addObject:node];
    
    [self notifySelectionChanged];
}

- (void) deselectNode:(WDBezierNode *)node
{
    if (selectedNodes_.count == 0) {
        return;
    }
    
    node.selected = NO;
    [selectedNodes_ removeObject:node];
    
    [self notifySelectionChanged];
}

- (void) deselectAllNodes
{
    for (WDBezierNode *node in selectedNodes_) {
        node.selected = NO;
    }
    [selectedNodes_ removeAllObjects];
    
    [self notifySelectionChanged];
}

- (BOOL) isNodeSelected:(WDBezierNode *)node
{
    return [selectedNodes_ containsObject:node];
}

- (void) setSelectedNodesFromSet:(NSSet *)set
{
    for (WDBezierNode *node in selectedNodes_) {
        node.selected = NO;
    }
    
    [selectedNodes_ setSet:set];
    
    for (WDBezierNode *node in selectedNodes_) {
        node.selected = YES;
    }
}

#pragma mark -
#pragma mark Querying Selection State

- (WDElement *) singleSelection
{
    if (selectedObjects_.count == 1) {
        return [selectedObjects_ anyObject];
    }
    
    return nil;
}

- (BOOL) allSiblingsSelected:(WDPath *)path
{
    if (!path.superpath) {
        return NO;
    } 
    
    NSMutableSet *siblings = [NSMutableSet setWithArray:path.superpath.subpaths];
    [siblings removeObject:path];
    
    if ([siblings isSubsetOfSet:selectedObjects_]) {
        return YES;
    }
    
    return NO;
}

- (NSMutableArray *) orderedSelectedObjects
{
    NSMutableArray *ordered = [NSMutableArray array];
    
    for (WDLayer *layer in drawing_.layers) {
        [ordered addObjectsFromArray:[self sortedSelectionForLayer:layer]];
    }
    
    return ordered;
}

- (NSArray *) sortedSelectionForLayer:(WDLayer *)layer
{
    return [layer.elements filter:^BOOL(id obj) {
        return [self isSelectedOrSubelementIsSelected:obj];
    }];
}

- (BOOL) isSelected:(WDElement *)element
{
    return [selectedObjects_ containsObject:element];
}

- (BOOL) isSelectedOrSubelementIsSelected:(WDElement *)element
{
    if ([element isKindOfClass:[WDCompoundPath class]]) {
        WDCompoundPath  *cp = (WDCompoundPath *) element;
        NSSet           *subpaths = [NSSet setWithArray:cp.subpaths];
        
        if ([subpaths intersectsSet:selectedObjects_]) {
            return YES;
        }
    }
    
    return [selectedObjects_ containsObject:element];
}

- (CGRect) selectionBounds
{
    CGRect bounds = CGRectNull;
    
    for (WDElement *element in selectedObjects_) {
        bounds = CGRectUnion(bounds, element.bounds);
    }
    
    return bounds;
}

- (NSSet *) selectedPaths
{
    NSMutableSet *selectedPaths = [NSMutableSet set];
    
    for (WDElement *element in self.selectedObjects) {
        if ([element isKindOfClass:[WDPath class]]) {
            [selectedPaths addObject:element];
        }
    }
    
    return selectedPaths;
}

- (BOOL) allSelectedObjectsAreRootObjects
{
    for (WDPath *path in self.selectedPaths) {
        if (path.superpath) {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark -
#pragma mark Updating Selection

- (void) delayedSelectionNotification:(id)obj
{
    [[NSNotificationCenter defaultCenter] postNotificationName:WDSelectionChangedNotification object:self userInfo:nil];
}

- (void) notifySelectionChanged
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(delayedSelectionNotification:) object:nil];
    [self performSelector:@selector(delayedSelectionNotification:) withObject:nil afterDelay:0];
}

- (void) selectObject:(WDElement *)element
{
    if ([element isKindOfClass:[WDCompoundPath class]]) {
        // if the compound path is selected, its subpaths ain't
        for (WDPath *path in ((WDCompoundPath *)element).subpaths) {
            [selectedObjects_ removeObject:path];
        }
    } else if ([element isKindOfClass:[WDPath class]] && [self allSiblingsSelected:(WDPath *)element]) {
        // We're selecting the final path in a compound path, which means the compound path should be selected
        // and not its subpaths. This is similar to the above case...
        element = ((WDPath *) element).superpath;
        
        for (WDPath *path in ((WDCompoundPath *)element).subpaths) {
            [selectedObjects_ removeObject:path];
        }
    }
    
    [selectedObjects_ addObject:element];
    [self deselectAllNodes];
    
    [self notifySelectionChanged];
}

- (void) selectObjects:(NSArray *)elements
{
    [selectedObjects_ addObjectsFromArray:elements];
    [self deselectAllNodes];
}

- (void) deselectObject:(WDElement *)element
{
    [selectedObjects_ removeObject:element];
    [self notifySelectionChanged];
}

- (void) deselectObjectAndSubelements:(WDElement *)element
{
    if ([element isKindOfClass:[WDCompoundPath class]]) {
        WDCompoundPath  *cp = (WDCompoundPath *) element;
        
        for (WDPath *sp in cp.subpaths) {
            [self deselectObject:sp];
        }
    }
    
    [self deselectObject:element];
}

- (void) selectObjectsInRect:(CGRect)rect
{
    [selectedObjects_ removeAllObjects];
    
    NSArray *layersToCheck = drawing_.isolateActiveLayer ? @[drawing_.activeLayer] : drawing_.layers;
    
    for (WDLayer *layer in [layersToCheck reverseObjectEnumerator]) {
        if (layer.hidden || layer.locked) {
            continue;
        }
        
        for (WDElement *element in [layer.elements reverseObjectEnumerator]) {
            if ([element intersectsRect:rect]) {
                [selectedObjects_ addObject:element];
            }
        }
    }
    
    [self deselectAllNodes];
    
    // if a single path is selected, select the nodes inside the marquee
    WDPath *singlePath = (WDPath *) [self singleSelection];
    if ([singlePath isKindOfClass:[WDPath class]]) {
        [self setSelectedNodesFromSet:[singlePath nodesInRect:rect]];
        
        // TODO: act as if we tapped the fill, or show node handles?
        //if ([singlePath allNodesSelected]) {
        //    [self deselectAllNodes];
        //}
    }
    
    [self notifySelectionChanged];
}

- (void) deselectNonActiveLayerContents
{
    for (WDLayer *layer in drawing_.layers) {
        if (layer != drawing_.activeLayer) {
            [selectedObjects_ minusSet:[NSSet setWithArray:layer.elements]];
            [self notifySelectionChanged];
        }
    }
}

#pragma mark -
#pragma mark Action Items

- (void) selectNone:(id)sender
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    [selectedObjects_ removeAllObjects];
    [self deselectAllNodes];
    
    [self notifySelectionChanged];
}

- (void) selectAll:(id)sender
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    if (drawing_.isolateActiveLayer) {
        return [self selectAllOnActiveLayer:sender];
    } else {
        for (WDLayer *layer in drawing_.layers) {
            if (layer.hidden || layer.locked) {
                continue;
            }
            
            [selectedObjects_ addObjectsFromArray:layer.elements];
        }
    }
    
    [self notifySelectionChanged];
}

- (void) selectAllOnActiveLayer:(id)sender
{
    WDLayer *activeLayer = [drawing_ activeLayer];
    
    if (activeLayer.hidden || activeLayer.locked) {
        return;
    }
    
    [selectedObjects_ removeAllObjects];
    
    // be sure to end any active path editing
    self.activePath = nil;
    
    [selectedObjects_ addObjectsFromArray:activeLayer.elements];
    
    [self notifySelectionChanged];
}

- (void) delete:(id)sender
{
    if ([self canDeleteAnchors]) {
        [self deleteAnchors:sender];
        return;
    }
    
    NSMutableArray *objectsToRemove = [NSMutableArray array];
    
    // be sure to end any active path editing
    self.activePath = nil;
    
    for (WDElement *element in self.selectedObjects) {
        WDPath *path = (WDPath *) element;
        
        if ([path isKindOfClass:[WDPath class]] && path.superpath) {
            WDCompoundPath *superpath = path.superpath;
            
            [superpath removeSubpath:path];
            
            if (superpath.subpaths.count == 1) {
                // down to one remaining subpath path, release it
                WDPath *lastPath = [superpath.subpaths lastObject];
                
                lastPath.superpath = nil;
                lastPath.strokeStyle = superpath.strokeStyle;
                lastPath.fillTransform = superpath.fillTransform;
                lastPath.fill = superpath.fill;
                lastPath.shadow = superpath.shadow;
                lastPath.opacity = superpath.opacity;
                
                [superpath.layer insertObject:lastPath above:superpath];
                [objectsToRemove addObject:superpath];
            }
        } else {
            [objectsToRemove addObject:element];
        }
    }
    
    for (WDElement *element in objectsToRemove) {
        [element.layer removeObject:element];
    }
    
    [selectedObjects_ removeAllObjects];
    
    [self notifySelectionChanged];
}

#pragma mark -
#pragma mark Pasteboard

- (id) generalPasteboard
{
#if TARGET_OS_IPHONE
    return [UIPasteboard generalPasteboard];
#else
    return [NSPasteboard generalPasteboard];
#endif
}

- (id) pasteboardWithUniqueName
{
#if TARGET_OS_IPHONE
    return [UIPasteboard pasteboardWithUniqueName];
#else
    return [NSPasteboard pasteboardWithUniqueName];
#endif
}

- (void) cut:(id)sender
{    
    [self copy:sender];
    [self delete:sender];
}

- (void) copy:(id)sender
{   
    [self copyToPasteboard:[self generalPasteboard]];
}

- (void) copyToPasteboard:(id)pb
{
    NSMutableData       *data = [NSMutableData data]; 
    NSKeyedArchiver     *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    NSArray             *selection = [self orderedSelectedObjects];
    NSMutableDictionary  *pbItems = [NSMutableDictionary dictionary];
    
    if ([pb isEqual:[UIPasteboard generalPasteboard]]) {
        UIImage *image = [WDDrawing imageForElements:selection scale:1];
        pbItems[(NSString *)kUTTypePNG] = UIImagePNGRepresentation(image);
    }
    
    [archiver encodeObject:selection forKey:@"WDElements"]; 
    [archiver finishEncoding]; 
    pbItems[WDPasteboardDataType] = data;

#if TARGET_OS_IPHONE
    ((UIPasteboard *)pb).items = @[pbItems];
#else
    [pb clearContents];
    [pb declareTypes:pbItems.allKeys owner:nil];
    for (NSString *key in pbItems.allKeys) {
        [pb setData:[pbItems objectForKey:key] forType:key];
    }
#endif    
}

- (void) duplicateInPlace:(id)sender
{
    id          pb = [self pasteboardWithUniqueName];
    WDLayer     *layer = drawing_.activeLayer;
    
    if (!layer.editable) {
        WDElement *element = (WDElement *) [[self orderedSelectedObjects] lastObject];
        layer = element.layer;
    }
    
    [self copyToPasteboard:pb];
    [self pasteFromPasteboard:pb toLayer:layer];
}

- (void) duplicate:(id)sender
{
    [self duplicateInPlace:sender];
    
    // TODO: Consider view scale here?
    CGAffineTransform transform = CGAffineTransformMakeTranslation(kDuplicateOffset, kDuplicateOffset);
    [self transformSelection:transform];
}

- (void) duplicateAndTransformAgain:(id)sender
{
    [self duplicateInPlace:sender];
    [self transformAgain:sender];
}

#if TARGET_OS_IPHONE

- (void) pasteFromPasteboard:(UIPasteboard *)pb toLayer:(WDLayer *)layer;
{
    if (!layer) {
        layer = drawing_.activeLayer;
    }
    
    // be sure to end any active path editing
    self.activePath = nil;
    
    if ([pb containsPasteboardTypes:@[WDPasteboardDataType]]) {
        NSData *data = [pb dataForPasteboardType:WDPasteboardDataType];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data]; 
        NSArray *toPaste = [unarchiver decodeObjectForKey:@"WDElements"];
        [unarchiver finishDecoding]; 
        
        [self selectNone:nil];
        [layer addObjects:toPaste];
        [self selectObjects:toPaste];
    } else if (pb.images) {
        for (UIImage *image in pb.images) {
            [self placeImage:image];
        }
    } else if (pb.image) {
        [self placeImage:[UIPasteboard generalPasteboard].image];
    } else if (pb.strings) {
        for (NSString *string in pb.strings) {
            [self createTextObjectWithText:string];
        }
    } else if (pb.string) {
        [self createTextObjectWithText:pb.string];
    } 
}

#else 

- (void) pasteFromPasteboard:(NSPasteboard *)pb toLayer:(WDLayer *)layer;
{
    if (!layer) {
        layer = drawing_.activeLayer;
    }
    
    // be sure to end any active path editing
    self.activePath = nil;
    
    NSString *type = [pb availableTypeFromArray:[NSArray arrayWithObjects:WDPasteboardDataType, nil]];
    
    if ([type isEqualToString:WDPasteboardDataType]) {
        NSData *data = [pb dataForType:type];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data]; 
        NSArray *toPaste = [unarchiver decodeObjectForKey:@"WDElements"];
        [unarchiver finishDecoding]; 
        [unarchiver release]; 
        
        [self selectNone:nil];
        [layer addObjects:toPaste];
        [self selectObjects:toPaste];
    }
}

#endif

- (void) paste:(id)sender
{    
    [self pasteFromPasteboard:[self generalPasteboard] toLayer:nil];
}

#pragma mark -
#pragma mark Path Actions

- (void) addAnchors:(id)sender
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    [self.selectedPaths makeObjectsPerformSelector:@selector(addAnchors)];
}

- (void) deleteAnchors:(id)sender
{
    [self.selectedPaths makeObjectsPerformSelector:@selector(deleteAnchors)];
}

- (void) reversePathDirection:(id)sender
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    [self.selectedPaths makeObjectsPerformSelector:@selector(reversePathDirection)];
}

- (void) outlineStroke:(id)sender
{
    NSMutableArray *newSelection = [NSMutableArray array];
    
    // be sure to end any active path editing
    self.activePath = nil;
    
    for (WDElement *element in [self orderedSelectedObjects]) {
        if (![element isKindOfClass:[WDAbstractPath class]]) {
            continue;
        }
        
        WDAbstractPath *path = (WDAbstractPath *) element;
        
        if (![path canOutlineStroke]) {
            continue;
        }
        
        WDAbstractPath *outline = [path outlineStroke];
        
        if (outline) {
            outline.fill = [self.propertyManager activeStrokeStyle].color;
            outline.shadow = [self.propertyManager activeShadow];
            outline.opacity = [[self.propertyManager defaultValueForProperty:WDOpacityProperty] floatValue];
            
            [path.layer insertObject:outline above:element];
            [path.layer removeObject:element];
            
            [self deselectObjectAndSubelements:element];                
            [newSelection addObject:outline];
        }
    }
    
    [self selectObjects:newSelection];
}

- (void) joinPaths:(id)sender
{
    if (![self canJoinPaths]) {
        return;
    }
    
    NSArray *ordered = [self orderedSelectedObjects];
    WDPath  *topPath = [ordered lastObject]; // topObject
    WDPath  *pathToAppend = ordered[0];
    
    [topPath appendPath:pathToAppend]; 
    
    [self selectNone:nil];   
    [pathToAppend.layer removeObject:pathToAppend];
    [self selectObject:topPath];
}

- (void) setActivePath:(WDPath *)path
{
    if ([path isEqual:[NSNull null]]) {
        activePath_ = nil;
    } else {
        if (path) {
            [selectedObjects_ addObject:path];
            [self notifySelectionChanged];
        } else if (activePath_) {
            [self deselectAllNodes];
        }
        
        activePath_ = path;
    }
}

#pragma mark -
#pragma mark Grouping

- (void) group:(id)sender
{
    NSMutableArray  *objects = [self orderedSelectedObjects];
    
    WDGroup *group = [[WDGroup alloc] init];
    
    WDElement *topObject = [objects lastObject];
    [topObject.layer insertObject:group above:topObject];
    
    // get rid of the old selected objects
    [self delete:nil];
    // and select the new group
    [self selectObject:group];
    
    group.elements = objects;
}

- (void) releaseGroupedObject:(WDGroup *)group
{
    NSMutableArray *newElements = group.elements;
    
    for (WDElement *element in newElements) {
        [group.layer insertObject:element above:group];
        element.group = nil;
    }
    
    [group.layer removeObject:group];
    [self deselectObject:group];
    
    // select the released object
    [self selectObjects:newElements];
}

- (void) ungroup:(id)sender
{
    NSMutableArray *objects = [self orderedSelectedObjects];
    
    for (WDElement *element in objects) {
        if ([element isKindOfClass:[WDGroup class]]) {
            [self releaseGroupedObject:(WDGroup *)element];
        }
    }
}

#pragma mark -
#pragma mark Compound Paths

- (void) makeCompoundPath:(id)sender
{
    NSMutableArray  *objects = [self orderedSelectedObjects];
    NSMutableArray  *paths = [NSMutableArray array];
    
    WDCompoundPath *path = [[WDCompoundPath alloc] init];
    
    WDPath *topObject = (WDPath *) [objects lastObject];
    [topObject.layer insertObject:path above:topObject];
    
    [path takeStylePropertiesFrom:topObject];
    
    for (WDElement *element in objects) {
        if ([element isKindOfClass:[WDPath class]]) {
            [paths addObject:element];
        } else {
            [paths addObjectsFromArray:((WDCompoundPath *)element).subpaths];
        }
    }
    
    // get rid of the old selected objects
    [self delete:nil];
    // and select the new group
    [self selectObject:path];
    
    path.subpaths = paths;
}

- (void) releaseCompoundPathObject:(WDCompoundPath *)cp
{
    if (cp.maskedElements) {
        [self releaseMaskedObject:cp];
    }
    
    NSMutableArray *subpaths = cp.subpaths;
    
    for (WDPath *path in subpaths) {
        path.superpath = nil;
        
        [path takeStylePropertiesFrom:cp];
        [cp.layer insertObject:path above:cp];
    }
    
    [cp.layer removeObject:cp];
    [self deselectObject:cp];
    
    // select the released object
    [self selectObjects:subpaths];
}

- (void) releaseCompoundPath:(id)sender
{
    NSMutableArray *objects = [self orderedSelectedObjects];
    
    for (WDElement *element in objects) {
        if ([element isKindOfClass:[WDCompoundPath class]]) {
            [self releaseCompoundPathObject:(WDCompoundPath *)element];
        }
    }
}

#pragma mark -
#pragma mark Masking

- (void) makeMask:(id)sender
{
    NSMutableArray  *objects = [self orderedSelectedObjects];
    WDAbstractPath  *maskingPath = [objects lastObject];
    
    [objects removeLastObject];
    maskingPath.maskedElements = objects;
    
    [self deselectObject:maskingPath];
    
    // get rid of the old selected objects
    [self delete:self];
    // and select the new mask
    [self selectObject:maskingPath];
}

- (void) releaseMaskedObject:(WDStylable *)mask
{
    NSArray *elements = mask.maskedElements;
    
    for (WDElement *element in elements) {
        [mask.layer insertObject:element above:mask];
    }
    
    mask.maskedElements = nil;
    
    // select the released objects
    [self selectObjects:elements];
}

- (void) releaseMask:(id)sender
{
    NSMutableArray *objects = [self orderedSelectedObjects];
    
    for (WDElement *element in objects) {
        if ([element canMaskElements]) {
            WDStylable *stylable = (WDStylable *) element;
            
            if (stylable.maskedElements) {
                [self releaseMaskedObject:stylable];
            }
        }
    }
}

#pragma mark -
#pragma mark Boolean Path Operations

- (void) booleanWithOperation:(WDPathfinderOperation)op
{
    NSMutableArray  *objects = [self orderedSelectedObjects];
    
    WDAbstractPath *result = [WDPathfinder combinePaths:objects operation:op];
    
    if (result) {
        result.fill = [propertyManager_ activeFillStyle];
        result.strokeStyle = [[propertyManager_ activeStrokeStyle] strokeStyleSansArrows];
        result.opacity = [[propertyManager_ defaultValueForProperty:WDOpacityProperty] floatValue];
        result.shadow = [propertyManager_ activeShadow];
        
        WDElement *topObject = [objects lastObject];
        [topObject.layer insertObject:result above:topObject];
        
        // get rid of the old selected objects
        [self delete:nil];
        
        // and select the new path
        [self selectObject:result];
    }
}

- (void) unitePaths:(id)sender
{
    [self booleanWithOperation:WDPathfinderUnite];
}

- (void) intersectPaths:(id)sender
{
    [self booleanWithOperation:WDPathfinderIntersect];
}

- (void) subtractPaths:(id)sender
{
    NSMutableArray  *objects = [self orderedSelectedObjects];
    WDAbstractPath  *bottommost = objects[0];
    
    WDAbstractPath *result = [WDPathfinder combinePaths:objects operation:WDPathFinderSubtract];
    
    if (result) {
        result.fill = bottommost.fill;
        result.strokeStyle = [bottommost.strokeStyle strokeStyleSansArrows];
        result.fillTransform = bottommost.fillTransform;
        result.opacity = bottommost.opacity;
        result.shadow = bottommost.shadow;
        
        [bottommost.layer insertObject:result above:bottommost];
    }
    
    // get rid of the old selected objects
    [self delete:nil];
    
    if (result) {
        // and select the new path
        [self selectObject:result];
    }
}

- (void) eraseWithPath:(WDAbstractPath *)erasePath
{
    NSMutableArray  *objectsToErase = [NSMutableArray array];
    
    if (self.selectedObjects.count != 0) {
        for (WDElement *element in [self orderedSelectedObjects]) {
            if ([element isErasable] && CGRectIntersectsRect(erasePath.bounds, element.bounds)) {
                [objectsToErase addObject:element];
            }
        }
    } else {
        NSArray *layers = drawing_.layers;
        
        if (drawing_.isolateActiveLayer) {
            layers = @[drawing_.activeLayer];
        }
        
        for (WDLayer *layer in layers) {
            if (layer.locked || layer.hidden) {
                continue;
            }
            
            for (WDElement *element in layer.elements) {
                if ([element isErasable] && CGRectIntersectsRect(erasePath.bounds, element.bounds)) {
                    [objectsToErase addObject:element];
                }
            }
        }
    }
    
    for (WDAbstractPath *ap in objectsToErase) {
        NSArray *result = [ap erase:erasePath];
        
        // if there's anything left, add it to the layer
        if (result) {
            for (WDAbstractPath *resultPath in result) {
                [ap.layer insertObject:resultPath above:ap];
            }
        }
        
        if ([self isSelectedOrSubelementIsSelected:ap]) {
            [self deselectObjectAndSubelements:ap];
            
            if (result) {
                [self selectObjects:result];
            }
        }
        
        [ap.layer removeObject:ap];
    }
}

/* Experimental. Only works for 2 paths.
 */
- (void) dividePaths:(id)sender
{
    NSMutableArray  *objects = [self orderedSelectedObjects];
    WDElement       *topObject = [objects lastObject];
    
    WDAbstractPath *exclusion = [WDPathfinder combinePaths:objects operation:WDPathFinderExclude];
    WDAbstractPath *intersection = [WDPathfinder combinePaths:objects operation:WDPathfinderIntersect];
    
    if (exclusion) {
        exclusion.fill = [propertyManager_ activeFillStyle];
        exclusion.strokeStyle = [[propertyManager_ activeStrokeStyle] strokeStyleSansArrows];
        [topObject.layer insertObject:exclusion above:topObject];
    }
    
    if (intersection) {
        intersection.fill = [propertyManager_ activeFillStyle];
        intersection.strokeStyle = [[propertyManager_ activeStrokeStyle] strokeStyleSansArrows];
        [topObject.layer insertObject:intersection above:topObject];
    }
    
    // get rid of the old selected objects
    [self delete:nil];
    
    // select the new items
    if (intersection) {
        [self selectObject:intersection];
    }
    if (exclusion) {
        [self selectObject:exclusion];
    }
    
    if ([self canReleaseCompoundPath]) {
        [self releaseCompoundPath:nil];
    }
}

- (void) excludePaths:(id)sender
{
    [self booleanWithOperation:WDPathFinderExclude];
}

#pragma mark -
#pragma mark Image Placement

- (void) placeImage:(UIImage *)image
{
    image = [image downsampleWithMaxDimension:1024];
    WDImage *placedImage = [WDImage imageWithUIImage:image inDrawing:drawing_];
    
    float scale = (drawing_.dimensions.width / 2) / image.size.width;
    scale = (scale > 1) ? 1 : scale;
    
    float width = scale * image.size.width;
    float height = scale * image.size.height;
    CGPoint ul = CGPointMake((drawing_.dimensions.width - width) / 2, (drawing_.dimensions.height - height) / 2);
    
    CGAffineTransform transform = CGAffineTransformMakeTranslation(ul.x, ul.y);
    transform = CGAffineTransformScale(transform, scale, scale);
    placedImage.transform = transform;
    
    // be sure to end any active path editing
    self.activePath = nil;
    
    [self selectNone:nil];
    [drawing_ addObject:placedImage];
    [self selectObject:placedImage];
}

#pragma mark -
#pragma mark Styles

- (void) setValue:(id)value forProperty:(NSString *)property
{
    if (self.selectedObjects.count == 0) {
        // no selection, so directly set the default value on the property manager
        [propertyManager_ setDefaultValue:value forProperty:property];
        // and invalidate it so that inspectors react properly
        [propertyManager_ addToInvalidProperties:property];
    }
    
    for (WDElement *element in [self.selectedObjects objectEnumerator]) {
        [element setValue:value forProperty:property propertyManager:propertyManager_];
    }
}

#pragma mark -
#pragma mark Arrange

- (void) bringForward:(id)sender
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    [drawing_.layers makeObjectsPerformSelector:@selector(bringForward:) withObject:[self orderedSelectedObjects]];
}

- (void) bringToFront:(id)sender
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    for (WDLayer *layer in drawing_.layers) {
        NSArray *sorted = [self sortedSelectionForLayer:layer];
        [layer bringToFront:sorted];
    }
}

- (void) sendBackward:(id)sender
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    [drawing_.layers makeObjectsPerformSelector:@selector(sendBackward:) withObject:[self orderedSelectedObjects]];
}

- (void) sendToBack:(id)sender
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    for (WDLayer *layer in drawing_.layers) {
        NSArray *sorted = [self sortedSelectionForLayer:layer];
        [layer sendToBack:sorted];
    }
}

#pragma mark -
#pragma mark Transform

- (void) transformSelection:(CGAffineTransform)transform
{
    if (CGAffineTransformIsIdentity(transform)) {
        // this will have no effect, so we don't want to register undos, etc.
        return;
    }
    
    lastAppliedTransform_ = transform;
    
    for (WDElement *element in selectedObjects_) {
        NSSet *replacedNodes = [element transform:transform];
        
        if (replacedNodes && replacedNodes.count) {
            [self setSelectedNodesFromSet:replacedNodes];
        }
    }
}

- (void) transformAgain:(id)sender
{
    [self transformSelection:lastAppliedTransform_];
}

- (void) align:(WDAlignment)alignment
{
    CGRect      selectionBounds;
    
    // be sure to end any active path editing
    self.activePath = nil;
    
    if (self.selectedObjects.count == 1) {
        WDElement *soleSelection = [self.selectedObjects anyObject];
        selectionBounds = [soleSelection subselectionBounds];
    } else {
        selectionBounds = self.selectionBounds;
    }
    
    for (WDElement *element in self.selectedObjects) {
        NSSet *newSelectedNodes = [element alignToRect:selectionBounds alignment:alignment];
        [self setSelectedNodesFromSet:newSelectedNodes];
    }
}

- (void) distributeHorizontally:(id)sender
{
    NSArray *selected = [self.selectedObjects allObjects];
    
    selected = [selected sortedArrayUsingComparator:^(id a, id b) {
        CGPoint centerA = WDCenterOfRect(((WDElement *) a).bounds);
        CGPoint centerB = WDCenterOfRect(((WDElement *) b).bounds);
        float delta = centerA.x - centerB.x;
        NSComparisonResult result = (delta < 0 ? NSOrderedAscending : (delta > 0 ? NSOrderedDescending : NSOrderedSame));
        return result;
    }];
    
    WDElement *firstObj = (WDElement *) selected[0];
    WDElement *lastObj = (WDElement *) [selected lastObject];
    
    float startX = WDCenterOfRect(firstObj.bounds).x;
    float endX = WDCenterOfRect(lastObj.bounds).x;
    float distance = endX - startX;
    
    float step = distance / (selected.count - 1);
    float offset = startX;
    
    for (WDElement *obj in selected) {
        [obj transform:CGAffineTransformMakeTranslation(offset - WDCenterOfRect(obj.bounds).x, 0)];
        offset += step;
    }
}

- (void) distributeVertically:(id)sender
{
    NSArray *selected = [self.selectedObjects allObjects];
    
    selected = [selected sortedArrayUsingComparator:^(id a, id b) {
        CGPoint centerA = WDCenterOfRect(((WDElement *) a).bounds);
        CGPoint centerB = WDCenterOfRect(((WDElement *) b).bounds);
        float delta = centerA.y - centerB.y;
        NSComparisonResult result = (delta < 0 ? NSOrderedAscending : (delta > 0 ? NSOrderedDescending : NSOrderedSame));
        return result;
    }];
    
    WDElement *firstObj = (WDElement *) selected[0];
    WDElement *lastObj = (WDElement *) [selected lastObject];
    
    float startY = WDCenterOfRect(firstObj.bounds).y;
    float endY = WDCenterOfRect(lastObj.bounds).y;
    float distance = endY - startY;
    
    float step = distance / (selected.count - 1);
    float offset = startY;
    
    for (WDElement *obj in selected) {
        [obj transform:CGAffineTransformMakeTranslation(0, offset - WDCenterOfRect(obj.bounds).y)];
        offset += step;
    }
}

- (void) flipHorizontally:(id)sender
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    CGPoint pivot = WDCenterOfRect([self selectionBounds]);
    CGAffineTransform transform = CGAffineTransformMakeTranslation(pivot.x, pivot.y);
    transform = CGAffineTransformScale(transform, -1, 1);
    transform = CGAffineTransformTranslate(transform, -pivot.x, -pivot.y);
    
    [self transformSelection:transform];
}

- (void) flipVertically:(id)sender
{
    // be sure to end any active path editing
    self.activePath = nil;
    
    CGPoint pivot = WDCenterOfRect([self selectionBounds]);
    CGAffineTransform transform = CGAffineTransformMakeTranslation(pivot.x, pivot.y);
    transform = CGAffineTransformScale(transform, 1, -1);
    transform = CGAffineTransformTranslate(transform, -pivot.x, -pivot.y);
    
    [self transformSelection:transform];
}

// Keyboard (Mac)
- (void) nudge:(unichar)arrowKey
{
#if !TARGET_OS_IPHONE
    CGAffineTransform translate = CGAffineTransformIdentity;
    
    switch (arrowKey) {
        case NSLeftArrowFunctionKey:
            translate = CGAffineTransformMakeTranslation(-1, 0);
            break;
        case NSRightArrowFunctionKey:
            translate = CGAffineTransformMakeTranslation(1, 0);
            break;
        case NSUpArrowFunctionKey:
            translate = CGAffineTransformMakeTranslation(0, -1);
            break;
        case NSDownArrowFunctionKey:
            translate = CGAffineTransformMakeTranslation(0, 1);
            break;
        default:
            break;
    }
    
    [self transformSelection:translate];
#endif
}

#pragma mark -
#pragma mark Text

// this is called by the text tool
- (WDText *) createTextObjectInRect:(CGRect)rect
{
    WDText *text = [[WDText alloc] init];
    text.width = CGRectGetWidth(rect);
    
    text.text = NSLocalizedString(@"Text", @"Text");
    text.fontName = [propertyManager_ defaultValueForProperty:WDFontNameProperty];
    text.fontSize = [[propertyManager_ defaultValueForProperty:WDFontSizeProperty] floatValue];
    text.transform = CGAffineTransformMakeTranslation(rect.origin.x, rect.origin.y);
    text.alignment = [[propertyManager_ defaultValueForProperty:WDTextAlignmentProperty] intValue];
    // set this after width, so that the gradient will be set up properly
    text.fill = [propertyManager_ activeFillStyle];
    text.opacity = [[propertyManager_ defaultValueForProperty:WDOpacityProperty] floatValue];
    text.shadow = [propertyManager_ activeShadow];
    
    if (!text.fill) {
        // make sure the text isn't invisible
        text.fill = [WDColor blackColor];
    }
    
    [drawing_ addObject:text];
    [self selectObject:text];
    
    return text;
}

// this is called when pasting text
- (void) createTextObjectWithText:(NSString *)string
{
    WDText *text = [[WDText alloc] init];
    text.text = string;
    text.fontName = [propertyManager_ defaultValueForProperty:WDFontNameProperty];
    text.fontSize = [[propertyManager_ defaultValueForProperty:WDFontSizeProperty] floatValue];
    
    CTFontRef fontRef = [[WDFontManager sharedInstance] newFontRefForFont:text.fontName withSize:text.fontSize provideDefault:YES];
    CGSize naturalSize = [string sizeWithCTFont:fontRef constrainedToSize:CGSizeMake(drawing_.dimensions.width, MAXFLOAT)];
    CFRelease(fontRef);
    
    text.width = naturalSize.width;
    text.alignment = [[propertyManager_ defaultValueForProperty:WDTextAlignmentProperty] intValue];
    
    text.transform = CGAffineTransformMakeTranslation((drawing_.dimensions.width - text.width) / 2,
                                                      (drawing_.dimensions.width - naturalSize.height) / 2);
    
    // set this after width, so that the gradient will be set up properly
    text.fill = [propertyManager_ activeFillStyle];
    
    if (!text.fill) {
        // make sure the text isn't invisible
        text.fill = [WDColor blackColor];
    }
    
    [self selectNone:nil];
    [drawing_ addObject:text];
    [self selectObject:text];
}

- (WDTextPath *) placeTextOnPath:(id)sender shouldStartEditing:(BOOL *)startEditing
{
    if (![self canPlaceTextOnPath]) {
        return nil;
    }
    
    // be sure to end any active path editing
    self.activePath = nil;
    
    WDPath          *path = nil;
    WDTextPath      *typePath = nil;
    WDText          *text = nil;
    NSArray         *orderedSelection = [self orderedSelectedObjects];
    
    // set to NO by default
    *startEditing = NO;
    
    // see if we're in the path+text or path only case
    if (self.selectedObjects.count == 1) {
        path = (WDPath *) [orderedSelection lastObject];
        typePath = [WDTextPath textPathWithPath:path];
        
        typePath.text = @"Text";
        typePath.fontName = [propertyManager_ defaultValueForProperty:WDFontNameProperty];
        typePath.fontSize = [[propertyManager_ defaultValueForProperty:WDFontSizeProperty] floatValue];
        typePath.fill = [propertyManager_ defaultFillStyle];
        typePath.fillTransform = path.fillTransform;
        typePath.shadow = path.shadow;
        typePath.opacity = path.opacity;
        
        if (!typePath.fill) {
            typePath.fill = [WDColor blackColor];
        }
        
        *startEditing = YES;
    } else { // path and text object selected
        if ([orderedSelection[0] isKindOfClass:[WDPath class]]) {
            path = (WDPath *) orderedSelection[0];
            text = (WDText *) orderedSelection[1];
        } else {
            path = (WDPath *) orderedSelection[1];
            text = (WDText *) orderedSelection[0];
        }
        
        typePath = [WDTextPath textPathWithPath:path];
        typePath.text = text.text;
        typePath.fontName = text.fontName;
        typePath.fontSize = text.fontSize;
        typePath.fill = text.fill;
        typePath.strokeStyle = text.strokeStyle;
        typePath.shadow = text.shadow;
        typePath.opacity = text.opacity;
    }
    
    [path.layer insertObject:typePath above:path];
    
    // get rid of the old selected objects
    [self delete:self];
    // and select the new mask
    [self selectObject:typePath];
    
    return typePath;
}

- (void) createTextOutlines:(id)sender
{
    if (selectedObjects_.count != 1) {
        return;
    }
    
    NSArray *paths = nil;
    
    for (WDElement *element in selectedObjects_) {
        if ([element conformsToProtocol:@protocol(WDTextRenderer)]) {
            WDText *text = (WDText *) element;
            paths = [text outlines];
            
            for (WDAbstractPath *path in paths) {
                path.fill = text.fill;
                path.fillTransform = text.fillTransform;
                path.strokeStyle = text.strokeStyle;
                path.opacity = text.opacity;
                path.shadow = text.shadow;
                
                [text.layer insertObject:path above:text];
            }
        }
    }
    
    [self delete:self];
    [self selectObjects:paths];
}

- (void) resetTextTransform:(id)sender
{
    for (WDElement *element in selectedObjects_) {
        if ([element conformsToProtocol:@protocol(WDTextRenderer)] && [element respondsToSelector:@selector(resetTransform)]) {
            WDTextPath *textPath =  (WDTextPath *) element;
            [textPath resetTransform];
        }
    }
}

#pragma mark -
#pragma mark Color

- (void) tossCachedColorAdjustmentData
{
    for (WDElement *element in [self selectedObjects]) {
        [element tossCachedColorAdjustmentData];
    }
}

- (void) restoreCachedColorAdjustmentData
{
    for (WDElement *element in [self selectedObjects]) {
        [element restoreCachedColorAdjustmentData];
    }
}

- (void) registerUndoWithCachedColorAdjustmentData
{
    for (WDElement *element in [self selectedObjects]) {
        [element registerUndoWithCachedColorAdjustmentData];
    }
}

- (void) adjustColor:(WDColor * (^)(WDColor *color))adjustment scope:(WDColorAdjustmentScope)scope
{
    for (WDElement *element in [self selectedObjects]) {
        [element adjustColor:adjustment scope:scope];
    }
}

- (NSArray *) blendables
{
    NSArray *ordered = [self orderedSelectedObjects];
    NSMutableArray *blendables = [NSMutableArray array];
    
    for (WDElement *element in ordered) {
        [element addBlendablesToArray:blendables];
    }
    
    return blendables;
}

- (void) blendColorBackToFront:(id)sender
{
    NSArray *blendables = [self blendables];
    
    if (blendables.count < 3) {
        return;
    }
    
    WDStylable *firstObj = (WDStylable *) blendables[0];
    WDStylable *lastObj = (WDStylable *) [blendables lastObject];
    
    WDColor *first = (WDColor *) firstObj.fill;
    WDColor *last =  (WDColor *) lastObj.fill;
    
    float step = 1.0f / (blendables.count - 1);
    float fraction = 0.0f;
    
    for (WDStylable *obj in blendables) {
        obj.fill = [first blendedColorWithFraction:fraction ofColor:last];
        fraction += step;
    }
}

- (void) blendColorHorizontally:(id)sender
{
    NSArray *blendables = [self blendables];
    
    if (blendables.count < 3) {
        return;
    }
    
    blendables = [blendables sortedArrayUsingComparator:^(id a, id b) {
        CGPoint centerA = WDCenterOfRect(((WDElement *) a).bounds);
        CGPoint centerB = WDCenterOfRect(((WDElement *) b).bounds);
        float delta = centerA.x - centerB.x;
        NSComparisonResult result = delta < 0 ? NSOrderedAscending : (delta > 0 ? NSOrderedDescending : NSOrderedSame);
        return result;
    }];
    
    WDStylable *firstObj = (WDStylable *) blendables[0];
    WDStylable *lastObj = (WDStylable *) [blendables lastObject];
    
    WDColor *first = (WDColor *) firstObj.fill;
    WDColor *last =  (WDColor *) lastObj.fill;
    
    float startX = WDCenterOfRect(firstObj.bounds).x;
    float endX = WDCenterOfRect(lastObj.bounds).x;
    float distance = endX - startX;
    
    if (distance == 0) {
        // undefined
        return;
    }
    
    for (WDStylable *obj in blendables) {
        float fraction = (WDCenterOfRect(obj.bounds).x - startX) / distance;
        obj.fill = [first blendedColorWithFraction:fraction ofColor:last];
    }
}

- (void) blendColorVertically:(id)sender
{
    NSArray *blendables = [self blendables];
    
    if (blendables.count < 3) {
        return;
    }
    
    blendables = [blendables sortedArrayUsingComparator:^(id a, id b) {
        CGPoint centerA = WDCenterOfRect(((WDElement *) a).bounds);
        CGPoint centerB = WDCenterOfRect(((WDElement *) b).bounds);
        float delta = centerA.y - centerB.y;
        NSComparisonResult result = (delta < 0 ? NSOrderedAscending : (delta > 0 ? NSOrderedDescending : NSOrderedSame));
        return result;
    }];
    
    WDStylable *firstObj = (WDStylable *) blendables[0];
    WDStylable *lastObj = (WDStylable *) [blendables lastObject];
    
    WDColor *first = (WDColor *) firstObj.fill;
    WDColor *last =  (WDColor *) lastObj.fill;
    
    float startY = WDCenterOfRect(firstObj.bounds).y;
    float endY = WDCenterOfRect(lastObj.bounds).y;
    float distance = endY - startY;
    
    if (distance == 0) {
        // undefined
        return;
    }
    
    for (WDStylable *obj in blendables) {
        float fraction = (WDCenterOfRect(obj.bounds).y - startY) / distance;
        obj.fill = [first blendedColorWithFraction:fraction ofColor:last];
    }
}

- (void) desaturate:(id)sender
{
    for (WDElement *element in [self selectedObjects]) {
        [element adjustColor:^(WDColor *color) { return [color adjustHue:0 saturation:(-1.0f) brightness:0]; }
                       scope:(WDColorAdjustFill | WDColorAdjustStroke | WDColorAdjustShadow)];
        [element tossCachedColorAdjustmentData];
    }
}

- (void) invertColors:(id)sender
{
    for (WDElement *element in [self selectedObjects]) {
        [element adjustColor:^(WDColor *color) { return [color inverted]; }
                       scope:(WDColorAdjustFill | WDColorAdjustStroke | WDColorAdjustShadow)];
        [element tossCachedColorAdjustmentData];
    }
}

#pragma mark -
#pragma mark Hit Testing

- (WDPickResult *) snappedPoint:(CGPoint)pt viewScale:(float)viewScale snapFlags:(int)flags
{
    WDPickResult    *pickResult;
    
    if ((flags & kWDSnapNodes) || (flags & kWDSnapEdges)) {
        // first test active path
        if (self.activePath) {
            pickResult = [self.activePath snappedPoint:pt viewScale:viewScale snapFlags:flags];
            
            if (pickResult.type != kWDEther) {
                return pickResult;
            }
        }
        
        if (drawing_.isolateActiveLayer) {
            for (WDElement *element in [drawing_.activeLayer.elements reverseObjectEnumerator]) {
                pickResult = [element snappedPoint:pt viewScale:viewScale snapFlags:flags];
                
                if (pickResult.type != kWDEther) {
                    return pickResult;
                }
            }
        } else {
            for (WDLayer *layer in [drawing_.layers reverseObjectEnumerator]) {
                if (layer.hidden) {
                    continue;
                }
                
                if (layer.locked && !(flags & kWDSnapLocked)) {
                    continue;
                }
                
                for (WDElement *element in [layer.elements reverseObjectEnumerator]) {
                    if ((flags & kWDSnapSelectedOnly) && ![self isSelectedOrSubelementIsSelected:element]) {
                        continue;
                    }
                    
                    pickResult = [element snappedPoint:pt viewScale:viewScale snapFlags:flags];
                    
                    if (pickResult.type != kWDEther) {
                        return pickResult;
                    }
                }
            }
        }
        
        // check drawing page boundary
        pickResult = WDSnapToRectangle(drawing_.bounds, NULL, pt, viewScale, flags);
        if (pickResult.snapped) {
            return pickResult;
        }
    }
    
    // check for grid snap
    if (flags & kWDSnapGrid) {
        float     gridSpacing = [drawing_ gridSpacing];
        CGPoint   snap;
        
        snap.x = floor((pt.x / gridSpacing) + 0.5) * gridSpacing;
        snap.y = floor((pt.y / gridSpacing) + 0.5) * gridSpacing;
        
        pickResult = [WDPickResult pickResult];
        pickResult.snappedPoint = snap;
        
        return pickResult;
    }
    
    return [WDPickResult pickResult];
}

- (WDPickResult *) inspectableUnderPoint:(CGPoint)pt viewScale:(float)viewScale
{
    WDPickResult    *pickResult;
    NSUInteger      flags = (kWDSnapEdges | kWDSnapSubelement);
    
    if (!drawing_.outlineMode) {
        flags |= kWDSnapFills;
    }
    
    for (WDLayer *layer in [drawing_.layers reverseObjectEnumerator]) {
        if (layer.hidden) {
            continue;
        }
        
        if (drawing_.isolateActiveLayer && (drawing_.activeLayer != layer)) {
            continue;
        }
        
        for (WDElement *element in [layer.elements reverseObjectEnumerator]) {
            pickResult = [element hitResultForPoint:pt viewScale:viewScale snapFlags:(int)flags];
            
            if (pickResult.type != kWDEther) {
                return pickResult;
            }
        }
    }
    
    return [WDPickResult pickResult];
}

- (WDPickResult *) objectUnderPoint:(CGPoint)pt viewScale:(float)viewScale
{
    WDPickResult    *pickResult;
    NSUInteger      flags = kWDSnapEdges;
    
    if (!drawing_.outlineMode) {
        flags |= kWDSnapFills;
    }
    
    // first test active path
    if (self.activePath) {
        pickResult = [self.activePath hitResultForPoint:pt viewScale:viewScale snapFlags:kWDSnapNodes];
    	
        if (pickResult.type != kWDEther) {
            return pickResult;
        }
    }
    
    // check singly selected objects, which get specialized behavior
    if (!self.activePath && self.selectedObjects.count == 1) {
        pickResult = [[self.selectedObjects anyObject] hitResultForPoint:pt
                                                               viewScale:viewScale
                                                               snapFlags:(kWDSnapNodes | kWDSnapEdges)];
        if (pickResult.type != kWDEther) {
            return pickResult;
        }
    }
    
    for (WDLayer *layer in [drawing_.layers reverseObjectEnumerator]) {
        if (!layer.editable) {
            continue;
        }
        
        if (drawing_.isolateActiveLayer && (drawing_.activeLayer != layer)) {
            continue;
        }
        
        for (WDElement *element in [layer.elements reverseObjectEnumerator]) {
            pickResult = [element hitResultForPoint:pt viewScale:viewScale snapFlags:(int)flags];
            
            if (pickResult.type != kWDEther) {
                return pickResult;
            }
        }
    }
    
    return [WDPickResult pickResult];
}

#pragma mark -
#pragma mark Can Do Methods

- (BOOL) canPaste
{
    if (!drawing_.activeLayer.editable) {
        return NO;
    }
    
#if TARGET_OS_IPHONE
    UIPasteboard *pb = [self generalPasteboard];
    
    if (pb.image || pb.images || pb.string || pb.strings) {
        return YES;
    }
    
    if ([pb containsPasteboardTypes:@[WDPasteboardDataType]]) {
        return YES;
    }
#endif
    
    return NO;
}

- (BOOL) canJoinPaths
{
    if (selectedObjects_.count != 2) {
        return NO;
    }
    
    for (WDElement *element in selectedObjects_) {
        WDPath *path = (WDPath *) element;
        if (![path isKindOfClass:[WDPath class]] || path.superpath || path.closed || [path conformsToProtocol:@protocol(WDTextRenderer)]) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL) canMakeCompoundPath
{
    if ([self orderedSelectedObjects].count > 1) {
        NSMutableArray *ordered = [self orderedSelectedObjects];
        
        for (WDElement *element in ordered) {
            if (![element isKindOfClass:[WDAbstractPath class]]) {
                return NO;
            } else {
                // don't allow masks or text paths to make compound paths
                WDAbstractPath *path = (WDAbstractPath *) element;
                
                if (path.isMasking || [path conformsToProtocol:@protocol(WDTextRenderer)]) {
                    return NO;
                }
            }
        }
        
        return YES;
    }
    
    return NO;
}

- (BOOL) canReleaseCompoundPath
{
    for (WDElement *element in selectedObjects_) {
        if ([element isKindOfClass:[WDCompoundPath class]]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL) canMakeMask
{
    if ((self.selectedObjects.count > 1) && [self allSelectedObjectsAreRootObjects]) {
        WDElement *element = [[self orderedSelectedObjects] lastObject];
        
        if (element && [element canMaskElements]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL) canReleaseMask
{
    for (WDElement *element in selectedObjects_) {
        if ([element canMaskElements]) {
            WDStylable *stylable = (WDStylable *) element;
            
            if (stylable.isMasking) {
                return YES;
            }
        }
    }
    
    return NO;
}


- (BOOL) canGroup
{
    return (self.selectedObjects.count > 1) ? [self allSelectedObjectsAreRootObjects] : NO;
}

- (BOOL) canUngroup
{
    for (WDElement *element in selectedObjects_) {
        if ([element isKindOfClass:[WDGroup class]]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL) canAddAnchors
{
    WDPath *path = (WDPath *) [self singleSelection];
    return [path isKindOfClass:[WDPath class]];
}

- (BOOL) canReversePathDirection
{
    for (WDElement *element in selectedObjects_) {
        if ([element isKindOfClass:[WDPath class]]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL) canOutlineStroke
{
    for (WDElement *element in [self orderedSelectedObjects]) {
        if ([element isKindOfClass:[WDAbstractPath class]]) {
            if ([(WDAbstractPath *)element canOutlineStroke]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL) canDeleteAnchors
{
    WDPath *path = (WDPath *) [self singleSelection];
    
    if ([path isKindOfClass:[WDPath class]]) {
        return [path canDeleteAnchors];
    }
    
    return NO;
}

- (BOOL) canCreateTextOutlines
{
    if (selectedObjects_.count != 1) {
        return NO;
    }
    
    for (WDElement *element in selectedObjects_) {
        if (![element conformsToProtocol:@protocol(WDTextRenderer)]) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL) canPlaceTextOnPath
{
    if (selectedObjects_.count == 2) {
        // see if we have a text object and a path selected
        BOOL oneIsText = NO;
        BOOL oneCanPlace = NO;
        
        for (WDElement *element in selectedObjects_) {
            if ([element canPlaceText]) {
                oneCanPlace = YES;
            } else if ([element isKindOfClass:[WDText class]]) {
                oneIsText = YES;
            }
        }
        
        return (oneIsText && oneCanPlace);
    }
    
    // otherwise see if we just have a path
    if (selectedObjects_.count != 1) {
        return NO;
    }
    
    WDElement *element = (WDElement *) [selectedObjects_ anyObject];
    return [element canPlaceText];
}

- (BOOL) canAdjustColor
{
    for (WDElement *element in self.selectedObjects) {
        if ([element canAdjustColor]) {
            return YES;
        }
    }
    
    return NO;
}

@end
