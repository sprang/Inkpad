//
//  WDBlendModeController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDBlendModeController.h"
#import "WDdrawingController.h"
#import "WDPropertyManager.h"
#import "WDInspectableProperties.h"

@interface WDBlendModeController ()
- (NSIndexPath *)indexPathForBlendMode:(CGBlendMode)blendMode;
- (NSIndexPath *) updateSelectedRow;
@end

@implementation WDBlendModeController

@synthesize drawingController = drawingController_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) {
		return nil;
    }	
    
    self.title = NSLocalizedString(@"Blend Mode", @"Blend Mode");    
	blendModeNames_ = [[NSArray alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"BlendModes" withExtension:@"plist"]];
    selectedRow_ = NSUIntegerMax;
    
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
                                               object:drawingController_.propertyManager];
}

#pragma mark -

- (void)loadView
{
    tableView_ = [[UITableView alloc] initWithFrame:CGRectMake(0,0,320,480) style:UITableViewStylePlain];
    tableView_.delegate = self;
    tableView_.dataSource = self;
    self.view = tableView_;
}

- (void)viewWillAppear:(BOOL)animated
{
    NSIndexPath *selectedIndexPath = [self updateSelectedRow];
    [tableView_ scrollToRowAtIndexPath:selectedIndexPath atScrollPosition:UITableViewScrollPositionNone animated:NO];
}

#pragma mark -

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [blendModeNames_ count];
}

- (NSString *) localizedTitleForKey:(NSString *)key
{
    // we could duplicate the BlendModes.plist for every localization, but this seems less error prone
    static NSMutableDictionary *map_ = nil;
    if (!map_) {
        map_ = [NSMutableDictionary dictionary];
        map_[@"Normal"]     = NSLocalizedString(@"Normal", @"Normal");
        map_[@"Darken"]     = NSLocalizedString(@"Darken", @"Darken");
        map_[@"Multiply"]   = NSLocalizedString(@"Multiply", @"Multiply");
        map_[@"Lighten"]    = NSLocalizedString(@"Lighten", @"Lighten");
        map_[@"Screen"]     = NSLocalizedString(@"Screen", @"Screen");
        map_[@"Overlay"]    = NSLocalizedString(@"Overlay", @"Overlay");
        map_[@"Difference"] = NSLocalizedString(@"Difference", @"Difference");
        map_[@"Exclusion"]  = NSLocalizedString(@"Exclusion", @"Exclusion");
        map_[@"Hue"]        = NSLocalizedString(@"Hue", @"Hue");
        map_[@"Saturation"] = NSLocalizedString(@"Saturation", @"Saturation");
        map_[@"Color"]      = NSLocalizedString(@"Color", @"Color");
        map_[@"Luminosity"] = NSLocalizedString(@"Luminosity", @"Luminosity");
    }
    
    return map_[key];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *identifier = @"blendModeCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
	}
    
    cell.accessoryType = (indexPath.row == selectedRow_) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    NSString *blendKey = blendModeNames_[indexPath.row][@"name"];
	cell.textLabel.text = [self localizedTitleForKey:blendKey];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:selectedRow_ inSection:0]] setAccessoryType:UITableViewCellAccessoryNone];
    selectedRow_ = indexPath.row;
    
	CGBlendMode blendMode = [blendModeNames_[indexPath.row][@"value"] intValue];	
	[self.drawingController setValue:@(blendMode) forProperty:WDBlendModeProperty];
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark -

- (void) invalidProperties:(NSNotification *)aNotification
{
    NSSet *properties = [aNotification userInfo][WDInvalidPropertiesKey];
    
    if ([properties containsObject:WDBlendModeProperty]) {
        NSIndexPath *selectedIndexPath = [self updateSelectedRow];
        [tableView_ scrollToRowAtIndexPath:selectedIndexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
    }
}

- (NSIndexPath *) updateSelectedRow
{
    [[tableView_ cellForRowAtIndexPath:[NSIndexPath indexPathForRow:selectedRow_ inSection:0]] setAccessoryType:UITableViewCellAccessoryNone];
	CGBlendMode blendMode = [[drawingController_.propertyManager defaultValueForProperty:WDBlendModeProperty] intValue];
    NSIndexPath *selectedIndexPath = [self indexPathForBlendMode:blendMode];
    [[tableView_ cellForRowAtIndexPath:selectedIndexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
    selectedRow_ = selectedIndexPath.row;
    return selectedIndexPath;
}

#pragma mark -

- (NSString *) displayNameForBlendMode:(CGBlendMode)blendMode
{
    for (NSDictionary *dict in blendModeNames_) {
        if ([dict[@"value"] intValue] == blendMode) {
            return [self localizedTitleForKey:dict[@"name"]];
        }
    }
    
	return nil;
}

- (NSIndexPath *) indexPathForBlendMode:(CGBlendMode)blendMode
{
    if ([tableView_ numberOfRowsInSection:0] > 1) {
        [tableView_ reloadData]; // first viewWillAppear:
    }
    
    for (NSDictionary *dict in blendModeNames_) {
        if ([dict[@"value"] intValue] == blendMode) {
            return  [NSIndexPath indexPathForRow:[blendModeNames_ indexOfObject:dict] inSection:0];
        }
    }
    
    return nil;
}

@end
