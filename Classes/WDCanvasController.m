//
//  WDCanvasController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Twitter/Twitter.h>
#import <MessageUI/MessageUI.h>
#import "WDButton.h"
#import "WDCanvas.h"
#import "WDCanvasController.h"
#import "WDColor.h"
#import "WDColorBalanceController.h"
#import "WDColorWell.h"
#import "WDEraserPreviewView.h"
#import "WDDocument.h"
#import "WDDrawingController.h"
#import "WDDrawingManager.h"
#import "WDFillController.h"
#import "WDFontController.h"
#import "WDHueSaturationController.h"
#import "WDInspectableProperties.h"
#import "WDLayer.h"
#import "WDLayerController.h"
#import "WDMenu.h"
#import "WDMenuItem.h"
#import "WDPropertyManager.h"
#import "WDRotateTool.h"
#import "WDSelectionTool.h"
#import "WDSelectionView.h"
#import "WDSettingsController.h"
#import "WDShadowController.h"
#import "WDShadowWell.h"
#import "WDStrokeController.h"
#import "WDSwatchController.h"
#import "WDTextPath.h"
#import "WDTextController.h"
#import "WDToolManager.h"
#import "WDUtilities.h"
#import "UIBarButtonItem+Additions.h"

#define kMaxDisplayableFilename     18

@implementation WDCanvasController

@synthesize document = document_;
@synthesize canvas = canvas_;
@synthesize drawingController = drawingController_;

- (WDDrawing *) drawing 
{
    return self.document.drawing;
}

- (void) editTextObject:(WDText *)text selectAll:(BOOL)selectAll
{
    [self hidePopovers];
    
    WDTextController *textController = [[WDTextController alloc] initWithNibName:@"Text" bundle:nil];
    
    textController.canvasController = self;
    textController.editingObject = text;
    if (selectAll) {
        [textController performSelector:@selector(selectAll) withObject:nil afterDelay:0];
    }
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:textController];
    popoverController_.passthroughViews = @[canvas_];
    
	popoverController_.delegate = self;
    
    CGRect bounds = CGRectIntegral([canvas_ convertRectToView:[text bounds]]);
    
    UIPopoverArrowDirection permittedArrowDir = (UIPopoverArrowDirectionDown | UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight);
    [popoverController_ presentPopoverFromRect:bounds inView:self.view permittedArrowDirections:permittedArrowDir animated:YES];
}

#pragma mark -
#pragma mark Interface Rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [canvas_.selectionView removeFromSuperview];
    canvas_.selectionView = nil;
    
    [canvas_.eraserPreview removeFromSuperview];
    canvas_.eraserPreview = nil;
    
    [canvas_ cacheVisibleRectCenter];
    [canvas_ showRulers:NO animated:NO];
    
    [canvas_ nixMessageLabel];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [canvas_ setVisibleRectCenterFromCached];
    [canvas_ rotateToInterfaceOrientation];
    
    [canvas_ showRulers:self.drawing.rulersVisible animated:NO];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [canvas_ ensureToolPaletteIsOnScreen];
    [balanceController_ bringOnScreenAnimated:YES];
    [hueController_ bringOnScreenAnimated:YES];
}

#pragma mark -
#pragma mark Show Controllers

- (BOOL) shouldDismissPopoverForClassController:(Class)controllerClass insideNavController:(BOOL)insideNav
{
    if (!popoverController_) {
        return NO;
    }
    
    if (insideNav && [popoverController_.contentViewController isKindOfClass:[UINavigationController class]]) {
        NSArray *viewControllers = [(UINavigationController *)popoverController_.contentViewController viewControllers];
        
        for (UIViewController *viewController in viewControllers) {
            if ([viewController isKindOfClass:controllerClass]) {
                return YES;
            }
        }
    } else if ([popoverController_.contentViewController isKindOfClass:controllerClass]) {
        return YES;
    }
    
    return NO;
}

- (void) scaleDocumentToFit:(id)sender
{
    [canvas_ scaleDocumentToFit];
}

- (void) showSettingsMenu:(id)sender
{
    if ([self shouldDismissPopoverForClassController:[WDSettingsController class] insideNavController:YES]) {
        [self hidePopovers];
        return;
    }
    
    WDSettingsController *settings = [[WDSettingsController alloc] initWithNibName:nil bundle:nil];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settings];
    
    settings.drawing = document_.drawing;
    [self runPopoverWithController:navController from:sender];
}

- (void) showPhotoBrowser:(id)sender
{
    if ([self shouldDismissPopoverForClassController:[UIImagePickerController class] insideNavController:NO]) {
        [self hidePopovers];
        return;
    }
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    
    [self runPopoverWithController:picker from:sender];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if ([self.drawingController respondsToSelector:aSelector]) {
        return self.drawingController;
    }
    
    return [super forwardingTargetForSelector:aSelector];
}

#pragma mark -
#pragma mark Image Placement

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self imagePickerControllerDidCancel:picker];
    
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [self.drawingController placeImage:image];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [popoverController_ dismissPopoverAnimated:YES];
    popoverController_ = nil;
}

#pragma mark -
#pragma mark Menus

