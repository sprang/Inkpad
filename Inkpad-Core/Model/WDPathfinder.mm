//
//  WDPathfinder.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "Path.h"
#import "Shape.h"

#import "WDBezierNode.h"
#import "WDCompoundPath.h"
#import "WDPath.h"
#import "WDPathfinder.h"
#import "WDUtilities.h"

@interface WDPath (Livarot)
- (Path *) convertToLivarotPath;
@end

@implementation WDPath (Livarot)

- (Path *) convertToLivarotPath
{    
    NSArray         *nodes = reversed_ ? [self reversedNodes] : self.nodes;
    WDBezierNode    *node;
    NSInteger       numNodes = self.closed ? nodes.count + 1 : nodes.count;
    CGPoint         pt, prev_pt, in_pt, prev_out;
     
    Path* thePath=new Path();
    
    for(int i = 0; i < numNodes; i++) {
        node = nodes[(i % nodes.count)];
        
        if (i == 0) {
            pt = node.anchorPoint;
            thePath->MoveTo(pt.x, pt.y);
        } else {
            pt = node.anchorPoint;
            in_pt = node.inPoint;
            
            if (prev_pt.x == prev_out.x && prev_pt.y == prev_out.y && in_pt.x == pt.x && in_pt.y == pt.y) {
            	thePath->LineTo(pt.x, pt.y);
            } else {
                prev_out = WDMultiplyPointScalar(WDSubtractPoints(prev_out, prev_pt), 3);
                in_pt = WDMultiplyPointScalar(WDSubtractPoints(in_pt, pt), -3);
                
                thePath->CubicTo(pt.x, pt.y, prev_out.x, prev_out.y, in_pt.x, in_pt.y);
            }       
        }
        
        prev_out = node.outPoint;
        prev_pt = pt; 
    }
    
    if (self.closed) {
        thePath->Close();
    }
    
    thePath->ConvertWithBackData(1);
    
    return thePath;
}

@end

@implementation WDPathfinder

+ (WDAbstractPath *) fromLivarotPath:(Path *)path
{
    NSMutableArray  *subpaths = [NSMutableArray array];
    WDPath          *currentPath = [[WDPath alloc] init];
    NSMutableArray  *nodes = [NSMutableArray array];
    
	for (int i = 0; i <path->descr_nb; i++) {
		int ty=(path->descr_data+i)->flags&descr_type_mask;
		if ( ty == descr_moveto ) {
            [nodes addObject:[WDBezierNode bezierNodeWithAnchorPoint:CGPointMake((path->descr_data+i)->d.m.x,(path->descr_data+i)->d.m.y)]];
		} else if ( ty == descr_lineto ) {
            [nodes addObject:[WDBezierNode bezierNodeWithAnchorPoint:CGPointMake((path->descr_data+i)->d.l.x,(path->descr_data+i)->d.l.y)]];
		} else if ( ty == descr_cubicto ) {
            WDBezierNode *lastObject = [nodes lastObject];
            [nodes removeLastObject];
            
            CGPoint outPoint = CGPointMake((path->descr_data+i)->d.c.stDx,(path->descr_data+i)->d.c.stDy);
            outPoint = WDMultiplyPointScalar(outPoint, (1.0f / 3));
            [nodes addObject:[WDBezierNode bezierNodeWithInPoint:lastObject.inPoint
                                                     anchorPoint:lastObject.anchorPoint
                                                        outPoint:WDAddPoints(lastObject.anchorPoint, outPoint)]];
            
            CGPoint anchorPoint = CGPointMake((path->descr_data+i)->d.c.x,(path->descr_data+i)->d.c.y);
            CGPoint inPoint = CGPointMake((path->descr_data+i)->d.c.enDx,(path->descr_data+i)->d.c.enDy);
            inPoint = WDMultiplyPointScalar(inPoint, (1.0f / -3));
            [nodes addObject:[WDBezierNode bezierNodeWithInPoint:WDAddPoints(anchorPoint, inPoint)
                                                     anchorPoint:anchorPoint
                                                        outPoint:anchorPoint]];
		} else if ( ty == descr_close ) {
            currentPath.nodes = nodes;
            currentPath.closed = YES;
            nodes = [NSMutableArray array];
            
            [subpaths addObject:currentPath];
            currentPath = [[WDPath alloc] init];
		}
	}
    
    
    if (subpaths.count > 1) {
        WDCompoundPath  *compoundPath = [[WDCompoundPath alloc] init];
        compoundPath.subpaths = subpaths;
        return compoundPath;
    } else {
        return [subpaths lastObject];
    }
}

+ (WDAbstractPath *) combinePaths:(NSArray *)abstractPaths operation:(WDPathfinderOperation)operation
{    
    int     pathCount = 0;
    
    for (WDAbstractPath *ap in abstractPaths) {
        pathCount += [ap subpathCount];
    }
    
    Path   *paths[pathCount];
    Shape  *temp = new Shape();
    Shape   *shapes[pathCount];
    Shape   *result;
    int     i = 0, shapeIx = 0;
    
    for (WDAbstractPath *ap in abstractPaths) {
        if (ap.subpathCount == 1) {
            paths[i] = [((WDPath *) ap) convertToLivarotPath];
            
            temp->Reset();
            paths[i]->Fill(temp, i);
            shapes[shapeIx] = new Shape();
            shapes[shapeIx]->ConvertToShape(temp, fill_nonZero);
            i++;
            shapeIx++;
            
        } else {
            WDCompoundPath *cp = (WDCompoundPath *) ap;
            
            temp->Reset();
            
            for (WDPath *sp in cp.subpaths) {
                paths[i] = [sp convertToLivarotPath];
                paths[i]->Fill(temp, i, true);
                i++;
            }
            
            shapes[shapeIx] = new Shape();
            shapes[shapeIx]->ConvertToShape(temp, fill_nonZero);
    
            shapeIx++;
        }
    }
    
    Shape *prev = shapes[0];
    for (int i = 1; i < shapeIx; i++) {
        result = new Shape();
        result->Booleen(prev, shapes[i], (BooleanOp) operation);
        
        if (i != 1) {
            delete prev;
        }
        prev = result;
    }
    
    Path *dest = new Path();
    result->ConvertToForme(dest, pathCount, paths);
    WDAbstractPath *finalResult = [WDPathfinder fromLivarotPath:dest];
    delete dest;
    delete result;
    
    for (i = 0; i < shapeIx; i++) {
        delete shapes[i];
    }
    for (i = 0; i < pathCount; i++) {
        delete paths[i];
    }
    delete temp;
    
    return finalResult;
}

@end
