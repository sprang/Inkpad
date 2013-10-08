//
//  NSDictionary+Dropbox.h
//  Dropbox
//
//  Created by Brian Smith on 6/5/11.
//  Copyright 2011 Dropbox, Inc. All rights reserved.
//


@interface NSDictionary (Dropbox)

+ (NSDictionary *)dictionaryWithQueryString:(NSString *)query;
- (NSString *)urlRepresentation;

@end