- (void) showActionMenu:(id)sender
{
    if (popoverController_ && (popoverController_.contentViewController.view == actionMenu_)) {
        [self hidePopovers];
        return;
    }
    
    if (!actionMenu_) {
        NSMutableArray  *menus = [NSMutableArray array];
        WDMenuItem      *item;
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Add to Photo Album", @"Add to Photo Album")
                                  action:@selector(addToPhotoAlbum:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Copy Drawing", @"Copy Drawing")
                                  action:@selector(copyDrawing:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Duplicate Drawing", @"Duplicate Drawing")
                                  action:@selector(duplicateDrawing:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Print Drawing", @"Print Drawing") action:@selector(printDrawing:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        if (NSClassFromString(@"SLComposeViewController")) { // if we can facebook
            item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Post on Facebook", @"Post on Facebook")
                                      action:@selector(postOnFacebook:) target:self];
            [menus addObject:item];
        }
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Tweet", @"Tweet")
                                  action:@selector(tweetDrawing:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Export as PNG", @"Export as PNG")
                                  action:@selector(exportAsPNG:) target:self];
        [menus addObject:item];

        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Export as PDF", @"Export as PDF")
                                  action:@selector(exportAsPDF:) target:self];
        [menus addObject:item];

        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Export as SVG", @"Export as SVG")
                                  action:@selector(exportAsSVG:) target:self];
        [menus addObject:item];
        
        actionMenu_ = [[WDMenu alloc] initWithItems:menus];
        actionMenu_.delegate = self;
    }
    
    for (WDMenuItem *item in actionMenu_.items) {
        [self validateMenuItem:item];
    }
    
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view = actionMenu_;
    controller.preferredContentSize = actionMenu_.frame.size;
    
    actionMenu_.popover = [self runPopoverWithController:controller from:sender];
    
    visibleMenu_ = actionMenu_;
}

