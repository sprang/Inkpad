//
//  WDExportController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <DropboxSDK/DropboxSDK.h>
#import "WDAppDelegate.h"
#import "WDExportController.h"

@implementation WDExportController

@synthesize mode = mode_;
@synthesize target = target_;
@synthesize action = action_;
@synthesize formats = formats_;

NSString *WDEmailFormatDefault = @"WDEmailFormatDefault";
NSString *WDDropboxFormatDefault = @"WDDropboxFormatDefault";

- (NSArray *) formats
{
    if (!formats_) {
        formats_ = @[@"JPEG", @"PNG", @"SVG", @"SVGZ", @"PDF", @"Inkpad"];
    }

    return formats_;
}

- (void) sendAction:(id)obj
{
    [[UIApplication sharedApplication] sendAction:action_ to:target_ from:self forEvent:nil];
}

- (void)loadView
{
    float numFormats = [self formats].count;
    float height = 44 * (numFormats + 0.5);
    
    formatTable_ = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, height) style:UITableViewStylePlain];
    formatTable_.delegate = self;
    formatTable_.dataSource = self;
    self.view = formatTable_;
    
    self.preferredContentSize = formatTable_.frame.size;
}

- (void) doExport:(id)sender
{
    self.title = NSLocalizedString(@"Creating Document...", @"Creating Document...");
    
    UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    UIBarButtonItem *spinner = [[UIBarButtonItem alloc] initWithCustomView:activity];
    self.navigationItem.rightBarButtonItem = spinner;

    [activity startAnimating];
    
    [self performSelector:@selector(sendAction:) withObject:nil afterDelay:0];
}

- (void) unlinkDropbox:(id)sender
{
    WDAppDelegate *appDelegate = (WDAppDelegate *) [UIApplication sharedApplication].delegate;
    [appDelegate unlinkDropbox];
}

- (void) setMode:(NSUInteger) mode
{
    mode_ = mode;
    
    if (mode == kWDExportViaEmailMode) {
        self.title = NSLocalizedString(@"Email", @"Email");
        
        UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Send", @"Send") style:UIBarButtonItemStyleDone target:self action:@selector(doExport:)];
        self.navigationItem.rightBarButtonItem = rightItem;
        
        self.navigationItem.leftBarButtonItem = nil;
    } else {
        
        self.title = NSLocalizedString(@"Dropbox", @"Dropbox");
        
        UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Upload", @"Upload") style:UIBarButtonItemStyleDone target:self action:@selector(doExport:)];
        self.navigationItem.rightBarButtonItem = rightItem;
        
        UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Unlink", @"Unlink") style:UIBarButtonItemStylePlain target:self action:@selector(unlinkDropbox:)];
        self.navigationItem.leftBarButtonItem = leftItem;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1; // PNG, JPEG, SVG, PDF, Inkpad
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    return [self formats].count; // PNG, JPEG, SVG, PDF, Inkpad
}

- (NSUInteger) indexForFormatName:(NSString *)formatName
{
    return [self.formats indexOfObject:formatName];
}

- (NSString *) stringForExportFormat:(WDExportFormat)format
{
    return (self.formats)[format];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
    UITableViewCell *newCell = [tableView cellForRowAtIndexPath:indexPath];
    UITableViewCell *oldCell = nil;
    NSIndexPath     *oldIndexPath = nil; 
    NSString        *defaultsKey = (mode_ == kWDExportViaEmailMode) ? WDEmailFormatDefault : WDDropboxFormatDefault;

    NSString *oldValue = [defaults objectForKey:defaultsKey];
    NSUInteger oldRow = [self indexForFormatName:oldValue];
    
    oldIndexPath = [NSIndexPath indexPathForRow:oldRow inSection:indexPath.section];
    oldCell = [tableView cellForRowAtIndexPath:oldIndexPath];
    
    [defaults setObject:[self stringForExportFormat:(WDExportFormat)indexPath.row] forKey:defaultsKey];
    
    // deselect old cell
    if (oldCell.accessoryType == UITableViewCellAccessoryCheckmark) {
        oldCell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    // select new value
    if (newCell.accessoryType == UITableViewCellAccessoryNone) {
        newCell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    
    [defaults synchronize];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *cellIdentifier = @"cellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        
        NSString *name = [self stringForExportFormat:(WDExportFormat)indexPath.row];
        cell.textLabel.text = name;

        if (mode_ == kWDExportViaEmailMode && [name isEqualToString:[defaults objectForKey:WDEmailFormatDefault]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else if (mode_ == kWDExportViaDropboxMode && [name isEqualToString:[defaults objectForKey:WDDropboxFormatDefault]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }
    
    return cell;
}                 

@end
