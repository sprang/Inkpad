//
//  WDDocument.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "NSData+Additions.h"
#import "WDDocument.h"
#import "WDSVGParser.h"
#import "WDSVGThumbnailExtractor.h"

NSString *WDDocumentDidLoadNotification = @"WDDocumentDidLoadNotification";
static NSString *errorDomain = @"WDDocument";

@implementation WDDocument

@synthesize drawing = drawing_;
@synthesize thumbnail = thumbnail_;
@synthesize loadOnlyThumbnail = loadOnlyThumbnail_;
@synthesize fileTypeOverride;

- (NSString *) filename
{
    return [self.fileURL.path lastPathComponent];
}

- (NSString *) fileType
{
    if (self.fileTypeOverride) {
        return fileTypeOverride;
    } else if ([self.filename.pathExtension caseInsensitiveCompare:@"svgz"] == NSOrderedSame) {
        // iOS returns "public.svg-image" for svgz
        return @"public.svgz-image";
    } else {
        return super.fileType;
    }
}

- (void) setDrawing:(WDDrawing *)drawing
{
    drawing_ = drawing;
    self.undoManager = drawing.undoManager;
    
    drawing.document = self;
}

- (BOOL) loadFromInkpad:(id)contents error:(NSError **)outError
{
    NSKeyedUnarchiver   *unarchiver = nil;
    BOOL                success = NO;
    
    @try {
        unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:contents]; 
        
        if (self.loadOnlyThumbnail) {
            self.thumbnail = [UIImage imageWithData:[unarchiver decodeObjectForKey:WDThumbnailKey]];
        } else {
            self.drawing = [unarchiver decodeObjectForKey:WDDrawingKey];
            self.undoManager = self.drawing.undoManager;
        }
        
        [unarchiver finishDecoding];
        
        success = (self.thumbnail || self.drawing) ? YES : NO;
    }
    @catch (NSException *exception) {
        NSLog(@"Caught %@: %@", [exception name], [exception reason]); 
        success = NO;
    }
    @finally {
        unarchiver = nil;
    }
    
    return success;
}

- (BOOL) loadFromSVG:(id)contents error:(NSError **)outError
{
#if WD_DEBUG
    NSDate *start = [NSDate date];
#endif
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:contents];
    
    if (self.loadOnlyThumbnail) {
        WDSVGThumbnailExtractor *extractor = [[WDSVGThumbnailExtractor alloc] init];
        [xmlParser setDelegate:extractor];
        [xmlParser parse];
        self.thumbnail = [UIImage imageWithData:extractor.thumbnail];
    }
    // load the whole drawing if we are either asked to or we failed to find a thumbnail
    if (!self.thumbnail) {
        WDDrawing   *drawing = [[WDDrawing alloc] initWithUnits:@"Points"];
        [drawing beginSuppressingNotifications];
        WDSVGParser *svgParser = [[WDSVGParser alloc] initWithDrawing:drawing];
        [xmlParser setDelegate:svgParser];
        [xmlParser parse];
        if ([svgParser hadMemoryWarning]) {
            if (outError) {
                *outError = [[NSError alloc] initWithDomain:errorDomain code:101 userInfo:nil];
            }
        } else if ([svgParser hadErrors]) {
            if (outError) {
                *outError = [[NSError alloc] initWithDomain:errorDomain code:102 userInfo:nil];
            }
        } else {
            self.drawing = drawing;
            if (self.loadOnlyThumbnail) {
                // trigger a save to store thumbnail in SVG
                [self markChanged];
            }
        }
        [drawing endSuppressingNotifications];
    }
    
#if WD_DEBUG
    NSLog(@"Time to parse: %f", -[start timeIntervalSinceNow]);
#endif
    return self.drawing || self.thumbnail;
}

