//
//  WDSVGParser.m
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

#import "NSString+Additions.h"
#import "WDColor.h"
#import "WDCompoundPath.h"
#import "WDFillTransform.h"
#import "WDGradient.h"
#import "WDGradientStop.h"
#import "WDGroup.h"
#import "WDImage.h"
#import "WDLayer.h"
#import "WDSVGParser.h"
#import "WDSVGPathParser.h"
#import "WDText.h"
#import "WDTextPath.h"
#import "WDUtilities.h"


@implementation WDSVGParser

- (id) initWithDrawing:(WDDrawing *)drawing
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    defs_ = [[NSMutableDictionary alloc] init];
    drawing_ = drawing;
    gradientStops_ = [[NSMutableArray alloc] init];
    state_ = [[WDSVGParserStateStack alloc] init];
    styleParser_ = [[WDSVGStyleParser alloc] initWithStack:state_];
    svgElements_ = [[NSMutableArray alloc] init];

#if TARGET_OS_IPHONE
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedMemoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:[UIApplication sharedApplication]];
#endif
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) receivedMemoryWarning:(NSNotification *)aNotification
{
    [state_ reportMemoryWarning];
    [state_ reportError:@"Low memory warning: %@", aNotification];
}

- (BOOL) hadErrors
{
    return [state_ errorCount] > 0;
}

- (BOOL) hadMemoryWarning
{
    return [state_ memoryWarning];
}

#pragma mark -
#pragma mark SVG element walk/copy

- (WDElement *) visitElement:(WDSVGElement *)element
{
    if ([self hadMemoryWarning]) {
        return nil;
    }

    [self startElement:element];
    for (WDSVGElement *child in element.children) {
        [self visitElement:child];
    }
    return [self endElement];
}

- (WDElement *) svgCopy:(NSString *)xmlid {
    WDSVGElement *element = defs_[xmlid];
    if (!element) {
        [state_ reportError:@"Could not find referenced element: #%@", xmlid];
        return nil;
    } else {
        WDElement *copy = [self visitElement:element];
        [state_.group removeObject:copy];
        return copy;
    }
}

- (WDSVGElement *) inheritXlinks:(WDSVGElement *)element
{
    NSString *iri = [element idFromIRI:@"xlink:href" withReporter:state_];
    if (!iri) {
        return element;
    } else if ([iri isEqualToString:[element attribute:@"id"]]) {
        [state_ reportError:@"Circular xlink:href in id=%@", iri];
        return element;
    } else {
        WDSVGElement *prototype = defs_[iri];
        if (!prototype) {
            [state_ reportError:@"Missing xlink:href=%@", [state_ attribute:@"xlink:href"]];
            return element;
        } else {
            prototype = [self inheritXlinks:prototype];
            NSMutableDictionary *combinedAttributes = [[NSMutableDictionary alloc] initWithDictionary:prototype.attributes];
            [combinedAttributes addEntriesFromDictionary:element.attributes];
            [combinedAttributes removeObjectForKey:@"id"];
            [combinedAttributes removeObjectForKey:@"xlink:href"];
            WDSVGElement *inherited = [[WDSVGElement alloc] initWithName:element.name andAttributes:combinedAttributes];
            [inherited.children addObjectsFromArray:element.children];
            [inherited.text appendString:element.text];
            return inherited;
        }
    }
}

#pragma mark -
#pragma mark Viewboxes

