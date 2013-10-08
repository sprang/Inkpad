//
//  WDSVGThumbnailExtractor.m
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

#import "WDSVGThumbnailExtractor.h"

@implementation WDSVGThumbnailExtractor

@synthesize thumbnail;

- (void) parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if ([elementName isEqualToString:@"inkpad:thumbnail"]) {
        NSString *iri = attributeDict[@"xlink:href"];
        NSRange base64 = [iri rangeOfString:@"base64,"];
        if (base64.location != NSNotFound) {
            thumbnail = [[NSData alloc] initWithBase64EncodedString:[iri substringFromIndex:base64.location + base64.length]
                                                            options:NSDataBase64DecodingIgnoreUnknownCharacters];
            [parser abortParsing];
        }
#if WD_DEBUG
        if (!thumbnail) {
            NSLog(@"Missing thumbnail data? %@", iri);
        }
#endif
    }
}

- (void) parserDidEndDocument:(NSXMLParser *)parser
{
#if WD_DEBUG
    if (!thumbnail) {
        NSLog(@"Document end reached without thumbnail data");
    }
#endif
}

- (void) parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
#if WD_DEBUG
    if ([parseError code] != 512) { // 512 is caused by abortParsing; it is expected
        NSLog(@"XML parse error in SVG: %d %@", (int) [parseError code], [parseError userInfo]);
    }
#endif
}

- (void) parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validationError
{
#if WD_DEBUG
    if ([validationError code] != 512) { // 512 is caused by abortParsing; it is expected
        NSLog(@"XML validation error in SVG: %d %@", (int) [validationError code], [validationError userInfo]);
    }
#endif
}

@end
