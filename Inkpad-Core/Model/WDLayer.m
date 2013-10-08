//
//  WDLayer.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "UIColor+Additions.h"
#import "WDDrawing.h"
#import "WDElement.h"
#import "WDLayer.h"
#import "WDSVGHelper.h"
#import "WDUtilities.h"

#define kPreviewInset               0
#define kDrawPreviewBorder          NO
#define kDefaultThumbnailDimension  50

NSString *WDLayerVisibilityChanged = @"WDLayerVisibilityChanged";
NSString *WDLayerLockedStatusChanged = @"WDLayerLockedStatusChanged";
NSString *WDLayerOpacityChanged = @"WDLayerOpacityChanged";
NSString *WDLayerContentsChangedNotification = @"WDLayerContentsChangedNotification";
NSString *WDLayerThumbnailChangedNotification = @"WDLayerThumbnailChangedNotification";
NSString *WDLayerNameChanged = @"WDLayerNameChanged";

NSString *WDElementsKey = @"WDElementsKey";
NSString *WDVisibleKey = @"WDVisibleKey";
NSString *WDLockedKey = @"WDLockedKey";
NSString *WDNameKey = @"WDNameKey";
NSString *WDHighlightColorKey = @"WDHighlightColorKey";
NSString *WDOpacityKey = @"WDOpacityKey";

@implementation WDLayer

@synthesize elements = elements_;
@synthesize highlightColor = highlightColor_;
@synthesize drawing = drawing_;
@synthesize name = name_;
@synthesize visible = visible_;
@synthesize locked = locked_;
@synthesize opacity = opacity_;
@synthesize styleBounds = styleBounds_;
@synthesize thumbnail = thumbnail_;

+ (WDLayer *) layer
{
    return [[WDLayer alloc] init];
}

- (id) init
{
    NSMutableArray* elements = [[NSMutableArray alloc] init];
    return [self initWithElements:elements];
}

- (id) initWithElements:(NSMutableArray *)elements
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    elements_ = elements;
    [elements_ makeObjectsPerformSelector:@selector(setLayer:) withObject:self];
    self.highlightColor = [UIColor saturatedRandomColor];
    self.visible = YES;
    opacity_ = 1.0f;
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:elements_ forKey:WDElementsKey];
    [coder encodeConditionalObject:drawing_ forKey:WDDrawingKey];
    [coder encodeBool:visible_ forKey:WDVisibleKey];
    [coder encodeBool:locked_ forKey:WDLockedKey];
    [coder encodeObject:name_ forKey:WDNameKey];
#if TARGET_OS_IPHONE
    [coder encodeObject:highlightColor_ forKey:WDHighlightColorKey];
#endif
    
    if (opacity_ != 1.0f) {
        [coder encodeFloat:opacity_ forKey:WDOpacityKey];
    }
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    elements_ = [coder decodeObjectForKey:WDElementsKey]; 
    drawing_ = [coder decodeObjectForKey:WDDrawingKey]; 
    visible_ = [coder decodeBoolForKey:WDVisibleKey];
    locked_ = [coder decodeBoolForKey:WDLockedKey];
    self.name = [coder decodeObjectForKey:WDNameKey];
#if TARGET_OS_IPHONE
    self.highlightColor = [coder decodeObjectForKey:WDHighlightColorKey];
#endif
    
    if ([coder containsValueForKey:WDOpacityKey]) {
        self.opacity = [coder decodeFloatForKey:WDOpacityKey];
    } else {
        self.opacity = 1.0f;
    }
    
    if (!self.highlightColor) {
        self.highlightColor = [UIColor saturatedRandomColor];
    }
    
    return self; 
}

- (void) awakeFromEncoding
{
    [elements_ makeObjectsPerformSelector:@selector(awakeFromEncoding) withObject:nil];
}

- (BOOL) isSuppressingNotifications
{
    if (!drawing_ || drawing_.isSuppressingNotifications) {
        return YES;
    }
    
    return NO;
}

- (void) renderInContext:(CGContextRef)ctx clipRect:(CGRect)clip metaData:(WDRenderingMetaData)metaData
{
    BOOL useTransparencyLayer = (!WDRenderingMetaDataOutlineOnly(metaData) && opacity_ != 1.0f) ? YES : NO;
    
    if (useTransparencyLayer) {
        CGContextSaveGState(ctx);
        CGContextSetAlpha(ctx, opacity_);
        CGContextBeginTransparencyLayer(ctx, NULL);
    }
    
    for (WDElement *element in elements_) {
        if (CGRectIntersectsRect([element styleBounds], clip)) {
            [element renderInContext:ctx metaData:metaData];
        }
    }
    
    if (useTransparencyLayer) {
        CGContextEndTransparencyLayer(ctx);
        CGContextRestoreGState(ctx);
    }
}

- (void) setOpacity:(float)opacity
{
    if (opacity == opacity_) {
        return;
    }
    
    [[[self.drawing undoManager] prepareWithInvocationTarget:self] setOpacity:opacity_];
    
    opacity_ = WDClamp(0.0f, 1.0f, opacity);
    
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"layer": self,
                                  @"rect": [NSValue valueWithCGRect:self.styleBounds]};
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDLayerOpacityChanged
                                                            object:self.drawing
                                                          userInfo:userInfo];
    }
}

