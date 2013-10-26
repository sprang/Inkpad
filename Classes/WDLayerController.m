//
//  WDLayerController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDLayer.h"
#import "WDLayerCell.h"
#import "WDLayerController.h"

#define kTextFieldTag       1
#define kVisibleButtonTag   3
#define kSimpleColorViewTag 4
#define kImageTag           5
#define kLockButtonTag      6

@interface WDLayerController (Private)
// convert from table cell order to drawing layer order and vice versa
- (NSUInteger) flipIndex_:(NSUInteger)ix;
@end

@implementation WDLayerController

@synthesize drawing = drawing_;
@synthesize layerCell = layerCell_;

- (CGSize) preferredContentSize
{
    NSUInteger layerSlots = MIN(12, MAX(8, [drawing_.layers count]));
    
    // add half the cell height so that it's clear when there are more cells to which to scroll
    return CGSizeMake(400, layerSlots * 60 + 30);
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (!self) {
        return nil;
    }
    
    self.title = NSLocalizedString(@"Layers", @"Layers");
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteLayer:)];
    
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                               target:self                                         
                                                                               action:@selector(addLayer:)];
    
    UIBarButtonItem *duplicateButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"duplicate.png"]
                                                                        style:UIBarButtonItemStylePlain
                                                                       target:self
                                                                       action:@selector(duplicateLayer:)];
    
    self.navigationItem.rightBarButtonItems = @[addButton, duplicateButton];
    
    return self;
}

- (void) setDrawing:(WDDrawing *)drawing
{
    drawing_ = drawing;
    [layerTable_ reloadData];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // stop listening to old drawing
    [nc removeObserver:self];
    
    [nc addObserver:self selector:@selector(activeLayerChanged:) name:WDActiveLayerChanged object:drawing_];
    [nc addObserver:self selector:@selector(layerAdded:) name:WDLayerAddedNotification object:drawing_];
    [nc addObserver:self selector:@selector(layerDeleted:) name:WDLayerDeletedNotification object:drawing_];
    [nc addObserver:self selector:@selector(layerVisibilityChanged:) name:WDLayerVisibilityChanged object:drawing_];
    [nc addObserver:self selector:@selector(layerOpacityChanged:) name:WDLayerOpacityChanged object:drawing_];
    [nc addObserver:self selector:@selector(layerLockedStatusChanged:) name:WDLayerLockedStatusChanged object:drawing_];
    [nc addObserver:self selector:@selector(layerNameChanged:) name:WDLayerNameChanged object:drawing_];
    [nc addObserver:self selector:@selector(layerThumbnailChanged:) name:WDLayerThumbnailChangedNotification object:drawing_];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) deselectSelectedRow
{
    NSUInteger      row = [self flipIndex_:drawing_.indexOfActiveLayer];
    NSIndexPath     *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    
    [layerTable_ deselectRowAtIndexPath:indexPath animated:NO];
}

- (void) deleteLayer:(id)sender
{
    [drawing_ deleteActiveLayer];
}

- (void) addLayer:(id)sender
{
    [drawing_ addLayer:[WDLayer layer]];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    return drawing_.layers.count;
}

- (void) layerAdded:(NSNotification *)aNotification
{
    if (activeField_) {
        [activeField_ resignFirstResponder];
    }
    
    WDLayer *addedLayer = [aNotification userInfo][@"layer"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self flipIndex_:[drawing_.layers indexOfObject:addedLayer]] inSection:0];
    
    [layerTable_ beginUpdates];
    [layerTable_ insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [layerTable_ endUpdates];
    
    self.navigationItem.leftBarButtonItem.enabled = [drawing_ canDeleteLayer];
    
    // ensure that the selection indicator doesn't disappear when undoing layer reorder
    [self performSelector:@selector(selectActiveLayer) withObject:nil afterDelay:0];
}

- (void) layerDeleted:(NSNotification *)aNotification
{
    if (activeField_) {
        [activeField_ resignFirstResponder];
    }
    
    NSNumber *index = [aNotification userInfo][@"index"];
    NSUInteger row = [self flipIndex_:[index integerValue]] + 1; // add one to account for the fact that the model already deleted the entry
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    
    [layerTable_ beginUpdates];
    [layerTable_ deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [layerTable_ endUpdates];
    
    self.navigationItem.leftBarButtonItem.enabled = [drawing_ canDeleteLayer];
}

- (void) activeLayerChanged:(NSNotification *)aNotification
{    
    [self performSelector:@selector(selectActiveLayer) withObject:nil afterDelay:0];
}

- (void) layerVisibilityChanged:(NSNotification *)aNotification
{
    WDLayer *layer = [aNotification userInfo][@"layer"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self flipIndex_:[drawing_.layers indexOfObject:layer]] inSection:0];
    
    WDLayerCell *layerCell = (WDLayerCell *) [layerTable_ cellForRowAtIndexPath:indexPath];
    [layerCell updateVisibilityButton];
    
    [self updateOpacity];
}

