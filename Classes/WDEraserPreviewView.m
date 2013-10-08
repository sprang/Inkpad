//
//  WDEraserPreviewView.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDCanvas.h"
#import "WDEraserPreviewView.h"
#import "WDPath.h"

@implementation WDEraserPreviewView

@synthesize canvas = canvas_;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    self.opaque = NO;
    self.backgroundColor = nil;
    
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGContextSaveGState(ctx);

    CGContextConcatCTM(ctx, canvas_.canvasTransform);
    CGContextSetShouldAntialias(ctx, NO);
    
    [canvas_.eraserPath renderInContext:ctx metaData:WDRenderingMetaDataMake(canvas_.viewScale, WDRenderDefault)];
    
    CGContextRestoreGState(ctx);
}

@end
