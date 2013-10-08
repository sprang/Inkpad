//
//  WDTextController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

@class WDText;
@class WDCanvasController;

@interface WDTextController : UIViewController <UITextViewDelegate> {
    IBOutlet UITextView             *text_;
}
@property (nonatomic, weak) WDText *editingObject;
@property (nonatomic, weak) WDCanvasController *canvasController;

- (void) configureWithTextObject:(WDText *)text;
- (void) selectAll;

@end

