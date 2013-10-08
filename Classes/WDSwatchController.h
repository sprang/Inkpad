//
//  WDSwatchController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import "WDPathPainter.h"

@class WDDrawingController;

enum {
    kWDShadowSwatchMode = 0,
    kWDStrokeSwatchMode,
    kWDFillSwatchMode
};

@interface WDSwatchController : UICollectionViewController {
    UICollectionView    *collectionView_;
    
    UIBarButtonItem     *deleteItem_;
    NSMutableSet        *selectedSwatches_;
    
    UISegmentedControl  *modeSegment_;
    NSInteger           mode_;
}

@property (nonatomic, weak) WDDrawingController *drawingController;
@property (nonatomic, strong) NSMutableArray *swatches;

@end

