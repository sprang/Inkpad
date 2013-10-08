//
//  WDSVGStyleParser.h
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

#import "WDAbstractPath.h"
#import "WDColor.h"
#import "WDFillTransform.h"
#import "WDParseUtil.h"
#import "WDShadow.h"
#import "WDSVGElement.h"
#import "WDSVGStyleParser.h"
#import "WDText.h"
#import "WDTextPath.h"

#define LOG_STYLE 0

NSString * const kWDPropertyClipRule         = @"clip-rule";
NSString * const kWDPropertyColor            = @"color";
NSString * const kWDPropertyDisplay          = @"display";
NSString * const kWDPropertyFill             = @"fill";
NSString * const kWDPropertyFillOpacity      = @"fill-opacity";
NSString * const kWDPropertyFontFamily       = @"font-family";
NSString * const kWDPropertyFontSize         = @"font-size";
NSString * const kWDPropertyOpacity          = @"opacity";
NSString * const kWDPropertyStopColor        = @"stop-color";
NSString * const kWDPropertyStopOpacity      = @"stop-opacity";
NSString * const kWDPropertyStroke           = @"stroke";
NSString * const kWDPropertyStrokeDashArray  = @"stroke-dasharray";
NSString * const kWDPropertyStrokeDashOffset = @"stroke-dashoffset";
NSString * const kWDPropertyStrokeLineCap    = @"stroke-linecap";
NSString * const kWDPropertyStrokeLineJoin   = @"stroke-linejoin";
NSString * const kWDPropertyStrokeOpacity    = @"stroke-opacity";
NSString * const kWDPropertyStrokeWidth      = @"stroke-width";
NSString * const kWDPropertyTextAnchor       = @"text-anchor";
NSString * const kWDPropertyVisibility       = @"visibility";

@implementation WDSVGStyleParser

- (id) initWithStack:(WDSVGParserStateStack *)stack
{
    self = [super init];
    if (!self) {
        return nil;
    }

    stack_ = stack;

    painters_ = [[NSMutableDictionary alloc] init];
    NSDictionary *colorWords = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"SVGColors" withExtension:@"plist"]];
    [colorWords enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL* stop) {
        painters_[[key lowercaseString]] = [self resolvePainter:obj alpha:1.f];
        }];
        
	NSArray *blendModeArray = [[NSArray alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"BlendModes" withExtension:@"plist"]];
    blendModeNames_ = [NSMutableDictionary dictionary];
    for (NSDictionary *dict in blendModeArray) {
        blendModeNames_[dict[@"name"]] = dict[@"value"];
    }
    
    return self;
}

- (NSDictionary *) defaultStyle
{
    NSMutableDictionary *defaultStyle = [NSMutableDictionary dictionary];

    defaultStyle[kWDPropertyClipRule] = @"nonzero";
    defaultStyle[kWDPropertyColor] = @"#000";
    defaultStyle[kWDPropertyDisplay] = @"inline";
    defaultStyle[kWDPropertyFill] = @"#000";
    defaultStyle[kWDPropertyFillOpacity] = @"1";
    defaultStyle[kWDPropertyFontFamily] = @"Helvetica";
    defaultStyle[kWDPropertyFontSize] = @"12";
    defaultStyle[kWDPropertyOpacity] = @"1";
    defaultStyle[kWDPropertyStopColor] = @"#000";
    defaultStyle[kWDPropertyStopOpacity] = @"1";
    defaultStyle[kWDPropertyStroke] = @"none";
    defaultStyle[kWDPropertyStrokeDashArray] = @"none";
    defaultStyle[kWDPropertyStrokeDashOffset] = @"0";
    defaultStyle[kWDPropertyStrokeLineCap] = @"butt";
    defaultStyle[kWDPropertyStrokeLineJoin] = @"miter";
    defaultStyle[kWDPropertyStrokeOpacity] = @"1";
    defaultStyle[kWDPropertyStrokeWidth] = @"1";
    defaultStyle[kWDPropertyTextAnchor] = @"start";
    defaultStyle[kWDPropertyVisibility] = @"visible";

    return defaultStyle;
}

#if LOG_STYLE
#define styleLog NSLog
#else
#define styleLog(...)
#endif

static inline BOOL charIsStyle(unichar c) 
{
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@":;/\'\""];
    return !charIsWhitespace(c) && ![separators characterIsMember:c];
}

static int charHexValue(unichar c) 
{
    if (c >= '0' && c <= '9') {
        return c - '0';
    } else if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    } else if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    } else {
        // TODO: needs to invalidate the whole color; throw exception?
        return 0;
    }
}

