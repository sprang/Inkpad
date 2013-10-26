//
//  WDDrawingManager.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "UIImage+Additions.h"
#import "WDDocument.h"
#import "WDDrawingManager.h"
#import "WDSVGParser.h"
#import "WDSVGThumbnailExtractor.h"

NSString *WDDrawingFileExtension = @"inkpad";
NSString *WDSVGFileExtension = @"svg";
NSString *WDDefaultDrawingExtension = @"inkpad";

// notifications
NSString *WDDrawingsDeleted = @"WDDrawingsDeleted";
NSString *WDDrawingAdded = @"WDDrawingAdded";
NSString *WDDrawingRenamed = @"WDDrawingRenamed";

NSString *WDDrawingOldFilenameKey = @"WDDrawingOldFilenameKey";
NSString *WDDrawingNewFilenameKey = @"WDDrawingNewFilenameKey";


@interface NSString (WDAdditions)
- (NSComparisonResult) compareNumeric:(NSString *)string;
@end

@implementation NSString (WDAdditions)
- (NSComparisonResult) compareNumeric:(NSString *)string {
    return [self compare:string options:NSNumericSearch];
}
@end

@interface WDDrawingManager (Private)
- (void) createNecessaryDirectories_;
- (void) saveDrawingOrder_;
@end

@implementation WDDrawingManager

+ (WDDrawingManager *) sharedInstance
{
    static WDDrawingManager *shared = nil;
    
    if (!shared) {
        shared = [[WDDrawingManager alloc] init];
    }
    
    return shared;
}

+ (NSString *) drawingOrderPath
{
    return [[WDDrawingManager drawingPath] stringByAppendingPathComponent:@".order.plist"];
}

// we only want Inkpad documents
- (NSArray *) filterFiles:(NSArray *)files
{
    NSMutableArray *filtered = [[NSMutableArray alloc] init];
    
    for (NSString *file in files) {
        if ([[file pathExtension] compare:WDDrawingFileExtension options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            [filtered addObject:file];
        } else if ([[file pathExtension] compare:WDSVGFileExtension options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            [filtered addObject:file];
        }
    }
    
    return filtered;
}

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    [self createNecessaryDirectories_];
    
    // load the plist containing the drawing order
    NSData          *data = [NSData dataWithContentsOfFile:[WDDrawingManager drawingOrderPath]];
    NSFileManager   *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:[WDDrawingManager drawingPath] error:NULL];
    
    files = [self filterFiles:files];
    
    if (data) {
        NSMutableArray  *finalNames = [NSMutableArray array];
        NSArray         *names = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:NULL error:NULL];
        
        // strip out duplicates
        for (NSString *name in names) {
            if (![finalNames containsObject:name]) {
                [finalNames addObject:name];
            }
        }
        
        //
        // make sure this list matches the file system
        //
        NSSet *knownFiles = [NSSet setWithArray:finalNames];
        NSSet *allFiles = [NSSet setWithArray:files];
        
        // see if the saved list of files contains drawings that don't actually exist in the file system
        NSMutableSet *bogus = [knownFiles mutableCopy];
        [bogus minusSet:allFiles];
        
        // remove any bogus files
        for (NSString *missingFile in [bogus allObjects]) {
            [finalNames removeObject:missingFile];
        }
        
        //
        // see if the file system contains drawings that we're not tracking
        //
        NSMutableSet *extras = [allFiles mutableCopy];
        [extras minusSet:knownFiles];
        
        // add any extra files
        for (NSString *newFile in [extras allObjects]) {
            [finalNames addObject:newFile];
        }
        
        drawingNames_ = finalNames;
    } else {
        drawingNames_ = [[files sortedArrayUsingSelector:@selector(compareNumeric:)] mutableCopy];
    }
    
    // save the accurate file list
    [self saveDrawingOrder_];
    
    return self;
}


+ (NSString *) documentDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); 
    NSString *documentsDirectory = paths[0]; 
    return documentsDirectory;
}

+ (NSString *) drawingPath
{
    return [[self documentDirectory] stringByAppendingPathComponent:@"drawings"];
}

