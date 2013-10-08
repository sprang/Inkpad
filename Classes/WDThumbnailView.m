//
//  WDThumbnailView.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2008-2013 Steve Sprang
//

#import "WDThumbnailView.h"
#import "WDDrawingManager.h"
#import "WDImageView.h"
#import "WDUtilities.h"
#import "UIView+Additions.h"

@interface WDThumbnailView (Private)
- (void) reloadFilenameFields_;
- (void) updateShadow_;
@end

#define kTitleFieldHeight       30
#define kMaxThumbnailDimension  120

@implementation WDThumbnailView

@synthesize filename = filename_;
@synthesize titleField = titleField_;
@synthesize imageView = imageView_;
@synthesize shouldShowSelectionIndicator;

@synthesize delegate;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];

    if (!self) {
        return nil;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(drawingRenamed:) name:WDDrawingRenamed object:nil];
    [self updateShadow_];
    
    return self;
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(drawingRenamed:) name:WDDrawingRenamed object:nil];
    [self updateShadow_];

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setSelected:(BOOL)flag
{
    [super setSelected:flag];
    
    if (!shouldShowSelectionIndicator) {
        [selectedIndicator_ removeFromSuperview];
        selectedIndicator_ = nil;
        return;
    }
    
    if (flag) {
        if (!selectedIndicator_) {
            UIImage *checkmark = [UIImage imageNamed:@"checkmark.png"];
            selectedIndicator_ = [[UIImageView alloc] initWithImage:checkmark];
            [self addSubview:selectedIndicator_];
        }
        
        CGPoint center = CGPointMake(CGRectGetMaxX(imageView_.frame) - 5, CGRectGetMaxY(imageView_.frame) - 5);
        selectedIndicator_.sharpCenter = center;
    } else if (!flag && selectedIndicator_){
        [UIView animateWithDuration:0.1f
                         animations:^{ selectedIndicator_.alpha = 0; }
                         completion:^(BOOL finished){
                             [selectedIndicator_ removeFromSuperview];
                             selectedIndicator_ = nil;
                         }];
    }
 }

- (void) editTitle:(id)sender
{
    BOOL shouldBegin = YES;
    
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(thumbnailShouldBeginEditing:)]) {
            shouldBegin = [self.delegate thumbnailShouldBeginEditing:self];
        }
    }
    
    if (shouldBegin) {
        titleField_.hidden = NO;
        [titleField_ becomeFirstResponder];
    }
}

- (void) textEditingDidEnd:(id)sender
{
    NSString *newName = titleField_.text;
    NSString *errorMessage = nil;
    
    // rehide the text field
    titleField_.hidden = YES;
    
    // tell the delegate we're done
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(thumbnailDidEndEditing:)]) {
            [self.delegate performSelector:@selector(thumbnailDidEndEditing:) withObject:self];
        }
    }
    
    if ([newName isEqualToString:[filename_ stringByDeletingPathExtension]]) {
        // nothing changed
        return;
    }
    
    if (newName.length == 0) {
        // no need to warn about blank names
        // errorMessage = @"The drawing name cannot be blank.";
        [self reloadFilenameFields_];
    } else if ([newName characterAtIndex:0] == '.') {
        errorMessage = @"The drawing name cannot begin with a dot “.”.";
    } else if ([newName rangeOfString:@"/"].length > 0 || [newName rangeOfString:@":"].length > 0) {
        errorMessage = @"The drawing name cannot contain “:” or “/”.";
    } else if ([WDDrawingManager drawingExists:newName]) {
        errorMessage = [NSString stringWithFormat:@"A drawing with the name “%@” already exists. Please choose a different name.", newName];
    } else {
        [[WDDrawingManager sharedInstance] renameDrawing:filename_ newName:titleField_.text];
    }
    
    if (errorMessage) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:errorMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        
        [self reloadFilenameFields_];
    }
}

- (void) textEdited:(id)sender
{
}

- (void) stopEditing
{
    [titleField_ endEditing:YES];
}

