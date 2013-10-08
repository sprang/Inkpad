//
//  WDImageData.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "UIImage+Additions.h"
#import "WDImageData.h"
#import "WDUtilities.h"

NSString *WDDataKey = @"WDDataKey";

#define kThumbnailDimension 128

@implementation WDImageData

@synthesize data = imageData_;
@synthesize naturalBounds = naturalBounds_;
@synthesize image = image_;
@synthesize thumbnailImage = thumbnailImage_;

+ (WDImageData *) imageDataWithData:(NSData *)data
{
    return [[WDImageData alloc] initWithData:data];
}

- (id) initWithData:(NSData *)data
{
    self = [super init];
 
    if (!self) {
        return nil;
    }
    
    imageData_ = data;
    
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedMemoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:[UIApplication sharedApplication]];
#endif
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:imageData_ forKey:WDDataKey];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    imageData_ = [coder decodeObjectForKey:WDDataKey];
    
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedMemoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:[UIApplication sharedApplication]];
#endif
    
    return self; 
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) receivedMemoryWarning:(NSNotification *)aNotification
{
    if (receivedMemoryWarning_) {
        // we've already received the warning and discarded the large cache
        return;
    }
    
    receivedMemoryWarning_ = YES;
    image_ = nil;
}

- (NSString *) mimetype
{
    if (self.imageFormat == WDImageDataJPEGFormat) {
        return @"image/jpeg";
    } else {
        return @"image/png";
    }
}

- (WDImageDataFormat) imageFormat
{
    UInt8 buffer[4];
    [imageData_ getBytes:buffer length:4];
    
    if (buffer[0] == 0xFF && buffer[1] == 0xD8 && buffer[2] == 0xFF && buffer[3] == 0xE0) {
        return WDImageDataJPEGFormat;
    }
    
    return WDImageDataPNGFormat;
}

- (UIImage *) inflatedImage
{
    UIImage *compressed = [[UIImage alloc] initWithData:imageData_];
    
    size_t width = compressed.size.width;
    size_t height = compressed.size.height;
    
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    size_t          bitmapBytesPerRow = (width * 4);
    
    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (NULL, width, height, 8, bitmapBytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), compressed.CGImage);
    CGImageRef result = CGBitmapContextCreateImage(context);
    CFRelease(context);
    
    UIImage *inflated = [UIImage imageWithCGImage:result];
    CGImageRelease(result);
    
    return inflated;
}

- (UIImage *) image
{
    if (!image_) {
        if (!receivedMemoryWarning_) {
            // keep the uncompressed image in memory... this increases rendering speed but uses a lot more memory
            // if we ever get a memory warning we'll switch to the compressed image
            image_ = [self inflatedImage];
        } else {
            // use the compressed image
            image_ = [[UIImage alloc] initWithData:imageData_];
        }
        
        naturalBounds_ = CGRectMake(0, 0, image_.size.width, image_.size.height);
        
        // use this image when rendering thumbnails
        if (!thumbnailImage_) {
            // only need to build this once
            thumbnailImage_ = [image_ downsampleWithMaxDimension:kThumbnailDimension];
        }
    }
    
    return image_;
}

- (UIImage *) thumbnailImage
{
    if (!thumbnailImage_) {
        [self image];
    }
    
    return thumbnailImage_;
}

- (NSData *) digest
{
    return WDSHA1DigestForData(imageData_);
}

- (id) copyWithZone:(NSZone *)zone
{
    return self;
}

@end