- (void) showObjectMenu:(id)sender
{
    if (popoverController_ && (popoverController_.contentViewController.view == objectMenu_)) {
        [self hidePopovers];
        return;
    }
    
    if (!objectMenu_) {
        NSMutableArray  *menus = [NSMutableArray array];
        WDMenuItem      *item;
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Select All", @"Select All")
                                  action:@selector(selectAll:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Select All in Layer", @"Select All in Layer")
                                  action:@selector(selectAllOnActiveLayer:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Deselect All", @"Deselect All")
                                  action:@selector(selectNone:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Cut", @"Cut")
                                  action:@selector(cut:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Copy", @"Copy")
                                  action:@selector(copy:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Paste", @"Paste")
                                  action:@selector(paste:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Duplicate", @"Duplicate")
                                  action:@selector(duplicate:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Duplicate in Place", @"Duplicate in Place")
                                  action:@selector(duplicateInPlace:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Transform Again", @"Transform Again")
                                  action:@selector(transformAgain:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Duplicate and Transform Again", @"Duplicate and Transform Again")
                                  action:@selector(duplicateAndTransformAgain:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Delete", @"Delete")
                                  action:@selector(delete:) target:self];
        [menus addObject:item];
        
        objectMenu_ = [[WDMenu alloc] initWithItems:menus];
        objectMenu_.delegate = self;
    }
    
    for (WDMenuItem *item in objectMenu_.items) {
        [self validateMenuItem:item];
    }
    
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view = objectMenu_;
    controller.preferredContentSize = objectMenu_.frame.size;
    
    objectMenu_.popover = [self runPopoverWithController:controller from:sender];
    
    visibleMenu_ = objectMenu_;
}

- (void) showArrangeMenu:(id)sender
{
    if (popoverController_ && (popoverController_.contentViewController.view == arrangeMenu_)) {
        [self hidePopovers];
        return;
    }
    
    if (!arrangeMenu_) {
        NSMutableArray  *menus = [NSMutableArray array];
        WDMenuItem      *item;
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Bring Forward", @"Bring Forward")
                                  action:@selector(bringForward:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Bring to Front", @"Bring to Front")
                                  action:@selector(bringToFront:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Send Backward", @"Send Backward")
                                  action:@selector(sendBackward:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Send to Back", @"Send to Back")
                                  action:@selector(sendToBack:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Flip Horizontally", @"Flip Horizontally")
                                  action:@selector(flipHorizontally:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Flip Vertically", @"Flip Vertically")
                                  action:@selector(flipVertically:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Distribute Horizontally", @"Distribute Horizontally")
                                  action:@selector(distributeHorizontally:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Distribute Vertically", @"Distribute Vertically")
                                  action:@selector(distributeVertically:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Group", @"Group") action:@selector(group:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Ungroup", @"Ungroup") action:@selector(ungroup:) target:self];
        [menus addObject:item];

        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Align Left", @"Align Left")
                                   image:[UIImage imageNamed:@"align_left.png"]
                                  action:@selector(align:) target:self];
        item.tag = WDAlignLeft;
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Align Center", @"Align Center")
                                   image:[UIImage imageNamed:@"align_center.png"]
                                  action:@selector(align:) target:self];
        item.tag = WDAlignCenter;
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Align Right", @"Align Right")
                                   image:[UIImage imageNamed:@"align_right.png"]
                                  action:@selector(align:) target:self];
        item.tag = WDAlignRight;
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Align Top", @"Align Top")
                                   image:[UIImage imageNamed:@"align_top.png"]
                                  action:@selector(align:) target:self];
        item.tag = WDAlignTop;
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Align Middle", @"Align Middle")
                                   image:[UIImage imageNamed:@"align_middle.png"]
                                  action:@selector(align:) target:self];
        item.tag = WDAlignMiddle;
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Align Bottom", @"Align Bottom")
                                   image:[UIImage imageNamed:@"align_bottom.png"]
                                  action:@selector(align:) target:self];
        item.tag = WDAlignBottom;
        [menus addObject:item];
        
        arrangeMenu_ = [[WDMenu alloc] initWithItems:menus];
        arrangeMenu_.delegate = self;
    }
    
    for (WDMenuItem *item in arrangeMenu_.items) {
        [self validateMenuItem:item];
    }
    
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view = arrangeMenu_;
    controller.preferredContentSize = arrangeMenu_.frame.size;
    
    arrangeMenu_.popover = [self runPopoverWithController:controller from:sender];
    
    visibleMenu_ = arrangeMenu_;
}

- (void) showPathMenu:(id)sender
{
    if (popoverController_ && (popoverController_.contentViewController.view == pathMenu_)) {
        [self hidePopovers];
        return;
    }
    
    if (!pathMenu_) {
        NSMutableArray  *menus = [NSMutableArray array];
        WDMenuItem      *item;
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Add Anchor Points", @"Add Anchor Points")
                                  action:@selector(addAnchors:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Delete Anchor Points", @"Delete Anchor Points")
                                  action:@selector(deleteAnchors:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Join Paths", @"Join Paths")
                                  action:@selector(joinPaths:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Outline Stroke", @"Outline Stroke")
                                  action:@selector(outlineStroke:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Combine Paths", @"Combine Paths")
                                  action:@selector(makeCompoundPath:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Separate Paths", @"Separate Paths")
                                  action:@selector(releaseCompoundPath:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Reverse Path Direction", @"Reverse Path Direction")
                                  action:@selector(reversePathDirection:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Unite", @"Unite")
                                  action:@selector(unitePaths:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Intersect", @"Intersect")
                                  action:@selector(intersectPaths:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Subtract Front", @"Subtract Front")
                                  action:@selector(subtractPaths:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Exclude", @"Exclude")
                                  action:@selector(excludePaths:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Mask", @"Mask")
                                  action:@selector(makeMask:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Unmask", @"Unmask")
                                  action:@selector(releaseMask:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Create Outlines from Text", @"Create Outlines from Text")
                                  action:@selector(createTextOutlines:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Place Text on Path", @"Place Text on Path")
                                  action:@selector(placeTextOnPath:) target:self];
        [menus addObject:item];
        
        pathMenu_ = [[WDMenu alloc] initWithItems:menus];
        pathMenu_.delegate = self;
    }
    
    for (WDMenuItem *item in pathMenu_.items) {
        [self validateMenuItem:item];
    }
    
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view = pathMenu_;
    controller.preferredContentSize = pathMenu_.frame.size;
    
    pathMenu_.popover = [self runPopoverWithController:controller from:sender];
    
    visibleMenu_ = pathMenu_;
}

- (void) showColorMenu:(id)sender
{
    if ((popoverController_ && (popoverController_.contentViewController.view == colorMenu_)) ||
        [self shouldDismissPopoverForClassController:[WDHueSaturationController class] insideNavController:YES] ||
        [self shouldDismissPopoverForClassController:[WDColorBalanceController class] insideNavController:YES])
    {
        [self hidePopovers];
        return;
    }
    
    if (!colorMenu_) {
        NSMutableArray  *menus = [NSMutableArray array];
        WDMenuItem      *item;
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Blend Back to Front", @"Blend Back to Front")
                                  action:@selector(blendColorBackToFront:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Blend Horizontally", @"Blend Horizontally")
                                  action:@selector(blendColorHorizontally:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Blend Vertically", @"Blend Vertically")
                                  action:@selector(blendColorVertically:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Color Balance…", @"Color Balance…")
                                  action:@selector(showColorBalance:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Hue and Saturation…", @"Hue and Saturation…")
                                  action:@selector(showHueAndSaturation:) target:self];
        [menus addObject:item];
        
        [menus addObject:[WDMenuItem separatorItem]];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Desaturate", @"Desaturate") action:@selector(desaturate:) target:self];
        [menus addObject:item];
        
        item = [WDMenuItem itemWithTitle:NSLocalizedString(@"Invert", @"Invert") action:@selector(invertColors:) target:self];
        [menus addObject:item];
        
        colorMenu_ = [[WDMenu alloc] initWithItems:menus];
        colorMenu_.delegate = self;
    }
    
    [self validateColorMenu];
    
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view = colorMenu_;
    controller.preferredContentSize = colorMenu_.frame.size;
    
    colorMenu_.popover = [self runPopoverWithController:controller from:((WDButton *)sender).barButtonItem];
    
    visibleMenu_ = colorMenu_;
}

- (void) validateMenuItem:(WDMenuItem *)item
{
    BOOL hasSelection = (self.drawingController.selectedObjects.count > 0) ? YES : NO;
    WDDrawingController *dc = self.drawingController;
    
    if (item.action == @selector(selectAll:) ||
        item.action == @selector(selectAllOnActiveLayer:)) {
        item.enabled = self.drawing ? YES : NO;
    }
    // OBJECT
    else if (item.action == @selector(cut:) ||
        item.action == @selector(copy:) ||
        item.action == @selector(duplicate:) ||
        item.action == @selector(duplicateInPlace:) ||
        item.action == @selector(delete:) ||
        item.action == @selector(selectNone:))
    {
        item.enabled = hasSelection;
    }
    else if (item.action == @selector(duplicateAndTransformAgain:) || item.action == @selector(transformAgain:)) {
        item.enabled = hasSelection && !dc.activePath && !CGAffineTransformEqualToTransform(dc.lastAppliedTransform, CGAffineTransformIdentity);
    }
    else if (item.action == @selector(selectAllOnActiveLayer:)) {
        item.enabled = !(self.drawing.activeLayer.locked || self.drawing.activeLayer.hidden);
    }
    else if (item.action == @selector(paste:)) {
        item.enabled = [dc canPaste];
    }
    
    // ARRANGE
    else if (item.action == @selector(align:) ||
             item.action == @selector(flipHorizontally:) ||
             item.action == @selector(flipVertically:))
    {
        item.enabled = hasSelection && !dc.activePath;
    } else if (item.action == @selector(sendToBack:) ||
               item.action == @selector(sendBackward:) ||
               item.action == @selector(bringForward:) ||
               item.action == @selector(bringToFront:))
    {
        item.enabled = hasSelection;
    } else if (item.action == @selector(group:)) {
        item.enabled = [dc canGroup];
    } else if (item.action == @selector(ungroup:)) {
        item.enabled = [dc canUngroup];
    } else if (item.action == @selector(distributeHorizontally:) ||
               item.action == @selector(distributeVertically:)) {
        item.enabled = (dc.selectedObjects.count > 2) ? YES : NO;
    }
    
    // PATH
    else if (item.action == @selector(addAnchors:)) {
        item.enabled = [dc canAddAnchors];
    } else if (item.action == @selector(deleteAnchors:)) {
        item.enabled = [dc canDeleteAnchors];
    } else if (item.action == @selector(joinPaths:)) {
        item.enabled = [dc canJoinPaths];
    } else if (item.action == @selector(makeCompoundPath:) ||
               item.action == @selector(unitePaths:) ||
               item.action == @selector(intersectPaths:) ||
               item.action == @selector(subtractPaths:) ||
               item.action == @selector(excludePaths:))
    {
        item.enabled = [dc canMakeCompoundPath];
    } else if (item.action == @selector(releaseCompoundPath:)) {
        item.enabled = [dc canReleaseCompoundPath];
    } else if (item.action == @selector(reversePathDirection:)) {
        item.enabled = [dc canReversePathDirection];
    } else if (item.action == @selector(outlineStroke:)) {
        item.enabled = [dc canOutlineStroke];
    } else if (item.action == @selector(makeMask:)) {
        item.enabled = [dc canMakeMask];
    } else if (item.action == @selector(releaseMask:)) {
        item.enabled = [dc canReleaseMask];
    } else if (item.action == @selector(createTextOutlines:)) {
        item.enabled = [dc canCreateTextOutlines];
    } else if (item.action == @selector(placeTextOnPath:)) {
        item.enabled = [dc canPlaceTextOnPath];
    }
    
    // ACTION
    else if (item.action == @selector(printDrawing:)) {
        item.enabled = [UIPrintInteractionController isPrintingAvailable];
    }
    
    // GENERIC CASE
    else {
        item.enabled = [self respondsToSelector:item.action];
    }
}

- (void) validateColorMenu
{
    NSArray     *sorted, *blendables = [self.drawingController blendables];
    BOOL        canAdjustColor = [self.drawingController canAdjustColor];
    
    for (WDMenuItem *item in colorMenu_.items) {
        if (item.action == @selector(blendColorBackToFront:) ||
            item.action == @selector(blendColorHorizontally:) ||
            item.action == @selector(blendColorVertically:))
        {
            if (blendables.count < 3) {
                item.enabled = NO;
                continue;
            }
            
            if (item.action == @selector(blendColorHorizontally:)) {
                sorted = [blendables sortedArrayUsingComparator:^(id a, id b) {
                    CGPoint centerA = WDCenterOfRect(((WDElement *) a).bounds);
                    CGPoint centerB = WDCenterOfRect(((WDElement *) b).bounds);
                    float delta = centerA.x - centerB.x;
                    return (delta < 0 ? NSOrderedAscending : (delta > 0 ? NSOrderedDescending : NSOrderedSame));
                }];
            } else if (item.action == @selector(blendColorVertically:)) {
                sorted = [blendables sortedArrayUsingComparator:^(id a, id b) {
                    CGPoint centerA = WDCenterOfRect(((WDElement *) a).bounds);
                    CGPoint centerB = WDCenterOfRect(((WDElement *) b).bounds);
                    float delta = centerA.y - centerB.y;
                    return (delta < 0 ? NSOrderedAscending : (delta > 0 ? NSOrderedDescending : NSOrderedSame));
                }];
            } else {
                sorted = blendables;
            }
            
            WDStylable *first = sorted[0];
            WDStylable *last = [sorted lastObject];
            
            item.enabled = [[first fill] isKindOfClass:[WDColor class]] && [[last fill] isKindOfClass:[WDColor class]];
        } else if (item.action == @selector(desaturate:) ||
               item.action == @selector(invertColors:) ||
               item.action == @selector(showColorBalance:) ||
               item.action == @selector(showHueAndSaturation:))
        {
            item.enabled = canAdjustColor;
        }
    }
}

- (void) validateVisibleMenuItems
{
    if (!visibleMenu_) {
        return;
    }
    
    if (visibleMenu_ == colorMenu_) {
        [self validateColorMenu];
    } else {
        for (WDMenuItem *item in visibleMenu_.items) {
            [self validateMenuItem:item];
        }
    }
}

- (void) align:(id)sender
{
    WDAlignment alignment = ((WDMenuItem *)sender).tag;
    [self.drawingController align:alignment];
}

#pragma mark -
#pragma mark Inspectors

- (void) showFontPanel:(id)sender
{
    if ([self shouldDismissPopoverForClassController:[WDFontController class] insideNavController:YES]) {
        [self hidePopovers];
        return;
    }
    
    WDFontController *controller = [[WDFontController alloc] initWithNibName:@"Font" bundle:nil];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
    controller.drawingController = self.drawingController;
    
    [self runPopoverWithController:navController from:sender];
}


- (void) showShadowPanel:(id)sender
{
    if ([self shouldDismissPopoverForClassController:[WDShadowController class] insideNavController:YES]) {
        [self hidePopovers];
        return;
    }
    
    if (!shadowController_) {
        shadowController_ = [[WDShadowController alloc] initWithNibName:@"Shadow" bundle:nil];
        shadowController_.drawingController = self.drawingController;
    }
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:shadowController_];
    [self runPopoverWithController:navController from:((WDColorWell *)sender).barButtonItem];
}

- (void) showFillStylePanel:(id)sender
{
    if ([self shouldDismissPopoverForClassController:[WDFillController class] insideNavController:YES]) {
        [self hidePopovers];
        return;
    }
    
    if (!fillController_) {
        fillController_ = [[WDFillController alloc] initWithNibName:@"Fill" bundle:nil];
        fillController_.drawingController = self.drawingController;
    }
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:fillController_];
    [self runPopoverWithController:navController from:((WDColorWell *)sender).barButtonItem];
}

- (void) showStrokeStylePanel:(id)sender
{
    if ([self shouldDismissPopoverForClassController:[WDStrokeController class] insideNavController:YES]) {
        [self hidePopovers];
        return;
    }
    
    if (!strokeController_) {
        strokeController_ = [[WDStrokeController alloc] initWithNibName:@"Stroke" bundle:nil];
        strokeController_.drawingController = self.drawingController;
    }
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:strokeController_];
    [self runPopoverWithController:navController from:((WDColorWell *)sender).barButtonItem];
}

- (void) showSwatches:(id)sender
{
    if ([self shouldDismissPopoverForClassController:[WDSwatchController class] insideNavController:YES]) {
        [self hidePopovers];
        return;
    }
    
    if (!swatchController_) {
        swatchController_ = [[WDSwatchController alloc] initWithNibName:nil bundle:nil];
        swatchController_.drawingController = self.drawingController;
    }
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:swatchController_];
    navController.toolbarHidden = NO;
    
    [self runPopoverWithController:navController from:((WDButton *)sender).barButtonItem];
}

- (void) showLayers:(id)sender
{
    if ([self shouldDismissPopoverForClassController:[WDLayerController class] insideNavController:YES]) {
        [self hidePopovers];
        return;
    }
    
    if (!layerController_) {
        layerController_ = [[WDLayerController alloc] initWithNibName:nil bundle:nil];
        layerController_.drawing = self.drawing;
    }
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:layerController_];
    navController.toolbarHidden = NO;
    
    [self runPopoverWithController:navController from:sender];
}

- (void) showHueAndSaturation:(id)sender
{
    if ([self shouldDismissPopoverForClassController:[WDHueSaturationController class] insideNavController:YES]) {
        [self hidePopovers];
        return;
    }
    
    if (!hueController_) {
        hueController_ = [[WDHueSaturationController alloc] initWithNibName:@"HueSaturation" bundle:nil];
        hueController_.drawingController = self.drawingController;
        hueController_.canvas = self.canvas;
    }
    
    [hueController_ runModalOverView:canvas_];
}

- (void) showColorBalance:(id)sender
{
    if ([self shouldDismissPopoverForClassController:[WDColorBalanceController class] insideNavController:YES]) {
        [self hidePopovers];
        return;
    }
    
    if (!balanceController_) {
        balanceController_ = [[WDColorBalanceController alloc] initWithNibName:@"ColorBalance" bundle:nil];
        balanceController_.drawingController = self.drawingController;
        balanceController_.canvas = self.canvas;
    }
    
    [balanceController_ runModalOverView:canvas_];
}

#pragma mark -
#pragma mark Popover Management

- (UIPopoverController *) runPopoverWithController:(UIViewController *)controller from:(id)sender
{
    [self hidePopovers];
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:controller];
	popoverController_.delegate = self;
    popoverController_.passthroughViews = @[self.navigationController.toolbar,
                                           self.navigationController.navigationBar,
                                           self.canvas];
    [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    
    return popoverController_;
}

- (void) hidePopovers
{
    if (popoverController_) {
        [popoverController_ dismissPopoverAnimated:NO];
        popoverController_ = nil;
        visibleMenu_ = nil;
    }
    
    [[UIPrintInteractionController sharedPrintController] dismissAnimated:NO];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (popoverController == popoverController_) {
        popoverController_ = nil;
        visibleMenu_ = nil;
    }
}

- (void) undo:(id)sender
{
    [document_.undoManager undo];
}

- (void) redo:(id)sender
{
    [document_.undoManager redo];
}

#pragma mark -
#pragma mark Toolbar Stuff

- (NSArray *) editingItems
{
    if (editingItems_) {
        return editingItems_;
    } 

    UIBarButtonItem *objectItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Edit", @"Edit")
                                                 style:UIBarButtonItemStyleBordered
                                                target:self
                                                action:@selector(showObjectMenu:)];
    
    UIBarButtonItem *arrangeItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Arrange", @"Arrange")
                                                                 style:UIBarButtonItemStyleBordered
                                                                target:self
                                                                action:@selector(showArrangeMenu:)];
    
    UIBarButtonItem *pathItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Path", @"Path")
                                                                   style:UIBarButtonItemStyleBordered
                                                                  target:self
                                                                  action:@selector(showPathMenu:)];
    
    WDButton *imageButton = [WDButton buttonWithType:UIButtonTypeCustom];
    imageButton.showsTouchWhenHighlighted = YES;
    [imageButton setImage:[UIImage imageNamed:@"color_wheel.png"] forState:UIControlStateNormal];
    [imageButton addTarget:self action:@selector(showColorMenu:) forControlEvents:UIControlEventTouchUpInside];
    [imageButton sizeToFit];
    CGRect frame = imageButton.frame;
    frame.size.height = 44;
    imageButton.frame = frame;
    colorItem_ = [[UIBarButtonItem alloc] initWithCustomView:imageButton];
    imageButton.barButtonItem = colorItem_;
    
    
    UIBarButtonItem *fontItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"font.png"]
                                                 style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(showFontPanel:)];
    
	undoItem_ = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"undo.png"]
                                                 style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(undo:)];
    
    redoItem_ = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"redo.png"]
                                                 style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(redo:)];
    
    imageButton = [WDButton buttonWithType:UIButtonTypeCustom];
    imageButton.showsTouchWhenHighlighted = YES;
    [imageButton setImage:[UIImage imageNamed:@"swatches.png"] forState:UIControlStateNormal];
    [imageButton addTarget:self action:@selector(showSwatches:) forControlEvents:UIControlEventTouchUpInside];
    [imageButton sizeToFit];
    frame = imageButton.frame;
    frame.size.height = 44;
    imageButton.frame = frame;
    UIBarButtonItem *swatchItem = [[UIBarButtonItem alloc] initWithCustomView:imageButton];
    imageButton.barButtonItem = swatchItem;
    
    layerItem_ = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Layers", @"Layers")
                                                  style:UIBarButtonItemStyleBordered
                                                 target:self
                                                 action:@selector(showLayers:)];
    
    UIBarButtonItem *flexibleItem = [UIBarButtonItem flexibleItem];
    UIBarButtonItem *fixedItem = [UIBarButtonItem fixedItemWithWidth:16];
    UIBarButtonItem *smallFixedItem = [UIBarButtonItem fixedItemWithWidth:8];
    
    shadowWell_ = [[WDShadowWell alloc] initWithFrame:CGRectMake(0, 0, 28, 44)];
    UIBarButtonItem *shadowItem = [[UIBarButtonItem alloc] initWithCustomView:shadowWell_];
    shadowWell_.barButtonItem = shadowItem;
    [shadowWell_ addTarget:self action:@selector(showShadowPanel:) forControlEvents:UIControlEventTouchUpInside];
    [shadowWell_ setShadow:[self.drawingController.propertyManager activeShadow]];
    [shadowWell_ setOpacity:[[self.drawingController.propertyManager defaultValueForProperty:WDOpacityProperty] floatValue]];
    
    fillWell_ = [[WDColorWell alloc] initWithFrame:CGRectMake(0, 0, 28, 44)];
    UIBarButtonItem *fillItem = [[UIBarButtonItem alloc] initWithCustomView:fillWell_];
    fillWell_.barButtonItem = fillItem;
    [fillWell_ addTarget:self action:@selector(showFillStylePanel:) forControlEvents:UIControlEventTouchUpInside];
    [fillWell_ setPainter:[self.drawingController.propertyManager activeFillStyle]];
    
    strokeWell_ = [[WDColorWell alloc] initWithFrame:CGRectMake(0, 0, 28, 44)];
    strokeWell_.strokeMode = YES;
    UIBarButtonItem *strokeItem = [[UIBarButtonItem alloc] initWithCustomView:strokeWell_];
    strokeWell_.barButtonItem = strokeItem;
    [strokeWell_ addTarget:self action:@selector(showStrokeStylePanel:) forControlEvents:UIControlEventTouchUpInside];
    [strokeWell_ setPainter:[self.drawingController.propertyManager activeStrokeStyle].color];
    
    
	editingItems_ = @[objectItem, smallFixedItem,
                     arrangeItem, smallFixedItem,
                     pathItem, fixedItem,
                     colorItem_, fixedItem,
                     undoItem_, fixedItem,
                     redoItem_, flexibleItem, 
                     fontItem, fixedItem,
                     shadowItem, fixedItem,
                     strokeItem, fixedItem,
                     fillItem, fixedItem,
                     swatchItem, fixedItem,
                     layerItem_];
    
    return editingItems_;
}

- (NSArray *) upperRightToolbarItems
{
    
    actionItem_ = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                   target:self action:@selector(showActionMenu:)];
    
    gearItem_ = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"]
                                                 style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(showSettingsMenu:)];
    
    albumItem_ = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"album.png"]
                                                  style:UIBarButtonItemStylePlain
                                                 target:self
                                                 action:@selector(showPhotoBrowser:)];
    
    zoomToFitItem_ = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"zoom_to_fit.png"]
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(scaleDocumentToFit:)];
    
	NSArray *items = @[actionItem_, gearItem_, albumItem_, zoomToFitItem_];
    
    // make sure the album item has the proper enabled state
    albumItem_.enabled = self.drawing.activeLayer.editable;
    
    return items;    
}

- (void) enableDocumentItems
{
    BOOL enabled = self.drawing ? YES : NO;
    
    actionItem_.enabled = enabled;
    albumItem_.enabled = enabled && self.drawing.activeLayer.editable;
    gearItem_.enabled = enabled;
    layerItem_.enabled = enabled;
    zoomToFitItem_.enabled = enabled;
}

#pragma mark -
#pragma mark Notifications

- (void) activeToolChanged:(NSNotification *)aNotification
{
    self.drawingController.activePath = nil;
    [canvas_ setShowsPivot:[WDToolManager sharedInstance].activeTool.needsPivot];
    [self hidePopovers];
    
    [self.canvas setToolOptionsView:[WDToolManager sharedInstance].activeTool.optionsView];
    
    [canvas_ invalidateSelectionView];
}
 
- (void) fillChanged:(NSNotification *)aNotification
{
    [fillWell_ setPainter:[self.drawingController.propertyManager activeFillStyle]];
}

- (void) strokeStyleChanged:(NSNotification *)aNotification
{
    [strokeWell_ setPainter:[self.drawingController.propertyManager activeStrokeStyle].color];
}

- (void) shadowChanged:(NSNotification *)aNotification
{
    WDPropertyManager *pm = self.drawingController.propertyManager;
    
    [shadowWell_ setShadow:[pm activeShadow]];
    [shadowWell_ setOpacity:[[pm defaultValueForProperty:WDOpacityProperty] floatValue]];
}

- (void) rulerVisibleSettingChanged:(NSNotification *)aNotification
{
    [canvas_ showRulers:self.drawing.rulersVisible animated:!self.drawing.rulersVisible];
}

- (void) undoStatusDidChange:(NSNotification *)aNotification
{
    dispatch_async(dispatch_get_main_queue(), ^{ 
        undoItem_.enabled = [document_.undoManager canUndo];
        redoItem_.enabled = [document_.undoManager canRedo];
        
        // stick this at the end of the queue to make sure that
        // the model has time to respond to the notification first
        [self validateVisibleMenuItems];
    });
}

- (void) activeLayerChanged:(NSNotification *)aNotification
{
    albumItem_.enabled = self.drawing.activeLayer.editable;
    
    if (self.drawing.isolateActiveLayer) {
        [canvas_ setNeedsDisplay];
    }
}

- (void) layerLockedStatusChanged:(NSNotification *)aNotification
{
    albumItem_.enabled = self.drawing.activeLayer.editable;
}

- (void) layerVisibilityChanged:(NSNotification *)aNotification
{
    albumItem_.enabled = self.drawing.activeLayer.editable;
}

#pragma mark -
#pragma mark View Controller Stuff

- (void)loadView
{
    canvas_ = [[WDCanvas alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    canvas_.controller = self;
    self.view = canvas_;
    
    // we don't want to go under the nav bar and tool bar
    self.edgesForExtendedLayout = UIRectEdgeNone;
}

- (void) didEnterBackground:(NSNotification *)aNotification
{
    if ([self.document hasUnsavedChanges]) {
        // might get terminated while backgrounded, so save now        
        UIApplication              *app = [UIApplication sharedApplication];
        
        __block UIBackgroundTaskIdentifier task = [app beginBackgroundTaskWithExpirationHandler:^{
            if (task != UIBackgroundTaskInvalid) {
                [app endBackgroundTask:task];
            }
        }];
        
        [self.document saveToURL:self.document.fileURL
                forSaveOperation:UIDocumentSaveForOverwriting
               completionHandler:^(BOOL success) {
                   if (task != UIBackgroundTaskInvalid) {
                       [app endBackgroundTask:task];
                   }
               }];
    }
    
    // save the user defaults
    [self.drawingController.propertyManager updateUserDefaults];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [self hidePopovers];
    
    // revert back to selection tool
    [WDToolManager sharedInstance].activeTool = ([WDToolManager sharedInstance].tools)[0];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (canvas_.drawing) {
        return;
    }
    
    [super viewWillAppear:animated];
    
    [self setToolbarItems:[self editingItems] animated:YES];
    
    // make sure the undo/redo buttons have the correct enabled state
    undoItem_.enabled = NO;
    redoItem_.enabled = NO;
    
    // set a good background color for the window so that orientation changes don't look hideous
    [UIApplication sharedApplication].keyWindow.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1];
    
    self.navigationItem.rightBarButtonItems = [self upperRightToolbarItems];

    if (self.drawing) {
        canvas_.drawing = self.drawing;
        [canvas_ scaleDocumentToFit];
        [canvas_ showRulers:self.drawing.rulersVisible];
    } else {
        [canvas_ startActivity];
    }
    
    [self enableDocumentItems];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (document_.documentState != UIDocumentStateClosed) {
        [document_ closeWithCompletionHandler:nil];
    }
}

#pragma mark - Loading

- (void) updateTitle
{
    if (!self.drawing) {
        return;
    }
    
    NSString    *filename = [self.document.filename stringByDeletingPathExtension];
    int         zoom = round(canvas_.displayableScale);
    BOOL        numericName = YES;
    
    for (int i = 0; i < filename.length; i++) {
        if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[filename characterAtIndex:i]]) {
            numericName = NO;
            break;
        }
    }
    
    if (numericName) {
        filename = [NSString stringWithFormat:@"Drawing %@", filename];
    }
    
    if (filename.length > kMaxDisplayableFilename + 3) { // add 3 to account for the ellipsis
        filename = [[filename substringToIndex:kMaxDisplayableFilename] stringByAppendingString:@"…"];
    }
    
    self.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"%@ @ %d%%", @"Drawing Title @ Z%"), filename, zoom];
}

- (void) registerNotifications
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // stop listening to everything
    [nc removeObserver:self];
    
    // listen for generic stuff
    [nc addObserver:self selector:@selector(activeToolChanged:) name:WDActiveToolDidChange object:nil];
    [nc addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    // listen to the new drawing
    [nc addObserver:self selector:@selector(layerLockedStatusChanged:) name:WDLayerLockedStatusChanged object:self.drawing];
    [nc addObserver:self selector:@selector(layerVisibilityChanged:) name:WDLayerVisibilityChanged object:self.drawing];
    [nc addObserver:self selector:@selector(activeLayerChanged:) name:WDActiveLayerChanged object:self.drawing];
    [nc addObserver:self selector:@selector(rulerVisibleSettingChanged:) name:WDRulersVisibleSettingChangedNotification object:self.drawing];
    
    // listen to the new undo manager
    NSUndoManager *undoManager = drawingController_.drawing.undoManager;
    [nc addObserver:self selector:@selector(undoStatusDidChange:) name:NSUndoManagerDidUndoChangeNotification object:undoManager];
    [nc addObserver:self selector:@selector(undoStatusDidChange:) name:NSUndoManagerDidRedoChangeNotification object:undoManager];
    [nc addObserver:self selector:@selector(undoStatusDidChange:) name:NSUndoManagerDidCloseUndoGroupNotification object:undoManager];
    
    // listen for property changes
    WDPropertyManager *pm = drawingController_.propertyManager;
    [nc addObserver:self selector:@selector(fillChanged:) name:WDActiveFillChangedNotification object:pm];
    [nc addObserver:self selector:@selector(strokeStyleChanged:) name:WDActiveStrokeChangedNotification object:pm];
    [nc addObserver:self selector:@selector(shadowChanged:) name:WDActiveShadowChangedNotification object:pm];
}

- (void) documentStateChanged:(NSNotification *)aNotification
{
    if (self.document.documentState == UIDocumentStateNormal) {
        [canvas_ stopActivity];
        
        drawingController_.drawing = self.drawing;
        canvas_.drawing = self.drawing;
        // if we have a layer controller, we need to change its drawing
        layerController_.drawing = self.drawing;
        
        [self registerNotifications];
        [self updateTitle];
        [self enableDocumentItems];
        [self undoStatusDidChange:nil];
    }
}

- (void) setDocument:(WDDocument *)document
{
    if (document != self.document) {
        [canvas_ startActivity];
        [CATransaction flush];
        
        if (document_ && (document_.documentState != UIDocumentStateClosed)) {
            [document_ closeWithCompletionHandler:nil];
        }
        
        // hide various UI elements
        [self hidePopovers];
        [balanceController_ cancel:nil];
        [hueController_ cancel:nil];
    }
    
    document_ = document;
    
    // see if we need to create a new drawing controller
    if (!drawingController_ || (self.drawing && (self.drawing != drawingController_.drawing))) {
        drawingController_ = [[WDDrawingController alloc] init];
        
        // update sub controllers if they've been created
        shadowController_.drawingController = drawingController_;
        strokeController_.drawingController = drawingController_;
        fillController_.drawingController = drawingController_;
        swatchController_.drawingController = drawingController_;
        hueController_.drawingController = drawingController_;
        balanceController_.drawingController = drawingController_;
    }
    
    if (document_.documentState == UIDocumentStateNormal) {
        [self documentStateChanged:nil];
    } else {
        // listen for this document to load
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentStateChanged:)
                                                     name:UIDocumentStateChangedNotification object:document_];
    }
}

