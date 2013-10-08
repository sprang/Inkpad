//
//  DBMetadata+Additions.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "DBMetadata+Additions.h"


@implementation DBMetadata (Additions)

- (NSString *)description 
{	
	return [NSString stringWithFormat:@"%@ - %@",
            NSStringFromClass([self class]), [[self dictionaryRepresentation] descriptionWithLocale:nil indent:0]];
}

- (NSDictionary *)dictionaryRepresentation 
{
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	dictionary[@"path"] = self.path ?: @"";
	dictionary[@"icon"] = self.icon ?: @"";
	dictionary[@"lastModifiedDate"] = self.lastModifiedDate ? [dateFormatter stringFromDate:self.lastModifiedDate] : @"";
	dictionary[@"thumbnailExists"] = @(self.thumbnailExists);
	dictionary[@"isDirectory"] = @(self.isDirectory);
	dictionary[@"isDeleted"] = @(self.isDeleted);
	
	dictionary[@"root"] = self.root ?: @"";
	dictionary[@"humanReadableSize"] = self.humanReadableSize ?: @"";
	dictionary[@"totalBytes"] = @(self.totalBytes);
	dictionary[@"revision"] = @(self.revision);
	dictionary[@"hash"] = self.hash ?: @"";
	dictionary[@"contents"] = self.contents ? [self.contents valueForKey:@"path"] : @"";
	
	return [dictionary copy];
}

@end
