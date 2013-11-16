//
//  WDFontManager.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDFontManager.h"
#import "WDUtilities.h"
#import "WDUserFont.h"

NSString *WDFontDeletedNotification = @"WDFontDeletedNotification";
NSString *WDFontAddedNotification = @"WDFontAddedNotification";

@implementation WDFontManager

@synthesize systemFontMap;
@synthesize systemFamilyMap;
@synthesize systemFonts;
@synthesize userFontMap;
@synthesize userFamilyMap;
@synthesize userFonts;
@synthesize supportedFonts;
@synthesize supportedFamilies;

+ (WDFontManager *) sharedInstance
{
    static WDFontManager *sharedInstance_ = nil;
    
    if (!sharedInstance_) {
        sharedInstance_ = [[WDFontManager alloc] init];
    }
    
    return sharedInstance_;
}

- (id)init
{
    self = [super init];

    if (!self) {
        return nil;
    }
    
    // create the user font dir if necessary
    [[NSFileManager defaultManager] createDirectoryAtPath:[self pathForUserLibrary]
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    
    [self loadAllFonts];
    
    return self;
}

- (dispatch_queue_t) fontQueue
{
    static dispatch_queue_t fontLoadingQueue;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        fontLoadingQueue = dispatch_queue_create("com.taptrix.inkpad.font", DISPATCH_QUEUE_SERIAL);
    });
    
    return fontLoadingQueue;
}

- (void) loadAllFonts
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async([self fontQueue], ^{
            // load system fonts
            systemFontMap = [[NSMutableDictionary alloc] init];
            systemFamilyMap = [[NSMutableDictionary alloc] init];
            
            NSArray *families = [UIFont familyNames];
            for (NSString *family in families) {
                for (NSString *fontName in [UIFont fontNamesForFamilyName:family]) {
                    CTFontRef myFont = CTFontCreateWithName((CFStringRef)fontName, 12, NULL);
                    CFStringRef displayName = CTFontCopyDisplayName(myFont);
                    CFStringRef familyName = CTFontCopyFamilyName(myFont);

                    systemFontMap[fontName] = (__bridge NSString *)displayName;
                    systemFamilyMap[fontName] = (__bridge NSString *)familyName;
                    
                    CFRelease(displayName);
                    CFRelease(familyName);
                    CFRelease(myFont);
                }
            }
            
            systemFonts = [[systemFontMap allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
            
            // load user fonts
            userFontMap = [NSMutableDictionary dictionary];
            userFamilyMap = [NSMutableDictionary dictionary];
            for (NSString *fontPath in [self userLibraryFontPaths]) {
                WDUserFont *userFont = [WDUserFont userFontWithFilename:fontPath];
                if (userFont) {
                    userFontMap[userFont.fullName] = userFont;
                    userFamilyMap[userFont.fullName] = userFont.familyName;
                }
            }
        });
    });
}

- (void) waitForInitialLoad
{
    // make sure the fonts are loaded (should be done at app launch)
    dispatch_sync([self fontQueue], ^{ [self loadAllFonts]; });
    
    // wait for load
    dispatch_sync([self fontQueue], ^{});
}

- (NSArray *) systemFonts
{
    [self waitForInitialLoad];
    return systemFonts;
}