#pragma mark - Edit

- (void) selectAll:(id)sender
{
    [self.drawingController selectAll:sender];
}

#pragma mark - Path

- (void) placeTextOnPath:(id)sender
{
    BOOL startEditing = NO;
    
    WDTextPath *path = [self.drawingController placeTextOnPath:sender shouldStartEditing:&startEditing];
    
    if (startEditing) {
        [self editTextObject:(WDText *)path selectAll:YES];
    }
}

#pragma mark - Action Menu

- (void) addToPhotoAlbum:(id)sender
{
    UIImageWriteToSavedPhotosAlbum([canvas_.drawing image], self, nil, NULL);
}

- (void) printDrawing:(id)sender
{
    UIPrintInteractionController *printController = [UIPrintInteractionController sharedPrintController];
    printController.printingItem = [self.drawing PDFRepresentation];
    [printController presentFromBarButtonItem:actionItem_ animated:NO completionHandler:nil];
}

- (void) postOnFacebook:(id)sender
{
    SLComposeViewController *facebookSheet = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
    
    [facebookSheet addImage:self.drawing.image];
    [facebookSheet setInitialText:NSLocalizedString(@"Check out my Inkpad drawing!", @"Check out my Inkpad drawing!")];
    
    dispatch_async(dispatch_get_main_queue(), ^ {
        [self presentViewController:facebookSheet animated:YES completion:nil];
    });
}

