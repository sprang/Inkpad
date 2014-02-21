//
//  WDBrowserController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <DropboxSDK/DropboxSDK.h>
#import "OCAEntry.h"
#import "OCAViewController.h"
#import "NSData+Additions.h"
#import "WDActivity.h"
#import "WDActivityController.h"
#import "WDActivityManager.h"
#import "WDAppDelegate.h"
#import "WDBlockingView.h"
#import "WDBrowserController.h"
#import "WDCanvasController.h"
#import "WDDocument.h"
#import "WDDrawing.h"
#import "WDDrawingManager.h"
#import "WDEmail.h"
#import "WDExportController.h"
#import "WDFontLibraryController.h"
#import "WDFontManager.h"
#import "WDPageSizeController.h"
#import "WDThumbnailView.h"
#import "UIBarButtonItem+Additions.h"

#define kEditingHighlightRadius     125

NSString *WDAttachmentNotification = @"WDAttachmentNotification";

@implementation WDBrowserController

#pragma mark -

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (!self) {
        return nil;
    }
    
    selectedDrawings_ = [[NSMutableSet alloc] init];
    filesBeingUploaded_ = [[NSMutableSet alloc] init];
    activities_ = [[WDActivityManager alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawingChanged:)
                                                 name:UIDocumentStateChangedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawingAdded:)
                                                 name:WDDrawingAdded
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawingsDeleted:)
                                                 name:WDDrawingsDeleted
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dropboxUnlinked:)
                                                 name:WDDropboxWasUnlinkedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(activityCountChanged:)
                                                 name:WDActivityAddedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(activityCountChanged:)
                                                 name:WDActivityRemovedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(emailAttached:)
                                                 name:WDAttachmentNotification
                                               object:nil];
    
    self.navigationItem.title = NSLocalizedString(@"Gallery", @"Gallery");
    
    NSMutableArray *rightBarButtonItems = [NSMutableArray array];

    // Create an "add new drawing" button
    UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                             target:self
                                                                             action:@selector(addDrawing:)];
    [rightBarButtonItems addObject:addItem];
    
    // create an album import button
    UIBarButtonItem *albumItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"album_centered.png"]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(importFromAlbum:)];
    [rightBarButtonItems addObject:albumItem];
    
    // add a camera import item if we have a camera (I think this will always be true from now on)
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        UIBarButtonItem *cameraItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera
                                                                                    target:self
                                                                                    action:@selector(importFromCamera:)];
        [rightBarButtonItems addObject:cameraItem];
    }
    
    UIBarButtonItem *openClipArtItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"openclipart.png"]
                                                                        style:UIBarButtonItemStylePlain
                                                                       target:self
                                                                       action:@selector(showOpenClipArt:)];
    [rightBarButtonItems addObject:openClipArtItem];

    // Create a help button to display in the top left corner.
    UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Help", @"Help")
                                                                 style:UIBarButtonItemStyleBordered
                                                                target:self
                                                                action:@selector(showHelp:)];
    self.navigationItem.leftBarButtonItem = leftItem;
    self.navigationItem.rightBarButtonItems = rightBarButtonItems;
    self.toolbarItems = [self defaultToolbarItems];
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (void) startEditingDrawing:(WDDocument *)document
{
    [self setEditing:NO animated:NO];
    
    WDCanvasController *canvasController = [[WDCanvasController alloc] init];
    [canvasController setDocument:document];
    
    [self.navigationController pushViewController:canvasController animated:YES];
}

- (void) createNewDrawing:(id)sender
{
    WDDocument *document = [[WDDrawingManager sharedInstance] createNewDrawingWithSize:pageSizeController_.size
                                                                              andUnits:pageSizeController_.units];

    [self startEditingDrawing:document];
    
    [self dismissPopover];
}

- (void) addDrawing:(id)sender
{
    if (popoverController_) {
        [self dismissPopover];
    } else {
        pageSizeController_ = [[WDPageSizeController alloc] initWithNibName:nil bundle:nil];
        UINavigationController  *navController = [[UINavigationController alloc] initWithRootViewController:pageSizeController_];
        
        pageSizeController_.target = self;
        pageSizeController_.action = @selector(createNewDrawing:);
        
        popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
        popoverController_.delegate = self;
        [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
    }
}

#pragma mark - OpenClipArt

- (void) takeDataFromDownloader:(OCADownloader *)downloader
{
    NSString *title = [downloader.info stringByAppendingPathExtension:@"svg"];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:title];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [downloader.data writeToFile:path atomically:YES];
        
        NSURL *pathURL = [[NSURL alloc] initFileURLWithPath:path isDirectory:NO];
        [[WDDrawingManager sharedInstance] importDrawingAtURL:pathURL
                                                   errorBlock:^{
                                                       [self showImportErrorMessage:downloader.info];
                                                       [[NSFileManager defaultManager] removeItemAtURL:pathURL error:nil];
                                                   }
                                        withCompletionHandler:^(WDDocument *document) {
                                            [[NSFileManager defaultManager] removeItemAtURL:pathURL error:nil];
                                        }];
    }
    
    [downloaders_ removeObject:downloader];
}

