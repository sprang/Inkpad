//
//  DBDeltaEntry.h
//  DropboxSDK
//
//  Created by Brian Smith on 3/25/12.
//  Copyright (c) 2012 Dropbox. All rights reserved.
//

#import "DBMetadata.h"

@interface DBDeltaEntry : NSObject <NSCoding> {
    NSString *lowercasePath;
    DBMetadata *metadata;
}

- (id)initWithArray:(NSArray *)array;

@property (nonatomic, readonly) NSString *lowercasePath;
@property (nonatomic, readonly) DBMetadata *metadata; // nil if file has been deleted

@end
