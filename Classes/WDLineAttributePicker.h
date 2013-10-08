//
//  WDLineAttributePicker.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import "WDStrokeStyle.h"

@interface WDLineAttributePicker : UIControl {
    int                 selectedIndex_;
    UIButton            *joinButton_[3];
    UIButton            *capButton_[3];
}

@property (nonatomic, assign) CGLineCap cap;
@property (nonatomic, assign) CGLineJoin join;
@property (nonatomic, assign) WDStrokeAttributes mode;

+ (UIImage *) joinImageWithSize:(CGSize)size join:(CGLineJoin)join highlight:(BOOL)highlight;
+ (UIImage *) capImageWithSize:(CGSize)size cap:(CGLineCap)cap highlight:(BOOL)highlight;

@end