+ (BOOL) drawingExists:(NSString *)drawing
{
    NSFileManager   *fm = [NSFileManager defaultManager];
    
    NSString        *inkpadFilename = [[drawing stringByDeletingPathExtension] stringByAppendingPathExtension:WDDrawingFileExtension];
    NSString        *svgFilename = [[drawing stringByDeletingPathExtension] stringByAppendingPathExtension:WDSVGFileExtension];
    
    NSString        *inkpadPath = [[self drawingPath] stringByAppendingPathComponent:inkpadFilename];
    NSString        *svgPath = [[self drawingPath] stringByAppendingPathComponent:svgFilename];
    
    return [fm fileExistsAtPath:svgPath] || [fm fileExistsAtPath:inkpadPath];
}

- (NSUInteger) numberOfDrawings
{
    return [drawingNames_ count];
}

- (NSArray *) drawingNames
{
    return drawingNames_;
}

- (NSString *) uniqueFilename
{
    return [self uniqueFilenameWithPrefix:@"Drawing" extension:WDDefaultDrawingExtension];
}

- (NSString *) cleanPrefix:(NSString *)prefix
{
    // if the last "word" of the prefix is an int, strip it off
    NSArray *components = [prefix componentsSeparatedByString:@" "];
    BOOL    hasNumericalSuffix = NO;
    
    if (components.count > 1) {
        NSString *lastComponent = [components lastObject];
        hasNumericalSuffix = YES;
        
        for (int i = 0; i < lastComponent.length; i++) {
            if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[lastComponent characterAtIndex:i]]) {
                hasNumericalSuffix = NO;
                break;
            }
        }
    }
    
    if (hasNumericalSuffix) {
        NSString *newPrefix = @"";
        for (int i = 0; i < components.count - 1; i++) {
            newPrefix = [newPrefix stringByAppendingString:components[i]];
            if (i != components.count - 2) {
                newPrefix = [newPrefix stringByAppendingString:@" "];
            }
        }
        
        prefix = newPrefix;
    }
    
    return prefix;
}

- (NSString *) uniqueFilenameWithPrefix:(NSString *)prefix extension:(NSString *)extension
{
    if (![WDDrawingManager drawingExists:prefix]) {
        return [prefix stringByAppendingPathExtension:extension];
    }
    
    prefix = [self cleanPrefix:prefix];

    NSString    *unique = nil;
    int         uniqueIx = 1;
    
    do {
        unique = [NSString stringWithFormat:@"%@ %d.%@", prefix, uniqueIx, extension];
        uniqueIx++;
    
    } while ([WDDrawingManager drawingExists:unique]);
    
    return unique;
}

- (WDDocument *) installDrawing:(WDDrawing *)drawing withName:(NSString *)drawingName closeAfterSaving:(BOOL)shouldClose
{
    [drawingNames_ addObject:drawingName];
    [self saveDrawingOrder_];
    
    NSString *path = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:drawingName];
    NSURL *url = [NSURL fileURLWithPath:path];
    
    WDDocument *document = [[WDDocument alloc] initWithFileURL:url];
    document.drawing = drawing;
    [document saveToURL:url forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WDDrawingAdded object:drawingName];
        if (shouldClose) {
            [document closeWithCompletionHandler:nil];
        }
    }];

    return document;
}

- (WDDocument *) createNewDrawingWithSize:(CGSize)size andUnits:(NSString *)units
{   
    WDDrawing *drawing = [[WDDrawing alloc] initWithSize:size andUnits:units];
    return [self installDrawing:drawing withName:[self uniqueFilename] closeAfterSaving:NO];
}

- (BOOL) createNewDrawingWithImage:(UIImage *)image imageName:(NSString *)imageName drawingName:(NSString *)drawingName
{
    if (!image) {
        return nil;
    }
    
    image = [image downsampleWithMaxDimension:1024];
    
    WDDrawing *drawing = [[WDDrawing alloc] initWithImage:image imageName:imageName];
    return [self installDrawing:drawing withName:drawingName closeAfterSaving:YES] ? YES : NO;
}

- (BOOL) createNewDrawingWithImage:(UIImage *)image
{
    NSString *imageName = NSLocalizedString(@"Photo", @"Photo");
    NSString *drawingName = [self uniqueFilenameWithPrefix:imageName extension:WDDefaultDrawingExtension];
    
    return [self createNewDrawingWithImage:image imageName:imageName drawingName:drawingName];
}

