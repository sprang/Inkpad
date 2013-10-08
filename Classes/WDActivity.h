//
//  WDActivity.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//

#import <Foundation/Foundation.h>

typedef enum {
    WDActivityTypeDownload,
    WDActivityTypeUpload,
    WDActivityTypeImport
} WDActivityType;

@interface WDActivity : NSObject

@property (nonatomic, assign) WDActivityType type;
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, assign) float progress;
@property (weak, nonatomic, readonly) NSString *title;

+ (WDActivity *) activityWithFilePath:(NSString *)title type:(WDActivityType)type;
- (id) initWithFilePath:(NSString *)aFilePath type:(WDActivityType)aType;

@end
