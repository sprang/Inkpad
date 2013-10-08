//
//  WDText.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2009-2013 Steve Sprang
//

#if TARGET_OS_MAC
#import <UIKit/UIKit.h>
#endif

#import <CoreText/CoreText.h>
#import "WDStylable.h"
#import "WDTextRenderer.h"

@class WDStrokeStyle;

@protocol WDPathPainter;

@interface WDText : WDStylable <NSCoding, NSCopying, WDTextRenderer> {
    float               width_;
    CGAffineTransform   transform_;
    NSString            *text_;
    NSTextAlignment     alignment_;
    NSString            *fontName_;
    float               fontSize_;
    
    CTFontRef           fontRef_;
    CGMutablePathRef    pathRef_;
    
    BOOL                needsLayout_;
    NSMutableArray      *glyphs_;
    CGRect              styleBounds_;
    
    NSString            *cachedText_;
    CGAffineTransform   cachedTransform_;
    float               cachedWidth_;
    BOOL                cachingWidth_;
    
    CGRect              naturalBounds_;
    BOOL                naturalBoundsDirty_;
}

@property (nonatomic, assign) float width;
@property (nonatomic, strong) NSString *fontName;
@property (nonatomic, assign) float fontSize;
@property (nonatomic, assign) CGAffineTransform transform;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, assign) NSTextAlignment alignment;
@property (nonatomic, readonly) CGRect naturalBounds;
@property (nonatomic, readonly) CTFontRef fontRef;
@property (nonatomic, readonly, strong) NSAttributedString *attributedString;

- (void) setFontName:(NSString *)fontName;
- (void) setFontSize:(float)fontSize;

+ (float) minimumWidth;
- (void) moveHandle:(NSUInteger)handle toPoint:(CGPoint)pt;

- (void) cacheOriginalText;
- (void) registerUndoWithCachedText;

- (void) cacheTransformAndWidth;
- (void) registerUndoWithCachedTransformAndWidth;

// an array of WDPath objects representing each glyph in the text object
- (NSArray *) outlines;

- (void) drawOpenGLTextOutlinesWithTransform:(CGAffineTransform)transform viewTransform:(CGAffineTransform)viewTransform;

- (void) setFontNameQuiet:(NSString *)fontName;
- (void) setFontSizeQuiet:(float)fontSize;
- (void) setTextQuiet:(NSString *)text;
- (void) setTransformQuiet:(CGAffineTransform)transform;
- (void) setWidthQuiet:(float)width;

@end
