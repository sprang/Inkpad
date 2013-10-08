//
//  NSArray+Additions.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "NSArray+Additions.h"

@implementation NSArray (WDAdditions)

- (NSArray *) map:(id (^)(id obj))fn
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:self.count];
    
    for (id element in self) {
        [result addObject:fn(element)];
    }
    
    return result;
}

- (NSArray *) filter:(BOOL (^)(id obj))predicate
{
    NSMutableArray *result = [NSMutableArray array];
    
    for (id element in self) {
        if (predicate(element)) {
            [result addObject:element];
        }
    }
    
    return result;
}

@end