- (CGAffineTransform) preserveAspectRatio:(NSString *)source withSize:(CGSize)size andBounds:(CGRect)bounds;
{
    NSArray *preserveAspectRatio = [[source lowercaseString] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL slice = [preserveAspectRatio containsObject:@"slice"];
    BOOL notUniformScale = [preserveAspectRatio containsObject:@"none"];
    enum {MIN, MID, MAX} xalign = MID, yalign = MID;
    for (NSString *token in preserveAspectRatio) {
        if ([token hasPrefix:@"xmin"]) {
            xalign = MIN;
        }
        if ([token hasPrefix:@"xmax"]) {
            xalign = MAX;
        }
        if ([token hasSuffix:@"ymin"]) {
            yalign = MIN;
        }
        if ([token hasSuffix:@"ymax"]) {
            yalign = MAX;
        }
    }
    CGPoint translate = CGPointZero;
    CGSize scale = CGSizeMake(bounds.size.width / size.width, bounds.size.height / size.height);
    if (notUniformScale) {} else
    if (((scale.width > scale.height) && slice) || ((scale.width < scale.height) && !slice)) {
        switch (xalign) {
            case MIN:
                translate.y = 0;
                break;
            case MID:
                translate.y = (scale.height - scale.width) * size.height / 2.f;
                break;
            case MAX:
                translate.y = (scale.height - scale.width) * size.height;
                break;
        }
        scale.height = scale.width;
    } else {
        switch (yalign) {
            case MIN:
                translate.x = 0;
                break;
            case MID:
                translate.x = (scale.width - scale.height) * size.width / 2.f;
                break;
            case MAX:
                translate.x = (scale.width - scale.height) * size.width;
                break;
        }
        scale.width = scale.height;
    }
    return CGAffineTransformScale(CGAffineTransformMakeTranslation(bounds.origin.x + translate.x, bounds.origin.y + translate.y), scale.width, scale.height);
}

- (void) checkViewBox
{
    NSString *viewBox = [state_ attribute:@"viewBox"];
    if (viewBox) {
        NSScanner *scanner = [NSScanner scannerWithString:viewBox];
        NSMutableCharacterSet *skip = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
        [skip addCharactersInString:@","];
        [scanner setCharactersToBeSkipped:skip];
        float x, y, w, h;
        if([scanner scanFloat:&x] && [scanner scanFloat:&y] && [scanner scanFloat:&w] && [scanner scanFloat:&h]) {
            NSString *preserve = [state_ attribute:@"preserveAspectRatio"];
            state_.viewBoxTransform = [self preserveAspectRatio:preserve withSize:CGSizeMake(w, h) andBounds:state_.viewport];
            state_.viewport = CGRectMake(x, y, w, h);
            state_.transform = CGAffineTransformConcat(state_.viewBoxTransform, state_.transform);
        }
    } 
}

#pragma mark -
#pragma mark Clipping

- (WDElement *) combineClippingPaths:(WDElement *)element
{
    if (![element isKindOfClass:[WDGroup class]]) {
        return element;
    }
    WDGroup *group = (WDGroup *) element;
    NSArray *elements = group.elements;
    if ([elements count] == 0) {
        // create empty clipping path
        CGPathRef emptyPath = CGPathCreateMutable();
        WDAbstractPath *path = [WDAbstractPath pathWithCGPathRef:emptyPath];
        CGPathRelease(emptyPath);
        return path;
    } else if ([elements count] == 1) {
        id element = [elements lastObject];
        if ([element isKindOfClass:[WDStylable class]]) {
            ((WDElement *) element).group = nil;
            return element;
        } else {
            [state_ reportError:@"unusable element in clipping path: %@", element];
            return nil;
        }
    } else {
        NSMutableArray *paths = [[NSMutableArray alloc] init];
        for (id element in elements) {
            if ([element isKindOfClass:[WDCompoundPath class]]) {
                WDCompoundPath *path = element;
                [paths addObjectsFromArray:path.subpaths];
            } else if ([element isKindOfClass:[WDAbstractPath class]]) {
                [paths addObject:element];
            } else {
                [state_ reportError:@"unusable element in clipping path: %@", element];
            }
        }
        for (WDElement *path in paths) {
            path.group = nil;
        }
        WDCompoundPath *compoundPath = [[WDCompoundPath alloc] init];
        [compoundPath setSubpathsQuiet:paths];
        return compoundPath;
    }
}

- (WDElement *) clip:(WDElement *)element
{
    NSString *clipPathId = [state_ idFromFuncIRI:@"clip-path"];
    if (!clipPathId || [clipPathId isEqualToString:@"none"]) {
        return element;
    } else {
        WDElement *clipCopy = [self svgCopy:clipPathId];
        WDElement *combinedClipPath = [self combineClippingPaths:clipCopy];
        if (clipCopy) {
            if (![combinedClipPath isKindOfClass:[WDStylable class]]) {
                [state_ reportError:@"clip-path not stylable: %@", clipPathId];
                return element;
            } else {
                WDStylable *stylableClipPath = (WDStylable *) combinedClipPath;
                stylableClipPath.maskedElements = [NSMutableArray arrayWithObject:element];
                [stylableClipPath setFillQuiet:nil];
                [stylableClipPath setStrokeStyleQuiet:nil];
                return stylableClipPath;
            }
        }
        [state_ reportError:@"clip-path not found: %@", clipPathId];
        return element;
    }
}

- (WDElement *) clipAndGroup:(WDElement *)element
{
    WDElement *clippedElement = [self clip:element];
#ifdef WD_DEBUG
    if ([state_.group containsObject:clippedElement]) {
        NSLog(@"Duplicate element! %@", clippedElement);
    }
#endif
    [state_.group addObject:clippedElement];
    return clippedElement;
}

- (WDElement *) styleClipAndGroup:(WDStylable *)stylable
{
    [styleParser_ style:stylable];
    return [self clipAndGroup:stylable];
}

#pragma mark -
#pragma mark Utility methods

- (WDElement *) addPath:(NSString *)source
{
    WDSVGPathParser *parser = [[WDSVGPathParser alloc] init];
    CGPathRef cgpath = [parser parse:source];
    
    if (self.hadMemoryWarning) {
        return nil;
    }
    
    CGPathRef transformedPath = WDCreateTransformedCGPathRef(cgpath, state_.transform);
    WDAbstractPath *path = [WDPath pathWithCGPathRef:transformedPath];
    CGPathRelease(transformedPath);
    return [self styleClipAndGroup:path];
}

- (void) foundString:(NSString *)string
{
    WDSVGElement *svgElement = [svgElements_ lastObject];
    if ([svgElement.text length] > 0) {
        [svgElement.text appendString:@" "];
    }
    [svgElement.text appendString:string];
}

- (WDElement *) addTextAtX:(float)x andY:(float)y rotate:(float)r alignment:(NSTextAlignment)alignment
{
    WDText *text = [[WDText alloc] init];
    text.alignment = alignment;
    // Temporarily give it some text and adequate width for correct height calculation.
    [text setTextQuiet:@"X"];
    [text setWidthQuiet:state_.viewport.size.width];
    [styleParser_ style:text];

    CGMutablePathRef path = CGPathCreateMutable();
    CGRect bounds = text.naturalBounds;
    CGPathAddRect(path, NULL, bounds);
    
    CFAttributedStringRef attrString = (__bridge CFAttributedStringRef) [text attributedString];
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attrString);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFRelease(framesetter);
    CFRelease(path);
    
    NSArray *lines = (NSArray *) CTFrameGetLines(frame);
    CGPoint origins[lines.count];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, lines.count), origins);

    CGAffineTransform translate = CGAffineTransformMakeTranslation(x, y - (bounds.size.height - origins[0].y));
    CGAffineTransform position = CGAffineTransformRotate(translate, r / 180 * M_PI);
    [text setTransformQuiet:CGAffineTransformConcat(position, state_.transform)];
    [text setTextQuiet:@""]; // clear before collecting actual text
    WDElement *clippedText = [self clipAndGroup:text];
    
    CFRelease(frame);
    
    return clippedText;
}

