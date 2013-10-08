//
//  WDSVGHelper.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Original implementation by Scott Vachalek
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@class WDXMLElement;

@interface WDSVGHelper : NSObject {
    NSMutableDictionary     *uniques_;
    WDXMLElement            *definitions_;
    NSMutableDictionary     *images_;
    NSMutableDictionary     *blendModeNames_;
}

@property (nonatomic, readonly) WDXMLElement *definitions;

+ (WDSVGHelper *) sharedSVGHelper;

- (void) beginSVGGeneration;
- (void) endSVGGeneration;

- (NSString *) uniqueIDWithPrefix:(NSString *)prefix;
- (void) addDefinition:(WDXMLElement *)def;
- (WDXMLElement *) definitions;

- (void) setImageID:(NSString *)unique forDigest:(NSData *)digest;
- (NSString *) imageIDForDigest:(NSData *)digest;

- (NSString *) displayNameForBlendMode:(CGBlendMode)blendMode;

@end
