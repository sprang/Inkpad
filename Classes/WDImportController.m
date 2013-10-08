//
//  WDImportController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Original implementation by Joe Ricioppo
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <DropboxSDK/DropboxSDK.h>
#import "UIImage+Additions.h"
#import "WDAppDelegate.h"
#import "WDImportController.h"
#import "UIBarButtonItem+Additions.h"

@interface WDImportController ()
- (WDImportController *)inkpadDirectoryImportController;
- (WDImportController *)subdirectoryImportControllerForPath:(NSString *)subdirectoryPath;
- (NSArray *)toolbarItems;
- (UIImage *) iconForPathExtension:(NSString *)pathExtension;
- (void)failedLoadingMissingSubdirectory:(NSNotification *)notification;
- (NSString *) importButtonTitle;
@end

static NSString * const kDropboxThumbSizeLarge = @"large";
static NSString * const WDDropboxLastPathVisited = @"WDDropboxLastPathVisited";
static NSString * const WDDropboxSubdirectoryMissingNotification = @"WDDropboxSubdirectoryMissingNotification";

@implementation WDImportController

@synthesize remotePath = remotePath_;
@synthesize delegate = delegate_;

+ (NSSet *) supportedImageFormats
{
    static NSSet *imageFormats_ = nil;
    
    if (!imageFormats_) {
        NSArray *temp = [NSArray arrayWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"ImportFormats" withExtension:@"plist"]];
        imageFormats_ = [[NSSet alloc] initWithArray:temp];
    }
    
    return imageFormats_;
}

+ (BOOL) canImportType:(NSString *)extension
{
    NSString *lowercase = [extension lowercaseString];
    
    if ([lowercase isEqualToString:@"inkpad"]) {
        return YES;
    }
    
    if ([self isFontType:lowercase]) {
        return YES;
    }

    return [[WDImportController supportedImageFormats] containsObject:lowercase];
}

+ (BOOL) isFontType:(NSString *)extension
{
    return [[NSSet setWithObjects:@"ttf", @"otf", nil] containsObject:extension];
}

#pragma mark -

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) {
		return nil;
		
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(failedLoadingMissingSubdirectory:) name:WDDropboxSubdirectoryMissingNotification object:nil];
	
	selectedItems_ = [[NSMutableSet alloc] init];
	itemsKeyedByImagePath_ = [[NSMutableDictionary alloc] init];
	itemsFailedImageLoading_ = [[NSMutableSet alloc] init];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *basePath = [[fm URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL] path];
	imageCacheDirectory_ = [basePath stringByAppendingString:@"/Dropbox_Icons/"];
	
	BOOL isDirectory = NO;
	if (![fm fileExistsAtPath:imageCacheDirectory_ isDirectory:&isDirectory] || !isDirectory) {
		[fm createDirectoryAtPath:imageCacheDirectory_ withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	
	dropboxClient_ = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
	dropboxClient_.delegate = self;
    
    
	importButton_ = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Import", @"Import")
                                                     style:UIBarButtonItemStyleDone target:self
                                                    action:@selector(importSelectedItems:)];
	self.navigationItem.rightBarButtonItem = importButton_;
    importButton_.enabled = NO;
    
    self.toolbarItems = [self toolbarItems];
	
    self.preferredContentSize = CGSizeMake(320, 480);
    
    return self;
}

#pragma mark -