- (float) floatFromArray:(NSArray *)array atIndex:(int)index
{
    if (index >= [array count]) {
        return 0;
    } else {
        return [array[index] floatValue];
    }
}

- (void) createLayerFor:(NSMutableArray *)elements
{
    if ([elements count] > 0) {
        NSMutableArray *copy = [elements mutableCopy];
        WDLayer *layer = [[WDLayer alloc] initWithElements:copy];
        [elements removeAllObjects];
        layer.name = @"Untitled";
        [drawing_ addLayer:layer];
    }
}

- (NSMutableArray *) copyStopsForId:(NSString *)gradientId
{
    NSMutableArray *stopsCopy = [gradientStops_ mutableCopy];
    [gradientStops_ removeAllObjects];
    
    NSString *iri = [state_ idFromIRI:@"xlink:href"];
    if (iri) {
        // this part of xlink:xref inheritance works a little differently, and isn't covered by inheritXlinks:
        id painter = [styleParser_ painterForId:iri];
        
        if (!painter && stopsCopy.count == 0) {
            // forward reference?
            [styleParser_ registerGradient:gradientId forForwardReference:iri];
        }
        
        if ([painter isKindOfClass:[WDGradient class]]) {
            WDGradient *refGradient = painter;
            if ([stopsCopy count] == 0) {
                [stopsCopy addObjectsFromArray:refGradient.stops];
            }
        }
    }
    return stopsCopy;
}

#pragma mark -
#pragma mark SVG element handling

- (void) startCircle
{
    CGPoint c = [state_ x:@"cx" y:@"cy"];
    float r = [state_ length:@"r" withBound:[state_ viewRadius]];
    if (r > 0) {
        CGRect rect = CGRectApplyAffineTransform(CGRectMake(c.x - r, c.y - r, r * 2, r * 2), state_.transform);
        state_.wdElement = [self styleClipAndGroup:[WDPath pathWithOvalInRect:rect]];
    } else if (r < 0) {
        [state_ reportError:@"circle with negative radius"];
    }
}

- (void) startEllipse
{
    CGPoint c = [state_ x:@"cx" y:@"cy"];
    CGSize r = [state_ width:@"rx" height:@"ry"];
    if (r.width > 0 && r.height > 0) {
        CGRect rect = CGRectMake(c.x - r.width, c.y - r.height, r.width * 2, r.height * 2);
        // need to transform the ellipse rather than the bounding rectangle, since the effect of rotation is different
        state_.wdElement = [self styleClipAndGroup:[WDPath pathWithOvalInRect:rect]];
        [state_.wdElement transform:state_.transform];
    } else if (r.width < 0 || r.height < 0) {
        [state_ reportError:@"circle with negative radius"];
    }
}

