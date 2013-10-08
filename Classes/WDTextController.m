//
//  WDTextController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDTextController.h"
#import "WDText.h"
#import "WDCanvasController.h"

#define kEditingTextSize    24

@implementation WDTextController

@synthesize editingObject = editingObject_;
@synthesize canvasController = canvasController_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    return self;
}
 
- (NSString *) text
{
    return text_.text;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    // we want the undo to be an atomic operation
    [editingObject_ cacheOriginalText];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [editingObject_ registerUndoWithCachedText];
}

- (void)textViewDidChange:(UITextView *)textView
{
    editingObject_.text = textView.text;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [text_ becomeFirstResponder];
}

- (void) configureWithTextObject:(WDText *)text
{
    text_.text = text.text;
    
    UIFont  *font = [UIFont fontWithName:text.fontName size:kEditingTextSize];

    if (!font) {
        // must be a user installed font
        font = [UIFont systemFontOfSize:kEditingTextSize];
    }
    
    text_.font = font;
}

- (void) selectAll
{
    [text_ selectAll:self];
    [UIMenuController sharedMenuController].menuVisible = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    text_.delegate = self;
    if (self.editingObject) {
        [self configureWithTextObject:self.editingObject];
    }
    
    self.preferredContentSize = self.view.frame.size;
}


@end
