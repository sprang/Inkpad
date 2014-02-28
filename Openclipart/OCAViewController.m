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
#import "UIView+Additions.h"
#import "WDUtilities.h"

//
// OCACollectionViewFooter
//

@interface OCACollectionViewFooter : UICollectionReusableView
@property (nonatomic) UIActivityIndicatorView *activity;
@end

@implementation OCACollectionViewFooter
- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    _activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activity.color = [UIColor colorWithRed:0.0f green:118.0f / 255 blue:1.0f alpha:1.0f];
    
    CGPoint center = WDCenterOfRect(self.bounds);
    center.y -= 10;
    _activity.sharpCenter = center;
    
    [self addSubview:_activity];
    
    return self;
}
@end


//
// OCAViewController
//

@interface OCAViewController ()

@property (nonatomic) UIBarButtonItem   *importButton;
@property (nonatomic) UILabel           *itemCountLabel;

@property (nonatomic) SEL               action;
@property (nonatomic) id                target;

@property (nonatomic) NSString          *queryString;
@property (nonatomic) NSString          *sortMode;

@property (nonatomic) NSMutableArray    *entries;
@property (nonatomic) NSUInteger        numItems;

@property (nonatomic) OCADownloader     *downloader;
@property (nonatomic) NSUInteger        pageCount;
@property (nonatomic) NSUInteger        nextPageToLoad;
@property (nonatomic) BOOL              moreToLoad;
@property (nonatomic) BOOL              haveSearchResults;

@end

@implementation OCAViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    self.title = NSLocalizedString(@"Openclipart", @"Title of Openclipart import panel. Probably shouldn't be localized.");
    
    _importButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Import", @"Import")
                                                     style:UIBarButtonItemStyleDone
                                                    target:self
                                                    action:@selector(performAction:)];
    self.navigationItem.rightBarButtonItem = _importButton;
    _importButton.enabled = NO;
    
    _entries = [NSMutableArray array];
    _sortMode = @"downloads";
    
    return self;
}

- (void) setImportTarget:(id)target action:(SEL)action
{
    self.target = target;
    self.action = action;
}

- (void) setActionTitle:(NSString *)title
{
    self.importButton.title = title;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.collectionView registerClass:[OCAThumbnailCell class] forCellWithReuseIdentifier:@"cellID"];
    
    [self.collectionView registerClass:[OCACollectionViewFooter class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                   withReuseIdentifier:@"footerID"];
    
    self.toolbarItems = [self toolbarItemArray];
    
    UIToolbar *toolbar = self.navigationController.toolbar;
    toolbar.translucent = NO;
    toolbar.backgroundColor = [UIColor colorWithWhite:0.975f alpha:1.0f];
    
    // work around localization bug with UISearchBar in an XIB?
    self.searchBar.placeholder = NSLocalizedString(@"Search Openclipart", @"Openclipart search bar placeholder text.");
    
    self.preferredContentSize = self.view.frame.size;
}

- (NSArray *) toolbarItemArray
{
    UIBarButtonItem *flexibleSpaceItem = [UIBarButtonItem flexibleItem];
    
    self.itemCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,0,100,44)];
    UIBarButtonItem *countItem = [[UIBarButtonItem alloc] initWithCustomView:self.itemCountLabel];
    
    return @[flexibleSpaceItem, countItem, flexibleSpaceItem];
}

- (void) performAction:(id)sender
{
    [[UIApplication sharedApplication] sendAction:self.action to:self.target from:self forEvent:nil];
}

- (void) updateItemCount
{
    if (self.numItems == 0) {
        self.itemCountLabel.text = NSLocalizedString(@"No items found", @"Label for no Openclipart search results");
    } else if (self.numItems == 1) {
        self.itemCountLabel.text = NSLocalizedString(@"1 item found", @"Label for Openclipart search results (1)");
    } else {
        NSString *format = NSLocalizedString(@"%lu items found", @"Format string for Openclipart search results");
        self.itemCountLabel.text = [NSString stringWithFormat:format, self.numItems];
    }
    
    self.itemCountLabel.hidden = !self.haveSearchResults;
    [self.itemCountLabel sizeToFit];
}

