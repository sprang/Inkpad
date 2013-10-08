//
//  WDSVGHelper.m
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

#import "WDSVGHelper.h"
#import "WDXMLElement.h"

@implementation WDSVGHelper

@synthesize definitions = definitions_;

+ (WDSVGHelper *) sharedSVGHelper
{
    static WDSVGHelper *sharedHelper_ = nil;
    
    if (!sharedHelper_) {
        sharedHelper_ = [[WDSVGHelper alloc] init];
    }
    
    return sharedHelper_;
}

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    uniques_ = [NSMutableDictionary dictionary];
    definitions_ = [[WDXMLElement alloc] initWithName:@"defs"];
    images_ = [NSMutableDictionary dictionary];
	NSArray *blendModeArray = [[NSArray alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"BlendModes" withExtension:@"plist"]];
    blendModeNames_ = [NSMutableDictionary dictionary];
    for (NSDictionary *dict in blendModeArray) {
        blendModeNames_[dict[@"value"]] = dict[@"name"];
    }
    return self;
}

- (void) beginSVGGeneration
{
    // reset the uniqueness tracker
    [uniques_ removeAllObjects];
    [definitions_ removeAllChildren];
    [images_ removeAllObjects];
}

- (void) endSVGGeneration
{
    // reset the uniqueness tracker
    [uniques_ removeAllObjects];
    [definitions_ removeAllChildren];
    [images_ removeAllObjects];
}

- (NSString *) uniqueIDWithPrefix:(NSString *)prefix
{
    NSNumber    *unique = uniques_[prefix];
    
    if (!unique) {
        uniques_[prefix] = @2;
        return prefix;
    }
    
    // incremement the old unique value and store it away for next time
    uniques_[prefix] = @([unique integerValue]+1);
    
    // return the unique string
    return [NSString stringWithFormat:@"%@_%@", prefix, [unique stringValue]];
}

- (void) addDefinition:(WDXMLElement *)def
{
    [definitions_ addChild:def];
}

- (void) setImageID:(NSString *)unique forDigest:(NSData *)digest
{
    images_[digest] = unique;
}

- (NSString *) imageIDForDigest:(NSData *)digest
{
    return images_[digest];
}

- (NSString *) displayNameForBlendMode:(CGBlendMode)blendMode
{
    return blendModeNames_[[NSNumber numberWithInt:blendMode]];
}

@end
