//
//  WDSVGElement.m
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

#import "WDSVGElement.h"
#import "WDSVGParserStateStack.h"
#import "WDParseUtil.h"


@implementation WDSVGElement

@synthesize name = name_;
@synthesize attributes = attributes_;

- (WDSVGElement *) initWithName:(NSString *)name andAttributes:(NSDictionary *)attributes
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    name_ = name;
    if ([attributes count]) {
        attributes_ = attributes;
    }

    return self;
}

- (NSMutableArray *) children
{
    if (!children_) {
        children_ = [[NSMutableArray alloc] init];
    }
    return children_;
}

- (NSMutableString *) text
{
    if (!text_) {
        text_ = [[NSMutableString alloc] init];
    }
    return text_;
}

- (NSString *) description
{
    NSMutableString *buf = [NSMutableString stringWithString:@"<"];
    [buf appendString:name_];
    [attributes_ enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [buf appendString:@" "];
        [buf appendString:key];
        [buf appendString:@"="];
        [buf appendString:@"\""];
        [buf appendString:obj];
        [buf appendString:@"\""];
    }];
    [buf appendString:@">"];
    if (text_) {
        [buf appendString:text_];
    }
    return buf;
}

- (NSString *) attribute:(NSString *)key withDefault:(NSString *)deft
{
    return attributes_[key] ?: deft;
}

- (NSString *) attribute:(NSString *)key
{
    return attributes_[key];
}

- (float) coordinate:(NSString *)key withBound:(float)bound andDefault:(float)deft
{
    NSString *source = [self attribute:key];
    return [WDSVGElement lengthFromString:source withBound:bound andDefault:deft];

}

- (float) coordinate:(NSString *)source withBound:(float)bound
{
    return [self coordinate:source withBound:bound andDefault:0];
}

+ (float) lengthFromString:(NSString *)source withBound:(float)bound andDefault:(float)deft
{
    NSInteger len = [source length];
    if (len == 0) {
        return deft;
    } else if (len == 1) {
        return  [source floatValue];
    } else {
        unichar u1 = [source characterAtIndex:(len - 1)];
        unichar u2 = (len > 2) ? [source characterAtIndex:(len - 2)] : u1;
        if (u1 >= 'A' && u1 <= 'Z') {
            u1 += ('a' - 'A');
        }
        if (u2 >= 'A' && u2 <= 'Z') {
            u2 += ('a' - 'A');
        }
        if (u1 == '%') {
            float ratio = [[source substringToIndex:len - 1] floatValue] / 100.f;
            return ratio * bound;
        } else if (u2 == 'p' && u1 == 'x') {
            return [[source substringToIndex:len - 2] floatValue] * 0.8f;
        } else if (u2 == 'p' && u1 == 't') {
            return [[source substringToIndex:len - 2] floatValue];
        } else if (u2 == 'p' && u1 == 'c') {
            return [[source substringToIndex:len - 2] floatValue] * 15.f * 0.8f;
        } else if (u2 == 'm' && u1 == 'm') {
            return [[source substringToIndex:len - 2] floatValue] * 3.543307f * 0.8f;
        } else if (u2 == 'c' && u1 == 'm') {
            return [[source substringToIndex:len - 2] floatValue] * 35.43307f * 0.8f;
        } else if (u2 == 'i' && u1 == 'n') {
            return [[source substringToIndex:len - 2] floatValue] * 90.f * 0.8f;
        } else if (u2 == 'p' && u1 == 'x') {
            return [[source substringToIndex:len - 2] floatValue] * 0.8f;
        } else if (u2 == 'e' && u1 == 'm') {
            // em and ex depend on the font of the enclosing block; since we don't have one the default font-size is "medium", let's call it 12pt
            return [[source substringToIndex:len - 2] floatValue] * 12.f;
        } else if (u2 == 'e' && u1 == 'x') {
            return [[source substringToIndex:len - 2] floatValue] * 8.f;
        } else {
            return [source floatValue];
        }
    }
}

- (float) length:(NSString *)key withBound:(float)bound andDefault:(float)deft
{
    NSString *source = [self attribute:key];
    return [WDSVGElement lengthFromString:source withBound:bound andDefault:deft];
}

- (float) length:(NSString *)key withBound:(float)bound
{
    return [self length:key withBound:bound andDefault:0];
}

+ (NSArray *) numberListFromString:(NSString *)source
{
    unichar *buf = malloc([source length] * sizeof(unichar));
    NSArray *tokens = tokenize(source, buf);
    NSMutableArray *numbers = [NSMutableArray array];
    for (NSString *token in tokens) {
        if (stringIsNumeric(token)) {
            float number = [token floatValue];
            [numbers addObject:@(number)];
        }
    }
    free(buf);
    return numbers;
}

- (NSArray *) numberList:(NSString *)key
{
    return [WDSVGElement numberListFromString:[self attribute:key]];
}

- (NSArray *) coordinateList:(NSString *)key
{
    return [WDSVGElement numberListFromString:[self attribute:key]];
}

+ (NSArray *) lengthListFromString:(NSString *)source withBound:(float)bound
{
    unichar *buf = malloc([source length] * sizeof(unichar));
    NSArray *tokens = tokenize(source, buf);
    NSMutableArray *numbers = [NSMutableArray array];
    for (NSString *token in tokens) {
        if (stringIsNumeric(token)) {
            float number = [WDSVGElement lengthFromString:token withBound:bound andDefault:0];
            [numbers addObject:@(number)];
        }
    }
    free(buf);
    return numbers;
}

- (NSArray *) lengthList:(NSString *)key withBound:(float)bound
{
    return [WDSVGElement lengthListFromString:[self attribute:key] withBound:bound];
}

- (CGPoint) x:(NSString *)xKey y:(NSString *)yKey withBounds:(CGSize)bounds andDefault:(CGPoint)deft
{
    float x = [self coordinate:xKey withBound:bounds.width andDefault:deft.x];
    float y = [self coordinate:yKey withBound:bounds.height andDefault:deft.y];
    return CGPointMake(x, y);
}

- (CGPoint) x:(NSString *)xKey y:(NSString *)yKey withBounds:(CGSize)bounds
{
    return [self x:xKey y:yKey withBounds:bounds andDefault:CGPointZero];
}

- (NSString *) idFromIRI:(NSString *)key withReporter:(id<WDErrorReporter>)reporter
{
    NSString *iri = [self attribute:key];
    if ([iri hasPrefix:@"#"]) {
        return [iri substringFromIndex:1];
    } else if (iri) {
        [reporter reportError:@"unsupported iri: %@", iri];
        return nil;
    } else {
        return nil;
    }
}

- (NSString *) idFromFuncIRI:(NSString *)key withReporter:(id<WDErrorReporter>)reporter
{
    NSString *funciri = [self attribute:key];
    if ([funciri hasPrefix:@"url(#"] && [funciri hasSuffix:@")"]) {
        return [funciri substringWithRange:NSMakeRange(5, [funciri length] - 6)];
    } else if (funciri) {
        [reporter reportError:@"unsupported funciri: %@", funciri];
        return nil;
    } else {
        return nil;
    }
}

@end
