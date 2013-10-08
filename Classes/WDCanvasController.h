//
//  WDCanvasController.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "WDElement.h"
#import "WDStrokeStyle.h"

@class WDCanvas;
@class WDColorBalanceController;
@class WDColorWell;
@class WDDocument;
@class WDDrawing;
@class WDDrawingController;
@class WDFillController;
@class WDHueSaturationController;
@class WDLayerController;
@class WDMenu;
@class WDMenuItem;
@class WDStrokeController;
@class WDSwatchController;
@class WDShadowController;
@class WDShadowWell;
@class WDText;

enum {
    kAddToPhotos = 0,
    kCopyDrawing,
    kDuplicateDrawing,
    kPrintDrawing,
    kEmailDrawing
};

@interface WDCanvasController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate,
                                                    MFMailComposeViewControllerDelegate, UIPopoverControllerDelegate>
{
    WDDocument          *document_;
    WDCanvas            *canvas_;
    NSArray             *editingItems_;
    
    UIBarButtonItem     *albumItem_;
    UIBarButtonItem     *zoomToFitItem_;
    UIBarButtonItem     *gearItem_;
    UIBarButtonItem     *actionItem_;
    
    UIBarButtonItem     *undoItem_;
    UIBarButtonItem     *redoItem_;
    UIBarButtonItem     *colorItem_;
    UIBarButtonItem     *layerItem_;
    
    WDShadowWell        *shadowWell_;
    WDColorWell         *fillWell_;
    WDColorWell         *strokeWell_;
    
    WDMenu              *objectMenu_;
    WDMenu              *arrangeMenu_;
    WDMenu              *pathMenu_;
    WDMenu              *colorMenu_;
    WDMenu              *actionMenu_;
    WDMenu              *visibleMenu_; // pointer to currently active menu
    
    UIPopoverController *popoverController_;
    
    WDSwatchController  *swatchController_;
    WDStrokeController  *strokeController_;
    WDFillController    *fillController_;
    WDShadowController  *shadowController_;
    WDLayerController   *layerController_;
    
    WDHueSaturationController   *hueController_;
    WDColorBalanceController   *balanceController_;
}

@property (nonatomic, strong) WDDocument *document;
@property (weak, nonatomic, readonly) WDDrawing *drawing;
@property (nonatomic, readonly) WDCanvas *canvas;
@property (nonatomic, readonly, strong) WDDrawingController *drawingController;

- (void) updateTitle;
- (void) hidePopovers;

- (BOOL) shouldDismissPopoverForClassController:(Class)controllerClass insideNavController:(BOOL)insideNav;
- (UIPopoverController *) runPopoverWithController:(UIViewController *)controller from:(id)sender;

- (void) validateMenuItem:(WDMenuItem *)item;
- (void) validateVisibleMenuItems;
- (void) validateColorMenu;

- (void) editTextObject:(WDText *)text selectAll:(BOOL)selectAll;
- (void) undoStatusDidChange:(NSNotification *)aNotification;

@end