- (BOOL) loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError
{
    self.drawing = nil;
    self.thumbnail = nil;
    self.undoManager = nil;
    
    if (outError) {
        *outError = nil;
    }
    
    if ([typeName isEqualToString:@"public.svg-image"]) {
        [self loadFromSVG:contents error:outError];
        if (*outError) {
            // could be a misidentified svgz, give it another try if we can decompress it
            NSData *decompressed = [(NSData *)contents decompress];
            
            if (decompressed) {
                *outError = nil;
                [self loadFromSVG:decompressed error:outError];
            }
        }
    } else if ([typeName isEqualToString:@"public.svgz-image"]) {
        [self loadFromSVG:[(NSData *)contents decompress] error:outError];
    } else if ([typeName isEqualToString:@"com.taptrix.inkpad"]) {
        [self loadFromInkpad:contents error:outError];
    } else {
        if (outError) {
            *outError = [[NSError alloc] initWithDomain:errorDomain
                                                   code:1
                                               userInfo:@{@"message": [NSString stringWithFormat:@"Unknown type: %@", typeName]}];
        }
        return NO;
    }

    if (!(*outError) && (thumbnail_ || self.drawing)) {
        dispatch_async(dispatch_get_main_queue(), ^{ 
           [[NSNotificationCenter defaultCenter] postNotificationName:WDDocumentDidLoadNotification object:self userInfo:nil];
        });
        return YES;
    } else {
        return NO;
    }
}

- (UIImage *) thumbnail
{
    return self.drawing ? self.drawing.thumbnailImage : thumbnail_;
}

- (id) contentsForType:(NSString *)typeName error:(NSError **)outError
{
#if WD_DEBUG
    NSDate *date = [NSDate date];
#endif
    WDDrawing *drawing = [self.drawing copy];
#if WD_DEBUG
    NSLog(@"Copy time: %f", -[date timeIntervalSinceNow]);
#endif
    return drawing;
}

- (BOOL) writeContents:(id)contents toURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)saveOperation originalContentsURL:(NSURL *)originalContentsURL error:(NSError **)outError
{
    WDDrawing *drawing = contents;
    NSString *typeName = self.fileType;
    if ([typeName isEqualToString:@"public.svg-image"] || [typeName isEqualToString:@"SVG"]) {
        contents = [drawing SVGRepresentation];
    } else if ([typeName isEqualToString:@"public.svgz-image"] || [typeName isEqualToString:@"SVGZ"]) {
        contents = [[drawing SVGRepresentation] compress];
    } else if ([typeName isEqualToString:@"com.taptrix.inkpad"] || [typeName isEqualToString:@"Inkpad"]) {
        contents = [drawing inkpadRepresentation];
    } else if ([typeName isEqualToString:@"com.adobe.pdf"] || [typeName isEqualToString:@"PDF"]) {
        contents = [drawing PDFRepresentation];
    } else if ([typeName isEqualToString:@"public.png"] || [typeName isEqualToString:@"PNG"]) {
        contents = UIImagePNGRepresentation([drawing image]);
    } else if ([typeName isEqualToString:@"public.jpeg"] || [typeName isEqualToString:@"JPEG"]) {
        contents = UIImageJPEGRepresentation([drawing image], 0.9);
    } else {
        if (outError) {
            *outError = [[NSError alloc] initWithDomain:errorDomain code:1 userInfo:@{@"message": [NSString stringWithFormat:@"Unknown type: %@", typeName]}];
        }
    }
    return [super writeContents:contents toURL:url forSaveOperation:saveOperation originalContentsURL:originalContentsURL error:outError];
}

- (NSString *) displayName
{    
    return [[self.fileURL lastPathComponent] stringByDeletingPathExtension];
}

- (void) markChanged
{
    [self updateChangeCount:UIDocumentChangeDone];
}

- (void) handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted
{
    [super handleError:error userInteractionPermitted:userInteractionPermitted];
#if WD_DEBUG
    NSLog(@"%@ %@", [error domain], [error userInfo]);
#endif
}

@end