- (void) setFilename:(NSString *)filename
{
    if ([filename isEqualToString:self.filename]) {
        return;
    }
    
    filename_ = filename;
    
    if (!titleLabel_) {
        titleLabel_ = [UIButton buttonWithType:UIButtonTypeCustom];
        titleLabel_.frame = CGRectMake(0, 0, self.bounds.size.width, kTitleFieldHeight);
        titleLabel_.opaque = NO;
        titleLabel_.backgroundColor = nil;
        titleLabel_.exclusiveTouch = YES;
        
        titleLabel_.titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel_.titleLabel.font = [UIFont systemFontOfSize:15];
        titleLabel_.titleLabel.shadowOffset = CGSizeMake(0, 1);
        titleLabel_.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        
        [titleLabel_ setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [titleLabel_ setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [titleLabel_ addTarget:self action:@selector(editTitle:) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:titleLabel_];
    }
    
    if (!titleField_) {
        titleField_ = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, kTitleFieldHeight)];
        titleField_.textAlignment = NSTextAlignmentCenter;
        titleField_.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        titleField_.delegate = self;
        titleField_.font = [UIFont systemFontOfSize:15];
        titleField_.textColor = [UIColor blackColor];
        titleField_.clearButtonMode = UITextFieldViewModeWhileEditing;
        titleField_.returnKeyType = UIReturnKeyDone;
        titleField_.borderStyle = UITextBorderStyleRoundedRect;
        titleField_.hidden = YES;
        [titleField_ addTarget:self action:@selector(textEdited:) forControlEvents:(UIControlEventEditingDidEndOnExit)]; 
        [titleField_ addTarget:self action:@selector(textEditingDidEnd:) forControlEvents:(UIControlEventEditingDidEnd)];
        [self addSubview:titleField_];
    }
    
    [self reload];
}

- (void) textFieldDidBeginEditing:(UITextField *)textField
{
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(thumbnailDidBeginEditing:)]) {
            [self.delegate thumbnailDidBeginEditing:self];
        }
    }
}

- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString    *proposed = textField.text;
    
    if (![string isEqualToString:@"\n"]) {
        proposed = [proposed stringByReplacingCharactersInRange:range withString:string];
    }
    
    if (proposed.length && [proposed characterAtIndex:0] == '.') {
        return NO;
    }
    
    if ([string isEqualToString:@":"]) {
        return NO;
    }
    
    if ([string isEqualToString:@"/"]) {
        return NO;
    }
    
    return YES;
}

- (void) drawingRenamed:(NSNotification *)aNotification
{
    NSDictionary *userInfo = [aNotification userInfo];
    
    if ([userInfo[WDDrawingOldFilenameKey] isEqualToString:filename_]) {
        self.filename = userInfo[WDDrawingNewFilenameKey];
    }
}

- (void) setHighlighted:(BOOL)highlighted
{
    if (highlighted) {
        UIView *view = [[UIView alloc] initWithFrame:imageView_.bounds];
        view.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.25f];
        [imageView_ addSubview:view];
    } else {
        [[[imageView_ subviews] lastObject] removeFromSuperview];
    }
}

- (void) reload
{
    UIImage *thumbImage = [[WDDrawingManager sharedInstance] getThumbnail:filename_];
    
    if (!imageView_) {
        imageView_ = [[WDImageView alloc] initWithImage:thumbImage maxDimension:kMaxThumbnailDimension];
        [self addSubview:imageView_];
    } else {
        imageView_.image = thumbImage;
    }
    
    imageView_.sharpCenter = CGPointMake(WDCenterOfRect(self.bounds).x, WDCenterOfRect(self.bounds).y - (kTitleFieldHeight / 2));
    [self updateShadow_];
    
    titleField_.sharpCenter = CGPointMake(CGRectGetWidth(self.bounds) / 2, CGRectGetMaxY(imageView_.frame) + (kTitleFieldHeight / 2) + 3);
    titleLabel_.sharpCenter = titleField_.sharpCenter;
    
    [self reloadFilenameFields_];
}

- (NSComparisonResult) compare:(WDThumbnailView *)thumbView
{
    return [self.filename compare:thumbView.filename options:NSNumericSearch];
}

- (void) startActivity
{
    if (self.superview) {
        activityView_ = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        
        // make sure this doesn't look fuzzy
        activityView_.sharpCenter = WDCenterOfRect(imageView_.frame);
        
        [self addSubview:activityView_];
        
        [activityView_ startAnimating];
        [CATransaction flush];
    }
}

- (void) stopActivity
{
    if (activityView_) {
        [activityView_ stopAnimating];
        [activityView_ removeFromSuperview];
        activityView_ = nil;
    }
}

@end

@implementation WDThumbnailView (Private)

- (void) updateShadow_
{
    CALayer *layer = imageView_.layer;
    
    CGMutablePathRef shadowPath = CGPathCreateMutable();
    CGPathAddRect(shadowPath, NULL, imageView_.bounds);
    
    layer.shadowPath = shadowPath;
    layer.shadowOpacity = 0.2f;
    layer.shadowRadius = 3;
    layer.shadowOffset = CGSizeMake(0, 2);
    
    CGPathRelease(shadowPath);
}

- (void) reloadFilenameFields_
{
    NSString *strippedFilename = [self.filename stringByDeletingPathExtension];
    
    titleField_.text = strippedFilename;
    [titleLabel_ setTitle:strippedFilename forState:UIControlStateNormal];
}

@end