- (void) startImage
{
    CGRect box = [state_ x:@"x" y:@"y" width:@"width" height:@"height"];
    NSString *iri = [state_ attribute:@"xlink:href"];
    NSString *preserve = [state_ attribute:@"preserveAspectRatio"];
    NSRange base64 = [iri rangeOfString:@"base64,"];
    UIImage *uiimage = nil;
    if (base64.location != NSNotFound) {
        NSData *data = [[NSData alloc] initWithBase64EncodedString:[iri substringFromIndex:base64.location + base64.length]
                                                           options:NSDataBase64DecodingIgnoreUnknownCharacters];
        uiimage = [[UIImage alloc] initWithData:data];
    }
    if (uiimage) {
        WDImage *wdimage = [WDImage imageWithUIImage:uiimage inDrawing:drawing_];
        wdimage.transform = CGAffineTransformConcat([self preserveAspectRatio:preserve withSize:wdimage.naturalBounds.size andBounds:box], state_.transform);
        [styleParser_ styleOpacityBlendAndShadow:wdimage];
        state_.wdElement = [self clipAndGroup:wdimage];
    } else {
        [state_ reportError:@"could not load image"];
    }
}

- (void) startRect
{
    CGRect rect = [state_ x:@"x" y:@"y" width:@"width" height:@"height"];
    float x = rect.origin.x, y = rect.origin.y, w = rect.size.width, h = rect.size.height;
    float rx = [state_ length:@"rx" withBound:[state_ viewWidth] andDefault:NAN];
    float ry = [state_ length:@"ry" withBound:[state_ viewHeight] andDefault:NAN];
    if (isnan(rx) && isnan(ry)) {
        rx = ry = 0;
    } else if (isnan(rx)) {
        rx = ry = MIN(ry, h / 2.f);
    } else if (isnan(ry)) {
        rx = ry = MIN(rx, w / 2.f);
    }
    state_.wdElement = [self addPath:[NSString stringWithFormat:@"M%f,%f H%f A%f,%f,0,0,1,%f,%f V%f A%f,%f,0,0,1,%f,%f H%f A%f,%f,0,0,1,%f,%f V%f A%f,%f,0,0,1,%f,%fz", x + rx, y, x + w - rx, rx, ry, x + w, y + ry, y + h - ry, rx, ry, x + w - rx, y + h, x + rx, rx, ry, x, y + h - ry, y + ry, rx, ry, x + ry, y]];
}

- (void) startStop
{
    float offset = [[state_ attribute:@"offset"] floatValue]; // relative to gradient range
    NSString *stopColor = [state_ style:kWDPropertyStopColor];
    NSString *stopOpacity = [state_ style:kWDPropertyStopOpacity];
    id resolvedColor = [styleParser_ resolvePainter:stopColor alpha:[stopOpacity floatValue]];
    if (resolvedColor == nil) {
        // must have been set to "none", but gradient stops need a non-nil color...
        resolvedColor = [WDColor colorWithRed:0 green:0 blue:0 alpha:0];
    }
    WDGradientStop *stop = [WDGradientStop stopWithColor:resolvedColor andRatio:offset];
    [gradientStops_ addObject:stop];
}

- (void) startSvg
{
    CGSize size = [state_ width:@"width" height:@"height"];
    if (size.width > 0 && size.height > 0) {
#if WD_DEBUG
        NSLog(@"Setting drawing width: %f height: %f", size.width, size.height);
#endif
        drawing_.width = size.width;
        drawing_.height = size.height;
        state_.viewport = CGRectMake(0, 0, size.width, size.height);
    }
    [self checkViewBox];
}

- (void) startSymbol
{
    [self checkViewBox];
}

