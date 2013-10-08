//
//  WDSVGParser.h
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
#import "WDDrawing.h"
#import "WDSVGElement.h"
#import "WDSVGParserStateStack.h"
#import "WDSVGStyleParser.h"
#import "WDSVGTransformParser.h"


@interface WDSVGParser : NSObject <NSXMLParserDelegate>  {
    NSMutableDictionary     *defs_;
    WDDrawing               *drawing_;
    NSMutableArray          *gradientStops_;
    WDSVGParserStateStack   *state_;
    WDSVGStyleParser        *styleParser_;
    NSMutableArray          *svgElements_;
}

- (id) initWithDrawing:(WDDrawing *)drawing;
- (void) startElement:(WDSVGElement *)element;
- (WDElement *) endElement;
- (BOOL) hadErrors;
- (BOOL) hadMemoryWarning;

@end
