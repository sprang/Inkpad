//
//  WDArrowheadCell.h
//  Inkpad
//
//  Created by Steve Sprang on 10/16/13.
//  Copyright (c) 2013 Taptrix, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class WDDrawingController;

@interface WDArrowheadCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UIButton *startArrowButton;
@property (nonatomic, strong) IBOutlet UIButton *endArrowButton;

@property (nonatomic, strong) NSString *arrowhead;
@property (nonatomic, weak) WDDrawingController *drawingController;

+ (UIColor *) tintColor;

- (UIImage *) selectedBackground;
- (UIImage *) imageForArrow:(NSString *)arrowID start:(BOOL)isStart;

@end
