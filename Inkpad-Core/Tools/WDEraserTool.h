//
//  WDEraserTool.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDTool.h"

@class WDPath;

@interface WDEraserTool : WDTool {
    WDPath              *tempPath_;
    NSUInteger          eraserSize_;
    
#if TARGET_OS_IPHONE
    IBOutlet UIView     *optionsView_;
    IBOutlet UILabel    *optionsTitle_;
    IBOutlet UILabel    *optionsValue_;
    IBOutlet UISlider   *optionsSlider_;
#endif
}

@end
