//
//  DBAccountInfo.h
//  DropboxSDK
//
//  Created by Brian Smith on 5/3/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//


#import "DBQuota.h"

@interface DBAccountInfo : NSObject <NSCoding> {
    NSString* country;
    NSString* displayName;
    DBQuota* quota;
    NSString* userId;
    NSString* referralLink;
    NSDictionary* original;
}

- (id)initWithDictionary:(NSDictionary*)dict;

@property (nonatomic, readonly) NSString* country;
@property (nonatomic, readonly) NSString* displayName;
@property (nonatomic, readonly) DBQuota* quota;
@property (nonatomic, readonly) NSString* userId;
@property (nonatomic, readonly) NSString* referralLink;

@end