- (WDXMLElement *) SVGElement
{
    if (elements_.count == 0) {
        // no reason to add this layer
        return nil;
    }
    
    WDXMLElement *layer = [WDXMLElement elementWithName:@"g"];
    [layer setAttribute:@"id" value:[[WDSVGHelper sharedSVGHelper] uniqueIDWithPrefix:@"Layer"]];
    [layer setAttribute:@"inkpad:layerName" value:name_];
    
    if (self.hidden) {
        [layer setAttribute:@"visibility" value:@"hidden"];
    }
    
    if (self.opacity != 1.0f) {
        [layer setAttribute:@"opacity" floatValue:opacity_];
    }
    
    for (WDElement *element in elements_) {
        [layer addChild:[element SVGElement]];
    }
    
    return layer;
}

- (void) addElementsToArray:(NSMutableArray *)elements
{
    [elements_ makeObjectsPerformSelector:@selector(addElementsToArray:) withObject:elements];
}

- (void) addObject:(WDElement *)obj
{
    [[self.drawing.undoManager prepareWithInvocationTarget:self] removeObject:obj];
     
    [elements_ addObject:obj];
    obj.layer = self;
    
    [self invalidateThumbnail];
    
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"layer": self,
                                  @"rect": [NSValue valueWithCGRect:obj.styleBounds]};
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDLayerContentsChangedNotification
                                                            object:self.drawing
                                                          userInfo:userInfo];  
    }
}

- (void) addObjects:(NSArray *)objects
{
    for (WDElement *element in objects) {
        [self addObject:element];
    }
}

- (void) removeObject:(WDElement *)obj
{
    [[self.drawing.undoManager prepareWithInvocationTarget:self] insertObject:obj atIndex:[elements_ indexOfObject:obj]];
    
    [elements_ removeObject:obj];
    
    [self invalidateThumbnail];
    
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"layer": self,
                                  @"rect": [NSValue valueWithCGRect:obj.styleBounds]};
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDLayerContentsChangedNotification
                                                            object:self.drawing
                                                          userInfo:userInfo];
    }
}

- (void) insertObject:(WDElement *)element atIndex:(NSUInteger)index
{
    [[self.drawing.undoManager prepareWithInvocationTarget:self] removeObject:element];
    
    element.layer = self;
    [elements_ insertObject:element atIndex:index];
    
    [self invalidateThumbnail];
    
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"layer": self,
                                  @"rect": [NSValue valueWithCGRect:element.styleBounds]};
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDLayerContentsChangedNotification
                                                            object:self.drawing
                                                          userInfo:userInfo];
    }
}

- (void) insertObject:(WDElement *)element above:(WDElement *)above
{
    [self insertObject:element atIndex:[elements_ indexOfObject:above]];
}

- (void) exchangeObjectAtIndex:(NSUInteger)src withObjectAtIndex:(NSUInteger)dest
{
    [[self.drawing.undoManager prepareWithInvocationTarget:self] exchangeObjectAtIndex:src withObjectAtIndex:dest];
    
    [elements_ exchangeObjectAtIndex:src withObjectAtIndex:dest];
    
    WDElement *srcElement = elements_[src];
    WDElement *destElement = elements_[dest];
    
    CGRect dirtyRect = CGRectIntersection(srcElement.styleBounds, destElement.styleBounds);
    
    [self invalidateThumbnail];
    
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"layer": self,
                                  @"rect": [NSValue valueWithCGRect:dirtyRect]};
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDLayerContentsChangedNotification
                                                            object:self.drawing
                                                          userInfo:userInfo];
    }
}

- (void) sendBackward:(NSSet *)elements
{
    NSInteger top = [elements_ count];
    
    for (int i = 1; i < top; i++) {
        WDElement *curr = (WDElement *) elements_[i];
        WDElement *below = (WDElement *) elements_[i-1];
        
        if ([elements containsObject:curr] && ![elements containsObject:below]) {
            [self exchangeObjectAtIndex:i withObjectAtIndex:(i-1)];
        }
    }
}

- (void) sendToBack:(NSArray *)sortedElements
{
    for (WDElement *e in [sortedElements reverseObjectEnumerator]) {
        [self removeObject:e];
        [self insertObject:e atIndex:0];
    }
}

- (void) bringForward:(NSSet *)elements
{
    NSInteger top = [elements_ count] - 1;
    
    for (NSInteger i = top - 1; i >= 0; i--) {
        WDElement *curr = (WDElement *) elements_[i];
        WDElement *above = (WDElement *) elements_[i+1];
        
        if ([elements containsObject:curr] && ![elements containsObject:above]) {
            [self exchangeObjectAtIndex:i withObjectAtIndex:(i+1)];
        }
    }
}

- (void) bringToFront:(NSArray *)sortedElements
{
    NSInteger top = [elements_ count] - 1;
    
    for (WDElement *e in sortedElements) {
        [self removeObject:e];
        [self insertObject:e atIndex:top];
    }
}

