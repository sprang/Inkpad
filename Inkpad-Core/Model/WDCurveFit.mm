//
//  WDCurveFit.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "bezier-utils.h"
#import "WDBezierNode.h"
#import "WDBezierSegment.h"
#import "WDCurveFit.h"
#import "WDPath.h"
#import "WDUtilities.h"

@implementation WDCurveFit

+ (WDPath *) smoothPathForPoints:(NSArray *)inPoints error:(float)epsilon attemptToClose:(BOOL)shouldClose
{
    NSMutableArray  *points = [inPoints mutableCopy];
	Geom::Point     *pd;
    int             i = 0, ec = (int) points.count;
	CGPoint			p;
    BOOL            closePath = NO;
	
	// see if this path should be closed
    if (shouldClose && points.count > 3) {
        CGPoint first = [points[0] CGPointValue];
        CGPoint last = [[points lastObject] CGPointValue];
        
        if (WDDistance(first, last) < (epsilon*2)) {
            CGPoint average = WDAveragePoints(first, last);
            
            closePath = YES;
            
            points[0] = [NSValue valueWithCGPoint:average];
            [points removeLastObject];
            [points addObject:[NSValue valueWithCGPoint:average]];
        }
    }
    
	pd = (Geom::Point*) malloc(sizeof( Geom::Point ) * ec);
	
    for (NSValue *value in points)	{
		p = [value CGPointValue];
		pd[i++] = Geom::Point((Geom::Coord)p.x, (Geom::Coord)p.y);
	}
	
	int				numSegments, maxSegments;
    int             segElement = 0;
	Geom::Point     *segBuffer;
	
	maxSegments = MAX(256, ec);
	segBuffer = (Geom::Point*) malloc( sizeof( Geom::Point ) * maxSegments * 4);
    
    WDBezierSegment wdSegments[maxSegments];
	numSegments = bezier_fit_cubic_r(segBuffer, pd, ec, epsilon, maxSegments);
	
	for (int i = 0; i < numSegments; i++) {
        wdSegments[i].a_.x = segBuffer[segElement][Geom::X];
        wdSegments[i].a_.y = segBuffer[segElement++][Geom::Y];
        wdSegments[i].out_.x = segBuffer[segElement][Geom::X];
        wdSegments[i].out_.y = segBuffer[segElement++][Geom::Y];
        wdSegments[i].in_.x = segBuffer[segElement][Geom::X];
        wdSegments[i].in_.y = segBuffer[segElement++][Geom::Y];
        wdSegments[i].b_.x = segBuffer[segElement][Geom::X];
        wdSegments[i].b_.y = segBuffer[segElement++][Geom::Y];
	}
	
	free(pd);
	free(segBuffer);
    
    NSMutableArray  *newNodes = [NSMutableArray array];
    WDBezierNode    *node;
    
    for (int i = 0; i < numSegments; i++) {
        if (i == 0) {
            CGPoint inPoint = closePath ? wdSegments[numSegments - 1].in_ : wdSegments[0].a_;
            node = [WDBezierNode bezierNodeWithInPoint:inPoint anchorPoint:wdSegments[0].a_ outPoint:wdSegments[0].out_];
        } else {
            node = [WDBezierNode bezierNodeWithInPoint:wdSegments[i-1].in_ anchorPoint:wdSegments[i].a_ outPoint:wdSegments[i].out_];
        }
        
        [newNodes addObject:node];
        
        if (i == (numSegments - 1) && !closePath) {
            node = [WDBezierNode bezierNodeWithInPoint:wdSegments[i].in_ anchorPoint:wdSegments[i].b_ outPoint:wdSegments[i].b_];
            [newNodes addObject:node];
        }
    }
    
    if (newNodes.count < 2) {
        return nil;
    }
    
    WDPath *path = [[WDPath alloc] init];
    path.nodes = newNodes;
    path.closed = closePath;
    
    return path;
}

@end
