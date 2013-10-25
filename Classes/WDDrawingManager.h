//
//  WDDrawingManager.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDDrawing;
@class WDDocument;

@interface WDDrawingManager : NSObject {
    NSMutableArray  *drawingNames_;
}

+ (WDDrawingManager *) sharedInstance;

+ (NSString *) documentDirectory;
+ (NSString *) drawingPath;
+ (BOOL) drawingExists:(NSString *)drawing;

- (WDDocument *) createNewDrawingWithSize:(CGSize)size andUnits:(NSString *)units;
- (BOOL) createNewDrawingWithImageAtURL:(NSURL *)imageURL;
- (BOOL) createNewDrawingWithImage:(UIImage *)image;

// these import methods are asynchronous
- (void) importDrawingAtURL:(NSURL *)url errorBlock:(void (^)(void))errorBlock withCompletionHandler:(void (^)(WDDocument *))completionBlock;

- (WDDocument *) openDocumentWithName:(NSString *)name withCompletionHandler:(void (^)(WDDocument *document))completionHandler;
- (WDDocument *) openDocumentAtIndex:(NSUInteger)ix withCompletionHandler:(void (^)(WDDocument *document))completionHandler;
- (NSData *) dataForFilename:(NSString *)name;
- (NSUInteger) numberOfDrawings;
- (NSArray *) drawingNames;
- (NSIndexPath *) indexPathForFilename:(NSString *)filename;

- (NSString *) fileAtIndex:(NSUInteger)ix;
- (WDDocument *) duplicateDrawing:(WDDocument *)document;

- (void) installSamples:(NSArray *)urls;

- (void) deleteDrawing:(WDDocument *)drawing;
- (void) deleteDrawings:(NSMutableSet *)set;

- (NSString *) uniqueFilenameWithPrefix:(NSString *)prefix extension:(NSString *)extension;
- (void) renameDrawing:(NSString *)drawing newName:(NSString *)newName;

- (UIImage *) getThumbnail:(NSString *)name;

@end

extern NSString *WDSVGFileExtension;
extern NSString *WDDrawingFileExtension;
extern NSString *WDDefaultDrawingExtension;

// notifications
extern NSString *WDDrawingsDeleted;
extern NSString *WDDrawingAdded;
extern NSString *WDDrawingRenamed;

extern NSString *WDDrawingOldFilenameKey;
extern NSString *WDDrawingNewFilenameKey;