- (void) layerLockedStatusChanged:(NSNotification *)aNotification
{
    WDLayer *layer = [aNotification userInfo][@"layer"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self flipIndex_:[drawing_.layers indexOfObject:layer]] inSection:0];
    
    WDLayerCell *layerCell = (WDLayerCell *) [layerTable_ cellForRowAtIndexPath:indexPath];
    [layerCell updateLockedStatusButton];
    
    [self updateOpacity];
}

- (void) layerOpacityChanged:(NSNotification *)aNotification
{
    WDLayer *layer = [aNotification userInfo][@"layer"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self flipIndex_:[drawing_.layers indexOfObject:layer]] inSection:0];
    
    WDLayerCell *layerCell = (WDLayerCell *) [layerTable_ cellForRowAtIndexPath:indexPath];
    [layerCell updateOpacity];
    
    [self updateOpacity];
}

- (void) layerThumbnailChanged:(NSNotification *)aNotification
{
    WDLayer *layer = [aNotification userInfo][@"layer"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self flipIndex_:[drawing_.layers indexOfObject:layer]] inSection:0];
    
    WDLayerCell *layerCell = (WDLayerCell *) [layerTable_ cellForRowAtIndexPath:indexPath];
    [layerCell updateThumbnail];
}

- (void) layerNameChanged:(NSNotification *)aNotification
{
    WDLayer *layer = [aNotification userInfo][@"layer"];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self flipIndex_:[drawing_.layers indexOfObject:layer]] inSection:0];
    
    WDLayerCell *layerCell = (WDLayerCell *) [layerTable_ cellForRowAtIndexPath:indexPath];
    [layerCell updateLayerName];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"LayerCell";
    WDLayer         *layer = (drawing_.layers)[[self flipIndex_:indexPath.row]];
    
    WDLayerCell *cell = (WDLayerCell *) [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"LayerCell" owner:self options:nil];
        cell = layerCell_;
        self.layerCell = nil;
    }
    
    cell.drawingLayer = layer;
    
    return cell;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    activeField_ = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    drawing_.activeLayer.name = textField.text;
    activeField_ = nil;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {    
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    if (activeField_) {
        [activeField_ resignFirstResponder];
    }
    
    NSUInteger srcIndex = sourceIndexPath.row;
    NSUInteger destIndex = destinationIndexPath.row;
    
    srcIndex = [self flipIndex_:srcIndex];
    destIndex = [self flipIndex_:destIndex];
    
    [drawing_ moveLayerAtIndex:srcIndex toIndex:destIndex];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath
{    
    NSUInteger index = [self flipIndex_:newIndexPath.row];
    
    if (activeField_) {
        [activeField_ resignFirstResponder];
    }
    
    [drawing_ activateLayerAtIndex:index];
}

- (void) scrollToSelectedRowIfNotVisible
{
    UITableViewCell *selected = [layerTable_ cellForRowAtIndexPath:[layerTable_ indexPathForSelectedRow]];

    // if the cell is nil or not completely visible, we should scroll the table
    if (!selected || !CGRectEqualToRect(CGRectIntersection(selected.frame, layerTable_.bounds), selected.frame)) { 
        [layerTable_ scrollToNearestSelectedRowAtScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    }
}

- (void) selectActiveLayer
{
    [self updateOpacity];
    
    NSUInteger  activeRow = [self flipIndex_:drawing_.indexOfActiveLayer];
    
    if ([[layerTable_ indexPathForSelectedRow] isEqual:[NSIndexPath indexPathForRow:activeRow inSection:0]]) {
        [self scrollToSelectedRowIfNotVisible];
        return;
    }
    
    for (NSUInteger i = 0; i < drawing_.layers.count; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        
        if (i != activeRow) {
            [layerTable_ cellForRowAtIndexPath:indexPath].selected = NO;
            [layerTable_ deselectRowAtIndexPath:indexPath animated:NO];
        } else {
            
            [layerTable_ selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle];
        }
    }
}

- (void)loadView
{
    layerTable_ = [[UITableView alloc] initWithFrame:CGRectMake(0,0,320,480) style:UITableViewStylePlain];
    layerTable_.delegate = self;
    layerTable_.dataSource = self;
    layerTable_.rowHeight = 60;
    layerTable_.allowsSelectionDuringEditing = YES;
    layerTable_.editing = YES;
    self.view = layerTable_;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationItem.leftBarButtonItem.enabled = [drawing_ canDeleteLayer];
    [self selectActiveLayer];
        
    [layerTable_ flashScrollIndicators];
}

- (void) duplicateLayer:(id)sender
{
    [drawing_ duplicateActiveLayer];
}

- (void) updateOpacity
{
    opacitySlider_.value = drawing_.activeLayer.opacity;
    
    BOOL enableOpacityControl = !drawing_.activeLayer.locked && !drawing_.activeLayer.hidden;
    float opacity = drawing_.activeLayer.opacity;
    
    opacitySlider_.enabled = enableOpacityControl;
    decrementButton_.enabled = enableOpacityControl && (opacity > 0.0f);
    incrementButton_.enabled = enableOpacityControl && (opacity < 1.0);
    
    int rounded = round(opacity * 100);
    opacityLabel_.text = [NSString stringWithFormat:@"%d%%", rounded];
}

- (void) opacitySliderMoved:(UISlider *)sender
{
    int rounded = round(sender.value * 100);
    opacityLabel_.text = [NSString stringWithFormat:@"%d%%", rounded];
}

- (void) takeOpacityFrom:(UISlider *)sender
{
    drawing_.activeLayer.opacity = [sender value];
}

- (void) decrement:(id)sender
{
    float opacity = drawing_.activeLayer.opacity;
    
    opacity = ((opacity * 100) - 1) / 100.0f;
    
    drawing_.activeLayer.opacity = opacity;
}

- (void) increment:(id)sender
{
    float opacity = drawing_.activeLayer.opacity;
    
    opacity = ((opacity * 100) + 1) / 100.0f;
    
    drawing_.activeLayer.opacity = opacity;
}

- (NSArray *) toolbarItems
{
    if (!toolbarItems_) {
        opacitySlider_ = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 250, 44)];
        opacitySlider_.maximumValue = 1.0f;
        opacitySlider_.minimumTrackTintColor = [UIColor grayColor];
        
        [opacitySlider_ addTarget:self action:@selector(takeOpacityFrom:) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
        [opacitySlider_ addTarget:self action:@selector(opacitySliderMoved:) forControlEvents:UIControlEventValueChanged];
        
        UIBarButtonItem *sliderItem = [[UIBarButtonItem alloc] initWithCustomView:opacitySlider_];
    
        opacityLabel_ = [[UILabel alloc] initWithFrame:CGRectZero];
        opacityLabel_.opaque = NO;
        opacityLabel_.backgroundColor = nil;
        opacityLabel_.textColor = [UIColor blackColor];
        opacityLabel_.font = [UIFont systemFontOfSize:15];
        opacityLabel_.textAlignment = NSTextAlignmentRight;
        
        // first set the longest string value so we can size to fit
        opacityLabel_.text = @"100%";
        [opacityLabel_ sizeToFit];
        
        [self updateOpacity];
        
        decrementButton_ = [UIButton buttonWithType:UIButtonTypeCustom];
        [decrementButton_ setImage:[UIImage imageNamed:@"decrement.png"] forState:UIControlStateNormal];
        [decrementButton_ sizeToFit];
        [decrementButton_ addTarget:self action:@selector(decrement:) forControlEvents:UIControlEventTouchUpInside];
        
        incrementButton_ = [UIButton buttonWithType:UIButtonTypeCustom];
        [incrementButton_ setImage:[UIImage imageNamed:@"increment.png"] forState:UIControlStateNormal];
        [incrementButton_ sizeToFit];
        [incrementButton_ addTarget:self action:@selector(increment:) forControlEvents:UIControlEventTouchUpInside];
        
        UIBarButtonItem *decrement = [[UIBarButtonItem alloc] initWithCustomView:decrementButton_];
        UIBarButtonItem *increment = [[UIBarButtonItem alloc] initWithCustomView:incrementButton_];
        UIBarButtonItem *labelItem = [[UIBarButtonItem alloc] initWithCustomView:opacityLabel_];
        
        toolbarItems_ = @[sliderItem, decrement, labelItem, increment];
    }
    
    return toolbarItems_;
}

@end

@implementation WDLayerController (Private)

- (NSUInteger) flipIndex_:(NSUInteger)ix
{
    return (drawing_.layers.count - ix - 1);
}

@end