- (void) startText
{
    NSArray *x = [state_ coordinateList:@"x"];
    NSArray *y = [state_ coordinateList:@"y"];
    NSArray *dx = [state_ lengthList:@"dx" withBound:[state_ viewWidth]];
    NSArray *dy = [state_ lengthList:@"dy" withBound:[state_ viewHeight]];
    NSArray *rotate = [state_ numberList:@"rotate"];
    NSInteger highestCount = MAX([x count], MAX([y count], MAX([dx count], MAX([dy count], [rotate count]))));
    if (highestCount <= 1) {
        float tx = [self floatFromArray:x atIndex:0] + [self floatFromArray:dx atIndex:0];
        float ty = [self floatFromArray:y atIndex:0] + [self floatFromArray:dy atIndex:0];
        float r = [self floatFromArray:rotate atIndex:0];
        NSTextAlignment alignment = NSTextAlignmentLeft;
        if ([[state_ style:kWDPropertyTextAnchor] isEqualToString:@"middle"]) {
            alignment = NSTextAlignmentCenter;
        } else if ([[state_ style:kWDPropertyTextAnchor] isEqualToString:@"end"]) {
            alignment = NSTextAlignmentRight;
        }
        state_.wdElement = [self addTextAtX:tx andY:ty rotate:r alignment:alignment];
    } else {
        // TODO this breakdown has to happen in endElement
        [state_ reportError:@"Multiple coordinates in text/tspan (currently unsupported)"];
        NSMutableArray *elements = [[NSMutableArray alloc] init];
        for (int i = 0; i < highestCount; ++i) {
            float tx = [self floatFromArray:x atIndex:0] + [self floatFromArray:dx atIndex:0];
            float ty = [self floatFromArray:y atIndex:0] + [self floatFromArray:dy atIndex:0];
            float r = [self floatFromArray:rotate atIndex:0];
            [elements addObject:[self addTextAtX:tx andY:ty rotate:r alignment:NSTextAlignmentLeft]];
        }
        WDGroup *group = [[WDGroup alloc] init];
        group.layer = drawing_.activeLayer;
        group.elements = elements;
        [state_.group removeObjectsInArray:elements];
        state_.wdElement = [self clipAndGroup:group];
    }
}

- (void) startTextPath
{
    NSString *pathId = [state_ idFromIRI:@"xlink:href"];
    if (pathId) {
        WDElement *element = [self svgCopy:pathId];
        if ([element isKindOfClass:[WDPath class]]) {
            WDPath *path = (WDPath *) element;
            path.strokeStyle = nil;
            path.fill = nil;
            WDTextPath *textPath = [WDTextPath textPathWithPath:path];
            state_.wdElement = [self styleClipAndGroup:textPath];
        } else if (element) {
            [state_ reportError:@"textPath href is not usable: %@", [state_ attribute:@"xlink:href"]];
        } else {
            [state_ reportError:@"textPath href not found: %@", [state_ attribute:@"xlink:href"]];
        }
    } else {
        [state_ reportError:@"textPath href not recognized: %@", [state_ attribute:@"xlink:href"]];
    }
}

- (void) startUse
{
    NSString *iri = [state_ idFromIRI:@"xlink:href"];
    if (iri) {
        CGRect box = [state_ x:@"x" y:@"y" width:@"width" height:@"height" withDefault:CGRectMake(0, 0, NAN, NAN)];
        if ((box.size.width < 0) || (box.size.height < 0)) {
            [state_ reportError:@"negative size for <use>: width=%f height=%f", box.size.width, box.size.height];
        } else if (isnan(box.size.width) || isnan(box.size.height)) {
            state_.transform = CGAffineTransformTranslate(state_.transform, box.origin.x, box.origin.y);
            WDElement *copy = [self svgCopy:iri];
            state_.wdElement = [self clipAndGroup:copy];
        } else if ((box.size.width != 0) && (box.size.height != 0)) {
            state_.viewport = CGRectMake(0, 0, box.size.width, box.size.height);
            state_.transform = CGAffineTransformTranslate(state_.transform, box.origin.x, box.origin.y);
            WDElement *copy = [self svgCopy:iri];
            if (copy) {
                state_.wdElement = [self clipAndGroup:copy];
            }    
        }
    }
}

