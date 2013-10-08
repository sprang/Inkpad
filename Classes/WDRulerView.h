//
//  WDRulerView.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <UIKit/UIKit.h>

typedef enum {
    WDHorizontalRuler,
    WDVerticalRuler
} WDRulerOrientation;

extern const int kWDRulerThickness;

@interface WDRulerCornerView : UIView {
}
@end

@interface WDRulerView : UIView {
    // computed values
    float               unitDistance_;
    float               markDistance_;
    int                 marksToMidMark_;
    int                 marksToBigMark_;
    int                 marksBetweenLabels_;
}

@property (nonatomic, assign) WDRulerOrientation orientation;
@property (nonatomic, assign) CGFloat ruleThickness;
@property (nonatomic, weak) UIView *clientView;
@property (nonatomic, strong) NSString *units;
@property (nonatomic, strong) NSString *labelFormat;

@end

@interface UIView (WDRulerViewClientView)

- (void) computeMarkValues;

+ (void)registerUnitWithName:(NSString *)unitName
                abbreviation:(NSString *)abbreviation
unitToPointsConversionFactor:(CGFloat)conversionFactor
                 stepUpCycle:(NSArray *)stepUpCycle
               stepDownCycle:(NSArray *)stepDownCycle;

+ (NSDictionary *) rulerUnits;

@end

