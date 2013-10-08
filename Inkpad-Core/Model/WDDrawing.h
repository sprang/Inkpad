//
//  WDDrawing.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>
#import "WDDocumentProtocol.h"
#import "WDStrokeStyle.h"

@class WDColor;
@class WDDrawing;
@class WDElement;
@class WDGradient;
@class WDImageData;
@class WDLayer;
@class WDPickResult;
@class WDRulerUnit;

extern const float kMinimumDrawingDimension;
extern const float kMaximumDrawingDimension;

enum {
    WDRenderDefault      = 0x0,
    WDRenderOutlineOnly  = 0x1,
    WDRenderThumbnail    = 0x1 << 1,
    WDRenderFlipped      = 0x1 << 2
};

typedef struct {
    float   scale;
    UInt32  flags;
} WDRenderingMetaData;

WDRenderingMetaData WDRenderingMetaDataMake(float scale, UInt32 flags);
BOOL WDRenderingMetaDataOutlineOnly(WDRenderingMetaData metaData);

@protocol WDDocumentProtocol;
@protocol WDPathPainter;

@interface WDDrawing : NSObject <NSCoding, NSCopying> {    
    NSMutableDictionary     *imageDatas_;
    NSInteger               suppressNotifications_;
}

@property (nonatomic, readonly) CGSize dimensions;
@property (nonatomic, readonly) NSMutableArray *layers;
@property (weak, nonatomic, readonly) WDLayer *activeLayer;
@property (nonatomic, readonly) NSMutableDictionary *settings;
@property (nonatomic, assign) BOOL deleted;
@property (nonatomic, strong) NSUndoManager *undoManager;
@property (nonatomic, weak) id<WDDocumentProtocol> document;

@property (nonatomic, assign) float width;
@property (nonatomic, assign) float height;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) NSUInteger indexOfActiveLayer;
@property (nonatomic, assign) BOOL snapToEdges;
@property (nonatomic, assign) BOOL snapToPoints;
@property (nonatomic, assign) BOOL snapToGrid;
@property (nonatomic, assign) BOOL showGrid;
@property (nonatomic, assign) BOOL isolateActiveLayer;
@property (nonatomic, assign) BOOL outlineMode;
@property (nonatomic, assign) BOOL rulersVisible;
@property (nonatomic, weak) NSString *units;
@property (weak, nonatomic, readonly) WDRulerUnit *rulerUnit;
@property (nonatomic, assign) float gridSpacing;
@property (nonatomic, readonly) BOOL isSuppressingNotifications;

- (id) initWithUnits:(NSString *)units; // for use with SVG import only
- (id) initWithSize:(CGSize)size andUnits:(NSString *)units;

- (void) beginSuppressingNotifications;
- (void) endSuppressingNotifications;

- (void) purgeUnreferencedImageDatas;
- (WDImageData *) trackedImageData:(WDImageData *)imageData;

- (void) renderInContext:(CGContextRef)ctx clipRect:(CGRect)clip metaData:(WDRenderingMetaData)metaData;

- (void) activateLayerAtIndex:(NSUInteger)ix;
- (void) addLayer:(WDLayer *)layer;
- (BOOL) canDeleteLayer;
- (void) deleteActiveLayer;
- (void) insertLayer:(WDLayer *)layer atIndex:(NSUInteger)index;
- (void) moveLayerAtIndex:(NSUInteger)src toIndex:(NSUInteger)dest;
- (void) duplicateActiveLayer;
- (NSString *) uniqueLayerName;

- (NSArray *) allElements;
- (void) addObject:(id)obj;

- (NSUInteger) snapFlags;

- (id) initWithImage:(UIImage *)image imageName:(NSString *)imageName;
- (WDImageData *) imageDataForUIImage:(UIImage *)image;
+ (UIImage *) imageForElements:(NSArray *)elements scale:(float)scale;
- (UIImage *) image;

- (NSData *) inkpadRepresentation;
- (NSData *) PDFRepresentation;
- (NSData *) SVGRepresentation;
- (NSData *) thumbnailData;
- (UIImage *) thumbnailImage;

- (void) setSetting:(NSString *)name value:(NSString *)value;

@end

// Setting keys
extern NSString *WDSnapToPoints;
extern NSString *WDSnapToEdges;
extern NSString *WDSnapToGrid;
extern NSString *WDShowGrid;
extern NSString *WDGridSpacing;
extern NSString *WDIsolateActiveLayer;
extern NSString *WDOutlineMode;
extern NSString *WDRulersVisible;
extern NSString *WDUnits;
extern NSString *WDCustomSizeWidth;
extern NSString *WDCustomSizeHeight;
extern NSString *WDCustomSizeUnits;

// Notifications
extern NSString *WDLayersReorderedNotification;
extern NSString *WDLayerAddedNotification;
extern NSString *WDLayerDeletedNotification;
extern NSString *WDIsolateActiveLayerSettingChangedNotification;
extern NSString *WDOutlineModeSettingChangedNotification;
extern NSString *WDActiveLayerChanged;
extern NSString *WDDrawingChangedNotification;
extern NSString *WDRulersVisibleSettingChangedNotification;
extern NSString *WDUnitsChangedNotification;
extern NSString *WDDrawingDimensionsChanged;
extern NSString *WDGridSpacingChangedNotification;

// encoder keys
extern NSString *WDDrawingKey;
extern NSString *WDThumbnailKey;
