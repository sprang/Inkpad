//
//  DBSession+iOS.h
//  DropboxSDK
//
//  Created by Brian Smith on 3/7/12.
//  Copyright (c) 2012 Dropbox. All rights reserved.
//

#import "DBSession.h"

@interface DBSession (iOS)

+ (NSDictionary*)parseURLParams:(NSString *)query;

- (NSString *)appScheme;

- (void)linkFromController:(UIViewController *)rootController;
- (void)linkUserId:(NSString *)userId fromController:(UIViewController *)rootController;

- (BOOL)handleOpenURL:(NSURL *)url;

@end
