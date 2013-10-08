//
//  WDUserFont.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

@interface WDUserFont : NSObject

@property (nonatomic, assign) CTFontRef fontRef;
@property (nonatomic, strong) NSString *filepath;
@property (nonatomic, strong) NSString *fullName;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSData *digest;

+ (WDUserFont *) userFontWithFilename:(NSString *)filename;
- (id) initWithFilename:(NSString *)filename;
- (CTFontRef) newFontRefForSize:(float)size;

@end