- (id) resolvePainter:(NSString *)source alpha:(float)alpha
{
    if (source == nil || [source isEqualToString:@"none"]) {
        return nil;
    } else if (painters_[source] != nil) {
        WDStylable *painter = painters_[source];
        if ([painter isKindOfClass:[WDStylable class]]) {
            WDStylable *prototype = [[WDStylable alloc] init];
            prototype.fill = painter.fill;
            prototype.fillTransform = [painter.fillTransform transform:stack_.transform];
            prototype.opacity = alpha;
            return prototype;
        } else {
            return painter;
        }
    } else if ([source characterAtIndex:0] == '#') {
        if ([source length] == 4) {
            unichar cr = [source characterAtIndex:1];
            unichar cg = [source characterAtIndex:2];
            unichar cb = [source characterAtIndex:3];
            float red = (charHexValue(cr) * 16 + charHexValue(cr)) / 255.f;
            float green = (charHexValue(cg) * 16 + charHexValue(cg)) / 255.f;
            float blue = (charHexValue(cb) * 16 + charHexValue(cb)) / 255.f;
            return [WDColor colorWithRed:red green:green blue:blue alpha:alpha];
        } else if ([source length] == 7) {
            unichar crh = [source characterAtIndex:1];
            unichar crl = [source characterAtIndex:2];
            unichar cgh = [source characterAtIndex:3];
            unichar cgl = [source characterAtIndex:4];
            unichar cbh = [source characterAtIndex:5];
            unichar cbl = [source characterAtIndex:6];
            float red = (charHexValue(crh) * 16 + charHexValue(crl)) / 255.f;
            float green = (charHexValue(cgh) * 16 + charHexValue(cgl)) / 255.f;
            float blue = (charHexValue(cbh) * 16 + charHexValue(cbl)) / 255.f;
            return [WDColor colorWithRed:red green:green blue:blue alpha:alpha];
        }
    } else if ([source hasPrefix:@"rgb("] && [source hasSuffix:@")"]) {
        NSScanner *scanner = [NSScanner scannerWithString:[source lowercaseString]];
        [scanner scanString:@"rgb(" intoString:NULL];
        float red, green, blue;
        [scanner scanFloat:&red];
        float redMax = ([scanner scanString:@"%" intoString:NULL]) ? 100.f : 255.f;
        [scanner scanString:@"," intoString:NULL];
        [scanner scanFloat:&green];
        float blueMax = ([scanner scanString:@"%" intoString:NULL]) ? 100.f : 255.f;
        [scanner scanString:@"," intoString:NULL];
        [scanner scanFloat:&blue];
        float greenMax = ([scanner scanString:@"%" intoString:NULL]) ? 100.f : 255.f;
        [scanner scanString:@")" intoString:NULL];
        return [WDColor colorWithRed:(red / redMax) green:(green / greenMax) blue:(blue / blueMax) alpha:alpha];
    } else if ([source hasPrefix:@"url("] && [source hasSuffix:@")"]) {
        NSString *url = [source substringWithRange:NSMakeRange(4, [source length] - 5)];
        return [self resolvePainter:url alpha:alpha];
    } else if ([source isEqualToString:@"currentColor"]) {
        return [self resolvePainter:[stack_ style:kWDPropertyColor] alpha:alpha];
    }
    // if all else fails just pick something
    [stack_ reportError:@"Unrecognized paint source: %@", source];
    return [WDColor redColor];
}

NSArray *tokenizeStyle(NSString *source) 
{
    NSMutableArray *tokens = [[NSMutableArray alloc] init];
    enum {START, IDENTIFIER, STRING1, STRING2, BEGIN_COMMENT, COMMENT, END_COMMENT} state = START;
    NSRange token;
    for (int i = 0; i < [source length]; ++i) {
        unichar c = [source characterAtIndex:i];
        switch (state) {
        case START:
            if (c == ':' || c == ';') {
                [tokens addObject:[source substringWithRange:NSMakeRange(i, 1)]]; 
            } else  if (c == '\'') {
                token = NSMakeRange(i + 1, 0);
                state = STRING1;
            } else if (c == '\"') {
                token = NSMakeRange(i + 1, 0);
                state = STRING2;
            } else if (c == '/') {
                state = BEGIN_COMMENT;
            } else if (!charIsWhitespace(c)) {
                token = NSMakeRange(i, 1);
                state = IDENTIFIER;
            }
            break;
        case IDENTIFIER:
            if (charIsStyle(c)) {
                token.length++;
            } else {
                [tokens addObject:[source substringWithRange:token]];
                state = START;
                --i; // re-evaluate the character from the START state
            }
            break;
        case STRING1:
            if (c == '\'') {
                [tokens addObject:[source substringWithRange:token]];
                state = START;
            } else {
                token.length++;
            }
            break;
        case STRING2:
            if (c == '\"') {
                [tokens addObject:[source substringWithRange:token]];
                state = START;
            } else {
                token.length++;
            }
            break;
        case BEGIN_COMMENT:
            if (c == '*') {
                state = COMMENT;
            } else {
                token = NSMakeRange(i - 1, 2);
                state = IDENTIFIER;
            }
            break;
        case COMMENT:
            if (c == '*') {
                state = END_COMMENT;
            }
            break;
        case END_COMMENT:
            if (c == '/') {
                state = START;
            } else {
                state = COMMENT;
            }
            break;
        }        
    }
    if (state == IDENTIFIER) {
        [tokens addObject:[source substringWithRange:token]];
    }
    return tokens;
}

