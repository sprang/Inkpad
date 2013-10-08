//
//  WDSVGElement.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Original implementation by Scott Vachalek
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@protocol WDErrorReporter;

@interface WDSVGElement : NSObject {
    NSString        *name_;
    NSDictionary    *attributes_;
    NSMutableArray  *children_;
    NSMutableString *text_;
}

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSDictionary *attributes;
@property (weak, nonatomic, readonly) NSMutableArray *children;
@property (weak, nonatomic, readonly) NSMutableString *text;

- (WDSVGElement *) initWithName:(NSString *)name andAttributes:(NSDictionary *)attributes;

- (NSString *) attribute:(NSString *)name withDefault:(NSString *)deft;
- (NSString *) attribute:(NSString *)name;
- (float) coordinate:(NSString *)key withBound:(float)bound andDefault:(float)deft;
- (float) coordinate:(NSString *)source withBound:(float)bound;
+ (float) lengthFromString:(NSString *)source withBound:(float)bound andDefault:(float)deft;
- (float) length:(NSString *)key withBound:(float)bound andDefault:(float)deft;
- (float) length:(NSString *)key withBound:(float)bound;
+ (NSArray *) numberListFromString:(NSString *)source;
- (NSArray *) numberList:(NSString *)key;
- (NSArray *) coordinateList:(NSString *)key;
+ (NSArray *) lengthListFromString:(NSString *)key withBound:(float)bound;
- (NSArray *) lengthList:(NSString *)key withBound:(float)bound;
- (CGPoint) x:(NSString *)xKey y:(NSString *)yKey withBounds:(CGSize)bounds andDefault:(CGPoint)deft;
- (CGPoint) x:(NSString *)xKey y:(NSString *)yKey withBounds:(CGSize)bounds;
- (NSString *) idFromIRI:(NSString *)key withReporter:(id<WDErrorReporter>)reporter;
- (NSString *) idFromFuncIRI:(NSString *)key withReporter:(id<WDErrorReporter>)reporter;

@end