- (void) startElement:(WDSVGElement *)element
{
    [state_ startElement:element];

    switch ([element.name characterAtIndex:0]) {
        case 'c':
            if ([element.name isEqualToString:@"circle"]) {
                [self startCircle];
            }
            break;
        case 'd':
            if ([element.name isEqualToString:@"defs"]) {
                // dump any transforms inherited from outside
                state_.transform = CGAffineTransformIdentity;
            }
            break;
        case 'e':
            if ([element.name isEqualToString:@"ellipse"]) {
                [self startEllipse];
            }
            break;
        case 'i':
            if ([element.name isEqualToString:@"image"]) {
                [self startImage];
            } else if ([element.name isEqualToString:@"inkpad:setting"]) {
                NSString *key = [state_ attribute:@"key"];
                NSString *value = [state_ attribute:@"value"];
                [drawing_ setSetting:key value:value];
            }
            break;
        case 'l':
            if ([element.name isEqualToString:@"line"]) {
                CGPoint p1 = CGPointApplyAffineTransform([state_ x:@"x1" y:@"y1"], state_.transform);
                CGPoint p2 = CGPointApplyAffineTransform([state_ x:@"x2" y:@"y2"], state_.transform);
                state_.wdElement = [self styleClipAndGroup:[WDPath pathWithStart:p1 end:p2]];
            }
            break;
        case 'p':
            if ([element.name isEqualToString:@"path"]) {
                @autoreleasepool {
                    state_.wdElement = [self addPath:[state_ attribute:@"d"]];
                }
            } else if ([element.name isEqualToString:@"polygon"]) {
                state_.wdElement = [self addPath:[NSString stringWithFormat:@"M%@Z", [state_ attribute:@"points"]]];
            } else if ([element.name isEqualToString:@"polyline"]) {
                state_.wdElement = [self addPath:[NSString stringWithFormat:@"M%@", [state_ attribute:@"points"]]];
            }
            break;
        case 'r':
            if ([element.name isEqualToString:@"rect"]) {
                [self startRect];
            }
            break;
        case 's':
            if ([element.name isEqualToString:@"stop"]) {
                [self startStop];
            } else if ([element.name isEqualToString:@"svg"]) {
                [self startSvg];
            } else if ([element.name isEqualToString:@"symbol"]) {
                [self startSymbol];
            }
            break;
        case 't':
            if ([element.name isEqualToString:@"text"] || [element.name isEqualToString:@"tspan"]) {
                [self startText];
            } else if ([element.name isEqualToString:@"textPath"]) {
                [self startTextPath];
            } else if ([element.name isEqualToString:@"tref"]) {
                // TODO
            }
            break;
        case 'u':
            if ([element.name isEqualToString:@"use"]) {
                [self startUse];
            }
    }
}

- (void) endClipPath
{
    NSMutableArray *elements = [state_.group mutableCopy];
    WDGroup *group = [[WDGroup alloc] init];
    group.elements = elements;
    state_.wdElement = [self clipAndGroup:group];
    // remove all objects grouped within this clipPath; they are only included via clip-path attributes
    [state_.group removeAllObjects];
}

- (void) endG
{
    NSMutableArray *elements = [state_.group mutableCopy];
    if ([elements count]) {
        [state_.group removeAllObjects];
        NSString *xmlid = [state_ attribute:@"id"];
        NSString *layerName = [state_ attribute:@"inkpad:layerName"];
        NSString *mask = [state_ idFromIRI:@"inkpad:mask"];
        if (mask) {
            NSMutableArray *maskedElements = nil;
            for (WDElement *element in elements) {
                if ([element isKindOfClass:[WDStylable class]]) {
                    maskedElements = [((WDStylable *) element).maskedElements mutableCopy];
                    while ([maskedElements count] == 1 && [[maskedElements lastObject] isKindOfClass:[WDGroup class]]) {
                        // if the list contains a single group, just unwrap it
                        maskedElements = ((WDGroup *) [maskedElements lastObject]).elements;
                    }
                    if (maskedElements) {
                        break;
                    }
                }
            }
            if (maskedElements) {
                id elementMask = [self svgCopy:mask];
                if ([elementMask isKindOfClass:[WDStylable class]]) {
                    WDStylable *stylableMask = elementMask;
                    stylableMask.maskedElements = maskedElements;
                    state_.wdElement = stylableMask;
                    [state_.group addObject:stylableMask];
                } else {
                    [state_ reportError:@"inkpad:mask property set on invalid element: %@", mask];
                }
            } else {
                [state_ reportError:@"Masked elements not found in mask group: %@", mask];
            }
        } else if ((layerName || xmlid) && (state_.group == [state_ stateAtDepth:3].group)) {
            // only the <svg> group and implicit top-level group are below this one
            WDLayer *layer = [[WDLayer alloc] initWithElements:elements];
            layer.name = layerName ?: xmlid;
            if ([state_ style:kWDPropertyOpacity]) {
                layer.opacity = [[state_ style:kWDPropertyOpacity] floatValue];
            }
            if ([[state_ style:kWDPropertyVisibility] isEqualToString:@"hidden"] || [[state_ style:kWDPropertyDisplay] isEqualToString:@"none"]) {
                layer.hidden = YES;
            }
            [self createLayerFor:[state_ stateAtDepth:2].group];
            [drawing_ addLayer:layer];
        } else if ([elements count] == 1) {
            state_.wdElement = [self clipAndGroup:[elements lastObject]];
            if ([state_ style:kWDPropertyOpacity]) {
                state_.wdElement.opacity *= [[state_ style:kWDPropertyOpacity] floatValue];
            }
        } else {
            WDGroup *group = [[WDGroup alloc] init];
            group.layer = drawing_.activeLayer;
            group.elements = elements;
            [styleParser_ styleOpacityBlendAndShadow:group];
            state_.wdElement = [self clipAndGroup:group];
        }
    }
}

