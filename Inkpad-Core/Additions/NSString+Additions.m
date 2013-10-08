//
//  NSString+Additions.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "NSString+Additions.h"

@implementation NSString (WDAdditions)

- (NSString *) stringByUnescapingEntities
{
    NSMutableString *unescapeStr = [NSMutableString stringWithString:self];
    NSRange range = NSMakeRange(0, [unescapeStr length]);
    
    [unescapeStr replaceOccurrencesOfString:@"&amp;"  withString:@"&"  options:NSLiteralSearch range:range];
    [unescapeStr replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:NSLiteralSearch range:range];
    [unescapeStr replaceOccurrencesOfString:@"&#x27;" withString:@"'"  options:NSLiteralSearch range:range];
    [unescapeStr replaceOccurrencesOfString:@"&#x39;" withString:@"'"  options:NSLiteralSearch range:range];
    [unescapeStr replaceOccurrencesOfString:@"&#x92;" withString:@"'"  options:NSLiteralSearch range:range];
    [unescapeStr replaceOccurrencesOfString:@"&#x96;" withString:@"'"  options:NSLiteralSearch range:range];
    [unescapeStr replaceOccurrencesOfString:@"&gt;"   withString:@">"  options:NSLiteralSearch range:range];
    [unescapeStr replaceOccurrencesOfString:@"&lt;"   withString:@"<"  options:NSLiteralSearch range:range];
    
    return unescapeStr;
}

- (NSString *) stringByEscapingEntities
{
    NSMutableString *escapeStr = [NSMutableString stringWithString:self];
    NSRange range = NSMakeRange(0, [escapeStr length]);
    
    [escapeStr replaceOccurrencesOfString:@"&"  withString:@"&amp;"  options:NSLiteralSearch range:range];
    [escapeStr replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:range];
    [escapeStr replaceOccurrencesOfString:@"'"  withString:@"&#x27;" options:NSLiteralSearch range:range];
    [escapeStr replaceOccurrencesOfString:@">"  withString:@"&gt;"   options:NSLiteralSearch range:range];
    [escapeStr replaceOccurrencesOfString:@"<"  withString:@"&lt;"   options:NSLiteralSearch range:range];
    
    return escapeStr;
}

- (NSString *) stringByEscapingEntitiesAndWhitespace
{
    NSMutableString *escapeStr = (NSMutableString *) [self stringByEscapingEntities];
    NSRange range = NSMakeRange(0, [escapeStr length]);
    
    [escapeStr replaceOccurrencesOfString:@"\n"  withString:@"&#xA;"  options:NSLiteralSearch range:range];
    [escapeStr replaceOccurrencesOfString:@"\r"  withString:@"&#xA;"  options:NSLiteralSearch range:range];
    [escapeStr replaceOccurrencesOfString:@" " withString:@"&#x20;" options:NSLiteralSearch range:range];
    
    return escapeStr;
}

- (CGSize) sizeWithCTFont:(CTFontRef)fontRef constrainedToSize:(CGSize)constraint
{
    CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    
    CFAttributedStringReplaceString(attrString, CFRangeMake(0, 0), (CFStringRef)self);    
    CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFStringGetLength((CFStringRef)self)), kCTFontAttributeName, fontRef);
        
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attrString);
    CFRange fitRange;
        
    // compute size
    CGSize naturalSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, constraint, &fitRange);
        
    // clean up
    CFRelease(framesetter);
    CFRelease(attrString);
        
    float fontHeight = CTFontGetLeading(fontRef);
    naturalSize.height = MAX(fontHeight, naturalSize.height + 1);
    
    return naturalSize;
}

@end

