//
//  WDPageSizeController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDPageSizeController.h"
#import "WDDrawing.h"
#import "WDRulerView.h"
#import "WDRulerUnit.h"
#import "WDUnitsController.h"

#define kSizeSection 0
#define kOrientationSection 1
#define kSectionCount   2

NSString *WDPageOrientation = @"WDPageOrientation";
NSString *WDPageSize = @"WDPageSize";

static NSString *orientations_[] = { @"Portrait", @"Landscape" };

@interface WDPageSizeController (Private)
- (NSUInteger) indexOfPageSizeInConfiguration:(NSString *)pageSize;
@end

@implementation WDPageSizeController

@synthesize target = target_;
@synthesize action = action_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    self.navigationItem.title = NSLocalizedString(@"New Drawing", @"New Drawing");
    
    NSString *settingsPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"PageSizes.plist"];
    configuration_ = [NSArray arrayWithContentsOfFile:settingsPath];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(customSizeChanged:) name:WDCustomDrawingSizeChanged object:nil];
    
    return self;
}

- (void) viewWillAppear:(BOOL)animated
{
    UIBarButtonItem *createItem = [[UIBarButtonItem alloc] initWithTitle:@"Create"
                                                                   style:UIBarButtonItemStyleDone
                                                                  target:target_
                                                                  action:action_];
    self.navigationItem.rightBarButtonItem = createItem;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (CGSize) size
{
    NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    NSString        *pageSize = [defaults objectForKey:WDPageSize];
    NSDictionary    *config = configuration_[[self indexOfPageSizeInConfiguration:pageSize]];
    CGSize          size;
    
    if (config[@"Custom"]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        size.width = [defaults floatForKey:WDCustomSizeWidth];
        size.height = [defaults floatForKey:WDCustomSizeHeight];
    } else {
        size.width = [config[@"Width"] floatValue];
        size.height = [config[@"Height"] floatValue];
    }
    
    BOOL landscape = [[defaults objectForKey:WDPageOrientation] isEqualToString:@"Landscape"];
    if ((landscape && (size.height > size.width)) || (!landscape && (size.width > size.height))) {
        // swap size and height
        float temp = size.height;
        size.height = size.width;
        size.width = temp;
    }

    return size;
}

- (NSString *) units
{
    NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    NSString        *pageSize = [defaults objectForKey:WDPageSize];
    NSDictionary    *config = configuration_[[self indexOfPageSizeInConfiguration:pageSize]];
    
    if (config[@"Custom"]) {
        return [defaults objectForKey:WDCustomSizeUnits];
    } else {
        return config[@"Units"];
    }
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kSectionCount;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
{
    return 44;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    if (section == kSizeSection) {
        return configuration_.count;
    } else {
        return 2; // portrait/landscape
    }
}

- (NSUInteger) indexOfPageSizeInConfiguration:(NSString *)pageSize
{
    for (NSDictionary *dict in configuration_) {
        if ([dict[@"Name"] isEqualToString:pageSize]) {
            return [configuration_ indexOfObject:dict];
        }
    }
    
    return 0;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    WDUnitsController *units = [[WDUnitsController alloc] initWithNibName:nil bundle:nil];
    
    [self tableView:table_ didSelectRowAtIndexPath:indexPath];
    
    [[self navigationController] pushViewController:units animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    UITableViewCell *newCell = [tableView cellForRowAtIndexPath:indexPath];
    UITableViewCell *oldCell = nil;
    NSIndexPath     *oldIndexPath = nil; 
    
    if (indexPath.section == kSizeSection) {
        // find old cell
        NSUInteger oldRow = [self indexOfPageSizeInConfiguration:[defaults objectForKey:WDPageSize]];
        oldIndexPath = [NSIndexPath indexPathForRow:oldRow inSection:indexPath.section];
        oldCell = [tableView cellForRowAtIndexPath:oldIndexPath];
        
        // update defaults
        [defaults setObject:configuration_[indexPath.row][@"Name"] forKey:WDPageSize];
    } else {
        NSString *oldOrientation = [defaults objectForKey:WDPageOrientation];
        int oldRow = ([oldOrientation isEqualToString:@"Portrait"] ? 0 : 1);
        
        oldIndexPath = [NSIndexPath indexPathForRow:oldRow inSection:indexPath.section];
        oldCell = [tableView cellForRowAtIndexPath:oldIndexPath];
        
        [defaults setObject:orientations_[indexPath.row] forKey:WDPageOrientation];
    }
    
    // deselect old cell
    oldCell.imageView.image = [UIImage imageNamed:@"table_unchecked.png"];
        
    // select new value
    newCell.imageView.image = [UIImage imageNamed:@"table_checkmark.png"];
    
    [defaults synchronize];
}

- (NSString *) dimensionsString:(NSDictionary *)config
{
    // Create formatter
    NSNumberFormatter   *formatter = [[NSNumberFormatter alloc] init];
    WDRulerUnit         *unit;
    CGSize              size;
    
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:2];
    [formatter setRoundingMode:kCFNumberFormatterRoundCeiling];
    [formatter setUsesGroupingSeparator:NO];
    
    if (config[@"Custom"]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        unit = [WDRulerView rulerUnits][[defaults objectForKey:WDCustomSizeUnits]];
        size = CGSizeMake([defaults floatForKey:WDCustomSizeWidth], [defaults floatForKey:WDCustomSizeHeight]);
    } else {
        unit = [WDRulerView rulerUnits][config[@"Units"]];
        size = CGSizeMake([ config[@"Width"] floatValue], [config[@"Height"] floatValue]);
    }
    
    NSString *width = [formatter stringFromNumber:@(size.width / unit.conversionFactor)];
    NSString *height = [formatter stringFromNumber:@(size.height / unit.conversionFactor)];
    
    return [NSString stringWithFormat:@"%@ %@ × %@ %@", width, unit.abbreviation, height, unit.abbreviation];
}

- (void) customSizeChanged:(NSNotification *)aNotification
{
    customCell_.detailTextLabel.text = [self dimensionsString:@{@"Custom": @YES}];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) { // dimensions
        return NSLocalizedString(@"Drawing Size", @"Drawing Size");
    } else {
        return NSLocalizedString(@"Orientation", @"Orientation");
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *cellIdentifier = @"cellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
        
    if (indexPath.section == kSizeSection) {
        NSString *name = configuration_[indexPath.row][@"Name"];

        cell.textLabel.text = name;
        cell.detailTextLabel.text = [self dimensionsString:configuration_[indexPath.row]];
        
        if ([name isEqualToString:[defaults objectForKey:WDPageSize]]) {
            cell.imageView.image = [UIImage imageNamed:@"table_checkmark.png"];
        } else {
            cell.imageView.image = [UIImage imageNamed:@"table_unchecked.png"];
        }
        
        if (configuration_[indexPath.row][@"Custom"]) {
            cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
            customCell_ = cell;
        }
                                    
    } else {
        cell.textLabel.text = orientations_[indexPath.row];
        if ([orientations_[indexPath.row] isEqualToString:[defaults objectForKey:WDPageOrientation]]) {
            cell.imageView.image = [UIImage imageNamed:@"table_checkmark.png"];
        } else {
            cell.imageView.image = [UIImage imageNamed:@"table_unchecked.png"];
        }
    }
    
    return cell;
}        

@end
