//
//  DBMetadata.h
//  DropboxSDK
//
//  Created by Brian Smith on 5/3/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//


@interface DBMetadata : NSObject <NSCoding> {
    BOOL thumbnailExists;
    long long totalBytes;
    NSDate* lastModifiedDate;
    NSDate *clientMtime; // file's mtime for display purposes only
    NSString* path;
    BOOL isDirectory;
    NSArray* contents;
    NSString* hash;
    NSString* humanReadableSize;
    NSString* root;
    NSString* icon;
    NSString* rev;
    long long revision; // Deprecated; will be removed in version 2. Use rev whenever possible
    BOOL isDeleted;

    NSString *filename;
}

- (id)initWithDictionary:(NSDictionary*)dict;

@property (nonatomic, readonly) BOOL thumbnailExists;
@property (nonatomic, readonly) long long totalBytes;
@property (nonatomic, readonly) NSDate* lastModifiedDate;
@property (nonatomic, readonly) NSDate* clientMtime;
@property (nonatomic, readonly) NSString* path;
@property (nonatomic, readonly) BOOL isDirectory;
@property (nonatomic, readonly) NSArray* contents;
@property (nonatomic, readonly) NSString* hash;
@property (nonatomic, readonly) NSString* humanReadableSize;
@property (nonatomic, readonly) NSString* root;
@property (nonatomic, readonly) NSString* icon;
@property (nonatomic, readonly) long long revision; // Deprecated, use rev instead
@property (nonatomic, readonly) NSString* rev;
@property (nonatomic, readonly) BOOL isDeleted;
@property (nonatomic, readonly) NSString* filename;

@end