- (void) endLinearGradient
{
    WDSVGElement *resolved = [self inheritXlinks:state_.svgElement];
    NSString *gradientId = [state_ attribute:@"id"];
    CGAffineTransform gradientTransform = [WDSVGTransformParser parse:[resolved attribute:@"gradientTransform"] withReporter:state_];
    CGPoint p1 = [resolved x:@"x1" y:@"y1" withBounds:state_.viewport.size];
    CGPoint p2 = [resolved x:@"x2" y:@"y2" withBounds:state_.viewport.size andDefault:CGPointMake([state_ viewWidth], 0)];
    WDFillTransform *transform = [[WDFillTransform alloc] initWithTransform:gradientTransform start:p1 end:p2];
    NSMutableArray *stopsCopy = [self copyStopsForId:gradientId];
    WDGradient *gradient = [WDGradient gradientWithType:kWDLinearGradient stops:stopsCopy];
    [styleParser_ setPainter:gradient withTransform:transform forId:gradientId];
}

- (void) endRadialGradient
{
    WDSVGElement *resolved = [self inheritXlinks:state_.svgElement];
    NSString *gradientId = [state_ attribute:@"id"];
    CGAffineTransform gradientTransform = [WDSVGTransformParser parse:[resolved attribute:@"gradientTransform"] withReporter:state_];
    CGPoint c = [resolved x:@"cx" y:@"cy" withBounds:state_.viewport.size andDefault:CGPointMake([state_ viewWidth] / 2.f, [state_ viewHeight] / 2.f)];
    CGPoint f = [resolved x:@"fx" y:@"fy" withBounds:state_.viewport.size andDefault:c];
    float r = [resolved length:@"r" withBound:[state_ viewRadius] andDefault:([state_ viewRadius] / 2.f)];
    if (r >= 0) {
        WDFillTransform *transform = [[WDFillTransform alloc] initWithTransform:gradientTransform start:f end:CGPointMake(c.x + r, c.y)];
        NSMutableArray *stopsCopy = [self copyStopsForId:gradientId];
        WDGradient *gradient = [WDGradient gradientWithType:kWDRadialGradient stops:stopsCopy];
        [styleParser_ setPainter:gradient withTransform:transform forId:gradientId];
    } else {
        [state_ reportError:@"negative radius in radial gradient"];
    }
}

- (void) endSymbol
{
    NSMutableArray *elements = [state_.group mutableCopy];
    [state_.group removeAllObjects];
    if ([elements count] == 1) {
        state_.wdElement = [self clip:[elements lastObject]];
    } else if ([elements count] > 1) {
        WDGroup *group = [[WDGroup alloc] init];
        group.layer = drawing_.activeLayer;
        group.elements = elements;
        state_.wdElement = [self clip:group];
    }
}

- (void) endText
{
    NSString *svgtext = state_.svgElement.text;
    NSString *inkpadText = [state_ attribute:@"inkpad:text"];
    if (inkpadText && [state_.wdElement isKindOfClass:[WDText class]]) {
        WDText *text = (WDText *) state_.wdElement;
        [text setTextQuiet:inkpadText];
        CGPoint coords = [state_ x:@"x" y:@"y"];
        [text setTransformQuiet:CGAffineTransformConcat(CGAffineTransformMakeTranslation(coords.x, coords.y), state_.transform)];
        float textLength = [state_ length:@"inkpad:width" withBound:[state_ viewWidth] andDefault:drawing_.width];
        [text setWidth:textLength];
        [state_.group removeAllObjects]; // no need for elements created by <tspan> children
        [state_.group addObject:text];
    } else if ([svgtext length] == 0) {
        [state_.group removeObject:state_.wdElement];
        state_.wdElement = nil;
    } else if ([state_.wdElement isKindOfClass:[WDText class]]) {
        WDText *text = (WDText *) state_.wdElement;
        [text setTextQuiet:svgtext];
        float textLength = [state_ length:@"textLength" withBound:[state_ viewWidth] andDefault:NAN];
        if (isnan(textLength)) {
            CGSize naturalSize = [text.text sizeWithCTFont:text.fontRef constrainedToSize:CGSizeMake(MAXFLOAT, MAXFLOAT)];
            textLength = naturalSize.width;
        }
        [text setWidthQuiet:textLength];
        switch (text.alignment) {
            case NSTextAlignmentLeft:
                // leave it where it is
                break;
            case NSTextAlignmentRight:
                text.transform = CGAffineTransformTranslate(text.transform, -textLength, 0);
                break;
            case NSTextAlignmentCenter:
                text.transform = CGAffineTransformTranslate(text.transform, -textLength / 2.f, 0);
                break;
            default:
                break;
        }
    } else if ([state_.wdElement isKindOfClass:[WDGroup class]]) {
        WDGroup *group = (WDGroup *) state_.wdElement;
        int count = (int) [group.elements count];
        for (int i = 0; (i < count - 1) && (i < [svgtext length]); ++i) {
            WDText *text = (group.elements)[i];
            [text setTextQuiet:[svgtext substringWithRange:NSMakeRange(i, 1)]];
        }
        if (count - 1 < [svgtext length]) {
            WDText *text = [group.elements lastObject];
            [text setTextQuiet:[svgtext substringFromIndex:(count - 1)]];
        }
    }
}