- (void) importOpenClipArt:(OCAViewController *)viewController
{
    OCAEntry *entry = viewController.selectedEntry;
    
    if (!downloaders_) {
        downloaders_ = [NSMutableSet set];
    }
    
    OCADownloader *downloader = [OCADownloader downloaderWithURL:entry.SVGURL delegate:self info:entry.title];
    [downloaders_ addObject:downloader];
    
    if (openClipArtController_.isVisible) {
        [self dismissPopover];
    }
}

- (void) showOpenClipArt:(id)sender
{
    if (openClipArtController_.isVisible) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    if (!openClipArtController_) {
        openClipArtController_ = [[OCAViewController alloc] initWithNibName:@"OpenClipArt" bundle:nil];
        [openClipArtController_ setImportTarget:self action:@selector(importOpenClipArt:)];
        [openClipArtController_ setActionTitle:NSLocalizedString(@"Import", @"Import")];
    }
    
    UINavigationController  *navController = [[UINavigationController alloc] initWithRootViewController:openClipArtController_];
    navController.toolbarHidden = NO;
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
    popoverController_.delegate = self;
    [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

#pragma mark - Camera

- (void) importFromImagePicker:(id)sender sourceType:(UIImagePickerControllerSourceType)sourceType
{
    if (pickerController_ && (pickerController_.sourceType == sourceType)) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    pickerController_ = [[UIImagePickerController alloc] init];
    pickerController_.sourceType = sourceType;
    pickerController_.delegate = self;
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:pickerController_];
    
    popoverController_.delegate = self;
    [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

- (void) importFromAlbum:(id)sender
{
    [self importFromImagePicker:sender sourceType:UIImagePickerControllerSourceTypePhotoLibrary];
}

- (void) importFromCamera:(id)sender
{
    [self importFromImagePicker:sender sourceType:UIImagePickerControllerSourceTypeCamera];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self imagePickerControllerDidCancel:picker];
    [[WDDrawingManager sharedInstance] createNewDrawingWithImage:info[UIImagePickerControllerOriginalImage]];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [popoverController_ dismissPopoverAnimated:YES];
    popoverController_ = nil;
}

#pragma mark - View Lifecycle

- (void) viewWillAppear:(BOOL)animated
{
    if (!everLoaded_) {
        if ([[WDDrawingManager sharedInstance] numberOfDrawings] > 0) {
            // scroll to bottom
            NSUInteger count = [[WDDrawingManager sharedInstance] numberOfDrawings] - 1;
            [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:count inSection:0]
                                        atScrollPosition:UICollectionViewScrollPositionTop
                                                animated:NO];
        }
        
        everLoaded_ = YES;
    }
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (editingThumbnail_) {
        [editingThumbnail_ stopEditing];
    }
}

- (void) keyboardWillShow:(NSNotification *)aNotification
{
    if (!editingThumbnail_ || blockingView_) {
        return;
    }
    
    NSValue     *endFrame = [aNotification userInfo][UIKeyboardFrameEndUserInfoKey];
    NSNumber    *duration = [aNotification userInfo][UIKeyboardAnimationDurationUserInfoKey];
    CGRect      frame = [endFrame CGRectValue];
    float       delta = 0;
    
    CGRect thumbFrame = editingThumbnail_.frame;
    thumbFrame.size.height += 20; // add a little extra margin between the thumb and the keyboard
    frame = [self.collectionView convertRect:frame fromView:nil];
    
    if (CGRectIntersectsRect(thumbFrame, frame)) {
        delta = CGRectGetMaxY(thumbFrame) - CGRectGetMinY(frame);
        
        CGPoint offset = self.collectionView.contentOffset;
        offset.y += delta;
        [self.collectionView setContentOffset:offset animated:YES];
    }
    
    blockingView_ = [[WDBlockingView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    WDAppDelegate *delegate = (WDAppDelegate *) [UIApplication sharedApplication].delegate;
    
    blockingView_.passthroughViews = @[editingThumbnail_.titleField];
    [delegate.window addSubview:blockingView_];
    
    blockingView_.target = self;
    blockingView_.action = @selector(blockingViewTapped:);
    
    CGPoint shadowCenter = [self.collectionView convertPoint:editingThumbnail_.center toView:delegate.window];
    [blockingView_ setShadowCenter:shadowCenter radius:kEditingHighlightRadius];
    blockingView_.alpha = 0;
    
    [UIView animateWithDuration:[duration doubleValue] animations:^{ blockingView_.alpha = 1; }];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (blockingView_ && editingThumbnail_) {
        WDAppDelegate *delegate = (WDAppDelegate *) [UIApplication sharedApplication].delegate;
        CGPoint shadowCenter = [self.collectionView convertPoint:editingThumbnail_.center toView:delegate.window];
        [blockingView_ setShadowCenter:shadowCenter radius:kEditingHighlightRadius];
    }
}

- (void) didEnterBackground:(NSNotification *)aNotification
{
    if (!editingThumbnail_) {
        return;
    }
    
    [editingThumbnail_ stopEditing];
}

#pragma mark - Thumbnail Editing

- (BOOL) thumbnailShouldBeginEditing:(WDThumbnailView *)thumb
{
    if (self.isEditing) {
        return NO;
    }
    
    // can't start editing if we're already editing another thumbnail
    return (editingThumbnail_ ? NO : YES);
}

- (void) blockingViewTapped:(id)sender
{
    [editingThumbnail_ stopEditing];
}

- (void) thumbnailDidBeginEditing:(WDThumbnailView *)thumbView
{
    editingThumbnail_ = thumbView;
}

- (void) thumbnailDidEndEditing:(WDThumbnailView *)thumbView
{
    [UIView animateWithDuration:0.2f
                     animations:^{ blockingView_.alpha = 0; }
                     completion:^(BOOL finished) {
                         [blockingView_ removeFromSuperview];
                         blockingView_ = nil;
                     }];
    
    editingThumbnail_ = nil;
}

- (WDThumbnailView *) getThumbnail:(NSString *)filename
{
    NSString *barefile = [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"inkpad"];
    NSIndexPath *indexPath = [[WDDrawingManager sharedInstance] indexPathForFilename:barefile];
    
    return (WDThumbnailView *) [self.collectionView cellForItemAtIndexPath:indexPath];
}

#pragma mark - Drawing Notifications

- (void) drawingChanged:(NSNotification *)aNotification
{
    WDDocument *document = [aNotification object];
    
    [[self getThumbnail:document.filename] reload];
}

- (void) drawingAdded:(NSNotification *)aNotification
{
    NSUInteger count = [[WDDrawingManager sharedInstance] numberOfDrawings] - 1;
    NSArray *indexPaths = @[[NSIndexPath indexPathForItem:count inSection:0]];
    [self.collectionView insertItemsAtIndexPaths:indexPaths];
}

- (void) drawingsDeleted:(NSNotification *)aNotification
{
    NSArray *indexPaths = aNotification.object;
    [self.collectionView deleteItemsAtIndexPaths:indexPaths];
    
    [selectedDrawings_ removeAllObjects];
    [self properlyEnableToolbarItems];
}

#pragma mark - Deleting Drawings

- (void) deleteSelectedDrawings
{
    NSString *format = NSLocalizedString(@"Delete %d Drawings", @"Delete %d Drawings");
    NSString *title = (selectedDrawings_.count) == 1 ? NSLocalizedString(@"Delete Drawing", @"Delete Drawing") :
    [NSString stringWithFormat:format, selectedDrawings_.count];
    
    NSString *message;
    
    if (selectedDrawings_.count == 1) {
        message = NSLocalizedString(@"Once deleted, this drawing cannot be recovered.", @"Alert text when deleting 1 drawing");
    } else {
        message = NSLocalizedString(@"Once deleted, these drawings cannot be recovered.", @"Alert text when deleting multiple drawings");
    }
    
    NSString *deleteButtonTitle = NSLocalizedString(@"Delete", @"Delete");
    NSString *cancelButtonTitle = NSLocalizedString(@"Cancel", @"Cancel");

    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:deleteButtonTitle, cancelButtonTitle, nil];
    alertView.cancelButtonIndex = 1;
    
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.cancelButtonIndex) {
        return;
    }
    
    [[WDDrawingManager sharedInstance] deleteDrawings:selectedDrawings_];
}

- (void) showDeleteMenu:(id)sender
{
    if (deleteSheet_) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    NSString *format = NSLocalizedString(@"Delete %d Drawings", @"Delete %d Drawings");
    NSString *title = (selectedDrawings_.count) == 1 ?
        NSLocalizedString(@"Delete Drawing", @"Delete Drawing") :
        [NSString stringWithFormat:format, selectedDrawings_.count];
    
	deleteSheet_ = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@""
                                 destructiveButtonTitle:title otherButtonTitles:nil];

    [deleteSheet_ showFromBarButtonItem:sender animated:YES];
}
     
 - (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (actionSheet == deleteSheet_) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self deleteSelectedDrawings];
        }
    }
    
    deleteSheet_ = nil;
}

