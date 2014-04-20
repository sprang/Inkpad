//
//  WDDrawing.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#if !TARGET_OS_IPHONE
#import "NSCoderAdditions.h"
#endif

#import "UIColor+Additions.h"
#import "WDColor.h"
#import "WDDocumentProtocol.h"
#import "WDImage.h"
#import "WDImageData.h"
#import "WDLayer.h"
#import "WDPath.h"
#import "WDRulerUnit.h"
#import "WDSVGHelper.h"
#import "WDUtilities.h"

const float kMinimumDrawingDimension = 16;
const float kMaximumDrawingDimension = 16000;
const float kMaximumBitmapImageArea = 4096 * 4096;
const float kMaximumCopiedBitmapImageDimension = 2048;
const float kMaximumThumbnailDimension = 120;

// encoder keys
NSString *WDDrawingKey = @"WDDrawingKey";
NSString *WDThumbnailKey = @"WDThumbnailKey";
NSString *WDLayersKey = @"WDLayersKey"; 
NSString *WDDimensionsKey = @"WDDimensionsKey"; 
NSString *WDImageDatasKey = @"WDImageDatasKey";
NSString *WDSettingsKey = @"WDSettingsKey";
NSString *WDActiveLayerKey = @"WDActiveLayerKey";
NSString *WDUnitsKey = @"WDUnitsKey";

// Setting Keys
NSString *WDSnapToPoints = @"WDSnapToPoints";
NSString *WDSnapToEdges = @"WDSnapToEdges";
NSString *WDIsolateActiveLayer = @"WDIsolateActiveLayer";
NSString *WDOutlineMode = @"WDOutlineMode";
NSString *WDSnapToGrid = @"WDSnapToGrid";
NSString *WDDynamicGuides = @"WDDynamicGuides";
NSString *WDShowGrid = @"WDShowGrid";
NSString *WDGridSpacing = @"WDGridSpacing";
NSString *WDRulersVisible = @"WDRulersVisible";
NSString *WDUnits = @"WDUnits";
NSString *WDCustomSizeWidth = @"WDCustomSizeWidth";
NSString *WDCustomSizeHeight = @"WDCustomSizeHeight";
NSString *WDCustomSizeUnits = @"WDCustomSizeUnits";

// Notifications
NSString *WDDrawingChangedNotification = @"WDDrawingChangedNotification";
NSString *WDLayersReorderedNotification = @"WDLayersReorderedNotification";
NSString *WDLayerAddedNotification = @"WDLayerAddedNotification";
NSString *WDLayerDeletedNotification = @"WDLayerDeletedNotification";
NSString *WDIsolateActiveLayerSettingChangedNotification = @"WDIsolateActiveLayerSettingChangedNotification";
NSString *WDOutlineModeSettingChangedNotification = @"WDOutlineModeSettingChangedNotification";
NSString *WDRulersVisibleSettingChangedNotification = @"WDRulersVisibleSettingChangedNotification";
NSString *WDUnitsChangedNotification = @"WDUnitsChangedNotification";
NSString *WDActiveLayerChanged = @"WDActiveLayerChanged";
NSString *WDDrawingDimensionsChanged = @"WDDrawingDimensionsChanged";
NSString *WDGridSpacingChangedNotification = @"WDGridSpacingChangedNotification";

WDRenderingMetaData WDRenderingMetaDataMake(float scale, UInt32 flags)
{
    WDRenderingMetaData metaData;
    
    metaData.scale = scale;
    metaData.flags = flags;
    
    return metaData;
}

BOOL WDRenderingMetaDataOutlineOnly(WDRenderingMetaData metaData)
{
    return (metaData.flags & WDRenderOutlineOnly) ? YES : NO;
}

@implementation WDDrawing

@synthesize dimensions = dimensions_;
@synthesize layers = layers_;
@synthesize activeLayer = activeLayer_;
@synthesize settings = settings_;
@synthesize deleted = deleted_;
@synthesize undoManager = undoManager_;
@synthesize document = document_;

