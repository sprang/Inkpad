//
//  WDCoreTextLabel.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDCoreTextLabel.h"

@implementation WDCoreTextLabel

@synthesize fontRef;
@synthesize text;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    self.backgroundColor = nil;
    self.opaque = NO;
    self.contentMode = UIViewContentModeRedraw;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    return self;
}

- (void) dealloc
{
    if (fontRef) {
        CFRelease(fontRef);
    }
}

- (void) setFontRef:(CTFontRef)font
{
    if (font) {
        CFRetain(font);
    }
    
    if (fontRef) {
        CFRelease(fontRef);
    }
    
    fontRef = font;
    
    [self setNeedsDisplay];
}

- (void) setText:(NSString *)inText
{
    text = inText;
    [self setNeedsDisplay];
}

- (CFMutableAttributedStringRef) newAttributedStringForText:(NSString *)string
{
    CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    
    CFAttributedStringReplaceString(attrString, CFRangeMake(0, 0), (CFStringRef)string);    
    CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFStringGetLength((CFStringRef)string)), kCTFontAttributeName, [self fontRef]);
    
    return attrString;
}

- (void) drawRect:(CGRect)rect
{
    if (!text || [text isEqualToString:@""]) {
        return;
    }
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetTextMatrix(ctx, CGAffineTransformMakeScale(1,-1));
    
    CFMutableAttributedStringRef attrString = [self newAttributedStringForText:text];
    CFMutableAttributedStringRef tokenString = [self newAttributedStringForText:@"…"];
    
    CTLineRef lineRef = CTLineCreateWithAttributedString(attrString); 
    CTLineRef tokenLineRef = CTLineCreateWithAttributedString(tokenString);
    CTLineRef truncatedLineRef = CTLineCreateTruncatedLine(lineRef, self.bounds.size.width, kCTLineTruncationEnd, tokenLineRef);
    
    float offset = roundf((CGRectGetHeight(self.bounds) - CTFontGetSize(self.fontRef)) / 2) + 2;
    CGContextSetTextPosition(ctx, 0, roundf(CGRectGetMaxY(self.bounds) - offset));
    CTLineDraw(truncatedLineRef, ctx);
    
    CFRelease(attrString);
    CFRelease(tokenString);
    CFRelease(lineRef);
    CFRelease(tokenLineRef);
    CFRelease(truncatedLineRef);
}

@end