- (NSDictionary *) parseStyle:(NSArray *)tokens
{
    NSMutableDictionary *styles = [NSMutableDictionary dictionary];
    enum {KEY, COLON, VALUE} state = KEY;
    NSString *key;
    for (id token in tokens) {
        switch (state) {
        case KEY: {
            key = token;
            state = COLON;
            NSMutableString *value = [[NSMutableString alloc] init];
            styles[token] = value;
            break;
        }
        case COLON:
            if ([token isEqual:@":"]) {
                state = VALUE;
            } else {
                [stack_ reportError:@"expected colon at: %@ in: %@", token, tokens];
                state = KEY;
            }
            break;
        case VALUE:
            if ([token isEqual:@";"]) {
                state = KEY;
            } else {
                [styles[key] appendString:token];
            }
            break;
        }
    }
    if (state != KEY && state != VALUE) {
        [stack_ reportError:@"unterminated style in: %@", tokens];
    }
    return styles;
}

- (NSDictionary *) parseStyles:(NSString *)source
{
    if (source) {
        NSArray *tokens = tokenizeStyle(source);
        NSDictionary *styles = [self parseStyle:tokens];
        return styles;
    } else {
        return nil;
    }
}

- (NSString *) fontName
{
    NSString *fontName = [stack_ style:kWDPropertyFontFamily];
    // TODO this is really over-simplified
    if ([fontName hasPrefix:@"'"] && [fontName hasSuffix:@"'"]) {
        fontName = [fontName substringWithRange:NSMakeRange(1, [fontName length] - 2)];
    }
    return fontName;
}

- (float) fontSize
{
    NSString *source = [stack_ style:kWDPropertyFontSize];
    return scaleRadially([stack_ lengthFromString:source withBound:[stack_ viewHeight] andDefault:0], stack_.viewBoxTransform);
}

- (void) styleStroke:(WDStylable *)stylable
{
    NSString *strokeSource = [stack_ style:kWDPropertyStroke];
    float strokeOpacity = [[stack_ style:kWDPropertyStrokeOpacity] floatValue];
    id strokeStyle = [self resolvePainter:strokeSource alpha:strokeOpacity];
    if ([strokeStyle isKindOfClass:[WDColor class]]) {
        NSString *strokeWidthSource = [stack_ style:kWDPropertyStrokeWidth];
        float width = scaleRadially([stack_ lengthFromString:strokeWidthSource withBound:[stack_ viewRadius] andDefault:1], stack_.transform);
        
        NSArray *dashArray = [WDSVGElement lengthListFromString:[stack_ style:kWDPropertyStrokeDashArray] withBound:[stack_ viewRadius]];
        NSArray *dashPattern;
        if ([dashArray count]) {
            NSMutableArray *scaledDashArray = [NSMutableArray array];
            for (NSNumber *n in dashArray) {
                [scaledDashArray addObject:@(scaleRadially([n floatValue], stack_.transform))];
            }
            dashPattern = scaledDashArray;
        } else {
            dashPattern = nil;
        }        
        
        CGLineCap cap = kCGLineCapButt;
        NSString *capSource = [stack_ style:kWDPropertyStrokeLineCap];
        if (capSource) {
            if ([capSource isEqualToString:@"round"]) {
                cap = kCGLineCapRound;
            } else if ([capSource isEqualToString:@"square"]) {
                cap = kCGLineCapSquare;
            }
        }
        
        CGLineJoin join = kCGLineJoinMiter;
        NSString *joinSource = [stack_ style:kWDPropertyStrokeLineJoin];
        if (joinSource) {
            if ([joinSource isEqualToString:@"bevel"]) {
                join = kCGLineJoinBevel;
            } else if ([capSource isEqualToString:@"round"]) {
                join = kCGLineJoinRound;
            }
        }

        [stylable setStrokeStyleQuiet:[WDStrokeStyle strokeStyleWithWidth:width cap:cap join:join color:strokeStyle dashPattern:dashPattern]];
    } else if ([strokeStyle isKindOfClass:[WDStylable class]]) {
        WDStylable *strokePrototype = strokeStyle;
        [stylable setStrokeStyleQuiet:strokePrototype.strokeStyle];
    } else {
        [stylable setStrokeStyleQuiet:nil];
    }
    styleLog(@"Stroke: %@ %@", strokeSource, stylable.strokeStyle);
}

