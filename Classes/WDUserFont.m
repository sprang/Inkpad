//
//  WDUserFont.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDUserFont.h"
#import "WDUtilities.h"

#define kDefaultFontSize 12

@implementation WDUserFont

@synthesize fontRef;
@synthesize filepath;
@synthesize fullName;
@synthesize displayName;
@synthesize digest;

+ (WDUserFont *) userFontWithFilename:(NSString *)filename
{
    return [[WDUserFont alloc] initWithFilename:filename];
}

- (id) initWithFilename:(NSString *)filename
{
    self = [super init];
    
    if (!self) {
        return nil;
        
    }
    // load the font
    NSData *data = [[NSData alloc] initWithContentsOfFile:filename];
    CGDataProviderRef fontProvider = CGDataProviderCreateWithCFData((CFDataRef)data);
    self.digest = WDSHA1DigestForData(data);
    
    CGFontRef cgFont = CGFontCreateWithDataProvider(fontProvider);
    CGDataProviderRelease(fontProvider);
    
    if (cgFont) {
        self.fontRef = CTFontCreateWithGraphicsFont(cgFont, kDefaultFontSize, NULL, NULL);
        CGFontRelease(cgFont);
    }
    
    if (!self.fontRef) {
#if WD_DEBUG
        NSLog(@"Could not load font: %@", filename);
#endif
        return nil;
    }
    
    self.filepath = filename;
    
    CFStringRef displayNameRef = CTFontCopyDisplayName(self.fontRef);
    self.displayName = (__bridge NSString *)displayNameRef;
    CFRelease(displayNameRef);
    
    CFStringRef fullNameRef = CTFontCopyFullName(self.fontRef);
    self.fullName = (__bridge NSString *)fullNameRef;
    CFRelease(fullNameRef);
    
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@: %@; %@; %@; %@", [super description],
            fontRef, displayName, fullName, filepath];
}

- (CTFontRef) newFontRefForSize:(float)size
{
    if (CTFontGetSize(fontRef) != size) {
        CTFontRef newRef = CTFontCreateCopyWithAttributes(fontRef, size, NULL, NULL);
        if (fontRef) {
            CFRelease(fontRef);
        }
        fontRef = newRef;
    }
    
    CFRetain(fontRef);
    return fontRef;
}

- (void) dealloc
{
    if (fontRef) {
        CFRelease(fontRef);
    }
}

@end
