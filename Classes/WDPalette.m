//
//  WDPalette.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import "WDPalette.h"
#import "WDUtilities.h"
#import "UIView+Additions.h"

#define kShadowCornerRadius 0
#define kVelocityDampening  0.85f
#define kEdgeBuffer         0

NSString *WDPaletteMovedNotification = @"WDPaletteMovedNotification";

@implementation WDPalette

@synthesize defaultsName = defaultsName_;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (!self) {
        return nil;
    }
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    [self addGestureRecognizer:panGesture];
    panGesture.delegate = self;
    panGesture.delaysTouchesBegan = YES;
    
    [self addParallaxEffect];
    
    self.opaque = NO;
    self.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.9f];
    
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:kShadowCornerRadius];
    CALayer *layer = self.layer;
    
    layer.shadowPath = shadowPath.CGPath;
    layer.shadowOpacity = 0.4f;
    layer.shadowRadius = 2;
    layer.shadowOffset = CGSizeZero;
    layer.cornerRadius = kShadowCornerRadius;
    
    self.userInteractionEnabled = YES;
    self.exclusiveTouch = YES;
    self.multipleTouchEnabled = NO;
    
    self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    return self;
}

- (void) constrainOriginToSuperview:(CGPoint)origin
{
    CGRect frame = self.frame;
    
    CGRect constrain = CGRectInset(self.superview.bounds, kEdgeBuffer, kEdgeBuffer);
    constrain.size.width -= CGRectGetWidth(frame);
    constrain.size.height -= CGRectGetHeight(frame);
    
    frame.origin.x = WDClamp(CGRectGetMinX(constrain), CGRectGetMaxX(constrain), origin.x);
    frame.origin.y = WDClamp(CGRectGetMinY(constrain), CGRectGetMaxY(constrain), origin.y);
    
    [UIView animateWithDuration:0.3f
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{ self.sharpCenter = WDCenterOfRect(frame); }
                     completion:NULL];
}

- (IBAction)handlePanGesture:(UIPanGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self.superview bringSubviewToFront:self];
    }
    
    if (sender.state == UIGestureRecognizerStateChanged) {
        CGPoint pan = [sender translationInView:self];
        self.center = WDAddPoints(self.center, pan);
        [sender setTranslation:CGPointZero inView:self];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WDPaletteMovedNotification object:self];
    }
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint velocity = [sender velocityInView:self];
        
        float xSign = (velocity.x < 0) ? -1 : 1;
        float ySign = (velocity.y < 0) ? -1 : 1;
        
        velocity.x = powf(fabs(velocity.x), kVelocityDampening) * xSign;
        velocity.y = powf(fabs(velocity.y), kVelocityDampening) * ySign;
        
        if (WDDistance(velocity, CGPointZero) > 128) {
            CGPoint endPoint = WDAddPoints(self.frame.origin, velocity);
            [self constrainOriginToSuperview:endPoint];
        }
        
        // make sure the user hasn't stranded this offscreen
        [self bringOnScreen];
        
        [[NSUserDefaults standardUserDefaults] setValue:NSStringFromCGPoint(self.frame.origin) forKey:defaultsName_];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void) bringOnScreen
{
    if (CGRectContainsRect(self.superview.bounds, self.frame)) {
        return;
    }
    
    [self constrainOriginToSuperview:self.frame.origin];
}

+ (WDPalette *) paletteWithBaseView:(UIView *)view defaultsName:(NSString *)name
{
    NSString *originString = [[NSUserDefaults standardUserDefaults] objectForKey:name];
    CGPoint origin = CGPointMake(20,20);
    
    if (originString) {
        origin = CGPointFromString(originString);
        origin = WDRoundPoint(origin);
    }
    
    CGRect frame = view.frame;
    frame.origin = origin;
    
    WDPalette *palette = [[WDPalette alloc] initWithFrame:frame];
    palette.defaultsName = name;
    [palette addSubview:view];
    
    return palette;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
}

@end
