//
//  OCADownloader.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import <Foundation/Foundation.h>

@class OCADownloader;

@protocol OCADownloaderDelegate <NSObject>
@required
- (void) takeDataFromDownloader:(OCADownloader *)downloader;
@end

@interface OCADownloader : NSObject <NSURLConnectionDataDelegate>

@property (nonatomic, readonly) NSString *urlString;
@property (nonatomic) NSMutableData *data;
@property (nonatomic) id info;
@property (nonatomic, weak) id<OCADownloaderDelegate> delegate;

+ (OCADownloader *) downloaderWithURL:(NSString *)urlString delegate:(id<OCADownloaderDelegate>)delegate;
+ (OCADownloader *) downloaderWithURL:(NSString *)urlString delegate:(id<OCADownloaderDelegate>)delegate info:(id)info;
- (void) cancel;

@end