- (NSArray *) supportedFamilies
{
    [self waitForInitialLoad];
    
    if (!supportedFamilies) {
        NSMutableSet *families = [NSMutableSet setWithArray:[self.systemFamilyMap allValues]];
        [families addObjectsFromArray:[self.userFamilyMap allValues]];
        
        supportedFamilies = [[families allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    }
    
    return supportedFamilies;
}

- (NSArray *) supportedFonts
{
    [self waitForInitialLoad];
    
    if (!supportedFonts) {
        NSMutableSet *combined = [NSMutableSet setWithArray:systemFonts];
        [combined addObjectsFromArray:self.userFonts];
        
        supportedFonts = [[combined allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    }
    
    return supportedFonts;
}

- (BOOL) validFont:(NSString *)fullName
{
    [self waitForInitialLoad];
    return [self.supportedFonts containsObject:fullName];
}

- (BOOL) isUserFont:(NSString *)fullName
{
    [self waitForInitialLoad];
    return userFontMap[fullName] ? YES : NO;
}

- (NSString *) typefaceNameForFont:(NSString *)fullName
{
    [self waitForInitialLoad];
    
    NSString *longName = systemFontMap[fullName] ?: ((WDUserFont *)userFontMap[fullName]).displayName;
    NSString *familyName = [self familyNameForFont:fullName];
    
    NSString *typeface = [longName copy];
    if ([typeface hasPrefix:familyName]) {
        typeface = [longName substringFromIndex:[familyName length]];
        typeface = [typeface stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
    if ([typeface length] == 0) {
        typeface = @"Regular";
    }
    
    return typeface;
}

- (NSString *) displayNameForFont:(NSString *)fullName
{
    [self waitForInitialLoad];
    return systemFontMap[fullName] ?: ((WDUserFont *)userFontMap[fullName]).displayName;
}

- (NSString *) familyNameForFont:(NSString *)fullName
{
    [self waitForInitialLoad];
    return systemFamilyMap[fullName] ?: ((WDUserFont *)userFamilyMap[fullName]);
}

- (NSString *) defaultFontForFamily:(NSString *)familyName
{
    [self waitForInitialLoad];
    
    NSArray *fonts = [self fontsInFamily:familyName];
    NSArray *sorted = [fonts sortedArrayUsingComparator:^NSComparisonResult(NSString *aString, NSString *bString) {
        NSNumber *a = @(aString.length);
        NSNumber *b = @(bString.length);
        return [a compare:b];
    }];
    
    for (NSString *fontName in sorted) {
        CTFontRef fontRef = [self newFontRefForFont:fontName withSize:10];
        CTFontSymbolicTraits traits = CTFontGetSymbolicTraits(fontRef);
        CFRelease(fontRef);
        
        BOOL isBold = (traits & kCTFontBoldTrait);
        if (isBold) {
            continue;
        }
        
        BOOL isItalic = (traits & kCTFontItalicTrait);
        if (isItalic) {
            continue;
        }
        
        return fontName;
    }
    
    // Fallback, just return the first font in this family
    return [sorted firstObject];
}

- (NSArray *) fontsInFamily:(NSString *)familyName
{
    [self waitForInitialLoad];
    
    NSArray *result = [systemFamilyMap allKeysForObject:familyName];
    
    if (!result || result.count == 0) {
        result = [userFamilyMap allKeysForObject:familyName];
    }
    
    return (result ?: @[]);
}

- (NSString *) pathForUserLibrary
{
    NSString *fontPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
    return [fontPath stringByAppendingPathComponent:@"Fonts"];
}

- (NSArray *) userLibraryFontPaths
{
    NSString *fontPath = [self pathForUserLibrary];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *expanded = [NSMutableArray array];
    
    for (NSString *font in [fm contentsOfDirectoryAtPath:fontPath error:NULL]) {
        [expanded addObject:[fontPath stringByAppendingPathComponent:font]];
    }
    
    return expanded;
}

- (CTFontRef) newFontRefForFont:(NSString *)fullName withSize:(float)size
{
    return [self newFontRefForFont:fullName withSize:size provideDefault:NO];
}

- (CTFontRef) newFontRefForFont:(NSString *)fullName withSize:(float)size provideDefault:(BOOL)provideDefault
{
    [self waitForInitialLoad];
    
    if (systemFontMap[fullName]) {
        // it's built in, just load it
        return CTFontCreateWithName((CFStringRef) fullName, size, NULL);
    } else if (userFontMap[fullName]) {
        WDUserFont *userFont = (WDUserFont *) userFontMap[fullName];
        return [userFont newFontRefForSize:size];
    } else if (provideDefault) {
        // if we got this far, return the default font
        return CTFontCreateWithName((CFStringRef) @"Helvetica", size, NULL);
    }
    
    return NULL;
}

- (NSArray *) userFonts
{
    [self waitForInitialLoad];
    
    if (!userFonts) {
        userFonts = [[userFontMap allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    }
    
    return userFonts;
}

- (WDUserFont *) isFontAlreadyInstalled:(NSString *)path
{
    [self waitForInitialLoad];
    
    NSData *hash = WDSHA1DigestForData([NSData dataWithContentsOfFile:path]);
    
    NSSet *keys = [userFontMap keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        WDUserFont *userFont = (WDUserFont *) obj;
        *stop = [userFont.digest isEqual:hash];
        return *stop;
    }];
    
    return userFontMap[[keys anyObject]];
}

- (WDUserFont *) userFontForPath:(NSString *)path
{
    [self waitForInitialLoad];
    
    NSSet *keys = [userFontMap keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        WDUserFont *userFont = (WDUserFont *) obj;
        *stop = [userFont.filepath caseInsensitiveCompare:path] == NSOrderedSame;
        return *stop;
    }];
    
    return userFontMap[[keys anyObject]];
}

- (void) userFontsChanged
{
    userFonts = nil;
    supportedFonts = nil;
}

- (NSString *) installUserFont:(NSURL *)srcURL alreadyInstalled:(BOOL *)alreadyInstalled
{
    [self waitForInitialLoad];
    
    // see if this font is already installed 
    WDUserFont *existing = [self isFontAlreadyInstalled:[srcURL path]];
    *alreadyInstalled = existing ? YES : NO;
    if (*alreadyInstalled) {
        return existing.displayName;
    }
    
    // load the font to see if it's valid
    WDUserFont *userFont = [WDUserFont userFontWithFilename:[srcURL path]];
    if (!userFont) {
        return nil;
    }
    
    NSString        *fontPath = [[self pathForUserLibrary] stringByAppendingPathComponent:[srcURL lastPathComponent]];
    NSURL           *dstURL = [NSURL fileURLWithPath:fontPath];
    NSError         *error = nil;
    
    // delete the old font at this path, if any
    [self deleteUserFontWithName:[self userFontForPath:fontPath].fullName];
    
    [[NSFileManager defaultManager] copyItemAtURL:srcURL toURL:dstURL error:&error];
    if (error) {
        NSLog(@"%@", error);
        return nil;
    }
    
    // make sure the font knows its new location
    userFont.filepath = [dstURL path];
    
    // the font is now copied to ~/Library/Fonts/ so update the user font map and name array
    userFontMap[userFont.fullName] = userFont;
    userFamilyMap[userFont.fullName] = userFont.familyName;
    
    [self userFontsChanged];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WDFontAddedNotification
                                                        object:self
                                                      userInfo:@{@"name": userFont.fullName}];
    
    return userFont.displayName;
}

- (void) deleteUserFontWithName:(NSString *)fullName
{
    [self waitForInitialLoad];
    
    WDUserFont *userFont = userFontMap[fullName];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if (!userFont || ![fm fileExistsAtPath:userFont.filepath]) {
        return;
    }
    
    // actually delete it
    [fm removeItemAtPath:userFont.filepath error:NULL];
    
    // update caches
    [userFontMap removeObjectForKey:userFont.fullName];
    [userFamilyMap removeObjectForKey:userFont.fullName];
    
    NSInteger index = [self.userFonts indexOfObject:userFont.fullName];
    [self userFontsChanged];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WDFontDeletedNotification
                                                        object:self
                                                      userInfo:@{@"index": @(index)}];
}

@end