#pragma mark - Editing

- (void) startEditing:(id)sender
{
    [self setEditing:YES animated:YES];
}

- (void) stopEditing:(id)sender
{
    [self setEditing:NO animated:YES];
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated
{
    [self dismissPopover];
    
    [super setEditing:editing animated:animated];
    
    if (editing) {
        self.title = NSLocalizedString(@"Select Drawings", @"Select Drawings");
        [self setToolbarItems:[self editingToolbarItems] animated:NO];
        [self properlyEnableToolbarItems];
    } else {
        self.title = NSLocalizedString(@"Gallery", @"Gallery");

        self.collectionView.allowsSelection = NO;
        self.collectionView.allowsSelection = YES;
        
        [selectedDrawings_ removeAllObjects];
        [self setToolbarItems:[self defaultToolbarItems] animated:NO];
    }
    
    self.collectionView.allowsMultipleSelection = editing;
}

#pragma mark - Toolbar

- (void) properlyEnableToolbarItems
{
    deleteItem_.enabled = [selectedDrawings_ count] == 0 ? NO : YES;
    emailItem_.enabled = ([selectedDrawings_ count] > 0 && [selectedDrawings_ count] < 6) ? YES : NO;
    dropboxExportItem_.enabled = [selectedDrawings_ count] == 0 ? NO : (filesBeingUploaded_.count == 0 ? YES : NO);
    
    if (filesBeingUploaded_.count) {
        dropboxExportItem_.title = NSLocalizedString(@"Uploading...", @"Uploading...");
    } else {
        dropboxExportItem_.title = NSLocalizedString(@"Dropbox", @"Dropbox");
    }
}

- (NSArray *) editingToolbarItems
{
    NSMutableArray *items = [NSMutableArray array];
    
    UIBarButtonItem *fixedItem = [UIBarButtonItem fixedItemWithWidth:10];
	UIBarButtonItem *flexibleItem = [UIBarButtonItem flexibleItem];
    
    if ([MFMailComposeViewController canSendMail]) {
        if (!emailItem_) {
            emailItem_ = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Email", @"Email")
                                                          style:UIBarButtonItemStyleBordered
                                                         target:self
                                                         action:@selector(showEmailPanel:)];
        }
        [items addObject:emailItem_];
        [items addObject:fixedItem];
    }
    
    if (!dropboxExportItem_) {
        dropboxExportItem_ = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Dropbox", @"Dropbox")
                                                              style:UIBarButtonItemStyleBordered
                                                             target:self
                                                             action:@selector(showDropboxExportPanel:)];
    }
    
    if (!deleteItem_) {
        deleteItem_ = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                    target:self
                                                                    action:@selector(showDeleteMenu:)];
    }
    
    UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                              target:self
                                                                              action:@selector(stopEditing:)];
    
    [items addObject:dropboxExportItem_];
    [items addObject:flexibleItem];
    [items addObject:deleteItem_];
    [items addObject:fixedItem];
    [items addObject:doneItem];
    
    return items;
}