- (void) tweetDrawing:(id)sender
{
    SLComposeViewController *tweetSheet = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    
    [tweetSheet addImage:self.drawing.image];
    [tweetSheet setInitialText:NSLocalizedString(@"Check out my Inkpad drawing!", @"Check out my Inkpad drawing!")];

    [self hidePopovers];
    
    [self presentViewController:tweetSheet animated:YES completion:nil];
}

- (void) copyDrawing:(id)sender
{
    [UIPasteboard generalPasteboard].image = [canvas_.drawing image];
}

- (void) duplicateDrawing:(id)sender
{
    [self setDocument:[[WDDrawingManager sharedInstance] duplicateDrawing:self.document]];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:1.0f];
    [UIView setAnimationTransition:UIViewAnimationTransitionCurlUp forView:canvas_ cache:YES];
    [UIView commitAnimations];
}

- (void) export:(id)sender format:(NSString *)format
{
    NSString *baseFilename = [self.document.filename stringByDeletingPathExtension];
    NSString *filename = nil;

    // Generates export file in requested format
    if ([format isEqualToString:@"PDF"]) {
        filename = [NSTemporaryDirectory() stringByAppendingPathComponent:[baseFilename stringByAppendingPathExtension:@"pdf"]];
        [[self.drawing PDFRepresentation] writeToFile:filename atomically:YES];
    } else if ([format isEqualToString:@"PNG"]) {
        filename = [NSTemporaryDirectory() stringByAppendingPathComponent:[baseFilename stringByAppendingPathExtension:@"png"]];
        [UIImagePNGRepresentation([canvas_.drawing image]) writeToFile:filename atomically:YES];
    } else if ([format isEqualToString:@"SVG"]) {
        filename = [NSTemporaryDirectory() stringByAppendingPathComponent:[baseFilename stringByAppendingPathExtension:@"svg"]];
        [[self.drawing SVGRepresentation] writeToFile:filename atomically:YES];
    }

    // Passes exported file to UIDocumentInteractionController
    exportFileUrl = [NSURL fileURLWithPath:filename];
    if(exportFileUrl) {
        self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:exportFileUrl];
        [self.documentInteractionController setDelegate:self];
        [self.documentInteractionController presentPreviewAnimated:YES];
    }
}

- (void) exportAsPNG:(id)sender
{
    [self export:sender format:@"PNG"];
}

- (void) exportAsPDF:(id)sender
{
    [self export:sender format:@"PDF"];
}

- (void) exportAsSVG:(id)sender
{
    [self export:sender format:@"SVG"];
}

#pragma mark - UIDocumentInteractionController

- (UIViewController *) documentInteractionControllerViewControllerForPreview: (UIDocumentInteractionController *) controller {
    return self;
}

- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController *)controller
{
    // Clean up by removing generated file
    NSError *error;
    if(exportFileUrl) {
        [[NSFileManager defaultManager] removeItemAtURL:exportFileUrl error:&error];
    }
}

@end