- (WDElement *) endElement
{
    WDSVGElement *element = state_.svgElement;

    switch ([element.name characterAtIndex:0]) {
        case 'c':
            if ([element.name isEqualToString:@"clipPath"]) {
                [self endClipPath];
            }
            break;
        case 'd':
            if ([element.name isEqualToString:@"defs"]) {
                // remove all objects grouped within <defs>; they are only included via <use> elements
                [state_.group removeAllObjects];
            }
            break;
        case 'g':
            if ([element.name isEqualToString:@"g"]) {
                [self endG];
            }
            break;
        case 'l':
            if ([element.name isEqualToString:@"linearGradient"]) {
                [self endLinearGradient];
            }
            break;
        case 'r':
            if ([element.name isEqualToString:@"radialGradient"]) {
                [self endRadialGradient];
            }
            break;
        case 's':
            if ([element.name isEqualToString:@"symbol"]) {
                [self endSymbol];
            }
            break;
        case 't':
            if ([element.name isEqualToString:@"text"] || [element.name isEqualToString:@"tspan"]) {
                [self endText];
            } else if ([element.name isEqualToString:@"textPath"]) {
                WDTextPath *textPath = (WDTextPath *) state_.wdElement;
                textPath.text = state_.svgElement.text;
            } else if ([element.name isEqualToString:@"tref"]) {
                // TODO
            }
    }

    return [state_ endElement];
}

#pragma mark -
#pragma mark NSXMLParserDelegate methods

- (void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    NSString *trimmedString = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self foundString:trimmedString];
}

- (void) parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
    NSString *string = [[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding];
    [self foundString:string];
}

- (void) parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
    namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
    attributes:(NSDictionary *)attributeDict
{
    if ([self hadMemoryWarning]) {
        [parser abortParsing];
        return;
    }

    NSDictionary *styles = [styleParser_ parseStyles:attributeDict[@"style"]];
    WDSVGElement *element;
    if (styles) {
        NSMutableDictionary *combined = [[NSMutableDictionary alloc] init];
        [combined addEntriesFromDictionary:styles];
        [combined addEntriesFromDictionary:attributeDict];
        element = [[WDSVGElement alloc] initWithName:elementName andAttributes:combined];
    } else {
        element = [[WDSVGElement alloc] initWithName:elementName andAttributes:attributeDict];
    }

    WDSVGElement *top = [svgElements_ lastObject];
    [top.children addObject:element];
    [svgElements_ addObject:element];

    NSString *xmlid = attributeDict[@"id"];
    if (xmlid && !defs_[xmlid]) {
        defs_[xmlid] = element;
    }
}

- (void) parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName 
    namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    [svgElements_ removeLastObject];
}

- (void) parserDidStartDocument:(NSXMLParser *)parser
{
    WDSVGElement *top = [[WDSVGElement alloc] initWithName:@"xml" andAttributes:[styleParser_ defaultStyle]];
    [svgElements_ addObject:top];
}

- (void) parserDidEndDocument:(NSXMLParser *)parser
{
    WDSVGElement *top = [svgElements_ lastObject];
    [self visitElement:top];
    [svgElements_ removeLastObject];
    [self createLayerFor:state_.group];
    
    if (drawing_.layers.count == 0) {
        [state_ reportError:@"No layers in drawing!"];
    } else if (drawing_.width == 0 || drawing_.height == 0) {
        // autosize if necessary
        for (WDLayer *layer in drawing_.layers) {
            if (layer.elements.count == 0) {
                continue;
            }
            
            CGRect bounds = [layer styleBounds];
            drawing_.width = MAX(drawing_.width, CGRectGetMaxX(bounds));
            drawing_.height = MAX(drawing_.height, CGRectGetMaxY(bounds));
        }
    }
}

- (void) parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    [state_ reportError:@"XML parse error in SVG: %d %@", [parseError code], [parseError userInfo]];
}

- (void) parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validationError
{
    [state_ reportError:@"XML validation error in SVG: %d %@", [validationError code], [validationError userInfo]];
}

@end