- (NSArray *) defaultToolbarItems
{
    if (!toolbarItems_) {
        toolbarItems_ = [[NSMutableArray alloc] init];
        
        UIBarButtonItem *importItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Import", @"Import")
                                                                       style:UIBarButtonItemStyleBordered target:self
                                                                      action:@selector(showDropboxImportPanel:)];
        UIBarButtonItem *samplesItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Samples", @"Samples")
                                                                        style:UIBarButtonItemStyleBordered
                                                                       target:self
                                                                       action:@selector(showSamplesPanel:)];
        
        UIBarButtonItem *fontItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Fonts", @"Fonts")
                                                                     style:UIBarButtonItemStylePlain target:self
                                                                    action:@selector(showFontLibraryPanel:)];
        activityIndicator_ = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        UIBarButtonItem *spinnerItem = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator_];
        
        activityItem_ = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Activity", @"Activity")
                                                         style:UIBarButtonItemStyleBordered target:self
                                                        action:@selector(showActivityPanel:)];
        
        UIBarButtonItem *editItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Select", @"Select")
                                                                     style:UIBarButtonItemStyleBordered
                                                                    target:self
                                                                    action:@selector(startEditing:)];
        editItem.style = UIBarButtonItemStyleBordered;
        
        UIBarButtonItem *flexibleItem = [UIBarButtonItem flexibleItem];
        UIBarButtonItem *fixedItem = [UIBarButtonItem fixedItemWithWidth:10];
        
        [toolbarItems_ addObject:importItem];
        [toolbarItems_ addObject:fixedItem];
        [toolbarItems_ addObject:samplesItem];
        [toolbarItems_ addObject:fixedItem];
        [toolbarItems_ addObject:fontItem];
        [toolbarItems_ addObject:flexibleItem];
        
        [toolbarItems_ addObject:spinnerItem];
        [toolbarItems_ addObject:fixedItem];
        [toolbarItems_ addObject:fixedItem];
        [toolbarItems_ addObject:editItem];
    }
    
    return toolbarItems_;
}

#pragma mark - Panels