#pragma mark - Setup

// for use with SVG import only
- (id) initWithUnits:(NSString *)units
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    // create layers array
    layers_ = [[NSMutableArray alloc] init];
    
    // create settings
    settings_ = [[NSMutableDictionary alloc] init];
    settings_[WDUnits] = units;
    settings_[WDGridSpacing] = @([[NSUserDefaults standardUserDefaults] floatForKey:WDGridSpacing]);
    
    // image datas
    imageDatas_ = [[NSMutableDictionary alloc] init];
    
    undoManager_ = [[NSUndoManager alloc] init];
    
    return self;
}

- (id) initWithSize:(CGSize)size andUnits:(NSString *)units
{
    self = [super init];
    
    if (!self) {
        return nil;
    }

    // we don't want to notify when we're initing
    [self beginSuppressingNotifications];
    
    dimensions_ = size;
    
    layers_ = [[NSMutableArray alloc] init];
    WDLayer *layer = [WDLayer layer];
    layer.drawing = self;
    [layers_ addObject:layer];
    
    layer.name = [self uniqueLayerName];
    activeLayer_ = layer;
    
    settings_ = [[NSMutableDictionary alloc] init];
    
    // each drawing saves its own settings, but when a user alters them they become the default settings for new documents
    // since this is a new document, look up the values in the defaults...
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *keyArray = @[WDShowGrid, WDSnapToGrid, WDSnapToPoints, WDSnapToEdges, WDDynamicGuides, WDRulersVisible];
    for (NSString *key in keyArray) {
        settings_[key] = @([defaults boolForKey:key]);
    }
    
    settings_[WDUnits] = units;
    settings_[WDGridSpacing] = @([defaults floatForKey:WDGridSpacing]);
    
    // NOTE: 'isolate active layer' is saved with the document, but that should always be turned off for a new document
    
    // for tracking redundant image data
    imageDatas_ = [[NSMutableDictionary alloc] init];
    
    undoManager_ = [[NSUndoManager alloc] init];
    
    [self endSuppressingNotifications];
    
    return self;
}

- (id) initWithImage:(UIImage *)image imageName:(NSString *)imageName
{
    self = [self initWithSize:image.size andUnits:@"Pixels"];
    
    if (!self) {
        return nil;
    }
    
    // we don't want to notify when we're initing
    [self beginSuppressingNotifications];
    
    WDImage *imageElement = [WDImage imageWithUIImage:image inDrawing:self];
    
    [self addObject:imageElement];
    self.activeLayer.name = imageName;
    self.activeLayer.locked = YES;
    
    // add a new blank layer
    [self addLayer:[WDLayer layer]];
    
    [self endSuppressingNotifications];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    // strip unused image datas
    [self purgeUnreferencedImageDatas];
    
    [coder encodeObject:imageDatas_ forKey:WDImageDatasKey];
    [coder encodeObject:layers_ forKey:WDLayersKey];
    [coder encodeObject:activeLayer_ forKey:WDActiveLayerKey];
    [coder encodeCGSize:dimensions_ forKey:WDDimensionsKey];
    
    [coder encodeObject:settings_ forKey:WDSettingsKey];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    layers_ = [coder decodeObjectForKey:WDLayersKey];
    dimensions_ = [coder decodeCGSizeForKey:WDDimensionsKey]; 
    imageDatas_ = [coder decodeObjectForKey:WDImageDatasKey];
    settings_ = [coder decodeObjectForKey:WDSettingsKey];
    
    if (!settings_[WDUnits]) {
        settings_[WDUnits] = [[NSUserDefaults standardUserDefaults] objectForKey:WDUnits];
    }
    
    activeLayer_ = [coder decodeObjectForKey:WDActiveLayerKey];
    if (!activeLayer_) {
        activeLayer_ = [layers_ lastObject];
    }
    
    undoManager_ = [[NSUndoManager alloc] init];
    
#ifdef WD_DEBUG
NSLog(@"Elements in drawing: %lu", (unsigned long)[self allElements].count);
#endif
    
    return self; 
}

