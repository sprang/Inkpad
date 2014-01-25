//
//  WDRulerUnit.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import "WDRulerUnit.h"

static NSMutableDictionary *registeredUnits_ = nil;

@implementation WDRulerUnit

@synthesize name = name_;
@synthesize abbreviation = abbeviation_;
@synthesize stepUpCycle = stepUpCycle_;
@synthesize stepDownCycle = stepDownCycle_;
@synthesize conversionFactor = conversionFactor_;

+ (void)registerUnitWithName:(NSString *)unitName abbreviation:(NSString *)abbreviation unitToPointsConversionFactor:(CGFloat)conversionFactor
                 stepUpCycle:(NSArray *)stepUpCycle stepDownCycle:(NSArray *)stepDownCycle
{
    if (!registeredUnits_) {
        registeredUnits_ = [[NSMutableDictionary alloc] init];
    }
    
    WDRulerUnit *rulerUnit = [WDRulerUnit rulerUnitWithName:unitName
                                                abbeviation:abbreviation
                               unitToPointsConversionFactor:conversionFactor
                                                stepUpCycle:stepUpCycle
                                              stepDownCycle:stepDownCycle];
    
    registeredUnits_[unitName] = rulerUnit;
}

+ (void) initialize
{
    if (self != [WDRulerUnit class]) {
        return;
    }
    
    NSArray *stepUp52 = @[@5.0f, @2.0f];
    
    [self registerUnitWithName:@"Points" abbreviation: @"pt" unitToPointsConversionFactor:1.0f 
                   stepUpCycle:stepUp52 stepDownCycle:@[@0.5f]];
    
    [self registerUnitWithName:@"Picas" abbreviation: @"pc" unitToPointsConversionFactor:12.0f 
                   stepUpCycle:@[@2.0f] stepDownCycle:@[@0.5f]];
    
    [self registerUnitWithName:@"Inches" abbreviation:@"in" unitToPointsConversionFactor:72.0f
                   stepUpCycle:@[@2.0f]
                 stepDownCycle:@[@0.5f]];
    
    [self registerUnitWithName:@"Millimeters" abbreviation:@"mm" unitToPointsConversionFactor:2.835f
                   stepUpCycle:stepUp52
                 stepDownCycle:@[@0.5f, @0.2f]];
    
    [self registerUnitWithName:@"Centimeters" abbreviation:@"cm" unitToPointsConversionFactor:28.35f
                   stepUpCycle:@[@2.0f]
                 stepDownCycle:@[@0.5f, @0.2f]];
    
    [self registerUnitWithName:@"Pixels" abbreviation: @"px" unitToPointsConversionFactor:1.0f 
                   stepUpCycle:stepUp52 stepDownCycle:@[@0.5f]];
}

+ (NSDictionary *) rulerUnits
{
    return registeredUnits_;
}

+ (WDRulerUnit *) rulerUnitWithName:(NSString *)name abbeviation:(NSString *)abbreviation
       unitToPointsConversionFactor:(CGFloat)conversionFactor stepUpCycle:(NSArray *)stepUpCycle stepDownCycle:(NSArray *)stepDownCycle
{
    WDRulerUnit *unit = [[WDRulerUnit alloc] init];
    
    unit.name = name;
    unit.abbreviation = abbreviation;
    unit.conversionFactor = conversionFactor;
    unit.stepUpCycle = stepUpCycle;
    unit.stepDownCycle = stepDownCycle;
    
    return unit;
}

+ (NSString *) localizedUnitName:(NSString *)name
{
    static NSMutableDictionary *unitMap_ = nil;
    if (!unitMap_) {
        unitMap_ = [NSMutableDictionary dictionary];
        unitMap_[@"Points"]        = NSLocalizedString(@"Points", @"Points");
        unitMap_[@"Picas"]         = NSLocalizedString(@"Picas", @"Picas");
        unitMap_[@"Inches"]        = NSLocalizedString(@"Inches", @"Inches");
        unitMap_[@"Millimeters"]   = NSLocalizedString(@"Millimeters", @"Millimeters");
        unitMap_[@"Centimeters"]   = NSLocalizedString(@"Centimeters", @"Centimeters");
        unitMap_[@"Pixels"]        = NSLocalizedString(@"Pixels", @"Pixels");
    }
    
    return unitMap_[name];
}

+ (NSString *) localizedUnitAbbreviation:(NSString *)abbreviation
{
    static NSMutableDictionary *abbrevMap_ = nil;
    if (!abbrevMap_) {
        abbrevMap_ = [NSMutableDictionary dictionary];
        abbrevMap_[@"pt"]   = NSLocalizedString(@"pt", @"Abbreviation for Points unit");
        abbrevMap_[@"pc"]   = NSLocalizedString(@"pc", @"Abbreviation for Picas unit");
        abbrevMap_[@"in"]   = NSLocalizedString(@"in", @"Abbreviation for Inches unit");
        abbrevMap_[@"mm"]   = NSLocalizedString(@"mm", @"Abbreviation for Millimeters unit");
        abbrevMap_[@"cm"]   = NSLocalizedString(@"cm", @"Abbreviation for Centimeters unit");
        abbrevMap_[@"px"]   = NSLocalizedString(@"px", @"Abbreviation for Pixels unit");
    }
    
    return abbrevMap_[abbreviation];
}

@end