- (CGRect) styleBounds 
{
    CGRect styleBounds = CGRectNull;
    
    for (WDElement *element in elements_) {
        styleBounds = CGRectUnion(styleBounds, element.styleBounds);
    }
    
    return styleBounds;
}

- (void) notifyThumbnailChanged:(id)obj
{
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"layer": self};
        [[NSNotificationCenter defaultCenter] postNotificationName:WDLayerThumbnailChangedNotification object:self.drawing userInfo:userInfo];
    }
}

- (void) invalidateThumbnail
{
    if (!thumbnail_) {
        return;
    }
    
    thumbnail_ = nil;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(notifyThumbnailChanged:) object:nil];
    [self performSelector:@selector(notifyThumbnailChanged:) withObject:nil afterDelay:0];
}

- (UIImage *) thumbnail
{
    if (!thumbnail_) {
        thumbnail_ = [self previewInRect:CGRectMake(0, 0, kDefaultThumbnailDimension, kDefaultThumbnailDimension)];
    }
    
    return thumbnail_;
}

- (UIImage *) previewInRect:(CGRect)dest
{
    CGRect  contentBounds = [self styleBounds];
    float   contentAspect = CGRectGetWidth(contentBounds) / CGRectGetHeight(contentBounds);
    float   destAspect = CGRectGetWidth(dest)  / CGRectGetHeight(dest);
    float   scaleFactor = 1.0f;
    CGPoint offset = CGPointZero;
    
    UIGraphicsBeginImageContextWithOptions(dest.size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    dest = CGRectInset(dest, kPreviewInset, kPreviewInset);
    
    if (contentAspect > destAspect) {
        scaleFactor = CGRectGetWidth(dest) / CGRectGetWidth(contentBounds);
        offset.y = CGRectGetHeight(dest) - (scaleFactor * CGRectGetHeight(contentBounds));
        offset.y /= 2;
    } else {
        scaleFactor = CGRectGetHeight(dest) / CGRectGetHeight(contentBounds);
        offset.x = CGRectGetWidth(dest) - (scaleFactor * CGRectGetWidth(contentBounds));
        offset.x /= 2;
    }
    
    // scale and offset the layer contents to render in the new image
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, offset.x + kPreviewInset, offset.y + kPreviewInset);
    CGContextScaleCTM(ctx, scaleFactor, scaleFactor);
    CGContextTranslateCTM(ctx, -contentBounds.origin.x, -contentBounds.origin.y);
    
    for (WDElement *element in elements_) {
        [element renderInContext:ctx metaData:WDRenderingMetaDataMake(scaleFactor, WDRenderThumbnail)];   
    }
    CGContextRestoreGState(ctx);
    
    if (kDrawPreviewBorder) {
        [[UIColor colorWithWhite:0.75 alpha:1] set];
        UIRectFrame(CGRectInset(dest, -kPreviewInset, -kPreviewInset));
    }
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    
    return result;
}

- (void) toggleLocked
{
    self.locked = !self.locked;
}

- (void) toggleVisibility
{
    self.visible = !self.visible;
}

- (BOOL) editable
{
    return (!self.locked && self.visible);
}

- (BOOL) hidden 
{
    return !visible_;
}

- (void) setHidden:(BOOL)hidden
{
    [self setVisible:!hidden];
}

- (void) setVisible:(BOOL)visible
{
    [[[self.drawing undoManager] prepareWithInvocationTarget:self] setVisible:visible_];
    
    visible_ = visible;
    
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"layer": self,
                                  @"rect": [NSValue valueWithCGRect:self.styleBounds]};
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDLayerVisibilityChanged
                                                            object:self.drawing
                                                          userInfo:userInfo];
    }
}

- (void) setLocked:(BOOL)locked
{
    [[[self.drawing undoManager] prepareWithInvocationTarget:self] setLocked:locked_];
    
    locked_ = locked;
    
    if (!self.isSuppressingNotifications) {
        
        NSDictionary *userInfo = @{@"layer": self};
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDLayerLockedStatusChanged
                                                            object:self.drawing
                                                          userInfo:userInfo];
    }
}

- (void) setName:(NSString *)name
{
    [(WDLayer *) [[self.drawing undoManager] prepareWithInvocationTarget:self] setName:name_];
    
    name_ = name;
    
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"layer": self};
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDLayerNameChanged object:self.drawing userInfo:userInfo];
    }
}

- (id) copyWithZone:(NSZone *)zone
{
    WDLayer *layer = [[WDLayer alloc] init];
    
    layer->opacity_ = self->opacity_;
    layer->locked_ = self->locked_;
    layer->visible_ = self->visible_;
    layer->name_ = [self.name copy];
    layer.highlightColor = self.highlightColor;
    
    // copy elements
    layer->elements_ = [[NSMutableArray alloc] initWithArray:elements_ copyItems:YES];
    [layer->elements_ makeObjectsPerformSelector:@selector(setLayer:) withObject:layer];
    
    return layer;
}

@end
