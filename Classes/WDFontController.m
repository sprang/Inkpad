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
#define kTableFadeRadius        6
#define kCoreTextLabelTag       1

@implementation WDFontController

@synthesize drawingController = drawingController_;
@synthesize selectedFontName = selectedFontName_;

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
    
    sizeLabel_.text = [NSString stringWithFormat:@"%d pt", size];
    
    [drawingController_ setValue:@(size) forProperty:WDFontSizeProperty];
}

- (IBAction) takeAlignmentFrom:(id)sender
{
    [drawingController_ setValue:@(alignment_.selectedSegmentIndex) forProperty:WDTextAlignmentProperty];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Fonts", @"Fonts");
    
    sizeSlider_.minimumValue = kMinFontSize;
    sizeSlider_.maximumValue = kMaxFontSize;
    
    alignment_.selectedSegmentIndex = [[drawingController_.propertyManager defaultValueForProperty:WDTextAlignmentProperty] intValue];
    [alignment_ addTarget:self action:@selector(takeAlignmentFrom:) forControlEvents:UIControlEventValueChanged];
    
    int size = [[drawingController_.propertyManager defaultValueForProperty:WDFontSizeProperty] intValue];
    sizeSlider_.value = size;
    sizeLabel_.text = [NSString stringWithFormat:@"%d pt", size];
    
    self.preferredContentSize = self.view.frame.size;
}

- (void) scrollToSelectedFont
{
    NSString *defaultFontName = [drawingController_.propertyManager defaultValueForProperty:WDFontNameProperty];
    
    NSUInteger familyIndex;
    if (self.selectedFamilyName) {
        familyIndex = [[[WDFontManager sharedInstance] supportedFamilies] indexOfObject:self.selectedFamilyName];
    } else {
        familyIndex = [[[WDFontManager sharedInstance] supportedFonts] indexOfObject:defaultFontName];
    }
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:familyIndex inSection:0];
    [familyTable_ scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    
    NSUInteger faceIndex = [[[WDFontManager sharedInstance] supportedFonts] indexOfObject:defaultFontName];
    indexPath = [NSIndexPath indexPathForRow:faceIndex inSection:0];
    [faceTable_ scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [faceTable_ reloadData];
//    [self scrollToSelectedFont];
}

- (void) invalidProperties:(NSNotification *)aNotification
{
    NSSet *properties = [aNotification userInfo][WDInvalidPropertiesKey];
    
    for (NSString *property in properties) {
        id value = [drawingController_.propertyManager defaultValueForProperty:property];
        
        if ([property isEqualToString:WDFontNameProperty]) {
            if (![value isEqualToString:self.selectedFontName]) {
                [faceTable_ reloadData];
                [self scrollToSelectedFont];
            }
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
    if (table == familyTable_)
    {
        return [[[WDFontManager sharedInstance] supportedFamilies] count];
    }
    
    return [[[WDFontManager sharedInstance] fontsInFamily:self.selectedFamilyName] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString        *cellIdentifier = @"fontIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        
        WDCoreTextLabel *label = [[WDCoreTextLabel alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 10, 0)];
        label.tag = kCoreTextLabelTag;
        [cell.contentView addSubview:label];
    }
    
    NSString *fontName = nil;
    CGFloat fontSize = 20.0f;
    WDCoreTextLabel *previewLabel = (WDCoreTextLabel *) [cell viewWithTag:kCoreTextLabelTag];
    
    if (tableView == familyTable_)
    {
        // Set the text to the font family name
        NSString *familyName = [[WDFontManager sharedInstance] supportedFamilies][indexPath.row];
        [previewLabel setText:familyName];
        
        fontName = [[WDFontManager sharedInstance] defaultFontForFamily:familyName];
        fontSize = 15.f;
    } else {
        // Set the text to the font display name
        fontName = [[WDFontManager sharedInstance] fontsInFamily:self.selectedFamilyName][indexPath.row];
        fontSize = 18.f;
        [previewLabel setText:[[WDFontManager sharedInstance] displayNameForFont:fontName]];
    }
    
    // Set both cells to use a font for the preview label
    CTFontRef fontRef = [[WDFontManager sharedInstance] newFontRefForFont:fontName withSize:fontSize];
    [previewLabel setFontRef:fontRef];
    CFRelease(fontRef);
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == faceTable_)
    {
        NSString *fontNameForRow = [[WDFontManager sharedInstance] fontsInFamily:self.selectedFamilyName][indexPath.row];
        BOOL isDefaultFont = [fontNameForRow isEqualToString:[drawingController_.propertyManager defaultValueForProperty:WDFontNameProperty]];
        if (isDefaultFont || [fontNameForRow isEqualToString:self.selectedFontName])
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else {
//        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == familyTable_)
    {
        self.selectedFamilyName = [[WDFontManager sharedInstance] supportedFamilies][indexPath.row];
        [faceTable_ reloadData];
    } else {
        self.selectedFontName = [[WDFontManager sharedInstance] fontsInFamily:self.selectedFamilyName][indexPath.row];
        NSString *font = [[WDFontManager sharedInstance] fontsInFamily:self.selectedFamilyName][indexPath.row];
        [drawingController_ setValue:font forProperty:WDFontNameProperty];
        
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
        [tableView reloadData];
    }
}

@end
