//
//  NSString+Dropbox.h
//  DropboxSDK
//
//  Created by Brian Smith on 7/19/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//


@interface NSString (Dropbox)

// This will take a path for a resource and normalize so you can compare paths
- (NSString*)normalizedDropboxPath;

// Normalizes both paths and compares them
- (BOOL)isEqualToDropboxPath:(NSString*)otherPath;

@end
