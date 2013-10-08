//
//  WDSVGParserStateStack.h
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
#import "WDSVGParserState.h"

@protocol WDErrorReporter

- (void) reportError:(NSString *)message, ...;
- (int) errorCount;
- (void) reportMemoryWarning;
- (BOOL) memoryWarning;

@end

@interface WDSVGParserStateStack : NSObject <WDErrorReporter> {
    int                 errorCount_;
    BOOL                memoryWarning_;
    NSMutableArray      *stack_;
}

@property (weak, nonatomic, readonly) NSMutableArray *group;
@property (weak, nonatomic, readonly) WDSVGElement *svgElement;
@property (nonatomic, assign) CGAffineTransform transform;
@property (nonatomic, assign) CGAffineTransform viewBoxTransform;
@property (nonatomic, assign) CGRect viewport;
@property (nonatomic, strong) WDElement *wdElement;

- (void) startElement:(WDSVGElement *)element;
- (WDElement *) endElement;
- (WDSVGParserState *) stateAtDepth:(int)depth;

- (float) viewWidth;
- (float) viewHeight;
- (float) viewRadius;

- (NSString *) style:(NSString *)name;
- (NSString *) attribute:(NSString *)name;
- (NSString *) attribute:(NSString *)name withDefault:(NSString *)deft;
- (float) coordinate:(NSString *)key withBound:(float)bound andDefault:(float)deft;
- (float) coordinate:(NSString *)key withBound:(float)bound;
- (float) lengthFromString:(NSString *)source withBound:(float)bound andDefault:(float)deft;
- (float) length:(NSString *)key withBound:(float)bound andDefault:(float)deft;
- (float) length:(NSString *)key withBound:(float)bound;
- (NSArray *) numberList:(NSString *)key;
- (NSArray *) coordinateList:(NSString *)key;
- (NSArray *) lengthList:(NSString *)key withBound:(float)bound;
- (CGPoint) x:(NSString *)xKey y:(NSString *)yKey withDefault:(CGPoint)deft;
- (CGPoint) x:(NSString *)xKey y:(NSString *)yKey;

- (CGSize) width:(NSString *)widthKey height:(NSString *)heightKey;
- (CGRect) x:(NSString *)xKey y:(NSString *)yKey width:(NSString *)widthKey height:(NSString *)heightKey withDefault:(CGRect)deft;
- (CGRect) x:(NSString *)xKey y:(NSString *)yKey width:(NSString *)widthKey height:(NSString *)heightKey;
- (NSString *) idFromIRI:(NSString *)key;
- (NSString *) idFromFuncIRI:(NSString *)key;

@end
