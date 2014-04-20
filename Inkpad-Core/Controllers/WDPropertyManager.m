//
//  WDPropertyManager.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDColor.h"
#import "WDDrawingController.h"
#import "WDFontManager.h"
#import "WDGradient.h"
#import "WDInspectableProperties.h"
#import "WDPropertyManager.h"
#import "WDShadow.h"

NSString *WDInvalidPropertiesNotification = @"WDInvalidPropertiesNotification";
NSString *WDActiveStrokeChangedNotification = @"WDActiveStrokeChangedNotification";
NSString *WDActiveFillChangedNotification = @"WDActiveFillChangedNotification";
NSString *WDActiveShadowChangedNotification = @"WDActiveShadowChangedNotification";
NSString *WDInvalidPropertiesKey = @"WDInvalidPropertiesKey";

@interface WDPropertyManager (private)
- (BOOL) propertyAffectsActiveShadow:(NSString *)property;
- (BOOL) propertyAffectsActiveStroke:(NSString *)property;
@end

@implementation WDPropertyManager

@synthesize drawingController = drawingController_;
@synthesize ignoreSelectionChanges = ignoreSelectionChanges_;

- (id) init
{
    self = [super init];

    if (!self) {
        return nil;
    }
    
    invalidProperties_ = [[NSMutableSet alloc] init];
    
    // constantly updating the user defaults kills responsiveness after the keyboard has been made visible
    // so use this temporary dictionary to avoid hitting the defaults all the time
    defaults_ = [[NSMutableDictionary alloc] init];
    
    // see if the default font has been uninstalled
    if (![[WDFontManager sharedInstance] validFont:[self defaultValueForProperty:WDFontNameProperty]]) {
        [self setDefaultValue:@"Helvetica" forProperty:WDFontNameProperty];
    }
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // transfer our cached defaults to the real defaults
    [self updateUserDefaults];
}

- (void) setDrawingController:(WDDrawingController *)drawingController
{
    drawingController_ = drawingController;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(propertyChanged:)
                                                 name:WDPropertyChangedNotification
                                               object:drawingController_.drawing];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(propertiesChanged:)
                                                 name:WDPropertiesChangedNotification
                                               object:drawingController_.drawing];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(selectionChanged:)
                                                 name:WDSelectionChangedNotification
                                               object:drawingController_];
}

- (void) updateUserDefaults
{
    for (NSString *key in [defaults_ allKeys]) {
        [[NSUserDefaults standardUserDefaults] setObject:defaults_[key] forKey:key];
    }
}

- (void) addToInvalidProperties:(NSString *)property
{
    if ([invalidProperties_ containsObject:property]) {
        return;
    }
    
    [invalidProperties_ addObject:property];
    
    if ([self propertyAffectsActiveShadow:property]) {
        [invalidProperties_ addObject:WDShadowVisibleProperty];
    }
    
    if ([self propertyAffectsActiveStroke:property]) {
        [invalidProperties_ addObject:WDStrokeVisibleProperty];
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invalidateProperties:) object:nil];
    [self performSelector:@selector(invalidateProperties:) withObject:nil afterDelay:0];
}

- (void) invalidateProperties:(id)obj
{
    // the default value for each property comes from the topmost selected object that has that property
    for (NSString *property in invalidProperties_) {
        for (WDElement *element in [[drawingController_ orderedSelectedObjects] reverseObjectEnumerator]) {
            if ([element valueForProperty:property]) {
                [self setDefaultValue:[element valueForProperty:property] forProperty:property];
                break;
            }
        }
    }
    
    NSDictionary *userInfo = @{WDInvalidPropertiesKey: [invalidProperties_ copy]};
    [[NSNotificationCenter defaultCenter] postNotificationName:WDInvalidPropertiesNotification object:self userInfo:userInfo];
    
    [invalidProperties_ removeAllObjects];
}

- (void) propertiesChanged:(NSNotification *)aNotification
{
    NSDictionary    *dictionary = aNotification.userInfo;
    NSSet           *properties = dictionary[WDPropertiesKey];
    
    if (![properties isSubsetOfSet:invalidProperties_]) {
        [invalidProperties_ unionSet:properties];
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invalidateProperties:) object:nil];
        [self performSelector:@selector(invalidateProperties:) withObject:nil afterDelay:0];
    }
}

- (void) propertyChanged:(NSNotification *)aNotification
{
    NSDictionary    *dictionary = aNotification.userInfo;
    NSString        *property = dictionary[WDPropertyKey];
    
    if (![invalidProperties_ containsObject:property]) {
        [invalidProperties_ addObject:property];
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invalidateProperties:) object:nil];
        [self performSelector:@selector(invalidateProperties:) withObject:nil afterDelay:0];
    }
}

- (void) selectionChanged:(NSNotification *)aNotification
{
    if (ignoreSelectionChanges_) {
        return;
    }
    
    NSArray *selected = [drawingController_ orderedSelectedObjects];
    
    WDElement *topSelected = [selected lastObject];
    
    if (topSelected) {
        for (NSString *property in [topSelected inspectableProperties]) {
            [self setDefaultValue:[topSelected valueForProperty:property] forProperty:property];
        }
    
        [invalidProperties_ addObjectsFromArray:[[topSelected inspectableProperties] allObjects]];
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invalidateProperties:) object:nil];
        [self performSelector:@selector(invalidateProperties:) withObject:nil afterDelay:0];
    }
}

