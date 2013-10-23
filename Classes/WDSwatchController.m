//
//  WDSwatchController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDColor.h"
#import "WDDrawingController.h"
#import "WDGradient.h"
#import "WDInspectableProperties.h"
#import "WDPropertyManager.h"
#import "WDShadow.h"
#import "WDSwatchCell.h"
#import "WDSwatchController.h"
#import "UIBarButtonItem+Additions.h"

NSString *WDSwatches = @"WDSwatches";
NSString *WDSwatchAdded = @"WDSwatchAdded";
NSString *WDSwatchPanelModeKey = @"WDSwatchPanelModeKey";

#define kSwatchDimension     42
#define kSwatchesPerRow      8
#define kSwatchSpacing       4

@implementation WDSwatchController

@synthesize drawingController = drawingController_;
@synthesize swatches = swatches_;

- (UIBarButtonItem *) addSwatchItem
{
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                         target:self
                                                         action:@selector(createNewSwatch:)];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    BOOL shouldSave = NO;
    swatches_ = [self loadSwitches:&shouldSave];
    if (shouldSave) {
        [self saveSwatches];
    }
    
    selectedSwatches_ = [[NSMutableSet alloc] init];
    mode_ = [[NSUserDefaults standardUserDefaults] integerForKey:WDSwatchPanelModeKey];
    
    self.navigationItem.title = NSLocalizedString(@"Swatches", @"Swatches");
    self.navigationItem.rightBarButtonItem = [self addSwatchItem];
    self.navigationItem.leftBarButtonItem = [self editButtonItem];
    
    return self;  
}

- (NSMutableArray *) loadSwitches:(BOOL *)shouldSave
{
    NSMutableArray *loadedSwatches;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    *shouldSave = NO;

    // attempt to load archived swatches
    if ([defaults objectForKey:WDSwatches]) {
        loadedSwatches = [NSKeyedUnarchiver unarchiveObjectWithData:[defaults objectForKey:WDSwatches]];
    }
    
    if (!loadedSwatches) {
        loadedSwatches = [[NSMutableArray alloc] init];
        
        // add 4 gray tones 
        for (int step = 0; step < 4; step++) {
            [loadedSwatches addObject:[WDColor colorWithHue:0 saturation:0 brightness:(step / 3.0f) alpha:1]];
        }
        
        // add starter colors 
        [loadedSwatches addObject:[WDColor colorWithHue:(180.0f / 360) saturation:0.21f brightness:0.56f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(138.0f / 360) saturation:0.36f brightness:0.71f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(101.0f / 360) saturation:0.38f brightness:0.49f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(19.0f / 360) saturation:0.49f brightness:0.37f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(215.0f / 360) saturation:0.34f brightness:0.87f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(207.0f / 360) saturation:0.90f brightness:0.64f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(229.0f / 360) saturation:0.59f brightness:0.45f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(272.0f / 360) saturation:0.28f brightness:0.36f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(331.0f / 360) saturation:0.28f brightness:0.51f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(44.0f / 360) saturation:0.77f brightness:0.85f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(84.0f / 360) saturation:0.15f brightness:0.9f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(51.0f / 360) saturation:0.08f brightness:0.96f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(5.0f / 360) saturation:0.65f brightness:0.96f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(15.0f / 360) saturation:0.39f brightness:0.98f alpha:1]];
        [loadedSwatches addObject:[WDColor colorWithHue:(59.0f / 360) saturation:0.27f brightness:0.99f alpha:1]];
        
        // add starter gradients
        WDColor *endColor = [WDColor colorWithHue:(201.0f / 360) saturation:1.0f brightness:0.57f alpha:1.0f];
        [loadedSwatches addObject:[WDGradient gradientWithStart:[WDColor whiteColor] andEnd:endColor]];
        
        WDColor *startColor = [WDColor colorWithHue:0.0f saturation:1.0f brightness:0.74f alpha:1.0f];
        endColor = [WDColor colorWithHue:(56.0f / 360) saturation:1.0f brightness:1.0f alpha:1.0f];
        [loadedSwatches addObject:[WDGradient gradientWithStart:startColor andEnd:endColor]];
        
        // since we created the swatches, we should save them
        *shouldSave = YES;
    }
    
    return loadedSwatches;
}

- (void) saveSwatches
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.swatches];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:WDSwatches];
}

- (void) addSwatch:(id<WDPathPainter>)swatch
{
    [self.swatches addObject:swatch];
    
    NSArray *indexPaths = @[[NSIndexPath indexPathForItem:(self.swatches.count - 1) inSection:0]];
    [collectionView_ insertItemsAtIndexPaths:indexPaths];
    
    [self saveSwatches];
}

- (void) createNewSwatch:(id)sender
{
    if (mode_ == kWDStrokeSwatchMode) {
        WDStrokeStyle *strokeStyle = [drawingController_.propertyManager activeStrokeStyle];
        
        if (strokeStyle) {
            [self addSwatch:strokeStyle.color];
        }
    } else if (mode_ == kWDFillSwatchMode) {
        id fillStyle = [drawingController_.propertyManager activeFillStyle];
        
        if (fillStyle) {
            [self addSwatch:fillStyle];
        }
    } else if (mode_ == kWDShadowSwatchMode) {
        WDShadow *shadow = [drawingController_.propertyManager activeShadow];
        
        if (shadow) {
            [self addSwatch:shadow.color];
        }
    }
}