- (void) setNumItems:(NSUInteger)numItems
{
    _numItems = numItems;
    [self updateItemCount];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.visible = false;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.visible = true;
}

#pragma mark - Downloader

- (void) takeDataFromDownloader:(OCADownloader *)downloader
{
    id jsonData = [NSJSONSerialization JSONObjectWithData:downloader.data options:0 error:nil];
    
    if (!jsonData) {
        WDLog(@"Failed to load from JSON!");
    }
    
    self.haveSearchResults = YES;
    self.numItems = [jsonData[@"info"][@"results"] integerValue];
    self.pageCount = [jsonData[@"info"][@"pages"] integerValue];

    NSUInteger currentPage = [jsonData[@"info"][@"current_page"] integerValue];
    self.moreToLoad = currentPage < self.pageCount;
    
    if (currentPage == 1) {
        [self.entries removeAllObjects];
    }
    
    self.nextPageToLoad++;
    
    for (NSDictionary *dict in jsonData[@"payload"]) {
        OCAEntry *entry = [OCAEntry openClipArtEntryWithDictionary:dict];
        [self.entries addObject:entry];
    }
    
    self.downloader = nil;
    
    [self.collectionView reloadData];
}

#pragma mark - Search

- (void) loadNextPage
{
    if (self.downloader) {
        return;
    }
    
    NSString *urlString = @"https://openclipart.org/search/json/?query=";
    urlString = [urlString stringByAppendingString:self.queryString];
    urlString = [urlString stringByAppendingString:@"&amount=30"];
    urlString = [urlString stringByAppendingString:@"&sort="];
    urlString = [urlString stringByAppendingString:self.sortMode];
    urlString = [urlString stringByAppendingString:@"&page="];
    urlString = [urlString stringByAppendingString:@(self.nextPageToLoad).stringValue];
    
    self.downloader = [OCADownloader downloaderWithURL:urlString delegate:self];
}

- (void) clearSearch
{
    if (self.downloader) {
        [self.downloader cancel];
        self.downloader = nil;
    }
    
    self.moreToLoad = NO;
    self.haveSearchResults = NO;
    self.numItems = 0;

    [self.entries removeAllObjects];
    [self.collectionView reloadData];
}

- (void) updateSearch:(UISearchBar *)searchBar
{
    NSArray *tokens = [searchBar.text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *searchTerm = [tokens componentsJoinedByString:@"+"];
    searchTerm = [searchTerm stringByAddingPercentEscapesUsingEncoding:NSStringEncodingConversionAllowLossy];

    self.queryString = searchTerm;
    self.moreToLoad = YES;
    self.nextPageToLoad = 1;
    
    [self.collectionView reloadData];
    
    [self loadNextPage];
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

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope
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
    self.selectedEntry = self.entries[indexPath.row];
    self.importButton.enabled = YES;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.entries.count;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    OCAThumbnailCell *thumbnail = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"cellID" forIndexPath:indexPath];
    
    thumbnail.entry = [self.entries objectAtIndex:indexPath.row];
    
    return thumbnail;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
    OCACollectionViewFooter *footerView = nil;
    
    if (kind == UICollectionElementKindSectionFooter) {
        footerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                                        withReuseIdentifier:@"footerID"
                                                               forIndexPath:indexPath];
        if (self.moreToLoad) {
            [footerView.activity startAnimating];
        } else {
            [footerView.activity stopAnimating];
        }
    }
    
    return footerView;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.y == scrollView.contentSize.height - scrollView.frame.size.height) {
        if (self.nextPageToLoad <= self.pageCount) {
            [self loadNextPage];
        }
    }
}

@end
