//
//  MPURLParameter.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.05.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MPURLRequestParameter : NSObject {
	NSString *_name;
	NSString *_value;
}

@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readwrite, copy) NSString *value;

+ (NSArray *)parametersFromString:(NSString *)inString;
+ (NSArray *)parametersFromDictionary:(NSDictionary *)inDictionary;
+ (NSDictionary *)parameterDictionaryFromString:(NSString *)inString;
+ (NSString *)parameterStringForParameters:(NSArray *)inParameters;
+ (NSString *)parameterStringForDictionary:(NSDictionary *)inParameterDictionary;

- (id)initWithName:(NSString *)inName andValue:(NSString *)inValue;

- (NSString *)URLEncodedParameterString;

@end
