//
//  MPOAuthSignatureParameter.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.07.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPURLRequestParameter.h"

#define kMPOAuthSignatureMethodPlaintext	@"PLAINTEXT"
#define kMPOAuthSignatureMethodHMACSHA1		@"HMAC-SHA1"
#define kMPOAuthSignatureMethodRSASHA1		@"RSA-SHA1"

@class MPOAuthURLRequest;

@interface MPOAuthSignatureParameter : MPURLRequestParameter {

}

+ (NSString *)signatureBaseStringUsingParameterString:(NSString *)inParameterString forRequest:(MPOAuthURLRequest *)inRequest;
+ (NSString *)HMAC_SHA1SignatureForText:(NSString *)inText usingSecret:(NSString *)inSecret;

- (id)initWithText:(NSString *)inText andSecret:(NSString *)inSecret forRequest:(MPOAuthURLRequest *)inRequest usingMethod:(NSString *)inMethod;


@end