- (void) styleFill:(WDStylable *)stylable
{
    NSString *fillSource = [stack_ style:kWDPropertyFill];
    float fillOpacity = [[stack_ style:kWDPropertyFillOpacity] floatValue];
    id fill = [self resolvePainter:fillSource alpha:fillOpacity];
    if ([fill isKindOfClass:[WDStylable class]]) {
        WDStylable *prototype = (WDStylable *) fill;
        [stylable setFillQuiet:prototype.fill];
        stylable.fillTransform = prototype.fillTransform;
    } else if ([fill isKindOfClass:[WDColor class]]) {
        [stylable setFillQuiet:fill];
    } else {
        [stylable setFillQuiet:nil];
    }
    styleLog(@"Fill: %@ %@", fillSource, stylable.fill);
}

- (void) styleOpacityBlendAndShadow:(WDElement *)element
{
    NSString *opacity = [stack_ style:kWDPropertyOpacity];
    NSString *visibility = [stack_ style:kWDPropertyVisibility];
    NSString *display= [stack_ style:kWDPropertyDisplay];
    if ([display isEqualToString:@"none"] || [visibility isEqualToString:@"hidden"]) {
        element.opacity = 0;
    } else {
        element.opacity = [opacity floatValue];
    }

    NSString *blendModeSource = [stack_ attribute:@"inkpad:blendMode"];
    if (blendModeSource) {
        element.blendMode = [blendModeNames_[blendModeSource] intValue];
    }
    NSString *shadowColorSource = [stack_ attribute:@"inkpad:shadowColor"];
    if (shadowColorSource) {
        float shadowOpacity = [[stack_ attribute:@"inkpad:shadowOpacity" withDefault:@"1"] floatValue];
        id shadowColor = [self resolvePainter:shadowColorSource alpha:shadowOpacity];
        if ([shadowColor isKindOfClass:[WDColor class]]) {
            float shadowAngle = [[stack_ attribute:@"inkpad:shadowAngle"] floatValue];
            float shadowOffset = [[stack_ attribute:@"inkpad:shadowOffset"] floatValue];
            float shadowRadius = [[stack_ attribute:@"inkpad:shadowRadius"] floatValue];
            WDShadow *shadow = [[WDShadow alloc] initWithColor:shadowColor radius:shadowRadius offset:shadowOffset angle:shadowAngle];
            element.shadow = shadow;
        } else {
            [stack_ reportError:@"Invalid shadow color: %@", shadowColorSource];
        }
    }
}

- (void) style:(WDStylable *)stylable
{
    [self styleStroke:stylable];
    [self styleFill:stylable];
    [self styleOpacityBlendAndShadow:stylable];
    
    // apply clipping rule
    if ([stylable isKindOfClass:[WDAbstractPath class]]) {
        WDAbstractPath *path = (WDAbstractPath *) stylable;
        NSString *clipRule = [stack_ style:kWDPropertyClipRule];
        if ([clipRule isEqualToString:@"nonzero"]) {
            path.fillRule = kWDNonZeroWindingFillRule;
        } else if ([clipRule isEqualToString:@"evenodd"]) {
            path.fillRule = kWDEvenOddFillRule;
        }
    }
    
    // apply text attributes
    if ([stylable isKindOfClass:[WDText class]]) {
        WDText *text = (WDText *) stylable;
        [text setFontNameQuiet:[self fontName]];
        [text setFontSizeQuiet:[self fontSize]];
        styleLog(@"Font: %@ %f", text.fontName, text.fontSize);
    } else if ([stylable isKindOfClass:[WDTextPath class]]) {
        WDTextPath *textPath = (WDTextPath *) stylable;
        textPath.fontName = [self fontName];
        textPath.fontSize = [self fontSize];
        styleLog(@"Font: %@ %f", textPath.fontName, textPath.fontSize);
    }
}

- (void) setPainter:(id<WDPathPainter>)painter withTransform:(WDFillTransform *)transform forId:(NSString *)painterId
{
    WDStylable *prototype = [[WDStylable alloc] init];
    // TODO pick a stroke style here    
    prototype.fill = painter;
    prototype.fillTransform = transform;
    painters_[[@"#" stringByAppendingString:painterId]] = prototype;
}

- (id<WDPathPainter>) painterForId:(NSString *)painterId
{
    WDStylable *painter = painters_[[@"#" stringByAppendingString:painterId]];
    return painter.fill;
}

- (WDFillTransform *) transformForId:(NSString *)painterId
{
    WDStylable *painter = painters_[[@"#" stringByAppendingString:painterId]];
    return painter.fillTransform;
}

@end
