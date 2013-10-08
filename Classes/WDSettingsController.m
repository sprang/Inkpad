//
//  WDSettingsController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDSettingsController.h"
#import "WDDrawing.h"
#import "WDRulerView.h"
#import "WDRulerUnit.h"
#import "WDUnitsController.h"

@implementation WDSettingsController

@synthesize drawing = drawing_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    self.navigationItem.title = NSLocalizedString(@"Settings", @"Settings");
    
    NSString *settingsPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Settings.plist"];
    configuration_ = [NSArray arrayWithContentsOfFile:settingsPath];
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setDrawing:(WDDrawing *)drawing
{
    drawing_ = drawing;
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // unregister for any old drawings
    [nc removeObserver:self];
    
    [nc addObserver:self selector:@selector(unitsChanged:) name:WDUnitsChangedNotification object:drawing_];
    [nc addObserver:self selector:@selector(drawingDimensionsChanged:) name:WDDrawingDimensionsChanged object:drawing_];
    [nc addObserver:self selector:@selector(gridSpacingChanged:) name:WDGridSpacingChangedNotification object:drawing_];
}

- (void)loadView
{
    table_ = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 5 * 28 + 9 * 44) style:UITableViewStyleGrouped];
    table_.delegate = self;
    table_.dataSource = self;
    table_.sectionHeaderHeight = 0;
    table_.sectionFooterHeight = 0;
    table_.separatorColor = [UIColor lightGrayColor];
    table_.separatorInset = UIEdgeInsetsMake(0, 15, 0, 0);
    self.view = table_;
    
    self.preferredContentSize = self.view.frame.size;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
{
    return 28;
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

- (void) updateGridSpacingField
{    
    NSString *spacing = [[self formatter] stringFromNumber:@(drawing_.gridSpacing / drawing_.rulerUnit.conversionFactor)];
    
    if (!gridSpacing_.isEditing) {
        gridSpacing_.text = nil;
    }
    
    gridSpacing_.placeholder = [NSString stringWithFormat:@"%@ %@", spacing, drawing_.rulerUnit.abbreviation];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString    *proposed = textField.text;
    NSNumber    *number = nil;
    
    if (![string isEqualToString:@"\n"]) {
        proposed = [proposed stringByReplacingCharactersInRange:range withString:string];
    }
    
    if ([proposed isEqualToString:@"."]) {
        return YES;
    }
    
    if (proposed.length == 0) {
        return YES;
    }
    
    number = [[self formatter] numberFromString:proposed];
    if (!number || [number floatValue] < 0) {
        return NO;
    }
    
    return YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return configuration_.count;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    NSArray *items = configuration_[section][@"Items"];
    
    return items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return configuration_[section][@"Title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"cellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    NSDictionary *cellDescription = configuration_[indexPath.section][@"Items"][indexPath.row];
    
    if (cell == nil) {
        UITableViewCellStyle cellStyle = [cellDescription[@"Type"] isEqualToString:@"Dimensions"] ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault;
        cell = [[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:cellIdentifier];
    }
    
    cell.textLabel.text = cellDescription[@"Title"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if ([cellDescription[@"Type"] isEqualToString:@"Switch"]) {
        UISwitch *mySwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        cell.accessoryView = mySwitch;
        
        mySwitch.onTintColor = [UIColor colorWithRed:0.0f green:(118.0f / 255.0f) blue:1.0f alpha:1.0f];
        [mySwitch setOn:[(drawing_.settings)[cellDescription[@"Key"]] boolValue]];
        [mySwitch addTarget:self action:NSSelectorFromString(cellDescription[@"Selector"]) forControlEvents:UIControlEventValueChanged];
    } else if ([cellDescription[@"Type"] isEqualToString:@"TextField"]) {
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0,0,99,31)];
        textField.textAlignment = NSTextAlignmentRight;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        textField.returnKeyType = UIReturnKeyDone;
        textField.delegate = self;
        
        cell.accessoryView = textField;
        gridSpacing_ = textField;
        
        [gridSpacing_ addTarget:self action:NSSelectorFromString(cellDescription[@"Selector"]) forControlEvents:(UIControlEventEditingDidEnd | UIControlEventEditingDidEndOnExit)];
        
        [self updateGridSpacingField];
    } else if ([cellDescription[@"Type"] isEqualToString:@"Dimensions"]) {
        unitsCell_ = cell;

        unitsCell_.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        unitsCell_.detailTextLabel.text = [self dimensionsString];
        unitsCell_.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    
    return cell;
}

- (NSString *) dimensionsString
{
    CGSize size = drawing_.dimensions; // size in points
    WDRulerUnit *unit = [WDRulerView rulerUnits][drawing_.units];
    
    // Create formatter
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:2];
    [formatter setRoundingMode:kCFNumberFormatterRoundCeiling];
    [formatter setUsesGroupingSeparator:NO];
    
    NSString *width = [formatter stringFromNumber:@(size.width / unit.conversionFactor)];
    NSString *height = [formatter stringFromNumber:@(size.height / unit.conversionFactor)];
    

    return [NSString stringWithFormat:@"%@ %@ × %@ %@", width, unit.abbreviation, height, unit.abbreviation];
}

- (void) unitsChanged:(NSNotification *)aNotification
{
    unitsCell_.detailTextLabel.text = [self dimensionsString];
    [self updateGridSpacingField];
}

- (void) drawingDimensionsChanged:(NSNotification *)aNotification
{
    unitsCell_.detailTextLabel.text = [self dimensionsString];
}

- (void) gridSpacingChanged:(NSNotification *)aNotification
{
    [self updateGridSpacingField];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath
{    
    if (unitsCell_ != [table_ cellForRowAtIndexPath:newIndexPath]) {
        return;
    }
    
    WDUnitsController *units = [[WDUnitsController alloc] initWithNibName:nil bundle:nil];
    units.drawing = self.drawing;
    [[self navigationController] pushViewController:units animated:YES];
    
    [table_ deselectRowAtIndexPath:newIndexPath animated:NO];
}

- (void) takeSnapToEdgesFrom:(id)sender
{
    UISwitch    *mySwitch = (UISwitch *)sender;
    
    drawing_.snapToEdges = mySwitch.isOn;
    [[NSUserDefaults standardUserDefaults] setBool:mySwitch.isOn forKey:WDSnapToEdges];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
                                                             
- (void) takeSnapToPointsFrom:(id)sender
{
    UISwitch    *mySwitch = (UISwitch *)sender;
    
    drawing_.snapToPoints = mySwitch.isOn;
    [[NSUserDefaults standardUserDefaults] setBool:mySwitch.isOn forKey:WDSnapToPoints];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) takeSnapToGridFrom:(id)sender
{
    UISwitch    *mySwitch = (UISwitch *)sender;
    
    drawing_.snapToGrid = mySwitch.isOn;
    [[NSUserDefaults standardUserDefaults] setBool:mySwitch.isOn forKey:WDSnapToGrid];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) takeShowGridFrom:(id)sender
{
    UISwitch    *mySwitch = (UISwitch *)sender;
    
    [[NSUserDefaults standardUserDefaults] setBool:mySwitch.isOn forKey:WDShowGrid];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    drawing_.showGrid = mySwitch.isOn;
}

- (void) takeGridSpacingFrom:(id)sender
{
    NSArray     *components = [gridSpacing_.text componentsSeparatedByString:@" "];
    NSNumber    *newSpacing = [[self formatter] numberFromString:components[0]];
    
    if (newSpacing && newSpacing.floatValue > 0) {
        drawing_.gridSpacing = newSpacing.floatValue * drawing_.rulerUnit.conversionFactor;
        
        [[NSUserDefaults standardUserDefaults] setFloat:drawing_.gridSpacing forKey:WDGridSpacing];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    [self updateGridSpacingField];
}

- (void) takeIsolateLayerFrom:(id)sender
{
    UISwitch    *mySwitch = (UISwitch *)sender;
    
    drawing_.isolateActiveLayer = mySwitch.isOn;
}

- (void) takeOutlineModeFrom:(id)sender
{
    UISwitch    *mySwitch = (UISwitch *)sender;
    
    drawing_.outlineMode = mySwitch.isOn;
}

- (void) takeShowRulersFrom:(id)sender
{
    UISwitch    *mySwitch = (UISwitch *)sender;
    
    [[NSUserDefaults standardUserDefaults] setBool:mySwitch.isOn forKey:WDRulersVisible];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    drawing_.rulersVisible = mySwitch.isOn;
}

@end
