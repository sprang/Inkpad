//
//  WDFillTransform.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@interface WDFillTransform : NSObject <NSCoding, NSCopying>

@property (nonatomic, readonly) CGPoint start;
@property (nonatomic, readonly) CGPoint end;
@property (nonatomic, readonly) CGAffineTransform transform;
@property (nonatomic, readonly) CGPoint transformedStart;
@property (nonatomic, readonly) CGPoint transformedEnd;

+ (WDFillTransform *) fillTransformWithRect:(CGRect)rect centered:(BOOL)centered;
- (id) initWithTransform:(CGAffineTransform)transform start:(CGPoint)start end:(CGPoint)end;

- (BOOL) isDefaultInRect:(CGRect)rect centered:(BOOL)centered;

- (WDFillTransform *) transform:(CGAffineTransform)transform;
- (WDFillTransform *) transformWithTransformedStart:(CGPoint)pt;
- (WDFillTransform *) transformWithTransformedEnd:(CGPoint)pt;

@end