- (void) viewDidLoad
{
    [self.navigationController setToolbarHidden:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
	NSString *rootPath = @"/";
	
	// first pass - push last viewed directory, or default to Inkpad directory, creating if necessary
	if (remotePath_ == nil) {
		self.remotePath = rootPath;
		isRoot_ = YES;
		
		NSString *lastPathVisited = [[NSUserDefaults standardUserDefaults] stringForKey:WDDropboxLastPathVisited];
		if ([lastPathVisited isEqual:rootPath]) {
			[activityIndicator_ startAnimating];
			[dropboxClient_	loadMetadata:remotePath_];			
			
		} else if (lastPathVisited.length > 1) {
			NSString *currentPath = rootPath;
			NSArray *pathComponents = [lastPathVisited componentsSeparatedByString:@"/"];
			for (NSString *pathComponent in pathComponents) {				
				if (pathComponent.length == 0) { // first component is an empty string
					continue;
				}
				currentPath = [currentPath stringByAppendingPathComponent:pathComponent];
				WDImportController *subdirectoryImportController = [self subdirectoryImportControllerForPath:currentPath];
				[self.navigationController pushViewController:subdirectoryImportController animated:NO];
			}
			
		} else {
			WDImportController *inkpadDirectoryImportController = [self inkpadDirectoryImportController];
			[self.navigationController pushViewController:inkpadDirectoryImportController animated:NO];
		}

	// pushed or popped-to view controller
	} else {
		[activityIndicator_ startAnimating];
		[dropboxClient_	loadMetadata:remotePath_];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[[NSUserDefaults standardUserDefaults] setObject:remotePath_ forKey:WDDropboxLastPathVisited];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[selectedItems_ removeAllObjects];
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [dropboxItems_ count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	DBMetadata *dropboxItem = dropboxItems_[indexPath.row];
	UITableViewCell *cell = nil;
	
	if (dropboxItem.isDirectory) {
		static NSString *kDirectoryCellIdentifier = @"kDirectoryCellIdentifier";
		cell = [tableView dequeueReusableCellWithIdentifier:kDirectoryCellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kDirectoryCellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.imageView.image = [UIImage imageNamed:@"dropbox_icon_directory.png"];
		}
	} else {
		static NSString *kItemCellIdentifier = @"kItemCellIdentifier";
		cell = [contentsTable_ dequeueReusableCellWithIdentifier:kItemCellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kItemCellIdentifier];
		}
		
		BOOL supportedFile = [WDImportController canImportType:[dropboxItem.path pathExtension]];
		cell.textLabel.textColor = supportedFile ? [UIColor blackColor] : [UIColor grayColor];
		cell.userInteractionEnabled = supportedFile ? YES : NO;
		cell.imageView.image = [self iconForPathExtension:[dropboxItem.path pathExtension]];
		
		if (dropboxItem.thumbnailExists) {
            // keep the path extension since multiple files can have the same name (with different extensions)
			NSString    *flatPath = [dropboxItem.path stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
			NSString    *cachedImagePath = [imageCacheDirectory_ stringByAppendingString:flatPath];
			UIImage     *dropboxItemIcon = [UIImage imageWithContentsOfFile:cachedImagePath];
            BOOL        outOfDate = NO;
            
			if (dropboxItemIcon) {
				cell.imageView.image = dropboxItemIcon;
                
                // we have a cached thumbnail, see if it's out of date relative to Dropbox
                NSFileManager *fm = [NSFileManager defaultManager];
                NSDictionary *attrs = [fm attributesOfItemAtPath:cachedImagePath error:NULL];
                NSDate *cachedDate = attrs[NSFileModificationDate];
                outOfDate = !cachedDate || [cachedDate compare:dropboxItem.lastModifiedDate] == NSOrderedAscending;
			} 
            
            if (!dropboxItemIcon || outOfDate) {
				itemsKeyedByImagePath_[cachedImagePath] = dropboxItem;
				[dropboxClient_ loadThumbnail:dropboxItem.path ofSize:kDropboxThumbSizeLarge intoPath:cachedImagePath];
            }
		}
        
        // always need to update the cell checkmark since they're reused
        [cell setAccessoryType:[selectedItems_ containsObject:dropboxItem] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone];
	}

	cell.textLabel.text = [[dropboxItem path] lastPathComponent];
	return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	DBMetadata *selectedItem = dropboxItems_[indexPath.row];	

	if (selectedItem.isDirectory) {		
		WDImportController *subdirectoryImportController = [self subdirectoryImportControllerForPath:selectedItem.path];
		[self.navigationController pushViewController:subdirectoryImportController animated:YES];
	} else {
		if (![selectedItems_ containsObject:selectedItem]) {
			[selectedItems_ addObject:selectedItem];
			[[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
		} else {
			[selectedItems_ removeObject:selectedItem];
			[[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
		}
	}
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	[importButton_ setTitle:[self importButtonTitle]];
	[importButton_ setEnabled:selectedItems_.count > 0 ? YES : NO];
}

#pragma mark -
#pragma mark DBRestClientDelegate

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata
{	
    if (metadata.isDeleted) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WDDropboxSubdirectoryMissingNotification object:nil];
        return;
    }
    
    [activityIndicator_ stopAnimating];
    NSPredicate *removeSoftDeletedFilesPredicate = [NSPredicate predicateWithFormat:@"self.isDeleted == NO"];
    dropboxItems_ = [metadata.contents filteredArrayUsingPredicate:removeSoftDeletedFilesPredicate];
    [contentsTable_ reloadData];
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error
{
	NSString *missingRemotePath = [[error userInfo] valueForKey:@"path"];
	NSString *lastVisitedPath = [[NSUserDefaults standardUserDefaults] valueForKey:WDDropboxLastPathVisited];
	if ([error code] == 404 && [missingRemotePath isEqualToString:lastVisitedPath]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:WDDropboxSubdirectoryMissingNotification object:nil];
	} else if ([error code] == 404 && [[[[error userInfo] valueForKey:@"path"] lastPathComponent] isEqualToString:@"Inkpad"]) {
		[dropboxClient_ createFolder:@"/Inkpad"];
	} else {
		[activityIndicator_ stopAnimating];
#if WD_DEBUG
		NSLog(@"Dropbox metadata load encountered error: %@", error);
#endif
	}
}

- (void)restClient:(DBRestClient*)client createdFolder:(DBMetadata*)folder 
{	
	[dropboxClient_ loadMetadata:folder.path];
}

- (void)restClient:(DBRestClient*)client createFolderFailedWithError:(NSError*)error
{
	[activityIndicator_ stopAnimating];
    
#if WD_DEBUG
	NSLog(@"Dropbox sub-folder creation encountered error: %@", error);
#endif
}

- (void)restClient:(DBRestClient*)client loadedThumbnail:(NSString*)imagePath
{	
	UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
	CGSize imageViewSize = CGSizeMake(40, 40);
    
    UIGraphicsBeginImageContextWithOptions(imageViewSize, NO, 0);
    [image drawToFillRect:CGRectMake(0, 0, imageViewSize.width, imageViewSize.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

	[UIImagePNGRepresentation(scaledImage) writeToFile:imagePath atomically:YES];
	
	DBMetadata *item = [itemsKeyedByImagePath_ valueForKey:imagePath];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[dropboxItems_ indexOfObject:item] inSection:0];
	
	[contentsTable_ reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
	[itemsKeyedByImagePath_ removeObjectForKey:imagePath];
}

- (void)restClient:(DBRestClient*)client loadThumbnailFailedWithError:(NSError*)error
{
	NSString *itemRemotePath = [[error userInfo] valueForKey:@"path"];
	NSString *itemLocalPath = [[error userInfo] valueForKey:@"destinationPath"];
	
	DBMetadata *failedItem = [itemsKeyedByImagePath_ valueForKey:itemLocalPath];
	
	if ([itemsFailedImageLoading_ containsObject:failedItem]) {
#if WD_DEBUG
		NSLog(@"Loading dropbox thumbnail encountered error: %@", error);
#endif
		return;
	} else {
		[itemsFailedImageLoading_ addObject:failedItem];
		[dropboxClient_ loadThumbnail:itemRemotePath ofSize:kDropboxThumbSizeLarge intoPath:itemLocalPath];
	}
}

#pragma mark -
#pragma mark Notifications

- (void)failedLoadingMissingSubdirectory:(NSNotification *)notification
{
	if (!isRoot_) {
		return;
	}
    
	[self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark -

- (void) importSelectedItems:(id)sender
{
	if (delegate_ && [(id) delegate_ respondsToSelector:@selector(importController:didSelectDropboxItems:)]) {
		[delegate_ importController:self didSelectDropboxItems:[selectedItems_ allObjects]];
	}
}

- (void) unlinkDropbox:(id)sender
{
    WDAppDelegate *appDelegate = (WDAppDelegate *) [UIApplication sharedApplication].delegate;
    [appDelegate unlinkDropbox];
}

#pragma mark -

- (WDImportController *)inkpadDirectoryImportController
{
	return [self subdirectoryImportControllerForPath:@"/Inkpad"];
}

- (WDImportController *)subdirectoryImportControllerForPath:(NSString *)subdirectoryPath
{
	WDImportController *subdirectoryImportController = [[WDImportController alloc] initWithNibName:@"Import" bundle:nil];
	subdirectoryImportController.remotePath = subdirectoryPath;
	subdirectoryImportController.title = [subdirectoryPath lastPathComponent];
	subdirectoryImportController.delegate = self.delegate;

	return subdirectoryImportController;
}

- (NSArray *)toolbarItems
{
    UIBarButtonItem *flexibleSpaceItem = [UIBarButtonItem flexibleItem];
    UIBarButtonItem *unlinkButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Unlink Dropbox", @"Unlink Dropbox") style:UIBarButtonItemStyleBordered target:self action:@selector(unlinkDropbox:)];

    NSArray *toolbarItems = @[flexibleSpaceItem, unlinkButtonItem];


    return toolbarItems;
}

- (NSString *) importButtonTitle
{
    NSString *title = nil;
    if (selectedItems_.count < 1) {
        title = NSLocalizedString(@"Import", @"Import");
    } else {
        NSString *format = NSLocalizedString(@"Import %lu", @"Import %lu");
        title = [NSString stringWithFormat:format, (unsigned long)selectedItems_.count];
    }
    return title;
}

- (UIImage *) iconForPathExtension:(NSString *)pathExtension
{
	if ([pathExtension caseInsensitiveCompare:@"inkpad"] == NSOrderedSame) {
		return [UIImage imageNamed:@"dropbox_icon_inkpad.png"];
	} else if ([WDImportController isFontType:[pathExtension lowercaseString]]) {
		return [UIImage imageNamed:@"dropbox_icon_font.png"];
	} else if ([pathExtension caseInsensitiveCompare:@"svg"] == NSOrderedSame) {
		return [UIImage imageNamed:@"dropbox_icon_svg.png"];
	} else if ([pathExtension caseInsensitiveCompare:@"svgz"] == NSOrderedSame) {
		return [UIImage imageNamed:@"dropbox_icon_svg.png"];
	} else if ([WDImportController canImportType:pathExtension]) {
		return [UIImage imageNamed:@"dropbox_icon_generic.png"];
	} else {
		return [UIImage imageNamed:@"dropbox_icon_unsupported.png"];
	}
}

#pragma mark -

- (void)dealloc 
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
