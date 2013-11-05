//
//  WDArrowController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2013 Steve Sprang
//

#import "WDArrowhead.h"
#import "WDArrowheadCell.h"
#import "WDArrowController.h"
#import "WDDrawingController.h"
#import "WDInspectableProperties.h"
#import "WDPropertyManager.h"

@implementation WDArrowController

@synthesize drawingController = drawingController_;

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    self.title = NSLocalizedString(@"Arrowheads", @"Arrowheads");
    
    UIBarButtonItem *swap = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Swap", @"Swap")
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(swapArrowheads:)];
    self.navigationItem.rightBarButtonItem = swap;
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray *) arrows
{
    return @[WDStrokeArrowNone, @"arrow1", @"arrow2", @"arrow3",
             @"T shape", @"closed circle", @"closed square",
             @"closed diamond", @"open circle", @"open square", @"open diamond"];
}

- (void) swapArrowheads:(id)sender
{
    WDStrokeStyle *strokeStyle = [drawingController_.propertyManager defaultStrokeStyle];
    
    NSString *start = strokeStyle.startArrow;
    NSString *end = strokeStyle.endArrow;
    
    [drawingController_ setValue:end forProperty:WDStartArrowProperty];
    [drawingController_ setValue:start forProperty:WDEndArrowProperty];
}

- (void) loadView
{
    CGRect frame = CGRectZero;
    frame.size = self.preferredContentSize;
    
    self.tableView = [[UITableView alloc] initWithFrame:frame];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.allowsSelection = NO;
    self.tableView.rowHeight = 46;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    return [self arrows].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString        *cellIdentifier = @"cellID";
    WDArrowheadCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    NSString        *arrowID = [self arrows][indexPath.row];
    WDStrokeStyle   *strokeStyle = [drawingController_.propertyManager defaultStrokeStyle];
    
    if (cell == nil) {
        UITableViewCellStyle cellStyle = UITableViewCellStyleDefault;
        cell = [[WDArrowheadCell alloc] initWithStyle:cellStyle reuseIdentifier:cellIdentifier];
        cell.drawingController = self.drawingController;
    }
    
    cell.arrowhead = arrowID;
    cell.startArrowButton.selected = [strokeStyle.startArrow isEqualToString:arrowID];
    cell.endArrowButton.selected = [strokeStyle.endArrow isEqualToString:arrowID];
    
    return cell;
}

@end
