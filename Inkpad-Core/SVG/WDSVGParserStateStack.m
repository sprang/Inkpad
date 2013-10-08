//
//  WDSVGParserStateStack.m
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

#import "WDSVGParserStateStack.h"
#import "WDSVGTransformParser.h"


@implementation WDSVGParserStateStack

- (id) init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    stack_ = [[NSMutableArray alloc] init];
    WDSVGParserState *defaultState = [[WDSVGParserState alloc] init];
    // default viewbox: translate from SVG's pixels to Inkpad's points
    defaultState.viewBoxTransform = CGAffineTransformIdentity;
    defaultState.transform = defaultState.viewBoxTransform;
    defaultState.viewport = CGRectMake(0, 0, 1000.f, 1000.f);
    [stack_ addObject:defaultState];
    
    return self;
}

- (WDSVGParserState *) state;
{
    return [stack_ lastObject];
}

- (void) startElement:(WDSVGElement *)element
{
    WDSVGParserState *oldState = self.state;
    WDSVGParserState *newState = [[WDSVGParserState alloc] initWithElement:element];
    [stack_ addObject:newState];

    NSString *transformAttribute = [newState.svgElement attribute:@"transform"];
    if (transformAttribute) {
        newState.transform = CGAffineTransformConcat([WDSVGTransformParser parse:transformAttribute withReporter:self], oldState.transform);
    } else {
        newState.transform = oldState.transform;
    }
    newState.viewBoxTransform = oldState.viewBoxTransform;
    newState.viewport = oldState.viewport;
}

- (WDElement *) endElement
{
    WDSVGParserState *oldState = self.state;
    [stack_ removeLastObject];
    
    // move any remaining group objects down a level
    [[self state].group addObjectsFromArray:oldState.group];

    WDElement *element = oldState.wdElement;
    return element;
}

- (WDSVGParserState *) stateAtDepth:(int)depth
{
    return ([stack_ count] > depth) ? stack_[depth] : nil;
}

- (NSString *) style:(NSString *)name
{
    for (WDSVGParserState *state in [stack_ reverseObjectEnumerator]) {
        NSString *value = [state.svgElement attribute:name];
        if (value) {
            return value;
        }
    }
    return nil;
}

- (CGAffineTransform) transform
{
    return self.state.transform;
}

- (void) setTransform:(CGAffineTransform)transform
{
    self.state.transform = transform;
}

- (CGAffineTransform) viewBoxTransform
{
    return self.state.viewBoxTransform;
}

- (void) setViewBoxTransform:(CGAffineTransform)viewBoxTransform
{
    self.state.viewBoxTransform = viewBoxTransform;
}

- (CGRect) viewport
{
    return self.state.viewport;
}

- (void) setViewport:(CGRect)viewport
{
    self.state.viewport = viewport;
}

- (NSMutableArray *) group
{
    return self.state.group;
}

- (WDSVGElement *) svgElement
{
    return self.state.svgElement;
}

- (WDElement *) wdElement
{
    return self.state.wdElement;
}

- (void) setWdElement:(WDElement *)wdElement
{
    self.state.wdElement = wdElement;
}

- (NSString *) attribute:(NSString *)name
{
    return [self.state.svgElement attribute:name withDefault:nil];
}

- (NSString *) attribute:(NSString *)name withDefault:(NSString *)deft
{
    return [self.state.svgElement attribute:name withDefault:deft];
}

- (float) coordinate:(NSString *)key withBound:(float)bound andDefault:(float)deft
{
    return [self.state.svgElement coordinate:key withBound:bound andDefault:deft];
}

- (float) coordinate:(NSString *)key withBound:(float)bound
{
    return [self.state.svgElement coordinate:key withBound:bound andDefault:0];
}

- (float) lengthFromString:(NSString *)source withBound:(float)bound andDefault:(float)deft
{
    return [WDSVGElement lengthFromString:source withBound:bound andDefault:deft];
}

- (float) length:(NSString *)key withBound:(float)bound andDefault:(float)deft
{
    return [self.state.svgElement length:key withBound:bound andDefault:deft];
}

- (float) length:(NSString *)key withBound:(float)bound
{
    return [self.state.svgElement length:key withBound:bound andDefault:0];
}

- (NSArray *) numberList:(NSString *)key 
{
    return [self.state.svgElement numberList:key];
}

- (NSArray *) coordinateList:(NSString *)key
{
    return [self.state.svgElement coordinateList:key];
}

- (NSArray *) lengthList:(NSString *)key withBound:(float)bound
{
    return [self.state.svgElement lengthList:key withBound:bound];
}

- (CGPoint) x:(NSString *)xKey y:(NSString *)yKey withDefault:(CGPoint)deft
{
    return [self.state.svgElement x:xKey y:yKey withBounds:self.viewport.size andDefault:deft];
}

- (CGPoint) x:(NSString *)xKey y:(NSString *)yKey
{
    return [self.state.svgElement x:xKey y:yKey withBounds:self.viewport.size andDefault:CGPointZero];
}

- (CGSize) width:(NSString *)widthKey height:(NSString *)heightKey
{
    float width = [self length:widthKey withBound:self.viewport.size.width];
    float height = [self length:heightKey withBound:self.viewport.size.height];
    return CGSizeMake(width, height);
}

- (CGRect) x:(NSString *)xKey y:(NSString *)yKey width:(NSString *)widthKey height:(NSString *)heightKey withDefault:(CGRect)deft
{
    float x = [self coordinate:xKey withBound:self.viewport.size.width andDefault:deft.origin.x];
    float y = [self coordinate:yKey withBound:self.viewport.size.height andDefault:deft.origin.y];
    float width = [self length:widthKey withBound:self.viewport.size.width andDefault:deft.size.width];
    float height = [self length:heightKey withBound:self.viewport.size.height andDefault:deft.size.height];
    return CGRectMake(x, y, width, height);
}

- (CGRect) x:(NSString *)xKey y:(NSString *)yKey width:(NSString *)widthKey height:(NSString *)heightKey
{
    return [self x:xKey y:yKey width:widthKey height:heightKey withDefault:CGRectZero];
}

- (NSString *)idFromIRI:(NSString *)key
{
    return [self.state.svgElement idFromIRI:key withReporter:self];
}

- (NSString *)idFromFuncIRI:(NSString *)key
{
    return [self.state.svgElement idFromFuncIRI:key withReporter:self];
}

- (float) viewWidth
{
    return self.state.viewport.size.width;
}

- (float) viewHeight
{
    return self.state.viewport.size.height;
}

- (float) viewRadius
{
    float w = [self viewWidth];
    float h = [self viewHeight];
    return sqrtf(w * w + h * h) / sqrtf(2.f);
}

- (void) reportError:(NSString *)message, ...
{
    ++errorCount_;
    va_list argp;
    va_start(argp, message);
    
    NSString *fullMessage = [[NSString alloc] initWithFormat:message arguments:argp];
    NSLog(@"ERROR: %@", fullMessage);
    va_end(argp);
}

- (int) errorCount
{
    return errorCount_;
}

- (void) reportMemoryWarning
{
    memoryWarning_ = YES;
}

- (BOOL) memoryWarning
{
    return memoryWarning_;
}

- (NSString *) description
{
    NSMutableString *tree = [[NSMutableString alloc] init];
    for (int i = 1; i < [stack_ count]; ++i) {
        [tree appendString:@"\n"];
        for (int j = 1; j < i; ++j) {
            [tree appendString:@"  "];
        }
        [tree appendString:[stack_[i] description]];
    }
    NSString *description = [NSString stringWithFormat:@"%@", tree];
    return description;
}

@end
