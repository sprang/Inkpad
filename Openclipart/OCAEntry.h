//
//  OCAEntry.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import <Foundation/Foundation.h>

@interface OCAEntry : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *uploader;
@property (nonatomic) NSUInteger ID;
@property (nonatomic) NSUInteger favorites;
@property (nonatomic) NSUInteger downloads;
@property (nonatomic) NSString *SVGURL;
@property (nonatomic) NSString *thumbURL;

+ (OCAEntry *) openClipArtEntryWithDictionary:(NSDictionary *)dict;

@end
