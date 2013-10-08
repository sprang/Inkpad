//
//  WDSamplesController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDSamplesController.h"
#import "WDDrawing.h"

const NSInteger kThumbnailDimension = 64;

@interface WDSamplesController ()
@property (nonatomic, copy)     NSArray             *sampleURLs;
@property (nonatomic, strong)   NSMutableSet        *selectedURLs;
@property (nonatomic, strong)   NSMutableDictionary *cachedThumbnails;
@property (nonatomic, weak)   UIBarButtonItem     *importButton;
- (NSString *)importButtonTitle;
@end

#pragma mark -

@implementation WDSamplesController

@synthesize cachedThumbnails;
@synthesize contentsTable;
@synthesize delegate;
@synthesize importButton;
@synthesize sampleURLs;
@synthesize selectedURLs;

#pragma mark -

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) {
        return nil;
    }
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Import All", @"Import All")
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(importAllButtonTapped:)];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Import", @"Import")
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(importButtonTapped:)];
    
    self.importButton = self.navigationItem.rightBarButtonItem;
    self.importButton.enabled = NO;
    
    self.selectedURLs = [NSMutableSet set];
    self.cachedThumbnails = [NSMutableDictionary dictionary];
    self.sampleURLs = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"inkpad" subdirectory:@"Samples"];
    
    return self;
}


#pragma mark -

- (void)loadView
{
    contentsTable = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 5 * 28 + 9 * 44) style:UITableViewStylePlain];
    contentsTable.delegate = self;
    contentsTable.dataSource = self;
    contentsTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    contentsTable.rowHeight = 80;
    self.view = contentsTable;
    
    self.preferredContentSize = CGSizeMake(320, 80 * 6);
}

#pragma mark -

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.sampleURLs.count;
}

- (UIImage *) thumbnailForURL:(NSURL *)sampleURL
{
    UIImage *thumbnail = (self.cachedThumbnails)[sampleURL.path];
    
    if (!thumbnail) {
        NSData              *data = [NSData dataWithContentsOfURL:sampleURL]; 
        NSKeyedUnarchiver   *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        NSData              *thumbData = [unarchiver decodeObjectForKey:WDThumbnailKey];
        
        [unarchiver finishDecoding];
        
        UIImage *image = [[UIImage alloc] initWithData:thumbData];
        
        CGRect  dest = CGRectMake(0, 0, kThumbnailDimension, kThumbnailDimension);
        CGRect  contentBounds = CGRectMake(0.0, 0.0, image.size.width, image.size.height);
        float   contentAspect = CGRectGetWidth(contentBounds) / CGRectGetHeight(contentBounds);
        float   destAspect = CGRectGetWidth(dest)  / CGRectGetHeight(dest);
        float   scaleFactor = 1.0f;
        CGPoint offset = CGPointZero;
        
        if (contentAspect > destAspect) {
            scaleFactor = CGRectGetWidth(dest) / CGRectGetWidth(contentBounds);
            offset.y = CGRectGetHeight(dest) - (scaleFactor * CGRectGetHeight(contentBounds));
            offset.y /= 2;
        } else {
            scaleFactor = CGRectGetHeight(dest) / CGRectGetHeight(contentBounds);
            offset.x = CGRectGetWidth(dest) - (scaleFactor * CGRectGetWidth(contentBounds));
            offset.x /= 2;
        }
        
        UIGraphicsBeginImageContextWithOptions(dest.size, NO, 0);
        CGRect imageRect = CGRectMake(offset.x, offset.y, image.size.width * scaleFactor, image.size.height * scaleFactor);
        imageRect = CGRectIntegral(imageRect);
        [image drawInRect:imageRect];
        thumbnail = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        (self.cachedThumbnails)[sampleURL.path] = thumbnail;
    } 
    
    return thumbnail;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *kCellIdentifier = @"cellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier];
        
        // add a slight shadow to the image view
        CALayer *caLayer = cell.imageView.layer;
        caLayer.shadowOpacity = 0.25;
        caLayer.shadowOffset = CGSizeMake(0,1);
        caLayer.shadowRadius = 2;
        
        // don't want thumbnail image too close to left edge
        cell.indentationLevel = 1;
        cell.indentationWidth = 5;
    }
    
    NSURL *sampleURL = (self.sampleURLs)[indexPath.row];
    cell.textLabel.text = [[sampleURL lastPathComponent] stringByDeletingPathExtension];
    cell.accessoryType = [self.selectedURLs containsObject:sampleURL] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.imageView.image = [self thumbnailForURL:sampleURL];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSURL *sampleURL = (self.sampleURLs)[indexPath.row];
    if (![self.selectedURLs containsObject:sampleURL]) {
        [self.selectedURLs addObject:sampleURL];
        [tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        [self.selectedURLs removeObject:sampleURL];
        [tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryNone;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    self.importButton.title = [self importButtonTitle];
    self.importButton.enabled = self.selectedURLs.count > 0 ? YES : NO;
}

#pragma mark -

- (void) importButtonTapped:(id)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(samplesController:didSelectURLs:)]) {
        [self.delegate samplesController:self didSelectURLs:[self.selectedURLs allObjects]];
    }
}

- (void) importAllButtonTapped:(id)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(samplesController:didSelectURLs:)]) {
        [self.delegate samplesController:self didSelectURLs:self.sampleURLs];
    }
}

#pragma mark -

- (NSString *)importButtonTitle
{
    NSString *title = nil;
    if (self.selectedURLs.count < 1) {
        title = NSLocalizedString(@"Import", @"Import");
    } else {
        NSString *format = NSLocalizedString(@"Import %lu", @"Import %lu");
        title = [NSString stringWithFormat:format, (unsigned long)self.selectedURLs.count];
    }
    return title;
}

@end