- (id) copyWithZone:(NSZone *)zone
{
    WDDrawing *drawing = [[WDDrawing alloc] init];
    
    drawing->dimensions_ = dimensions_;
    drawing->settings_ = [settings_ mutableCopy];
    drawing->imageDatas_ = [imageDatas_ mutableCopy];
    
    // copy layers
    drawing->layers_ = [[NSMutableArray alloc] initWithArray:layers_ copyItems:YES];
    [drawing->layers_ makeObjectsPerformSelector:@selector(setDrawing:) withObject:drawing];
    
    // active layer
    drawing->activeLayer_ = drawing->layers_[[layers_ indexOfObject:activeLayer_]];
    
    [drawing purgeUnreferencedImageDatas];
    
    return drawing;
}

- (void) beginSuppressingNotifications
{
    suppressNotifications_++;
}

- (void) endSuppressingNotifications
{
    suppressNotifications_--;
    
    if (suppressNotifications_ < 0) {
        NSLog(@"Unbalanced notification suppression: %d", (int) suppressNotifications_);
    }
}

- (BOOL) isSuppressingNotifications
{
    return (suppressNotifications_ > 0) ? YES : NO;
}

#pragma mark - Drawing Attributes

// return all the elements in the drawing
- (NSArray *) allElements
{
    NSMutableArray *elements = [[NSMutableArray alloc] init];
    
    [layers_ makeObjectsPerformSelector:@selector(addElementsToArray:) withObject:elements];
    
    return elements;
}

- (NSUInteger) snapFlags
{
    NSUInteger      flags = 0;
    
    if ([settings_[WDSnapToGrid] boolValue]) {
        flags |= kWDSnapGrid;
    }
    
    if ([settings_[WDSnapToPoints] boolValue]) {
        flags |= kWDSnapNodes;
    }
    
    if ([settings_[WDSnapToEdges] boolValue]) {
        flags |= kWDSnapEdges;
    }
    
    return flags;
}

- (CGRect) bounds
{
    return CGRectMake(0, 0, dimensions_.width, dimensions_.height);
}

- (CGRect) styleBounds
{
    CGRect styleBounds = CGRectNull;
    
    for (WDLayer *layer in layers_) {
        styleBounds = CGRectUnion(styleBounds, layer.styleBounds);
    }
    
    return styleBounds;
}

#pragma mark - Image Data

- (void) purgeUnreferencedImageDatas
{
    WDImageData     *imageData;
    NSData          *digest;
    NSMutableArray  *images = [NSMutableArray array];
    
    imageDatas_ = [[NSMutableDictionary alloc] init];
    
    for (WDImage *image in [self allElements]) {
        if ([image isKindOfClass:[WDImage class]]) {
            imageData = image.imageData;
            digest = WDSHA1DigestForData(imageData.data);
            imageDatas_[digest] = imageData;
            
            [images addObject:image];
        }
    }
    
    // we now only have unique image datas... ensure no image is pointing to one that's not tracked
    [images makeObjectsPerformSelector:@selector(useTrackedImageData) withObject:nil];
}

- (WDImageData *) imageDataForUIImage:(UIImage *)image
{
    WDImageData     *imageData = nil;
    NSData          *data;
    NSData          *digest;
    
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(image.CGImage);
    if (alphaInfo == kCGImageAlphaNoneSkipLast) {
        // no alpha data, so let's make a JPEG
        data = UIImageJPEGRepresentation(image, 0.9);
    } else {
        data = UIImagePNGRepresentation(image);
    }
    
    digest = WDSHA1DigestForData(data);
    imageData = imageDatas_[digest];
    
    if (!imageData) {
        imageData = [WDImageData imageDataWithData:data];
        imageDatas_[digest] = imageData;
    }
    
    return imageData;
}

- (WDImageData *) trackedImageData:(WDImageData *)imageData
{
    NSData          *digest = WDSHA1DigestForData(imageData.data);
    WDImageData     *existingData = imageDatas_[digest];
    
    if (!existingData) {
        imageDatas_[digest] = imageData;
        return imageData;
    } else {
        return existingData;
    }
}

