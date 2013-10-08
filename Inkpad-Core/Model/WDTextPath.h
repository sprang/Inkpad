//
//  WDTextPath.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDPath.h"
#import "WDTextRenderer.h"

typedef enum {
    kWDTextPathAlignmentBaseline,
    kWDTextPathAlignmentCentered, // currently unsupported
    kWDTextPathAlignmentVertical  // currently unsupported
} WDTextPathAlignment;

@interface WDTextPath : WDPath <NSCoding, NSCopying, WDTextRenderer> {
    NSString                *text_;
    NSString                *fontName_;
    float                   fontSize_;
    WDTextPathAlignment     alignment_;
    float                   startOffset_;
    CGAffineTransform       transform_;
    
    CTFontRef               fontRef_;
    BOOL                    needsLayout_;
    NSMutableArray          *glyphs_;
    BOOL                    overflow_;
    
    CGRect                  styleBounds_;
    
    NSString                *cachedText_;
    NSNumber                *cachedStartOffset_;
}

@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSString *fontName;
@property (nonatomic, assign) float fontSize;
@property (nonatomic, readonly) CTFontRef fontRef;

@property (nonatomic, assign) WDTextPathAlignment alignment;
@property (nonatomic, assign) float startOffset;
@property (nonatomic, readonly) NSAttributedString *attributedString;
@property (nonatomic, strong) NSNumber *cachedStartOffset;

+ (WDTextPath *) textPathWithPath:(WDPath *)path;

- (void) setFontName:(NSString *)fontName;
- (void) setFontSize:(float)fontSize;

- (void) moveStartKnobToNearestPoint:(CGPoint)pt;

- (void) cacheOriginalText;
- (void) registerUndoWithCachedText;

- (void) cacheOriginalStartOffset;
- (void) registerUndoWithCachedStartOffset;

- (void) resetTransform;

@end
