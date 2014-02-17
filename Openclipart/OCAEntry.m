//
//  OCAEntry.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import "OCAEntry.h"

@implementation OCAEntry

+ (OCAEntry *) openClipArtEntryWithDictionary:(NSDictionary *)dict
{
    OCAEntry *entry = [[OCAEntry alloc] init];
    
    entry.title = dict[@"title"];
    entry.uploader = dict[@"uploader"];
    entry.ID = dict[@"id"];
    entry.favorites = [dict[@"total_favorites"] integerValue];
    entry.downloads = [dict[@"downloaded_by"] integerValue];
    entry.SVGURL = [dict[@"svg"][@"url"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    entry.thumbURL = [dict[@"svg"][@"png_thumb"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    return entry;
}

@end
