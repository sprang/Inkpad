//
//  OCAViewController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import "OCAViewController.h"
#import "OCAEntry.h"
#import "OCAThumbnailCell.h"
#import "UIBarButtonItem+Additions.h"

@interface OCAViewController () {
    BOOL            haveSearchResults_;
    OCADownloader   *downloader_;
}

@property (nonatomic) UIBarButtonItem       *importButton;
@property (nonatomic) UILabel               *itemCountLabel;
@property (nonatomic) NSMutableArray        *entries;
@property (nonatomic) NSUInteger            numItems;
@property (nonatomic) NSString              *sortMode;
@property (nonatomic) SEL                   action;
@property (nonatomic) id                    target;

@end

@implementation OCAViewController

@synthesize importButton = importButton_;
@synthesize itemCountLabel = itemCountLabel_;
@synthesize entries = entries_;
@synthesize selectedEntry = selectedEntry_;
@synthesize numItems = numItems_;
@synthesize sortMode = sortMode_;
@synthesize action = action_;
@synthesize target = target_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    self.title = NSLocalizedString(@"Openclipart", @"Title of Openclipart import panel. Probably shouldn't be localized.");
    
	importButton_ = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Import", @"Import")
                                                     style:UIBarButtonItemStyleDone
                                                    target:self
                                                    action:@selector(performAction:)];
	self.navigationItem.rightBarButtonItem = importButton_;
    importButton_.enabled = NO;
    
    entries_ = [NSMutableArray array];
    self.sortMode = @"downloads";
    
    return self;
}

- (void) setImportTarget:(id)target action:(SEL)action
{
    self.target = target;
    self.action = action;
}

- (void) setActionTitle:(NSString *)title
{
    importButton_.title = title;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.collectionView registerClass:[OCAThumbnailCell class] forCellWithReuseIdentifier:@"cellID"];
    
    [self.navigationController setToolbarHidden:NO];
    self.toolbarItems = [self toolbarItemArray];
    
    self.preferredContentSize = self.view.frame.size;
}

- (NSArray *) toolbarItemArray
{
    UIBarButtonItem *flexibleSpaceItem = [UIBarButtonItem flexibleItem];
    
    itemCountLabel_ = [[UILabel alloc] initWithFrame:CGRectMake(0,0,100,20)];
    UIBarButtonItem *countItem = [[UIBarButtonItem alloc] initWithCustomView:itemCountLabel_];
    
    return @[flexibleSpaceItem, countItem, flexibleSpaceItem];
}

- (void) performAction:(id)sender
{
    [[UIApplication sharedApplication] sendAction:action_ to:target_ from:self forEvent:nil];
}

- (void) setNumItems:(NSUInteger)numItems
{
    numItems_ = numItems;
    [self updateItemCount];
}

- (void) updateItemCount
{
    if (numItems_ == 0) {
        itemCountLabel_.text = NSLocalizedString(@"No Items Found", @"Label for no Openclipart search results");
    } else if (numItems_ == 1) {
        itemCountLabel_.text = NSLocalizedString(@"1 Item Found", @"Label for Openclipart search results (1)");
    } else {
        NSString *format = NSLocalizedString(@"%lu Items Found", @"Format string for Openclipart search results");
        itemCountLabel_.text = [NSString stringWithFormat:format, numItems_];
    }
    
    itemCountLabel_.hidden = !haveSearchResults_;
    [itemCountLabel_ sizeToFit];
    
}
#pragma mark - Downloader

- (void) takeDataFromDownloader:(OCADownloader *)downloader
{
    id jsonData = [NSJSONSerialization JSONObjectWithData:downloader.data options:0 error:nil];
    
    if (!jsonData) {
        NSLog(@"Failed to load from JSON!");
    }
    
    haveSearchResults_ = YES;
    self.numItems = [jsonData[@"info"][@"results"] integerValue];
    
    [entries_ removeAllObjects];
    for (NSDictionary *dict in jsonData[@"payload"]) {
        OCAEntry *entry = [OCAEntry openClipArtEntryWithDictionary:dict];
        [entries_ addObject:entry];
    }
    
    downloader_ = nil;
    [self.activityIndicator stopAnimating];
    [self.collectionView reloadData];
}

#pragma mark - Search

- (void) clearSearch
{
    haveSearchResults_ = NO;
    self.numItems = 0;

    [entries_ removeAllObjects];
    [self.collectionView reloadData];
}

- (void) updateSearch:(UISearchBar *)searchBar
{
    NSArray *tokens = [searchBar.text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *searchTerm = [tokens componentsJoinedByString:@"+"];
    searchTerm = [searchTerm stringByAddingPercentEscapesUsingEncoding:NSStringEncodingConversionAllowLossy];
    
    // TODO (sprang): Handle multiple pages of result data...
    NSString *urlString = @"https://openclipart.org/search/json/?query=";
    urlString = [urlString stringByAppendingString:searchTerm];
    urlString = [urlString stringByAppendingString:@"&page=1&amount=42&sort="];
    urlString = [urlString stringByAppendingString:self.sortMode];
    
    if (downloader_) {
        [downloader_ cancel];
        downloader_ = nil;
    }
    
    downloader_ = [OCADownloader downloaderWithURL:urlString delegate:self];
    [self.activityIndicator startAnimating];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    [self updateSearch:searchBar];
}

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self clearSearch];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope NS_AVAILABLE_IOS(3_0)
{
    NSString *modes[] = {@"downloads", @"favorites", @"date"};
    self.sortMode = modes[selectedScope];
    
    [self clearSearch];
    
    if (!searchBar.text || ![searchBar.text isEqualToString:@""]) {
        [self updateSearch:searchBar];
    }
}

#pragma mark - Collection View

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    self.selectedEntry = entries_[indexPath.row];
    importButton_.enabled = YES;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return entries_.count;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    OCAThumbnailCell *thumbnail = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"cellID" forIndexPath:indexPath];
    
    thumbnail.entry = [entries_ objectAtIndex:indexPath.row];
    
    return thumbnail;
}

@end
