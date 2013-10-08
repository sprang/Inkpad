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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *identifier = @"blendModeCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
	}
    
    cell.accessoryType = (indexPath.row == selectedRow_) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	cell.textLabel.text = blendModeNames_[indexPath.row][@"name"];
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
            return dict[@"name"];
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
