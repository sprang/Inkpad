//
//  NSURL+MPURLParameterAdditions.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.08.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSURL (MPURLParameterAdditions)

- (NSURL *)urlByAddingParameters:(NSArray *)inParameters;
- (NSURL *)urlByAddingParameterDictionary:(NSDictionary *)inParameters;
- (NSURL *)urlByRemovingQuery;
- (NSString *)absoluteNormalizedString;

- (BOOL)domainMatches:(NSString *)inString;

@end
