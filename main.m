//
//  main.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <mach/mach_time.h>
#import "WDAppDelegate.h"

int main(int argc, char *argv[]) {
    srandom((unsigned)(mach_absolute_time() & 0xFFFFFFFF));
    
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([WDAppDelegate class]));
    }
}
