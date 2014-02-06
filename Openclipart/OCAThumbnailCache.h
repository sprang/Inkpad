//
//  OCAThumbnailCache.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import <Foundation/Foundation.h>
#import "OCADownloader.h"

@protocol WDOpenClipArtThumbnailReceiver <NSObject>
- (void) setThumbnail:(UIImage *)thumbnail;
@end


@interface OCAThumbnailCache : NSObject <OCADownloaderDelegate>

+ (OCAThumbnailCache *) sharedInstance;
- (void) registerForThumbnail:(id<WDOpenClipArtThumbnailReceiver>)receiver url:(NSString *)thumbURL;

@end
