//
//  WDParseUtil.m
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

BOOL stringIsNumeric(NSString *s)
{
    if ([s length] == 0) {
        return NO;
    }
    unichar c = [s characterAtIndex:0];
    switch (c) {
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
        case '-':
        case '+':
        case '.':
            return YES;
        default:
            return NO;
    }
}



NSArray *tokenize(NSString *source, unichar* buf)
{
    // NOTE: this method is *the* hotspot for SVG parsing so it is carefully optimized
    NSMutableArray *tokens = [[NSMutableArray alloc] initWithCapacity:([source length] / 3)];
    enum {START, NUMBER, EXPONENT} state = START;
    NSInteger length = [source length];
    [source getCharacters:buf range:NSMakeRange(0, length)];
    unichar *tokenStart = buf;
    unichar *tokenEnd;
    NSString *token;
    for (tokenEnd = buf; tokenEnd < buf + length; ++tokenEnd) {
        unichar c = *tokenEnd;
        switch (state) {
            case START:
                switch (c) {
                    case '0':
                    case '1':
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                    case '8':
                    case '9':
                    case '.':
                    case '+':
                    case '-':
                        tokenStart = tokenEnd;
                        state = NUMBER;
                        break;
                    case ' ':
                    case '\n':
                    case '\r':
                    case '\t':
                        // ignore whitespace
                        break;
                    default:
                        token = [[NSString alloc] initWithCharactersNoCopy:tokenEnd length:1 freeWhenDone:NO];
                        [tokens addObject:token];
                }
                break;
            case NUMBER:
                switch (c) {
                    case '0':
                    case '1':
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                    case '8':
                    case '9':
                    case '.':
                        break;
                    case 'e':
                    case 'E':
                        state = EXPONENT;
                        break;
                    case '+':
                    case '-':
                        token = [[NSString alloc] initWithCharactersNoCopy:tokenStart length:(tokenEnd - tokenStart) freeWhenDone:NO];
                        [tokens addObject:token];
                        // sign starts a new number
                        tokenStart = tokenEnd;
                        state = NUMBER;
                        break;
                    case ' ':
                    case '\n':
                    case '\r':
                    case '\t':
                    case ',':
                        token = [[NSString alloc] initWithCharactersNoCopy:tokenStart length:(tokenEnd - tokenStart) freeWhenDone:NO];
                        [tokens addObject:token];
                        // whitespace/comma ends the number
                        state = START;
                        break;
                    default:
                        token = [[NSString alloc] initWithCharactersNoCopy:tokenStart length:(tokenEnd - tokenStart) freeWhenDone:NO];
                        [tokens addObject:token];
                        // command character ends the number and resets state
                        token = [[NSString alloc] initWithCharactersNoCopy:tokenEnd length:1 freeWhenDone:NO];
                        [tokens addObject:token];
                        state = START;
                }
                break;
            case EXPONENT:
                switch (c) {
                    case '0':
                    case '1':
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                    case '8':
                    case '9':
                    case '.':
                    case '-':
                    case '+':
                        state = NUMBER;
                        break;
                    case ' ':
                    case '\n':
                    case '\r':
                    case '\t':
                    case ',':
                        token = [[NSString alloc] initWithCharactersNoCopy:tokenStart length:(tokenEnd - tokenStart) freeWhenDone:NO];
                        [tokens addObject:token];
                        // whitespace/comma ends the number
                        state = START;
                        break;
                    default:
                        token = [[NSString alloc] initWithCharactersNoCopy:tokenStart length:(tokenEnd - tokenStart) freeWhenDone:NO];
                        [tokens addObject:token];
                        // command character ends the number and resets state
                        token = [[NSString alloc] initWithCharactersNoCopy:tokenEnd length:1 freeWhenDone:NO];
                        [tokens addObject:token];
                        state = START;
                }
                break;
        }
    }
    if (state == NUMBER || state == EXPONENT) {
        token = [[NSString alloc] initWithCharactersNoCopy:tokenStart length:(tokenEnd - tokenStart) freeWhenDone:NO];
        [tokens addObject:token];
    }
    return tokens;
}
