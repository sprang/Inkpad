//
//  WDMenuItem.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <Foundation/Foundation.h>


@interface WDMenuItem : NSObject

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) SEL action;
@property (weak, nonatomic, readonly) id target;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL separator;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, readonly) float imageWidth;
@property (nonatomic, assign) int tag;
@property (nonatomic, weak) UILabel *label;
@property (nonatomic, weak) UIImageView *imageView;

- (id)initWithTitle:(NSString *)aString image:(UIImage *)image action:(SEL)aSelector target:(id)target;

+ (id)itemWithTitle:(NSString *)aString action:(SEL)aSelector target:(id)target;
+ (id)itemWithTitle:(NSString *)aString image:(UIImage *)image action:(SEL)aSelector target:(id)target;

+ (WDMenuItem *)separatorItem;

@end
