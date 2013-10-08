//
//  WDImageData.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

typedef enum {
    WDImageDataJPEGFormat,
    WDImageDataPNGFormat
} WDImageDataFormat;

@interface WDImageData : NSObject <NSCoding, NSCopying> {
    BOOL    receivedMemoryWarning_;
}

@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) UIImage *image;
@property (nonatomic, readonly) UIImage *thumbnailImage;
@property (nonatomic, readonly) NSData *digest;
@property (nonatomic, readonly) NSString *mimetype;
@property (nonatomic, readonly) CGRect naturalBounds;

+ (WDImageData *) imageDataWithData:(NSData *)data;
- (id) initWithData:(NSData *)data;

- (WDImageDataFormat) imageFormat;

@end
