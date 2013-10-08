//
//  WDRulerUnit.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

@interface WDRulerUnit : NSObject 

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *abbreviation;
@property (nonatomic, strong) NSArray *stepUpCycle;
@property (nonatomic, strong) NSArray *stepDownCycle;
@property (nonatomic, assign) float conversionFactor;

+ (WDRulerUnit *) rulerUnitWithName:(NSString *)name
                        abbeviation:(NSString *)abbreviation
       unitToPointsConversionFactor:(CGFloat)conversionFactor
                        stepUpCycle:(NSArray *)stepUpCycle
                      stepDownCycle:(NSArray *)stepDownCycle;
    
+ (NSDictionary *) rulerUnits;

@end
