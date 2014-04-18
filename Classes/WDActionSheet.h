//
//  WDActionSheet.h
//  Brushes
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2012-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@protocol WDActionSheetDelegate;

@interface WDActionSheet : NSObject <UIActionSheetDelegate>

@property (nonatomic) UIActionSheet *sheet;
@property (nonatomic) NSMutableArray *actions;
@property (nonatomic) NSMutableArray *tags;
@property (nonatomic, weak) id<WDActionSheetDelegate> delegate;

+ (WDActionSheet *) sheet;

- (void) addButtonWithTitle:(NSString *)title action:(void (^)(id))action;
- (void) addButtonWithTitle:(NSString *)title action:(void (^)(id))action tag:(int)tag;
- (void) addCancelButton;

@end

@protocol WDActionSheetDelegate <NSObject>
- (void) actionSheetDismissed:(WDActionSheet *)actionSheet;
@end
