//
//  WDXMLElement.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDXMLElement.h"

@implementation WDXMLElement

@synthesize name = name_;
@synthesize children = children_;
@synthesize attributes = attributes_;
@synthesize value = value_;

+ (WDXMLElement *) elementWithName:(NSString *)name
{
    WDXMLElement *element = [[WDXMLElement alloc] initWithName:name];
    return element;
}

- (id) initWithName:(NSString *)name
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    self.name = name;
    self.children = [NSMutableArray array];
    self.attributes = [NSMutableDictionary dictionary];
    
    return self;
}

- (void) setAttribute:(NSString *)attribute value:(NSString *)value
{
    [self.attributes setValue:value forKey:attribute];
}

- (void) setAttribute:(NSString *)attribute floatValue:(float)value
{
    [self.attributes setValue:[NSString stringWithFormat:@"%g", value] forKey:attribute];
}

- (void) addChild:(WDXMLElement *)element
{
    [self.children addObject:element];
}

- (void) removeAllChildren
{
    [self.children removeAllObjects];
}

- (NSString *) XMLValue
{
    NSMutableString *xmlValue = [NSMutableString string];
    BOOL            needsCloseTag = (self.value || self.children.count) ? YES : NO;
    
    [xmlValue appendString:[NSString stringWithFormat:@"<%@", name_]];
    
    for (NSString *key in [attributes_ allKeys]) {
        [xmlValue appendString:[NSString stringWithFormat:@" %@=\"%@\"", key, [attributes_ valueForKey:key]]];
    }
    
    if (!needsCloseTag) {
        [xmlValue appendString:@"/>\n"];
    } else {
        [xmlValue appendString:@">\n"];
    }
    
    if (self.value) {
        [xmlValue appendString:@"<![CDATA["];
        [xmlValue appendString:self.value];
        [xmlValue appendString:@"]]>"];
    } else if (self.children) {
        for (WDXMLElement *element in self.children) {
            [xmlValue appendString:[element XMLValue]];
        }
    }
    
    // close tag
    if (needsCloseTag) {
        [xmlValue appendString:[NSString stringWithFormat:@"</%@>\n", name_]];
    }
    
    return xmlValue;
}

- (NSString *) description
{
    return [self XMLValue];
}

@end
