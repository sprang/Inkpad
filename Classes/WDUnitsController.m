//
//  WDUnitsController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDDrawing.h"
#import "WDRulerView.h"
#import "WDRulerUnit.h"
#import "WDUnitsController.h"
#import "WDUtilities.h"

NSString *WDCustomDrawingSizeChanged = @"WDCustomDrawingSizeChanged";

@implementation WDUnitsController

@synthesize drawing = drawing_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    units_ = @[NSLocalizedString(@"Points", @"Points"),
              NSLocalizedString(@"Picas", @"Picas"),
              NSLocalizedString(@"Inches", @"Inches"),
              NSLocalizedString(@"Millimeters", @"Millimeters"),
              NSLocalizedString(@"Centimeters", @"Centimeters"),
              NSLocalizedString(@"Pixels", @"Pixels")];
    
    self.navigationItem.title = NSLocalizedString(@"Custom Size", @"Custom Size");
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setDrawing:(WDDrawing *)drawing
{
    drawing_ = drawing;
    
    self.navigationItem.title = NSLocalizedString(@"Size and Units", @"Size and Units");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawingDimensionsChanged:)
                                                 name:WDDrawingDimensionsChanged
                                               object:drawing_];
}

- (NSNumberFormatter *) formatter
{
    if (!formatter_) {
        formatter_ = [[NSNumberFormatter alloc] init];
        
        [formatter_ setNumberStyle:NSNumberFormatterDecimalStyle];
        [formatter_ setMaximumFractionDigits:2];
        [formatter_ setRoundingMode:NSNumberFormatterRoundHalfUp];
        [formatter_ setUsesGroupingSeparator:NO];
        [formatter_ setNegativeFormat:@""];
    }
    
    return formatter_;
}

- (void)loadView
{
    table_ = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 13 * 44) style:UITableViewStyleGrouped];
    table_.delegate = self;
    table_.dataSource = self;
    table_.sectionHeaderHeight = 0;
    table_.sectionFooterHeight = 0;
    table_.separatorColor = [UIColor lightGrayColor];
    table_.separatorInset = UIEdgeInsetsMake(0, 15, 0, 0);
    self.view = table_;
    
    self.preferredContentSize = self.view.frame.size;
}

- (WDRulerUnit *) units
{
    return [WDRulerView rulerUnits][(drawing_ ? drawing_.units : [[NSUserDefaults standardUserDefaults] objectForKey:WDCustomSizeUnits])];
}

- (void) updateDimensionFields
{
    NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    WDRulerUnit     *unit = [self units];
    CGSize          size;
    
    if (drawing_) {
        size = drawing_.dimensions;
    } else {
        size = CGSizeMake([defaults floatForKey:WDCustomSizeWidth], [defaults floatForKey:WDCustomSizeHeight]);
    }
    
    NSString *width = [[self formatter] stringFromNumber:@(size.width / unit.conversionFactor)];
    if (!width_.isEditing) {
        width_.text = nil;
    }
    width_.placeholder = [NSString stringWithFormat:@"%@ %@", width, unit.abbreviation];
    
    NSString *height = [[self formatter] stringFromNumber:@(size.height / unit.conversionFactor)];
    if (!height_.isEditing) {
        height_.text = nil;
    }
    height_.placeholder = [NSString stringWithFormat:@"%@ %@", height, unit.abbreviation];
}

- (void) drawingDimensionsChanged:(NSNotification *)aNotification
{
    [self updateDimensionFields];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateDimensionFields];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) { // dimensions
        return 2;
    } else { // units
        return units_.count;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
{
    return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) { // dimensions
        return NSLocalizedString(@"Drawing Size", @"Drawing Size");
    } else {
        return NSLocalizedString(@"Units", @"Units");
    }
}

- (void) widthFieldEdited:(id)sender
{
    WDRulerUnit *unit = [self units];
    NSArray     *components = [width_.text componentsSeparatedByString:@" "];
    NSNumber    *newWidth = [[self formatter] numberFromString:components[0]];
    
    if (newWidth && newWidth.floatValue > 0) {
        float widthInPoints = WDClamp(kMinimumDrawingDimension, kMaximumDrawingDimension,
                              newWidth.floatValue * unit.conversionFactor);
        
        if (drawing_) {
            drawing_.width = widthInPoints;
        } else {
            [[NSUserDefaults standardUserDefaults] setFloat:widthInPoints forKey:WDCustomSizeWidth];
            [[NSNotificationCenter defaultCenter] postNotificationName:WDCustomDrawingSizeChanged object:self];
        }
    }
    
    [self updateDimensionFields];
}

