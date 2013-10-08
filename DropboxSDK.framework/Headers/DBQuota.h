//
//  DBQuota.h
//  DropboxSDK
//
//  Created by Brian Smith on 5/3/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//


@interface DBQuota : NSObject <NSCoding> {
    long long normalConsumedBytes;
    long long sharedConsumedBytes;
    long long totalBytes;
}

- (id)initWithDictionary:(NSDictionary*)dict;

@property (nonatomic, readonly) long long normalConsumedBytes;
@property (nonatomic, readonly) long long sharedConsumedBytes;
@property (nonatomic, readonly) long long totalConsumedBytes;
@property (nonatomic, readonly) long long totalBytes;

@end
