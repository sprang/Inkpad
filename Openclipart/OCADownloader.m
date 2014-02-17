//
//  OCADownloader.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import "OCADownloader.h"

@interface OCADownloader () {
    NSURLConnection     *connection_;
}
@end

@implementation OCADownloader

@synthesize urlString = urlString_;
@synthesize delegate = delegate_;
@synthesize data = data_;
@synthesize info = info_;

+ (OCADownloader *) downloaderWithURL:(NSString *)url delegate:(id<OCADownloaderDelegate>)delegate
{
    return [[OCADownloader alloc] initWithURL:url delegate:delegate info:nil];
}

+ (OCADownloader *) downloaderWithURL:(NSString *)url delegate:(id<OCADownloaderDelegate>)delegate info:(id)info
{
    return [[OCADownloader alloc] initWithURL:url delegate:delegate info:info];
}

- (id) initWithURL:(NSString *)url delegate:(id<OCADownloaderDelegate>)delegate info:(id)info
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    urlString_ = url;
    self.info = info;
    self.delegate = delegate;
    
    // use this to accumulate downloaded data
    self.data = [NSMutableData data];
    
    // start downloading
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString_]];
    connection_ = [NSURLConnection connectionWithRequest:request delegate:self];
    [connection_ start];
    
    return self;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [data_ appendData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
    [delegate_ takeDataFromDownloader:self];
}

- (void) cancel
{
    [connection_ cancel];
}

@end
