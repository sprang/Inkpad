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

#import <CoreText/CoreText.h>
#import "WDCanvasController.h"
#import "WDDrawingController.h"
#import "WDCoreTextLabel.h"
#import "WDFontController.h"
#import "WDFontManager.h"
#import "WDInspectableProperties.h"
#import "WDPropertyManager.h"

#define kMinFontSize            1
#define kMaxFontSize            200
#define kCoreTextLabelTag       1

@implementation WDFontController

@synthesize drawingController = drawingController_;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.text = NSLocalizedString(@"Font", @"Font");
    title.font = [UIFont boldSystemFontOfSize:17.0f];
    title.textColor = [UIColor blackColor];
    title.backgroundColor = nil;
    title.opaque = NO;
    [title sizeToFit];
    
    // make sure the title is centered vertically
    CGRect frame = title.frame;
    frame.size.height = 44;
    title.frame = frame;
    
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:title];
    self.navigationItem.leftBarButtonItem = item;
    
    alignment_ = [[UISegmentedControl alloc] initWithItems:@[[UIImage imageNamed:@"textLeft.png"],
                                                             [UIImage imageNamed:@"textCenter.png"],
                                                             [UIImage imageNamed:@"textRight.png"]]];
    [alignment_ sizeToFit];
    frame = alignment_.frame;
    frame.size.width += 30;
    alignment_.frame = frame;
    
    [alignment_ addTarget:self action:@selector(takeAlignmentFrom:) forControlEvents:UIControlEventValueChanged];
    
    item = [[UIBarButtonItem alloc] initWithCustomView:alignment_];
    self.navigationItem.rightBarButtonItem = item;
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setDrawingController:(WDDrawingController *)drawingController
{
    drawingController_ = drawingController;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(invalidProperties:)
                                                 name:WDInvalidPropertiesNotification
                                               object:drawingController.propertyManager];
}