- (void) setIgnoreSelectionChanges:(BOOL)ignore
{
    ignoreSelectionChanges_ = ignore;
    
    if (!ignore) {
        // find out what's changed while we were ignoring
        [self selectionChanged:nil];
    }
}

- (BOOL) propertyAffectsActiveShadow:(NSString *)property
{
    static NSSet *shadowProperties = nil;
    
    if (!shadowProperties) {
        shadowProperties = [NSSet setWithObjects:WDOpacityProperty, WDShadowColorProperty, WDShadowAngleProperty,
                            WDShadowOffsetProperty, WDShadowRadiusProperty, WDShadowVisibleProperty, nil];
    }
    
    return [shadowProperties containsObject:property];
}

- (BOOL) propertyAffectsActiveStroke:(NSString *)property
{
    static NSSet *strokeProperties = nil;
    
    if (!strokeProperties) {
        strokeProperties = [NSSet setWithObjects:WDStrokeColorProperty, WDStrokeCapProperty, WDStrokeJoinProperty,
                            WDStrokeWidthProperty, WDStrokeVisibleProperty, WDStrokeDashPatternProperty,
                            WDStartArrowProperty, WDEndArrowProperty, nil];
    }
    
    return [strokeProperties containsObject:property];
}

- (void) setDefaultValue:(id)value forProperty:(NSString *)property
{
    if (!value) {
        return;
    }
    
    if ([property isEqualToString:WDFillProperty]) {
        // want to track the default color and gradient
        if ([value isKindOfClass:[WDColor class]]) {
            defaults_[WDFillColorProperty] = [NSKeyedArchiver archivedDataWithRootObject:value];
        } else if ([value isKindOfClass:[WDGradient class]]) {
            defaults_[WDFillGradientProperty] = [NSKeyedArchiver archivedDataWithRootObject:value];
        }
    }
    
    if ([property isEqualToString:WDFillProperty] || [property isEqualToString:WDStrokeColorProperty] || [property isEqualToString:WDShadowColorProperty]) {
        value = [NSKeyedArchiver archivedDataWithRootObject:value];
    }
    
    if ([[defaults_ valueForKey:property] isEqual:value]) {
        return;
    }
    
    defaults_[property] = value;
    
    if ([property isEqualToString:WDFillProperty]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WDActiveFillChangedNotification object:self userInfo:nil];
    } else if ([self propertyAffectsActiveStroke:property]) {
        if (![property isEqual:WDStrokeVisibleProperty]) {
            defaults_[WDStrokeVisibleProperty] = @YES;
        } else if (![value boolValue]) {
            // turning off the stroke, so reset the arrows
            defaults_[WDStartArrowProperty] = WDStrokeArrowNone;
            defaults_[WDEndArrowProperty] = WDStrokeArrowNone;
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDActiveStrokeChangedNotification object:self userInfo:nil];
    } else if ([self propertyAffectsActiveShadow:property]) {
        if (![property isEqual:WDShadowVisibleProperty] && ![property isEqual:WDOpacityProperty]) {
            defaults_[WDShadowVisibleProperty] = @YES;
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDActiveShadowChangedNotification object:self userInfo:nil];
    } 
}

- (id) defaultValueForProperty:(NSString *)property
{
    id      value = [defaults_ valueForKey:property];
    NSData  *data = nil;
    
    if (!value) {
        value = [[NSUserDefaults standardUserDefaults] valueForKey:property];
        defaults_[property] = value;
    }
    
    if ([value isKindOfClass:[NSData class]]) {
        data = (NSData *) value;
        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return value;
}

- (WDStrokeStyle *) activeStrokeStyle
{
    if (![[self defaultValueForProperty:WDStrokeVisibleProperty] boolValue]) {
        return nil;
    }
    
    return [self defaultStrokeStyle];
}

- (WDStrokeStyle *) defaultStrokeStyle
{
    return [WDStrokeStyle strokeStyleWithWidth:[[self defaultValueForProperty:WDStrokeWidthProperty] floatValue]
                                           cap:(int)[[self defaultValueForProperty:WDStrokeCapProperty] integerValue]
                                          join:(int)[[self defaultValueForProperty:WDStrokeJoinProperty] integerValue]
                                         color:[self defaultValueForProperty:WDStrokeColorProperty]
                                   dashPattern:[self defaultValueForProperty:WDStrokeDashPatternProperty]
                                    startArrow:[self defaultValueForProperty:WDStartArrowProperty]
                                      endArrow:[self defaultValueForProperty:WDEndArrowProperty]];
}

- (WDShadow *) activeShadow
{   
    if (![[self defaultValueForProperty:WDShadowVisibleProperty] boolValue]) {
        return nil;
    }
    
    return [self defaultShadow];
}

- (WDShadow *) defaultShadow
{
    return [WDShadow shadowWithColor:[self defaultValueForProperty:WDShadowColorProperty]
                              radius:[[self defaultValueForProperty:WDShadowRadiusProperty] floatValue]
                              offset:[[self defaultValueForProperty:WDShadowOffsetProperty] floatValue]
                               angle:[[self defaultValueForProperty:WDShadowAngleProperty] floatValue]];
}

- (id<WDPathPainter>) activeFillStyle
{
    id value = [self defaultValueForProperty:WDFillProperty];
    
    if ([value isEqual:[NSNull null]]) {
        return nil;
    }
    
    return value;
}

- (id<WDPathPainter>) defaultFillStyle
{
    id value = [self defaultValueForProperty:WDFillProperty];
    
    if ([value isEqual:[NSNull null]]) {
        return nil;
    }
    
    return value;
}

@end