- (CGSize) preferredContentSize
{
    float       width = kSwatchesPerRow * (kSwatchDimension + kSwatchSpacing) + kSwatchSpacing;
    NSUInteger  numRows = (self.swatches.count / kSwatchesPerRow) + 2;
    float       height = numRows * (kSwatchDimension + kSwatchSpacing) + kSwatchSpacing;
    
    return CGSizeMake(width, height);
}

- (void)loadView
{
    CGRect  frame = CGRectZero;
    frame.size = self.preferredContentSize;
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.minimumLineSpacing = kSwatchSpacing;
    flowLayout.minimumInteritemSpacing = kSwatchSpacing;
    flowLayout.itemSize = CGSizeMake(kSwatchDimension, kSwatchDimension);
    flowLayout.sectionInset = UIEdgeInsetsMake(kSwatchSpacing, kSwatchSpacing, kSwatchSpacing, kSwatchSpacing);
    
    collectionView_ = [[UICollectionView alloc] initWithFrame:frame collectionViewLayout:flowLayout];
    collectionView_.delegate = self;
    collectionView_.dataSource = self;
    collectionView_.alwaysBounceVertical = YES;
    collectionView_.backgroundColor = nil;
    
    [collectionView_ registerClass:[WDSwatchCell class] forCellWithReuseIdentifier:@"cellID"];
    
    self.view = collectionView_;
}

- (NSArray *) toolbarItems
{
    NSArray *labels = @[NSLocalizedString(@"Shadow", @"Shadow"),
                       NSLocalizedString(@"Stroke", @"Stroke"), NSLocalizedString(@"Fill", @"Fill")];
    modeSegment_ = [[UISegmentedControl alloc] initWithItems:labels];
    
    CGRect frame = modeSegment_.frame;
    frame.size.width =  kSwatchesPerRow * (kSwatchDimension + kSwatchSpacing) - (2 * kSwatchSpacing);
    modeSegment_.frame = frame;
    modeSegment_.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:WDSwatchPanelModeKey];
    
    [modeSegment_ addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem *modeItem = [[UIBarButtonItem alloc] initWithCustomView:modeSegment_];
    
    UIBarButtonItem *flexibleItem = [UIBarButtonItem flexibleItem];
    NSArray *result = @[flexibleItem, modeItem, flexibleItem];
    
    return result;
}

- (void) modeChanged:(id)sender
{
    mode_ = [modeSegment_ selectedSegmentIndex];
    [[NSUserDefaults standardUserDefaults] setInteger:mode_ forKey:WDSwatchPanelModeKey];
}

- (void) deleteSwatches:(id)sender
{
    NSArray *sorted = [[selectedSwatches_ allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    // remove them from the model
    for (NSIndexPath *indexPath in sorted.reverseObjectEnumerator) {
        [self.swatches removeObjectAtIndex:indexPath.item];
    }
    
    // remove them from the view
    [collectionView_ deleteItemsAtIndexPaths:sorted];
    
    [self saveSwatches];
    
    [selectedSwatches_ removeAllObjects];
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];

    collectionView_.allowsMultipleSelection = editing;
    
    if (editing) {
        self.title = NSLocalizedString(@"Select Swatches", @"Select Swatches");
        
        if (!deleteItem_) {
            deleteItem_ = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                        target:self
                                                                        action:@selector(deleteSwatches:)];
        }
        
        deleteItem_.enabled = NO;
        self.navigationItem.rightBarButtonItem = deleteItem_;
    } else {
        self.title = NSLocalizedString(@"Swatches", @"Swatches");
        self.navigationItem.rightBarButtonItem = [self addSwatchItem];
        
        // clear selection
        collectionView_.allowsSelection = NO;
        collectionView_.allowsSelection = YES;
        
        [selectedSwatches_ removeAllObjects];
    }
}

- (void) viewWillDisappear:(BOOL)animated
{
    [self setEditing:NO animated:NO];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath;
{
    WDSwatchCell *swatch = (WDSwatchCell *) [collectionView cellForItemAtIndexPath:indexPath];
    swatch.shouldShowSelectionIndicator = self.isEditing;
    
    return YES;
}

- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.isEditing) {
        id<WDPathPainter> swatch = (self.swatches)[indexPath.item];
        
        if (![swatch canPaintStroke] || mode_ == kWDFillSwatchMode) {
            // can't stroke, so set fill no matter what
            [drawingController_ setValue:swatch forProperty:WDFillProperty];
        } else if (mode_ == kWDStrokeSwatchMode) {
            [drawingController_ setValue:swatch forProperty:WDStrokeColorProperty];
        } else if (mode_ == kWDShadowSwatchMode) {
            [drawingController_ setValue:swatch forProperty:WDShadowColorProperty];
        }
    } else {
        [selectedSwatches_ addObject:indexPath];
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

- (void) collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isEditing) {
        [selectedSwatches_ removeObject:indexPath];
        self.navigationItem.rightBarButtonItem.enabled = [selectedSwatches_ count] == 0 ? NO : YES;
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;
{
    return self.swatches.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    WDSwatchCell *swatchCell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cellID" forIndexPath:indexPath];
    swatchCell.swatch = (self.swatches)[indexPath.item];
    return swatchCell;
}

@end