- (IBAction) decrement:(id)sender
{
    sizeSlider_.value = sizeSlider_.value - 1;
    [sizeSlider_ sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (IBAction) increment:(id)sender
{
    sizeSlider_.value = sizeSlider_.value + 1;
    [sizeSlider_ sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (IBAction) takeFontSizeFrom:(id)sender
{
    int size = round([(UISlider *)sender value]);
    sizeLabel_.text = [NSString stringWithFormat:@"%d pt", size];
}

- (IBAction) takeFinalFontSizeFrom:(id)sender
{
    int size = round([(UISlider *)sender value]);
    [drawingController_ setValue:@(size) forProperty:WDFontSizeProperty];
}

- (IBAction) takeAlignmentFrom:(id)sender
{
    [drawingController_ setValue:@(alignment_.selectedSegmentIndex) forProperty:WDTextAlignmentProperty];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    sizeSlider_.minimumValue = kMinFontSize;
    sizeSlider_.maximumValue = kMaxFontSize;
    
    alignment_.selectedSegmentIndex = [[drawingController_.propertyManager defaultValueForProperty:WDTextAlignmentProperty] intValue];
    
    int size = [[drawingController_.propertyManager defaultValueForProperty:WDFontSizeProperty] intValue];
    sizeSlider_.value = size;
    sizeLabel_.text = [NSString stringWithFormat:@"%d pt", size];

    UIColor *color = [UIColor colorWithWhite:1 alpha:0.5f];
    familyTable_.backgroundColor = color;
    faceTable_.backgroundColor = color;
    
    CALayer *layer = familyTable_.layer;
    color = [UIColor colorWithWhite:0.9f alpha:1.0];
    layer.borderColor = color.CGColor;
    layer.borderWidth = 1;
    
    layer = faceTable_.layer;
    layer.borderColor = color.CGColor;
    layer.borderWidth = 1;
    
    self.preferredContentSize = self.view.frame.size;
}

- (NSString *) defaultFontFamilyName
{
    NSString *defaultFontName = [drawingController_.propertyManager defaultValueForProperty:WDFontNameProperty];
    return [[WDFontManager sharedInstance] familyNameForFont:defaultFontName];
}

- (void) scrollToSelectedFont
{
    NSString    *defaultFontName = [drawingController_.propertyManager defaultValueForProperty:WDFontNameProperty];
    NSString    *familyName = [[WDFontManager sharedInstance] familyNameForFont:defaultFontName];
    NSUInteger  familyIndex;
    BOOL        scroll;
    
    // update the family table
    familyIndex = [[[WDFontManager sharedInstance] supportedFamilies] indexOfObject:familyName];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:familyIndex inSection:0];
    
    scroll = ![[familyTable_ indexPathsForVisibleRows] containsObject:indexPath];
    UITableViewScrollPosition position = scroll ? UITableViewScrollPositionMiddle : UITableViewScrollPositionNone;
    [familyTable_ selectRowAtIndexPath:indexPath animated:YES scrollPosition:position];
    
    // update the typeface table
    if (![familyName isEqualToString:lastLoadedFamily_]) {
        [faceTable_ reloadData];
        lastLoadedFamily_ = familyName;
    }
    NSArray *faces = [[WDFontManager sharedInstance] fontsInFamily:familyName];
    NSUInteger faceIndex = [faces indexOfObject:defaultFontName];
    
    indexPath = [NSIndexPath indexPathForRow:faceIndex inSection:0];
    scroll = ![[faceTable_ indexPathsForVisibleRows] containsObject:indexPath];
    position = scroll ? UITableViewScrollPositionMiddle : UITableViewScrollPositionNone;
    [faceTable_ selectRowAtIndexPath:indexPath animated:YES scrollPosition:position];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self scrollToSelectedFont];
}

- (void) invalidProperties:(NSNotification *)aNotification
{
    NSSet *properties = [aNotification userInfo][WDInvalidPropertiesKey];
    
    for (NSString *property in properties) {
        id value = [drawingController_.propertyManager defaultValueForProperty:property];
        
        if ([property isEqualToString:WDFontNameProperty]) {
            [self scrollToSelectedFont];
        } else if ([property isEqualToString:WDFontSizeProperty]) {
            int size = [value intValue];
            
            sizeSlider_.value = size;
            sizeLabel_.text = [NSString stringWithFormat:@"%d pt", size];
        } else if ([property isEqualToString:WDTextAlignmentProperty]) {
            [alignment_ removeTarget:self action:@selector(takeAlignmentFrom:) forControlEvents:UIControlEventValueChanged];
            alignment_.selectedSegmentIndex = [value intValue];
            [alignment_ addTarget:self action:@selector(takeAlignmentFrom:) forControlEvents:UIControlEventValueChanged];
        }
    }
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    if (table == familyTable_) {
        return [[[WDFontManager sharedInstance] supportedFamilies] count];
    }
    
    NSString *familyName = [self defaultFontFamilyName];
    
    return [[[WDFontManager sharedInstance] fontsInFamily:familyName] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString        *cellIdentifier = @"fontIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        
        WDCoreTextLabel *label = [[WDCoreTextLabel alloc] initWithFrame:cell.contentView.bounds];
        label.tag = kCoreTextLabelTag;
        [cell.contentView addSubview:label];
        
        UIView *selectionView = [[UIView alloc] init];
        cell.selectedBackgroundView = selectionView;
        selectionView.backgroundColor = [UIColor colorWithRed:(193.0f / 255) green:(220.0f / 255) blue:1.0f alpha:0.666f];
    }
    
    NSString *fontName = nil;
    CGFloat fontSize = 18.0f;
    WDCoreTextLabel *previewLabel = (WDCoreTextLabel *) [cell viewWithTag:kCoreTextLabelTag];
    
    if (tableView == familyTable_) {
        // Set the text to the font family name
        NSString *familyName = [[WDFontManager sharedInstance] supportedFamilies][indexPath.row];
        [previewLabel setText:familyName];
        
        fontName = [[WDFontManager sharedInstance] defaultFontForFamily:familyName];
    } else {
        NSString *familyName = [self defaultFontFamilyName];
        
        // Set the text to the font display name
        fontName = [[WDFontManager sharedInstance] fontsInFamily:familyName][indexPath.row];
        [previewLabel setText:[[WDFontManager sharedInstance] typefaceNameForFont:fontName]];
    }
    
    // Set both cells to use a font for the preview label
    CTFontRef fontRef = [[WDFontManager sharedInstance] newFontRefForFont:fontName withSize:fontSize];
    [previewLabel setFontRef:fontRef];
    CFRelease(fontRef);
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    WDCoreTextLabel *previewLabel = (WDCoreTextLabel *) [cell viewWithTag:kCoreTextLabelTag];
    previewLabel.frame = CGRectInset(cell.contentView.bounds, 10, 0);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *font = nil;
    NSString *familyName;
    
    if (tableView == familyTable_) {
        familyName = [[WDFontManager sharedInstance] supportedFamilies][indexPath.row];
        font = [[WDFontManager sharedInstance] defaultFontForFamily:familyName];
    } else {
        familyName = [self defaultFontFamilyName];
        font = [[WDFontManager sharedInstance] fontsInFamily:familyName][indexPath.row];
    }
    
    [drawingController_ setValue:font forProperty:WDFontNameProperty];
}

@end
