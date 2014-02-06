//
//  OCAThumbnailCache.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import "OCAThumbnailCache.h"

@interface OCAThumbnailCache () {
    NSCache             *thumbnailCache_;
    NSMutableSet        *downloaders_;
    NSMutableDictionary *urlToReceiverMap_;
}
@end

@implementation OCAThumbnailCache

+ (OCAThumbnailCache *) sharedInstance
{
    static OCAThumbnailCache *loader_ = nil;
    
    if (!loader_) {
        loader_ = [[OCAThumbnailCache alloc] init];
    }
    
    return loader_;
}

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    thumbnailCache_ = [[NSCache alloc] init];
    urlToReceiverMap_ = [NSMutableDictionary dictionary];
    downloaders_ = [NSMutableSet set];
    
    return self;
}

- (void) takeDataFromDownloader:(OCADownloader *)downloader
{
    NSString *key = downloader.urlString;
    [thumbnailCache_ setObject:downloader.data forKey:key];

    id<WDOpenClipArtThumbnailReceiver> receiver = [urlToReceiverMap_ objectForKey:key];
    if (receiver) {
        [receiver setThumbnail:[UIImage imageWithData:downloader.data]];
        [urlToReceiverMap_ removeObjectForKey:key];
    }

    [downloaders_ removeObject:downloader];
}

- (BOOL) alreadyDownloading:(NSString *)urlString
{
    for (OCADownloader *dl in downloaders_) {
        if ([dl.urlString isEqualToString:urlString]) {
            return YES;
        }
    }
    
    return NO;
}

- (void) registerForThumbnail:(id<WDOpenClipArtThumbnailReceiver>)receiver url:(NSString *)thumbURL
{
    NSData *imageData = [thumbnailCache_ objectForKey:thumbURL];
    
    if (imageData) {
        [receiver setThumbnail:[UIImage imageWithData:imageData]];
        return;
    }
    
    // start downloading the data
    if (![self alreadyDownloading:thumbURL]) {
        OCADownloader *downloader = [OCADownloader downloaderWithURL:thumbURL delegate:self];
        [downloaders_ addObject:downloader];
    }
    
    if ([[urlToReceiverMap_ allValues] containsObject:receiver]) {
        // need to remove the previous mapping, since it's now out of date
        for (NSString *key in [urlToReceiverMap_ allKeys]) {
            if ([urlToReceiverMap_ objectForKey:key] == receiver) {
                [urlToReceiverMap_ removeObjectForKey:key];
                break;
            }
        }
    }
    
    // register the object
    [urlToReceiverMap_ setObject:receiver forKey:thumbURL];
}

@end
