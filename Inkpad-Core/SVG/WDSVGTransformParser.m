//
//  WDSVGTransformParser.m
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

#import "WDParseUtil.h"
#import "WDSVGParserStateStack.h"
#import "WDSVGTransformParser.h"

@implementation WDSVGTransformParser

NSArray *tokenizeTransforms(NSString* source, id<WDErrorReporter> reporter) 
{
    NSMutableArray *tokens = [NSMutableArray array];
    enum {START, FUNCTION, OPEN_PAREN, START_ARGUMENT, ARGUMENT} state = START;
    NSRange token;
    for (int i = 0; i < [source length]; ++i) {
        unichar c = [source characterAtIndex:i];
        switch (state) {
        case START:
            if (!charIsWhitespace(c) && c != ',') {
                token = NSMakeRange(i, 1);
                state = FUNCTION;
            }
            break;
        case FUNCTION:
            if (c == '(') {
                [tokens addObject:[source substringWithRange:token]];
                [tokens addObject:@"("];
                state = START_ARGUMENT;
            } else if (charIsWhitespace(c)) {
                [tokens addObject:[source substringWithRange:token]];
                state = OPEN_PAREN;
            } else {
                token.length++;
            }
            break;
        case OPEN_PAREN:
            if (c == '(') {
                state = START_ARGUMENT;
            } else if (!charIsWhitespace(c)) {
                NSLog(@"ERROR: expected '(': %c in %@", c, source);
            }
            break;
        case START_ARGUMENT:
            if (!charIsWhitespace(c) && c != ',') {
                token = NSMakeRange(i, 1);
                state = ARGUMENT;
            }
            break;
        case ARGUMENT:
            if (charIsWhitespace(c) || c == ',') {
                [tokens addObject:[source substringWithRange:token]];
                state = START_ARGUMENT;
            } else if (c == ')') {
                [tokens addObject:[source substringWithRange:token]];
                [tokens addObject:@")"];
                state = START;
            } else {
                token.length++;
            }
            break;
        }
    }
    if (state != START) {
        [reporter reportError:@"unterminated function in: %@", source];
    }
    return tokens;
}

CGAffineTransform processTransform(NSString *function, NSArray *arguments, id<WDErrorReporter> reporter)
{
    if ([function isEqualToString:@"matrix"]) {
        float a = [arguments[0] floatValue];
        float b = [arguments[1] floatValue];
        float c = [arguments[2] floatValue];
        float d = [arguments[3] floatValue];
        float tx = [arguments[4] floatValue];
        float ty = [arguments[5] floatValue];
        return CGAffineTransformMake(a, b, c, d, tx, ty);
    } else if ([function isEqualToString:@"translate"]) {
        float tx = [arguments[0] floatValue];
        float ty = [arguments count] > 1 ? [arguments[1] floatValue] : 0.0;
        return CGAffineTransformMake(1, 0, 0, 1, tx, ty);
    } else if ([function isEqualToString:@"scale"]) {
        float sx = [arguments[0] floatValue];
        float sy = [arguments count] > 1 ? [arguments[1] floatValue] : sx;
        return CGAffineTransformMake(sx, 0, 0, sy, 0, 0);
    } else if ([function isEqualToString:@"rotate"]) {
        float a = [arguments[0] floatValue] * M_PI / 180;
        if ([arguments count] == 3) {
            float cx = [arguments[1] floatValue];
            float cy = [arguments[2] floatValue];
            return CGAffineTransformTranslate(CGAffineTransformRotate(CGAffineTransformMakeTranslation(cx, cy), a), -cx, -cy);
        } else {
            return CGAffineTransformMake(cos(a), sin(a), -sin(a), cos(a), 0, 0);
        }
    } else if ([function isEqualToString:@"skewX"]) {
        float a = [arguments[0] floatValue] * M_PI / 180;
        return CGAffineTransformMake(1, 0, tan(a), 1, 0, 0);
    } else if ([function isEqualToString:@"skewY"]) {
        float a = [arguments[0] floatValue] * M_PI / 180;
        return CGAffineTransformMake(1, tan(a), 0, 1, 0, 0);
    } else {
        [reporter reportError:@"unknown transform function: %@", function];
        return CGAffineTransformIdentity;
    }
}

CGAffineTransform parseTransforms(NSArray *tokens, id<WDErrorReporter> reporter) 
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    enum {FUNCTION, OPEN_PAREN, ARGUMENT} state = FUNCTION;
    NSString *function;
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    for (id token in tokens) {
        switch (state) {
        case FUNCTION:
            function = token;
            [arguments removeAllObjects];
            state = OPEN_PAREN;
            break;
        case OPEN_PAREN:
            if ([token isEqual:@"("]) {
                state = ARGUMENT;
            } else {
                [reporter reportError:@"ERROR: expected '(' at: %@ in: %@", token, tokens];
                state = FUNCTION;
            }
            break;
        case ARGUMENT:
            if ([token isEqual:@")"]) {
                transform = CGAffineTransformConcat(processTransform(function, arguments, reporter), transform);
                state = FUNCTION;
            } else {
                [arguments addObject:@([token floatValue])];
                state = ARGUMENT;
            }
            break;
        }
    }
    if (state != FUNCTION) {
        [reporter reportError:@"ERROR: unterminated transform in: %@", tokens];
    }
    return transform;
}

+ (CGAffineTransform) parse:(NSString *)source withReporter:(id<WDErrorReporter>)reporter
{
    if (source) {
        NSArray *tokens = tokenizeTransforms(source, reporter);
        return parseTransforms(tokens, reporter);
    } else {
        return CGAffineTransformIdentity;
    }
}

@end