#pragma mark - Layers

- (void) addObject:(id)obj
{
    [activeLayer_ addObject:obj];
}

- (void) setActiveLayer:(WDLayer *)layer
{
    if (activeLayer_ == layer) {
        return;
    }
    
    NSUInteger oldIndex = self.indexOfActiveLayer;
    
    activeLayer_ = layer;
    
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"old index": @(oldIndex)};
        [[NSNotificationCenter defaultCenter] postNotificationName:WDActiveLayerChanged object:self userInfo:userInfo];
    }
}

- (void) activateLayerAtIndex:(NSUInteger)ix
{
    self.activeLayer = layers_[ix];
}

- (NSUInteger) indexOfActiveLayer
{
    return layers_.count ? [layers_ indexOfObject:activeLayer_] : -1;
}

- (void) removeLayer:(WDLayer *)layer
{
    [[undoManager_ prepareWithInvocationTarget:self] insertLayer:layer atIndex:[layers_ indexOfObject:layer]];
    
    NSUInteger index = [layers_ indexOfObject:layer];
    NSValue *dirtyRect = [NSValue valueWithCGRect:layer.styleBounds];
    [layers_ removeObject:layer];
    
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"index": @(index), @"rect": dirtyRect, @"layer": layer};
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:WDLayerDeletedNotification object:self userInfo:userInfo]];
    }
}

- (void) insertLayer:(WDLayer *)layer atIndex:(NSUInteger)index
{
    [[undoManager_ prepareWithInvocationTarget:self] removeLayer:layer];
    
    [layers_ insertObject:layer atIndex:index];
    
    if (!self.isSuppressingNotifications) {
        NSDictionary *userInfo = @{@"layer": layer, @"rect": [NSValue valueWithCGRect:layer.styleBounds]};
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:WDLayerAddedNotification object:self userInfo:userInfo]];
    }
}

- (NSString *) uniqueLayerName
{
    NSMutableSet *layerNames = [NSMutableSet set];
    
    for (WDLayer *layer in layers_) {
        if (!layer.name) {
            continue;
        }
        
        [layerNames addObject:layer.name];
    }
    
    NSString    *unique = nil;
    int         uniqueIx = 1;
    
    do {
        unique = [NSString stringWithFormat:NSLocalizedString(@"Layer %d", @"Layer %d"), uniqueIx];
        uniqueIx++;
    } while ([layerNames containsObject:unique]);
    
    return unique;
}

- (void) addLayer:(WDLayer *)layer;
{
    layer.drawing = self;
    
    if (!layer.name) {
        layer.name = [self uniqueLayerName];
    }
    
    [self insertLayer:layer atIndex:self.indexOfActiveLayer+1];
    self.activeLayer = layer;
}

- (void) duplicateActiveLayer
{
    NSMutableData   *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    
    // encode
    [archiver encodeObject:self.activeLayer forKey:@"layer"];
    [archiver finishEncoding];
    
    // decode
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    WDLayer *layer = [unarchiver decodeObjectForKey:@"layer"];
    [unarchiver finishDecoding];
    
    layer.drawing = self;
    layer.highlightColor = [UIColor saturatedRandomColor];
    
    [layer awakeFromEncoding];
    
    [self insertLayer:layer atIndex:self.indexOfActiveLayer+1];
    self.activeLayer = layer;
}

- (BOOL) canDeleteLayer
{
    return (layers_.count > 1) ? YES : NO;
}

- (void) deleteActiveLayer
{
    if (layers_.count < 2) {
        return;
    }
    
    //[activeLayer_ deselectAll];
    
    NSUInteger index = self.indexOfActiveLayer;
    
    // do this before decrementing index
    [self removeLayer:activeLayer_];
    
    if (index >= 1) {
        index--;
    }
    
    self.activeLayer = layers_[index];
}

