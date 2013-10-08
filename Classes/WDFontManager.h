//
//  WDFontManager.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>

@class WDUserFont;

@interface WDFontManager : NSObject

@property (weak, nonatomic, readonly) NSArray *supportedFonts;
@property (nonatomic, strong, readonly) NSMutableDictionary *userFontMap;
@property (nonatomic, strong, readonly) NSArray *userFonts;
@property (nonatomic, strong, readonly) NSMutableDictionary *systemFontMap;
@property (nonatomic, strong, readonly) NSArray *systemFonts;

+ (WDFontManager *) sharedInstance;

- (void) loadAllFonts;

- (BOOL) isUserFont:(NSString *)fullName;
- (BOOL) validFont:(NSString *)fullName;
- (NSString *) displayNameForFont:(NSString *)fullName;

- (WDUserFont *) userFontForPath:(NSString *)path;
// on success returns the display name of the font, otherwise returns nil
- (NSString *) installUserFont:(NSURL *)srcURL alreadyInstalled:(BOOL *)alreadyInstalled;
- (void) deleteUserFontWithName:(NSString *)fullName;

- (CTFontRef) newFontRefForFont:(NSString *)fullName withSize:(float)size;
- (CTFontRef) newFontRefForFont:(NSString *)fullName withSize:(float)size provideDefault:(BOOL)provideDefault;

- (NSString *) pathForUserLibrary;
- (NSArray *) userLibraryFontPaths;

@end

extern NSString *WDFontAddedNotification;
extern NSString *WDFontDeletedNotification;
