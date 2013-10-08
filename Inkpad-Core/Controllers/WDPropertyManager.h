//
//  WDPropertyManager.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@class WDDrawingController;
@class WDShadow;
@class WDStrokeStyle;

@protocol WDPathPainter;

@interface WDPropertyManager : NSObject {
@private
    NSMutableSet        *invalidProperties_;
    NSMutableDictionary *defaults_;
}

@property (nonatomic, weak) WDDrawingController *drawingController;
@property (nonatomic, assign) BOOL ignoreSelectionChanges;

- (void) addToInvalidProperties:(NSString *)property;

- (void) setDefaultValue:(id)value forProperty:(NSString *)property;
- (id) defaultValueForProperty:(NSString *)property;

- (WDStrokeStyle *) activeStrokeStyle;
- (WDStrokeStyle *) defaultStrokeStyle;

- (id<WDPathPainter>) activeFillStyle;
- (id<WDPathPainter>) defaultFillStyle;

- (WDShadow *) activeShadow;
- (WDShadow *) defaultShadow;

- (void) updateUserDefaults;

@end

// notifications
extern NSString *WDActiveStrokeChangedNotification;
extern NSString *WDActiveFillChangedNotification;
extern NSString *WDActiveShadowChangedNotification;
extern NSString *WDInvalidPropertiesNotification;
extern NSString *WDInvalidPropertiesKey;
