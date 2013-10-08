//
//  NSString+URLEscapingAdditions.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.07.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString (MPURLEscapingAdditions)

- (BOOL)isIPAddress;
- (NSString *)stringByAddingURIPercentEscapesUsingEncoding:(NSStringEncoding)inEncoding;

@end

@interface NSURL (MPURLEscapingAdditions)
- (NSString *)stringByAddingURIPercentEscapesUsingEncoding:(NSStringEncoding)inEncoding;
@end