- (void) moveLayerAtIndex:(NSUInteger)src toIndex:(NSUInteger)dest
{
    [self beginSuppressingNotifications];
    
    WDLayer *layer = layers_[src];
    [self removeLayer:layer];
    [self insertLayer:layer atIndex:dest];
    
    [self endSuppressingNotifications];
    
    if (!self.isSuppressingNotifications) {
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:WDLayersReorderedNotification object:self]];
    }
}

#pragma mark - Representations

- (void) renderInContext:(CGContextRef)ctx clipRect:(CGRect)clip metaData:(WDRenderingMetaData)metaData
{
    // make sure blending modes behave correctly
    CGContextBeginTransparencyLayer(ctx, NULL);
    
    for (WDLayer *layer in layers_) {
        if (!layer.hidden) {        
            [layer renderInContext:ctx clipRect:clip metaData:metaData];
        }
    }
    
    CGContextEndTransparencyLayer(ctx);
}

- (UIImage *) pixelImage
{
    CGSize  dimensions = self.dimensions;
    double  scale = 1.0f;
    double  area = dimensions.width * dimensions.height;
    
    // make sure we don't use all the memory generating this bitmap
    if (area > kMaximumBitmapImageArea) {
        scale = sqrt(kMaximumBitmapImageArea) / sqrt(area);
        dimensions = WDMultiplySizeScalar(dimensions, scale);
        // whole pixel size
        dimensions = WDRoundSize(dimensions);
    }

    UIGraphicsBeginImageContext(dimensions);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(ctx, scale, scale);
    [self renderInContext:ctx clipRect:self.bounds metaData:WDRenderingMetaDataMake(1, WDRenderDefault)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result; 
}

- (UIImage *) image
{
    if ([self.units isEqualToString:@"Pixels"]) {
        // for pixel units, include the entire drawing bounds
        return [self pixelImage];
    }
    
    // for any other unit, crop to the style bounds of the drawing content
    CGRect styleBounds = self.styleBounds;
    CGRect docBounds = self.bounds;
    
    if (CGRectEqualToRect(styleBounds, CGRectNull)) {
        styleBounds = docBounds;
    } else {
        styleBounds = CGRectIntersection(styleBounds, docBounds);
    }
    
    // there's no canonical mapping from units to pixels: we'll double the resolution
    double  scale = 2.0f;
    CGSize  dimensions = WDMultiplySizeScalar(styleBounds.size, scale);
    double  area = dimensions.width * dimensions.height;
    
    // make sure we don't use all the memory generating this bitmap
    if (area > kMaximumBitmapImageArea) {
        double shrink = sqrt(kMaximumBitmapImageArea) / sqrt(area);
        dimensions = WDMultiplySizeScalar(dimensions, shrink);
        // whole pixel size
        dimensions = WDRoundSize(dimensions);

        // update the scale since it will have changed (approximately the same as scale *= shrink)
        scale = dimensions.width / styleBounds.size.width;
    }
    
    UIGraphicsBeginImageContext(dimensions);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(ctx, scale, scale);
    CGContextTranslateCTM(ctx, -styleBounds.origin.x, -styleBounds.origin.y);
    [self renderInContext:ctx clipRect:self.bounds metaData:WDRenderingMetaDataMake(scale, WDRenderDefault)];
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

//
// Used for copying an image of the selection to the clipboard
//
+ (UIImage *) imageForElements:(NSArray *)elements scale:(float)scaleFactor
{
    CGRect contentBounds = CGRectNull;
    for (WDElement *element in elements) {
        contentBounds = CGRectUnion(contentBounds, element.styleBounds);
    }
    
    // apply the requested scale factor
    CGSize size = WDMultiplySizeScalar(contentBounds.size, scaleFactor);
    
    // make sure we didn't exceed the maximum dimension
    size = WDClampSize(size, kMaximumCopiedBitmapImageDimension);
    
    // ... and make sure the scale factor is still accurate
    scaleFactor = size.width / contentBounds.size.width;
    
    UIGraphicsBeginImageContext(size);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // scale and offset the elements to render in the new image
    CGPoint origin = WDMultiplyPointScalar(contentBounds.origin, -scaleFactor);
    CGContextTranslateCTM(ctx, origin.x, origin.y);
    CGContextScaleCTM(ctx, scaleFactor, scaleFactor);
    for (WDElement *element in elements) {
        [element renderInContext:ctx metaData:WDRenderingMetaDataMake(scaleFactor, WDRenderDefault)];   
    }
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

- (NSData *) PDFRepresentation
{
    CGRect              mediaBox = CGRectMake(0, 0, dimensions_.width, dimensions_.height);
    CFMutableDataRef	data = CFDataCreateMutable(NULL, 0);
    CGDataConsumerRef	consumer = CGDataConsumerCreateWithCFData(data);
    CGContextRef        pdfContext = CGPDFContextCreate(consumer, &mediaBox, NULL);	
    
    CGDataConsumerRelease(consumer);
    CGPDFContextBeginPage(pdfContext, NULL);
    
    // flip!
    CGContextTranslateCTM(pdfContext, 0, dimensions_.height);
    CGContextScaleCTM(pdfContext, 1, -1);
    
    [self renderInContext:pdfContext clipRect:self.bounds metaData:WDRenderingMetaDataMake(1, WDRenderFlipped)];
    CGPDFContextEndPage(pdfContext);
    
    CGContextRelease(pdfContext);

    NSData *nsdata = (NSData *)CFBridgingRelease(data);
    return nsdata;
}

- (NSData *) SVGRepresentation
{
    NSMutableString     *svg = [NSMutableString string];
    WDSVGHelper         *sharedHelper = [WDSVGHelper sharedSVGHelper];
    
    [sharedHelper beginSVGGeneration];
    
	[svg appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
	[svg appendString:@"<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\"\n"];
	[svg appendString:@"  \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n"];
    [svg appendString:@"<!-- Created with Inkpad (http://www.taptrix.com/) -->"];
    
    WDXMLElement *svgElement = [WDXMLElement elementWithName:@"svg"];
    [svgElement setAttribute:@"version" value:@"1.1"];
    [svgElement setAttribute:@"xmlns" value:@"http://www.w3.org/2000/svg"];
    [svgElement setAttribute:@"xmlns:xlink" value:@"http://www.w3.org/1999/xlink"];
    [svgElement setAttribute:@"xmlns:inkpad" value:@"http://taptrix.com/inkpad/svg_extensions"];
    [svgElement setAttribute:@"width" value:[NSString stringWithFormat:@"%gpt", dimensions_.width]];
    [svgElement setAttribute:@"height" value:[NSString stringWithFormat:@"%gpt", dimensions_.height]];
    [svgElement setAttribute:@"viewBox" value:[NSString stringWithFormat:@"0,0,%g,%g", dimensions_.width, dimensions_.height]];
	
    NSData *thumbnailData = [self thumbnailData];
    WDXMLElement *metadataElement = [WDXMLElement elementWithName:@"metadata"];
    WDXMLElement *thumbnailElement = [WDXMLElement elementWithName:@"inkpad:thumbnail"];
    [thumbnailElement setAttribute:@"xlink:href" value:[NSString stringWithFormat:@"data:%@;base64,\n%@", @"image/jpeg",
                                                        [thumbnailData base64EncodedStringWithOptions:0]]];
    [metadataElement addChild:thumbnailElement];
    [svgElement addChild:metadataElement];
    
    for (WDImageData *imgData in [imageDatas_ allValues]) {
        NSString        *unique = [[WDSVGHelper sharedSVGHelper] uniqueIDWithPrefix:@"Image"];
        WDXMLElement    *image = [WDXMLElement elementWithName:@"image"];
        
        [image setAttribute:@"id" value:unique];
        [image setAttribute:@"overflow" value:@"visible"];
        [image setAttribute:@"width" floatValue:imgData.image.size.width];
        [image setAttribute:@"height" floatValue:imgData.image.size.height];
        
        NSString *base64encoding = [NSString stringWithFormat:@"data:%@;base64,\n%@", imgData.mimetype, [imgData.data base64EncodedStringWithOptions:0]];
        [image setAttribute:@"xlink:href" value:base64encoding];
        
        [sharedHelper addDefinition:image];
        [sharedHelper setImageID:unique forDigest:imgData.digest];
    }
    
    WDXMLElement *drawingMetadataElement = [WDXMLElement elementWithName:@"metadata"];
    [settings_ enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        WDXMLElement *settingElement = [WDXMLElement elementWithName:@"inkpad:setting"];
        [settingElement setAttribute:@"key" value:[key substringFromIndex:2]];
        [settingElement setAttribute:@"value" value:[NSString stringWithFormat:@"%@", obj]];
        [drawingMetadataElement addChild:settingElement];
    }];
    
    [svgElement addChild:drawingMetadataElement];
    [svgElement addChild:[sharedHelper definitions]];
    
    for (WDLayer *layer in layers_) {
        WDXMLElement *layerSVG = [layer SVGElement];
        
        if (layerSVG) {
            [svgElement addChild:layerSVG];
        }
    }
	
    [svg appendString:[svgElement XMLValue]];
    NSData *result = [svg dataUsingEncoding:NSUTF8StringEncoding];
    
    [sharedHelper endSVGGeneration];
    
    return result;
}

- (UIImage *) thumbnailImage
{
    float   width = kMaximumThumbnailDimension, height = kMaximumThumbnailDimension;
    float   aspectRatio = dimensions_.width / dimensions_.height;
    
    if (dimensions_.height > dimensions_.width) {
        width = round(kMaximumThumbnailDimension * aspectRatio);
    } else {
        height = round(kMaximumThumbnailDimension / aspectRatio);
    }
    
    CGSize  size = CGSizeMake(width, height);
    
    // always generate the 2x icon
    UIGraphicsBeginImageContextWithOptions(size, NO, 2);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextSetGrayFillColor(ctx, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
    
    float scale = width / dimensions_.width;
    CGContextScaleCTM(ctx, scale, scale);
    [self renderInContext:ctx clipRect:self.bounds metaData:WDRenderingMetaDataMake(scale, WDRenderThumbnail)];
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

- (NSData *) thumbnailData
{
    return UIImageJPEGRepresentation([self thumbnailImage], 0.9f);
}

- (NSData *) inkpadRepresentation
{
#if WD_DEBUG
    NSDate *date = [NSDate date];
#endif
    
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    
    // Customize archiver here
    [archiver encodeObject:self forKey:WDDrawingKey];
    [archiver encodeObject:[self thumbnailData] forKey:WDThumbnailKey];
    
    [archiver finishEncoding];
    
#if WD_DEBUG
    NSLog(@"Encoding time: %f", -[date timeIntervalSinceNow]);
#endif
    
    return data;
}

#pragma mark - Settings

- (void) setSetting:(NSString *)name value:(NSString *)value
{
    if ([name hasPrefix:@"WD"]) {
        [settings_ setValue:value forKey:name];
    } else {
        [settings_ setValue:value forKey:[@"WD" stringByAppendingString:name]];
    }
}

- (BOOL) snapToPoints
{
    return [settings_[WDSnapToPoints] boolValue];
}

- (void) setSnapToPoints:(BOOL)snap
{
    settings_[WDSnapToPoints] = @(snap);
    
    // this isn't an undoable action so it does not dirty the document
    [self.document markChanged];
}

- (BOOL) snapToEdges
{
    return [settings_[WDSnapToEdges] boolValue];
}

- (void) setSnapToEdges:(BOOL)snap
{
    settings_[WDSnapToEdges] = @(snap);
    
    // this isn't an undoable action so it does not dirty the document
    [self.document markChanged];
}

- (BOOL) snapToGrid
{
    return [settings_[WDSnapToGrid] boolValue];
}

- (void) setSnapToGrid:(BOOL)snap
{
    settings_[WDSnapToGrid] = @(snap);
    
    // this isn't an undoable action so it does not dirty the document
    [self.document markChanged];
}

- (BOOL) dynamicGuides
{
    return [settings_[WDDynamicGuides] boolValue];
}

- (void) setDynamicGuides:(BOOL)dynamicGuides
{
    settings_[WDDynamicGuides] = @(dynamicGuides);
    
    // this isn't an undoable action so it does not dirty the document
    [self.document markChanged];
}

- (BOOL) isolateActiveLayer
{
    return [settings_[WDIsolateActiveLayer] boolValue];
}

- (void) setIsolateActiveLayer:(BOOL)isolate
{
    settings_[WDIsolateActiveLayer] = @(isolate);
    [[NSNotificationCenter defaultCenter] postNotificationName:WDIsolateActiveLayerSettingChangedNotification object:self];
    
    // this isn't an undoable action so it does not dirty the document
    [self.document markChanged];
}

- (BOOL) outlineMode
{
    return [settings_[WDOutlineMode] boolValue];
}

- (void) setOutlineMode:(BOOL)outline
{
    settings_[WDOutlineMode] = @(outline);
    [[NSNotificationCenter defaultCenter] postNotificationName:WDOutlineModeSettingChangedNotification object:self];
    
    // this isn't an undoable action so it does not dirty the document
    [self.document markChanged];
}

- (void) setShowGrid:(BOOL)showGrid
{
    settings_[WDShowGrid] = @(showGrid);
    [[NSNotificationCenter defaultCenter] postNotificationName:WDDrawingChangedNotification object:self];
    
    // this isn't an undoable action so it does not dirty the document
    [self.document markChanged];
}

- (BOOL) showGrid
{
    return [settings_[WDShowGrid] boolValue];
}

- (float) gridSpacing
{
    return [settings_[WDGridSpacing] floatValue];
}

- (void) setGridSpacing:(float)spacing
{
    spacing = WDClamp(1, kMaximumDrawingDimension / 2, spacing);
    
    settings_[WDGridSpacing] = @(spacing);
    [[NSNotificationCenter defaultCenter] postNotificationName:WDGridSpacingChangedNotification object:self];
    
    // this isn't an undoable action so it does not dirty the document
    [self.document markChanged];
}

- (BOOL) rulersVisible
{
    return [settings_[WDRulersVisible] boolValue];
}

- (void) setRulersVisible:(BOOL)visible
{
    settings_[WDRulersVisible] = @(visible);
    [[NSNotificationCenter defaultCenter] postNotificationName:WDRulersVisibleSettingChangedNotification object:self];
    
    // this isn't an undoable action so it does not dirty the document
    [self.document markChanged];
}

- (NSString *) units
{
    return settings_[WDUnits];
}

- (void) setUnits:(NSString *)units
{
    settings_[WDUnits] = units;
    [[NSNotificationCenter defaultCenter] postNotificationName:WDUnitsChangedNotification object:self];
    
    // this isn't an undoable action so it does not dirty the document
    [self.document markChanged];
}

- (WDRulerUnit *) rulerUnit
{
    return [WDRulerUnit rulerUnits][self.units];
}

- (float) width
{
    return dimensions_.width;
}

- (void) setWidth:(float)width
{
    if (dimensions_.width == width) {
        return;
    }
    
    [(WDDrawing *)[undoManager_ prepareWithInvocationTarget:self] setWidth:dimensions_.width];
    
    dimensions_.width = WDClamp(kMinimumDrawingDimension, kMaximumDrawingDimension, width);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WDDrawingDimensionsChanged object:self];
}

- (float) height
{
    return dimensions_.height;
}

- (void) setHeight:(float)height
{
    if (dimensions_.height == height) {
        return;
    }
    
    [[undoManager_ prepareWithInvocationTarget:self] setHeight:dimensions_.height];
    
    dimensions_.height = WDClamp(kMinimumDrawingDimension, kMaximumDrawingDimension, height);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WDDrawingDimensionsChanged object:self];
}

@end
