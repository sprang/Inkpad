//
//  MPOAuthURLResponse.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.05.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MPOAuthURLResponse : NSObject {
	NSURLResponse	*_urlResponse;
	NSDictionary	*_oauthParameters;
}

@property (nonatomic, readonly, retain) NSURLResponse *urlResponse;
@property (nonatomic, readonly, retain) NSDictionary *oauthParameters;

@end