- (void) heightFieldEdited:(id)sender
{
    WDRulerUnit *unit = [self units];
    NSNumber    *newHeight = [[self formatter] numberFromString:height_.text];
    
    if (newHeight && newHeight.floatValue > 0) {
        float heightInPoints = WDClamp(kMinimumDrawingDimension, kMaximumDrawingDimension,
                                       newHeight.floatValue * unit.conversionFactor);
        
        if (drawing_) {
            drawing_.height = heightInPoints;
        } else {
            [[NSUserDefaults standardUserDefaults] setFloat:heightInPoints forKey:WDCustomSizeHeight];
            [[NSNotificationCenter defaultCenter] postNotificationName:WDCustomDrawingSizeChanged object:self];
        }
    }
    
    [self updateDimensionFields];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString    *proposed = textField.text;
    NSNumber    *number = nil;
    
    if (![string isEqualToString:@"\n"]) {
        proposed = [proposed stringByReplacingCharactersInRange:range withString:string];
    }
    
    if (proposed.length == 0) {
        return YES;
    }
    
    if ([proposed isEqualToString:@"."]) {
        return YES;
    }
    
    number = [[self formatter] numberFromString:proposed];
    if (!number || [number floatValue] < 0) {
        return NO;
    }
    
    return YES;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"cellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    if (indexPath.section == 0) {
        cell.textLabel.text = (indexPath.row == 0) ? NSLocalizedString(@"Width", @"Width") : NSLocalizedString(@"Height", @"Height");
        
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0,0,130,31)];
        textField.textAlignment = NSTextAlignmentRight;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        textField.returnKeyType = UIReturnKeyDone;
        textField.delegate = self;
        
        cell.accessoryView = textField;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        WDRulerUnit *unit = [self units];
        
        if (indexPath.row == 0) { // width
            width_ = textField;
            [textField addTarget:self action:@selector(widthFieldEdited:) forControlEvents:(UIControlEventEditingDidEnd | UIControlEventEditingDidEndOnExit)];
            
            float dimension = (drawing_ ? drawing_.width : [[NSUserDefaults standardUserDefaults] floatForKey:WDCustomSizeWidth]);
            NSString *width = [[self formatter] stringFromNumber:@(dimension / unit.conversionFactor)];
            width_.placeholder = [NSString stringWithFormat:@"%@ %@", width, unit.abbreviation];
        } else { // height
            height_ = textField;
            [textField addTarget:self action:@selector(heightFieldEdited:) forControlEvents:(UIControlEventEditingDidEnd | UIControlEventEditingDidEndOnExit)];
            
            float dimension = (drawing_ ? drawing_.height : [[NSUserDefaults standardUserDefaults] floatForKey:WDCustomSizeHeight]);
            NSString *height = [[self formatter] stringFromNumber:@(dimension / unit.conversionFactor)];
            height_.placeholder = [NSString stringWithFormat:@"%@ %@", height, unit.abbreviation];
        }
    } else {
        cell.textLabel.text = units_[indexPath.row];
        
        if ([[self units].name isEqualToString:units_[indexPath.row]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath
{   
    if (newIndexPath.section == 0) {
        return;
    }
    
    NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    NSIndexPath     *oldIndex;
    
    if (drawing_) {
        oldIndex = [NSIndexPath indexPathForRow:[units_ indexOfObject:drawing_.units] inSection:1];
        drawing_.units = units_[newIndexPath.row];
        
        [[NSUserDefaults standardUserDefaults] setObject:drawing_.units forKey:WDUnits];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        oldIndex = [NSIndexPath indexPathForRow:[units_ indexOfObject:[defaults objectForKey:WDCustomSizeUnits]] inSection:1];
        [defaults setObject:units_[newIndexPath.row] forKey:WDCustomSizeUnits];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDCustomDrawingSizeChanged object:self];
    }
    
    [table_ cellForRowAtIndexPath:oldIndex].accessoryType = UITableViewCellAccessoryNone;
    
    [table_ deselectRowAtIndexPath:newIndexPath animated:NO];
    [table_ cellForRowAtIndexPath:newIndexPath].accessoryType = UITableViewCellAccessoryCheckmark;
    
    [self updateDimensionFields];
}

@end
