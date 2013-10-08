//
//  WDFontLibraryController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDCoreTextLabel.h"
#import "WDFontLibraryController.h"
#import "WDFontManager.h"

#define kCoreTextLabelWidth      300
#define kCoreTextLabelHeight     43
#define kCoreTextLabelTag        1

@implementation WDFontLibraryController

@synthesize table;
@synthesize selectedFonts;

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    UIBarButtonItem *trashItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                               target:self action:@selector(deleteSelectedFonts:)];
    self.navigationItem.rightBarButtonItem = trashItem;
    trashItem.enabled = NO;
    
    self.navigationItem.prompt = NSLocalizedString(@"Import your own fonts via Dropbox",
                                                   @"Import your own fonts via Dropbox");
    
    self.selectedFonts = [NSMutableSet set];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fontAdded:) name:WDFontAddedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fontDeleted:) name:WDFontDeletedNotification object:nil];
    
    self.title = NSLocalizedString(@"Font Library", @"Font Library");
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) properlyEnableTrashButton
{
    self.navigationItem.rightBarButtonItem.enabled = (selectedFonts.count > 0 ? YES : NO);
}

- (void) loadView
{
    table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 428) style:UITableViewStylePlain];
    self.view = table;
    
    table.delegate = self;
    table.dataSource = self;
    table.allowsSelection = YES;
    
    self.preferredContentSize = table.frame.size;
}

- (void) fontAdded:(NSNotification *)aNotification
{
    NSString    *fontName = (aNotification.userInfo)[@"name"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[[[WDFontManager sharedInstance] userFonts] indexOfObject:fontName] inSection:0];
    
    [table beginUpdates];
    [table insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [table endUpdates];
}

- (void) fontDeleted:(NSNotification *)aNotification
{
    NSNumber    *index = (aNotification.userInfo)[@"index"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index.integerValue inSection:0];
    
    [table beginUpdates];
    [table deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [table endUpdates];
    
    [self properlyEnableTrashButton];
}

- (void) deleteSelectedFonts:(id)sender
{
    for (NSString *fontName in selectedFonts) {
        [[WDFontManager sharedInstance] deleteUserFontWithName:fontName];
    }
    
    [selectedFonts removeAllObjects];
    [self properlyEnableTrashButton];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    return [[[WDFontManager sharedInstance] userFonts] count];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *fontName = [[WDFontManager sharedInstance] userFonts][indexPath.row];
    
    if ([selectedFonts containsObject:fontName]) {
        [selectedFonts removeObject:fontName];
        [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
    } else {
        [selectedFonts addObject:fontName];
        [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
    }
    
    [self properlyEnableTrashButton];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString        *cellIdentifier = @"fontIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        
        WDCoreTextLabel *label = [[WDCoreTextLabel alloc] initWithFrame:CGRectMake(10, 0, kCoreTextLabelWidth - 10, kCoreTextLabelHeight)];
        label.tag = kCoreTextLabelTag;
        [cell.contentView addSubview:label];
    }
    
    NSString *fontName = [[WDFontManager sharedInstance] userFonts][indexPath.row];
    
    WDCoreTextLabel *label = (WDCoreTextLabel *) [cell viewWithTag:kCoreTextLabelTag];
    
    CTFontRef fontRef = [[WDFontManager sharedInstance] newFontRefForFont:fontName withSize:22];
    [label setFontRef:fontRef];
    CFRelease(fontRef);
    
    [label setText:[[WDFontManager sharedInstance] displayNameForFont:fontName]];
    
    cell.accessoryType = [selectedFonts containsObject:fontName] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

@end
