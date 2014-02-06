//
//  OCAThumbnailCell.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2014 Steve Sprang
//

#import <UIKit/UIKit.h>
#import "OCAThumbnailCache.h"

@class OCAEntry;

@interface OCAThumbnailCell : UICollectionViewCell <WDOpenClipArtThumbnailReceiver>

@property (nonatomic) OCAEntry *entry;

@end
