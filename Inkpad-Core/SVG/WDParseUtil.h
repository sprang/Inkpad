//
//  WDParseUtil.h
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


static inline BOOL charIsWhitespace(unichar c)
{
    return [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c];
}

static inline float scaleRadially(float length, CGAffineTransform transform) {
    CGSize size = CGSizeApplyAffineTransform(CGSizeMake(length, length), transform);
    return sqrtf(size.width * size.width + size.height * size.height) / sqrtf(2.f);
}

BOOL stringIsNumeric(NSString *s);

NSArray *tokenize(NSString *source, unichar* buf);
