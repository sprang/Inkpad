//
//  WDSVGPathParser.h
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

@interface WDSVGPathParser : NSObject {
    id<WDErrorReporter> reporter_;
    CGMutablePathRef    path_;
    CGPoint             lastCurveControl_;
    CGPoint             lastQuadCurveControl_;
}

- (id) initWithErrorReporter:(id<WDErrorReporter>)reporter;
- (CGPathRef) parse:(NSString *)source;

@end