- (BOOL) createNewDrawingWithImageAtURL:(NSURL *)imageURL
{
    UIImage *image = [UIImage imageWithContentsOfFile:imageURL.path];
    NSString *imageName = [[imageURL lastPathComponent] stringByDeletingPathExtension];
    NSString *drawingName = [self uniqueFilenameWithPrefix:imageName extension:WDDefaultDrawingExtension];
    
    return [self createNewDrawingWithImage:image imageName:imageName drawingName:drawingName];
}

- (dispatch_queue_t) importQueue
{
    static dispatch_queue_t importQueue;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        importQueue = dispatch_queue_create("com.taptrix.inkpad.import", DISPATCH_QUEUE_SERIAL);
    });
    
    return importQueue;
}

- (NSString *) fileAtIndex:(NSUInteger)ix
{
    if (ix < [drawingNames_ count]) {
        return drawingNames_[ix];
    }
    
    return nil;
}

- (NSData *) dataForFilename:(NSString *)name
{
    NSString *archivePath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:name]; 
    return [NSData dataWithContentsOfFile:archivePath]; 
}

- (WDDocument *) openDocumentWithName:(NSString *)name withCompletionHandler:(void (^)(WDDocument *document))completionHandler
{
    return [self openDocumentAtIndex:[drawingNames_ indexOfObject:name] withCompletionHandler:completionHandler];    
}

- (WDDocument *) openDocumentAtIndex:(NSUInteger)ix withCompletionHandler:(void (^)(WDDocument *document))completionHandler
{
    NSString *filename = drawingNames_[ix];
    NSString *path = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:filename];
    NSURL *url = [NSURL fileURLWithPath:path];
    WDDocument *document = [[WDDocument alloc] initWithFileURL:url];
    [document openWithCompletionHandler:^(BOOL success) {
        if (completionHandler) {
            completionHandler(document);
        }
    }];
    
    return document;
}

- (WDDocument *) duplicateDrawing:(WDDocument *)document
{ 
    NSString *unique = [self uniqueFilenameWithPrefix:[document.filename stringByDeletingPathExtension]
                                            extension:[document.filename pathExtension]];
    
    // the original drawing will save when it's freed
    
    return [self installDrawing:document.drawing withName:unique closeAfterSaving:NO];
}

- (void) importDrawingAtURL:(NSURL *)url errorBlock:(void (^)(void))errorBlock withCompletionHandler:(void (^)(WDDocument *document))completionBlock
{
    WDDocument *doc = [[WDDocument alloc] initWithFileURL:url];
    [doc openWithCompletionHandler:^(BOOL success) {
        dispatch_async([self importQueue], ^{
            if (success) {
                doc.fileTypeOverride = @"com.taptrix.inkpad";
                NSString *svgName = [[url lastPathComponent] stringByDeletingPathExtension];
                NSString *drawingName = [self uniqueFilenameWithPrefix:svgName extension:WDDefaultDrawingExtension];
                NSString *path = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:drawingName]; 
                NSURL *newUrl = [NSURL fileURLWithPath:path];
                [doc saveToURL:newUrl forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [drawingNames_ addObject:drawingName];
                        [self saveDrawingOrder_];
                        [[NSNotificationCenter defaultCenter] postNotificationName:WDDrawingAdded object:drawingName];
                        completionBlock(doc);
                        [doc closeWithCompletionHandler:nil];
                    });
                }];
            } else {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    errorBlock();
                    completionBlock(nil);
                });
            }
        });
    }];
}

- (void) installSamples:(NSArray *)urls
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSURL *url in urls) {
        NSString *prefix = [[url lastPathComponent] stringByDeletingPathExtension];
        NSString *unique = [self uniqueFilenameWithPrefix:prefix extension:[[url lastPathComponent] pathExtension]];
        
        NSString *dstPath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:unique];
        [fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:dstPath] error:NULL];
        
        [drawingNames_ addObject:unique];
        [[NSNotificationCenter defaultCenter] postNotificationName:WDDrawingAdded object:unique];
    }
    
    [self saveDrawingOrder_];
}

- (NSIndexPath *) indexPathForFilename:(NSString *)filename
{
    return [NSIndexPath indexPathForItem:[[self drawingNames] indexOfObject:filename] inSection:0];
}