- (void) showFontLibraryPanel:(id)sender
{
    if (fontLibraryController_) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    fontLibraryController_ = [[WDFontLibraryController alloc] initWithNibName:nil bundle:nil];

    UINavigationController  *navController = [[UINavigationController alloc] initWithRootViewController:fontLibraryController_];
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
    popoverController_.delegate = self;
    [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

- (void) samplesController:(WDSamplesController *)controller didSelectURLs:(NSArray *)sampleURLs
{
    [self dismissPopover];
    
    [[WDDrawingManager sharedInstance] installSamples:sampleURLs];
}

- (void) showSamplesPanel:(id)sender
{
    if (samplesController_) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    samplesController_ = [[WDSamplesController alloc] initWithNibName:nil bundle:nil];
    samplesController_.title = NSLocalizedString(@"Samples", @"Samples");
    samplesController_.delegate = self;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:samplesController_];
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
    popoverController_.delegate = self;
    [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

- (void) showActivityPanel:(id)sender
{
    if (activityController_) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    activityController_ = [[WDActivityController alloc] initWithNibName:nil bundle:nil];
    activityController_.activityManager = activities_;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:activityController_];
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
    popoverController_.delegate = self;
    [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

- (void) activityCountChanged:(NSNotification *)aNotification
{
    NSUInteger numActivities = activities_.count;
    
    if (numActivities) {
        [activityIndicator_ startAnimating];
    } else {
        [activityIndicator_ stopAnimating];
    }
    
    if (numActivities == 0) {
        if (activityController_) {
            [self dismissPopoverAnimated:YES];
        }
        
        [toolbarItems_ removeObject:activityItem_];
        
        if (!self.isEditing) {
            [self setToolbarItems:[NSArray arrayWithArray:[self defaultToolbarItems]] animated:YES];
        }
    } else if (![toolbarItems_ containsObject:activityItem_]) {
        [toolbarItems_ insertObject:activityItem_ atIndex:(toolbarItems_.count - 2)];
        
        if (!self.isEditing) {
            [self setToolbarItems:[NSArray arrayWithArray:[self defaultToolbarItems]] animated:YES];
        }
    }
}

- (void) showHelp:(id)sender
{
    WDHelpController *helpController = [[WDHelpController alloc] initWithNibName:nil bundle:nil];
    
    // Create a Navigation controller
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:helpController];
    navController.modalPresentationStyle = UIModalPresentationPageSheet;
    
    // show the navigation controller modally
    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - Popovers

- (void) dismissPopoverAnimated:(BOOL)animated
{
    if (popoverController_) {
        [popoverController_ dismissPopoverAnimated:animated];
        popoverController_ = nil;
    }
    
    exportController_ = nil;
    importController_ = nil;
    pickerController_ = nil;
    fontLibraryController_ = nil;
    samplesController_ = nil;
    activityController_ = nil;
    
    if (deleteSheet_) {
        [deleteSheet_ dismissWithClickedButtonIndex:deleteSheet_.cancelButtonIndex animated:NO];
        deleteSheet_ = nil;
    }
}

- (void) dismissPopover
{
    [self dismissPopoverAnimated:NO];
}

- (void) popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (popoverController == popoverController_) {
        popoverController_ = nil;
    }
    
    exportController_ = nil;
    importController_ = nil;
    pickerController_ = nil;
    fontLibraryController_ = nil;
    samplesController_ = nil;
    activityController_ = nil;
}

- (void)didDismissModalView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Email

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
	[self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void) emailDrawings:(id)sender
{
    [self dismissPopover];
    
    NSString *format = [[NSUserDefaults standardUserDefaults] objectForKey:WDEmailFormatDefault];
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = self;
    
    [picker setSubject:NSLocalizedString(@"Inkpad Drawing", @"Inkpad Drawing")];
    
    WDEmail *email = [[WDEmail alloc] init];
    email.completeAttachments = 0;
    email.expectedAttachments = [selectedDrawings_ count];
    email.picker = picker;
    
    for (NSString *filename in selectedDrawings_) {
        [[self getThumbnail:filename] startActivity];
        [[WDDrawingManager sharedInstance] openDocumentWithName:filename withCompletionHandler:^(WDDocument *document) {
            @autoreleasepool {
                WDDrawing *drawing = document.drawing;
                // TODO use document contentForType
                NSData *data = nil;
                NSString *extension = nil;
                NSString *mimeType = nil;
                if ([format isEqualToString:@"Inkpad"]) {
                    data = [[WDDrawingManager sharedInstance] dataForFilename:filename];
                    extension = WDDrawingFileExtension;
                    mimeType = @"application/x-inkpad";
                } else if ([format isEqualToString:@"SVG"]) {
                    data = [drawing SVGRepresentation];
                    extension = @"svg";
                    mimeType = @"image/svg+xml";
                } else if ([format isEqualToString:@"SVGZ"]) {
                    data = [[drawing SVGRepresentation] compress];
                    extension = @"svgz";
                    mimeType = @"image/svg+xml";
                } else if ([format isEqualToString:@"PNG"]) {
                    data = UIImagePNGRepresentation([drawing image]);
                    extension = @"png";
                    mimeType = @"image/png";
                } else if ([format isEqualToString:@"JPEG"]) {
                    data = UIImageJPEGRepresentation([drawing image], 0.9);
                    extension = @"jpeg";
                    mimeType = @"image/jpeg";
                } else if ([format isEqualToString:@"PDF"]) {
                    data = [drawing PDFRepresentation];
                    extension = @"pdf";
                    mimeType = @"image/pdf";
                }
                [picker addAttachmentData:data mimeType:mimeType fileName:[[filename stringByDeletingPathExtension] stringByAppendingPathExtension:extension]];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:WDAttachmentNotification object:email userInfo:@{@"path": filename}];
        }];
    }
}

- (void) emailAttached:(NSNotification *)aNotification
{
    WDEmail *email = aNotification.object;
    NSString *path = [aNotification.userInfo valueForKey:@"path"];
    id thumbnail = [self getThumbnail:path];
    [thumbnail stopActivity];
    if (++email.completeAttachments == email.expectedAttachments) {
        [self.navigationController presentViewController:email.picker animated:YES completion:nil];
    }
}

- (void) showEmailPanel:(id)sender
{
    if (exportController_ && exportController_.mode == kWDExportViaEmailMode) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    exportController_ = [[WDExportController alloc] initWithNibName:nil bundle:nil];
    exportController_.mode = kWDExportViaEmailMode;
    
    exportController_.action = @selector(emailDrawings:);
    exportController_.target = self;
    
    UINavigationController  *navController = [[UINavigationController alloc] initWithRootViewController:exportController_];
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
    popoverController_.delegate = self;
    [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

#pragma mark - Dropbox

- (void) uploadDrawings:(id)sender
{
    [self dismissPopover];
    
    if (!restClient_) {
        restClient_ = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        restClient_.delegate = self;
        
        [restClient_ loadMetadata:@"/"];
    }
    
    NSString *format = [[NSUserDefaults standardUserDefaults] objectForKey:WDDropboxFormatDefault];
    
    for (NSString *filename in selectedDrawings_) {
        [[WDDrawingManager sharedInstance] openDocumentWithName:filename withCompletionHandler:^(WDDocument *document) {
            @autoreleasepool {
                NSData      *data = nil;
                // TODO: use document contentForType
                if ([format isEqualToString:@"Inkpad"]) {
                    data = [[WDDrawingManager sharedInstance] dataForFilename:filename];
                } else if ([format isEqualToString:@"SVG"]) {
                    data = [document.drawing SVGRepresentation];
                } else if ([format isEqualToString:@"SVGZ"]) {
                    data = [[document.drawing SVGRepresentation] compress];
                } else if ([format isEqualToString:@"PNG"]) {
                    data = UIImagePNGRepresentation([document.drawing image]);
                } else if ([format isEqualToString:@"JPEG"]) {
                    data = UIImageJPEGRepresentation([document.drawing image], 0.9);
                } else if ([format isEqualToString:@"PDF"]) {
                    data = [document.drawing PDFRepresentation];
                }
                if (data) {
                    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
                    path = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:[format lowercaseString]];
                    [data writeToFile:path atomically:YES];
                    
                    
                    [restClient_ uploadFile:[path lastPathComponent] toPath:[self appFolderPath]
                              withParentRev:nil fromPath:path];
                    [activities_ addActivity:[WDActivity activityWithFilePath:path type:WDActivityTypeUpload]];
                    [filesBeingUploaded_ addObject:path];
                    
                    [[self getThumbnail:filename] startActivity];
                }
            }
        }];
    }
    
    [self properlyEnableToolbarItems];
}

- (void) reallyShowDropboxExportPanel:(id)sender
{
    if (exportController_ && exportController_.mode == kWDExportViaDropboxMode) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    exportController_ = [[WDExportController alloc] initWithNibName:nil bundle:nil];
    exportController_.mode = kWDExportViaDropboxMode;
    
    exportController_.action = @selector(uploadDrawings:);
    exportController_.target = self;
    
    UINavigationController  *navController = [[UINavigationController alloc] initWithRootViewController:exportController_];
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
    popoverController_.delegate = self;
    [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

- (void) showDropboxExportPanel:(id)sender
{
	if (![self dropboxIsLinked]) {
        WDAppDelegate *delegate = (WDAppDelegate *) [UIApplication sharedApplication].delegate;
        delegate.performAfterDropboxLoginBlock = ^{ [self reallyShowDropboxExportPanel:sender]; };
	} else {
        [self reallyShowDropboxExportPanel:sender];
    }
}

#pragma mark -

- (void) reallyShowDropboxImportPanel:(id)sender
{
	if (importController_) {
		[self dismissPopover];
		return;
	}
	
	[self dismissPopover];
	
	importController_ = [[WDImportController alloc] initWithNibName:@"Import" bundle:nil];
	importController_.title = @"Dropbox";
	importController_.delegate = self;
	
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:importController_];
	
	popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
	popoverController_.delegate = self;
	[popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

- (void) showDropboxImportPanel:(id)sender
{
    if (![self dropboxIsLinked]) {
        WDAppDelegate *delegate = (WDAppDelegate *) [UIApplication sharedApplication].delegate;
        delegate.performAfterDropboxLoginBlock = ^{ [self reallyShowDropboxImportPanel:sender]; };
	} else {
        [self reallyShowDropboxImportPanel:sender];
    }
}

- (void) importController:(WDImportController *)controller didSelectDropboxItems:(NSArray *)dropboxItems
{
	if (!restClient_) {
		restClient_ = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
		restClient_.delegate = self;
	}
    
    NSString    *downloadsDirectory = [NSTemporaryDirectory() stringByAppendingString:@"Downloads/"];
    BOOL        isDirectory = NO;
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:downloadsDirectory isDirectory:&isDirectory] || !isDirectory) {
        [[NSFileManager defaultManager] createDirectoryAtPath:downloadsDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
	for (DBMetadata *item in dropboxItems) {
		NSString *downloadPath = [downloadsDirectory stringByAppendingFormat:@"%@", [item.path lastPathComponent]];
        
        // make sure we're not already downloading/importing this file
        if (!activities_.count || ![activities_ activityWithFilepath:downloadPath]) {
            [restClient_ loadFile:item.path intoPath:downloadPath];
            [activities_ addActivity:[WDActivity activityWithFilePath:downloadPath type:WDActivityTypeDownload]];
        }
	}
	
	[self dismissPopover];
}

#pragma mark -

- (void) showImportErrorMessage:(NSString *)filename
{
    NSString *format = NSLocalizedString(@"Inkpad could not import “%@”. It may be corrupt or in a format that's not supported.",
                                         @"Inkpad could not import “%@”. It may be corrupt or in a format that's not supported.");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Import Problem", @"Import Problem")
                                                        message:[NSString stringWithFormat:format, filename]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void) showImportMemoryWarningMessage:(NSString *)filename
{
    NSString *format = NSLocalizedString(@"Inkpad could not import “%@”. There is not enough available memory.",
                                         @"Inkpad could not import “%@”. There is not enough available memory.");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Import Problem", @"Import Problem")
                                                        message:[NSString stringWithFormat:format, filename]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                              otherButtonTitles:nil];
    [alertView show];
}

#pragma mark -

- (NSString*) appFolderPath
{
    NSString* appFolderPath = @"Inkpad";
    if (![appFolderPath isAbsolutePath]) {
        appFolderPath = [@"/" stringByAppendingString:appFolderPath];
    }
    
    return appFolderPath;
}

- (void) dropboxUnlinked:(NSNotification *)aNotification
{
    [self dismissPopoverAnimated:YES];
}

- (BOOL) dropboxIsLinked
{
    if ([[DBSession sharedSession] isLinked]) {
        return YES;
    } else {
        [self dismissPopover];
        
        [[DBSession sharedSession] linkUserId:nil fromController:self];
        return NO;
    }
}

#pragma mark -

- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath
{
    [filesBeingUploaded_ removeObject:srcPath];
    [activities_ removeActivityWithFilepath:srcPath];
    
    [[self getThumbnail:[srcPath lastPathComponent]] stopActivity];
    
    [self properlyEnableToolbarItems];
}

- (void)restClient:(DBRestClient*)client uploadProgress:(CGFloat)progress forFile:(NSString*)destPath from:(NSString*)srcPath;
{
    [activities_ updateProgressForFilepath:srcPath progress:progress];
}

- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath
{
    [activities_ updateProgressForFilepath:destPath progress:progress];
}

- (void) restClient:(DBRestClient*)client loadedFile:(NSString*)downloadPath
{
    NSString    *extension = [[downloadPath pathExtension] lowercaseString];
    NSString    *filename = [downloadPath lastPathComponent];
    
    // find the associated download activity
    WDActivity  *downloadActivity = [activities_ activityWithFilepath:downloadPath];
    
	if ([extension isEqualToString:@"inkpad"] || [extension isEqualToString:@"svg"] || [extension isEqualToString:@"svgz"]) {
        WDActivity *importActivity = [WDActivity activityWithFilePath:downloadPath type:WDActivityTypeImport];
        [activities_ addActivity:importActivity];
        
        // this is asynchronous
		[[WDDrawingManager sharedInstance] importDrawingAtURL:[NSURL fileURLWithPath:downloadPath]
                                                   errorBlock:^{ [self showImportErrorMessage:filename]; }
                                        withCompletionHandler:^(WDDocument *document) {
                                            [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:NULL];
                                            [activities_ removeActivity:importActivity];
                                        }];
	} else if ([WDImportController isFontType:extension]) {
        BOOL alreadyInstalled;
        NSString *importedFontName = [[WDFontManager sharedInstance] installUserFont:[NSURL fileURLWithPath:downloadPath]
                                                                    alreadyInstalled:&alreadyInstalled];
        if (!importedFontName) {
            [self showImportErrorMessage:filename];
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:NULL];
	} else if ([WDImportController canImportType:extension]) {
        BOOL success = [[WDDrawingManager sharedInstance] createNewDrawingWithImageAtURL:[NSURL fileURLWithPath:downloadPath]];
        if (!success) {
            [self showImportErrorMessage:filename];
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:NULL];
	}
    
    // remove the download activity. do this last so the activity count doesn't drop to 0
    [activities_ removeActivity:downloadActivity];
}

- (void) restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error
{
	NSString *downloadPath = [[error userInfo] valueForKey:@"destinationPath"];
	
    [activities_ removeActivityWithFilepath:downloadPath];
	[[NSFileManager defaultManager] removeItemAtPath:downloadPath error:NULL];
    
    NSString *format = NSLocalizedString(@"There was a problem downloading “%@”. Check your network connection and try again.",
                                         @"There was a problem downloading“%@”. Check your network connection and try again.");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Download Problem", @"Download Problem")
                                                        message:[NSString stringWithFormat:format, [downloadPath lastPathComponent]]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
    NSString *srcPath = [[error userInfo] valueForKey:@"sourcePath"];
	
    [activities_ removeActivityWithFilepath:srcPath];
    [filesBeingUploaded_ removeObject:srcPath];
    
    [[self getThumbnail:[srcPath lastPathComponent]] stopActivity];
    
    [self properlyEnableToolbarItems];
    
    NSString *format = NSLocalizedString(@"There was a problem uploading “%@”. Check your network connection and try again.",
                                         @"There was a problem uploading“%@”. Check your network connection and try again.");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Upload Problem", @"Upload Problem")
                                                        message:[NSString stringWithFormat:format, [srcPath lastPathComponent]]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                              otherButtonTitles:nil];
    [alertView show];
}

#pragma mark - Storyboard / Collection View

- (BOOL) shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    return !self.isEditing;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"editDrawing"]) {
        WDCanvasController *canvasController = [segue destinationViewController];
        NSUInteger index = [[WDDrawingManager sharedInstance] indexPathForFilename:((WDThumbnailView *)sender).filename].item;
        WDDocument *document = [[WDDrawingManager sharedInstance] openDocumentAtIndex:index withCompletionHandler:nil];
        [canvasController setDocument:document];
    }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath;
{
    WDThumbnailView *thumbnailView = (WDThumbnailView *) [collectionView cellForItemAtIndexPath:indexPath];
    thumbnailView.shouldShowSelectionIndicator = self.isEditing;
    
    return YES;
}

- (void) updateSelectionTitle
{
    NSUInteger  count = selectedDrawings_.count;
    NSString    *format;
    
    if (count == 0) {
        self.title = NSLocalizedString(@"Select Drawings", @"Select Drawings");
    } else if (count == 1) {
        self.title = NSLocalizedString(@"1 Drawing Selected", @"1 Drawing Selected");
    } else {
        format = NSLocalizedString(@"%lu Drawings Selected", @"%lu Drawings Selected");
        self.title = [NSString stringWithFormat:format, count];
    }
}

- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString    *filename = [[WDDrawingManager sharedInstance] fileAtIndex:indexPath.item];
    
    if (self.isEditing) {
        [selectedDrawings_ addObject:filename];
        
        [self updateSelectionTitle];
        [self properlyEnableToolbarItems];
    } else {
        [self getThumbnail:filename].selected = NO;
    }
}

- (void) collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isEditing) {
        NSString    *filename = [[WDDrawingManager sharedInstance] fileAtIndex:indexPath.item];
        [selectedDrawings_ removeObject:filename];
        
        [self updateSelectionTitle];
        [self properlyEnableToolbarItems];
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;
{
    return [[WDDrawingManager sharedInstance] numberOfDrawings];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    WDThumbnailView *thumbnail = [collectionView dequeueReusableCellWithReuseIdentifier:@"cellID" forIndexPath:indexPath];
    NSArray         *drawings = [[WDDrawingManager sharedInstance] drawingNames];
    
    thumbnail.filename = drawings[indexPath.item];
    thumbnail.tag = indexPath.item;
    thumbnail.delegate = self;
    
    if (self.isEditing) {
        thumbnail.shouldShowSelectionIndicator = YES;
        thumbnail.selected = [selectedDrawings_ containsObject:thumbnail.filename] ? YES : NO;
    }
    
    return thumbnail;
}

@end