- (void) deleteDrawings:(NSMutableSet *)set
{
    NSFileManager   *fm = [NSFileManager defaultManager];
    
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (NSString *filename in set) {
       [indexPaths addObject:[NSIndexPath indexPathForItem:[drawingNames_ indexOfObject:filename] inSection:0]];
    }
    
    for (NSString *filename in set) {
        [fm removeItemAtPath:[[WDDrawingManager drawingPath] stringByAppendingPathComponent:filename] error:NULL];
        [drawingNames_ removeObject:filename];
    }
    
    [self saveDrawingOrder_];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WDDrawingsDeleted object:indexPaths];
}

- (void) deleteDrawing:(WDDocument *)document
{
    NSFileManager   *fm = [NSFileManager defaultManager];
    
    // make sure it doesn't resave when it deallocates
    [document.drawing setDeleted:YES];
    
    [fm removeItemAtPath:[[WDDrawingManager drawingPath] stringByAppendingPathComponent:document.filename] error:NULL];
    
    [drawingNames_ removeObject:document.filename];
    [self saveDrawingOrder_];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WDDrawingsDeleted object:[NSSet setWithObject:document.filename]];
}

- (UIImage *) getThumbnail:(NSString *)name
{
    NSString            *archivePath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:name]; 
    NSData              *thumbData = nil;
    
    if ([name hasSuffix:WDDrawingFileExtension]) {
        NSData              *data = [NSData dataWithContentsOfFile:archivePath]; 
        NSKeyedUnarchiver   *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        
        thumbData = [unarchiver decodeObjectForKey:WDThumbnailKey];
        
        [unarchiver finishDecoding]; 
    } else if ([name hasSuffix:WDSVGFileExtension]) {
        NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:[NSURL fileURLWithPath:archivePath]];
        WDSVGThumbnailExtractor *extractor = [[WDSVGThumbnailExtractor alloc] init];
        [xmlParser setDelegate:extractor];
        [xmlParser parse];
        thumbData = [extractor thumbnail];
    }
    
    UIImage *result = [[UIImage alloc] initWithData:thumbData];
    return result;
}

- (void) renameDrawing:(NSString *)drawing newName:(NSString *)newName
{
    NSFileManager   *fm = [NSFileManager defaultManager];
    NSString        *originalPath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:drawing];
    
    if (![fm fileExistsAtPath:originalPath]) {
        return;
    }
    
    if (![[newName pathExtension] isEqualToString:[drawing pathExtension]]) {
        newName = [newName stringByAppendingPathExtension:[drawing pathExtension]];
    }
    NSString *newPath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:newName];
    
    [fm moveItemAtPath:originalPath toPath:newPath error:NULL];
    drawingNames_[[drawingNames_ indexOfObject:drawing]] = newName;
    
    [self saveDrawingOrder_];
    
    NSDictionary *info = @{WDDrawingOldFilenameKey: drawing, WDDrawingNewFilenameKey: newName};
    [[NSNotificationCenter defaultCenter] postNotificationName:WDDrawingRenamed object:self userInfo:info];
}

@end

@implementation WDDrawingManager (Private)

- (void) createNecessaryDirectories_
{
    NSFileManager   *fm = [NSFileManager defaultManager];
    BOOL createSamples = NO;
    
    if (![fm fileExistsAtPath:[WDDrawingManager drawingPath]]) {
        // assume this is the first time we've been run... copy over the sample drawings
        createSamples = YES;
    }
    
    [fm createDirectoryAtPath:[WDDrawingManager drawingPath] withIntermediateDirectories:YES attributes:nil error:NULL];
    
    if (createSamples) {
        NSArray *samplePaths = [[NSBundle mainBundle] pathsForResourcesOfType:WDDrawingFileExtension inDirectory:@"Samples"];
        for (NSString *path in samplePaths) {
            [fm copyItemAtPath:path toPath:[[WDDrawingManager drawingPath] stringByAppendingPathComponent:[path lastPathComponent]] error:NULL];
        }
        
        samplePaths = [[NSBundle mainBundle] pathsForResourcesOfType:WDSVGFileExtension inDirectory:@"Samples"];
        for (NSString *path in samplePaths) {
            [fm copyItemAtPath:path toPath:[[WDDrawingManager drawingPath] stringByAppendingPathComponent:[path lastPathComponent]] error:NULL];
        }
    }
}

- (void) saveDrawingOrder_
{
    [[NSPropertyListSerialization dataWithPropertyList:drawingNames_ format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL]
     writeToFile:[WDDrawingManager drawingOrderPath] atomically:YES];
}

@end
