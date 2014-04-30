//
//  WDShapeTool.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2011-2013 Steve Sprang
//


#import "WDBezierNode.h"
#import "WDCanvas.h"
#import "WDDrawingController.h"
#import "WDDynamicGuideController.h"
#import "WDInspectableProperties.h"
#import "WDPath.h"
#import "WDPropertyManager.h"
#import "WDShapeTool.h"
#import "WDUtilities.h"

NSString *WDShapeToolStarInnerRadiusRatio = @"WDShapeToolStarInnerRadiusRatio";
NSString *WDShapeToolStarPointCount = @"WDShapeToolStarPointCount";
NSString *WDShapeToolPolygonSideCount = @"WDShapeToolPolygonSideCount";
NSString *WDShapeToolRectCornerRadius = @"WDShapeToolRectCornerRadius";
NSString *WDDefaultShapeTool = @"WDDefaultShapeTool";
NSString *WDShapeToolSpiralDecay = @"WDShapeToolSpiralDecay";

@implementation WDShapeTool

@synthesize shapeMode = shapeMode_;

- (NSString *) iconName
{
    NSArray *imageNames = @[@"rect.png", @"oval.png", @"star.png", @"polygon.png", @"line.png", @"spiral.png"];
    
    return imageNames[shapeMode_];
}

- (id) init
{
    self = [super init];

    if (!self) {
        return nil;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    starInnerRadiusRatio_ = [defaults floatForKey:WDShapeToolStarInnerRadiusRatio];
    starInnerRadiusRatio_ = WDClamp(0.05, 2.0, starInnerRadiusRatio_);
    
    numStarPoints_ = (int) [defaults integerForKey:WDShapeToolStarPointCount];
    numPolygonPoints_ = (int) [defaults integerForKey:WDShapeToolPolygonSideCount];
    rectCornerRadius_ = [defaults floatForKey:WDShapeToolRectCornerRadius];
    decay_ = [defaults floatForKey:WDShapeToolSpiralDecay];
    
    return self;
}

- (BOOL) isDefaultForKind
{
    NSNumber *defaultShape = [[NSUserDefaults standardUserDefaults] valueForKey:WDDefaultShapeTool];
    return (shapeMode_ == [defaultShape intValue]) ? YES : NO;
}

- (void) activated
{
    [[NSUserDefaults standardUserDefaults] setValue:@(shapeMode_) forKey:WDDefaultShapeTool];
}

- (WDPath *) pathWithPoint:(CGPoint)pt constrain:(BOOL)constrain
{
    CGPoint initialPoint = self.initialEvent.snappedLocation;
    
    if (shapeMode_ == WDShapeOval) {
        CGRect rect = WDRectWithPointsConstrained(initialPoint, pt, constrain);
        return [WDPath pathWithOvalInRect:rect];
    } else if (shapeMode_ == WDShapeRectangle) {
        CGRect rect = WDRectWithPointsConstrained(initialPoint, pt, constrain);
        
        return [WDPath pathWithRoundedRect:rect cornerRadius:rectCornerRadius_];
    } else if (shapeMode_ == WDShapeLine) {
        if (constrain) {
            CGPoint delta = WDConstrainPoint(WDSubtractPoints(pt, initialPoint));
            pt = WDAddPoints(initialPoint, delta);
        }
        
        return [WDPath pathWithStart:initialPoint end:pt];
    } else if (shapeMode_== WDShapePolygon) {
        NSMutableArray  *nodes = [NSMutableArray array];
        CGPoint         delta = WDSubtractPoints(pt, initialPoint);
        float           angle, x, y, theta = M_PI * 2 / numPolygonPoints_;
        float           radius = WDDistance(initialPoint, pt);
        float           offsetAngle = atan2(delta.y, delta.x);
        
        for(int i = 0; i < numPolygonPoints_; i++) {
            angle = theta * i + offsetAngle;
            
            x = cos(angle) * radius;
            y = sin(angle) * radius;
            
            [nodes addObject:[WDBezierNode bezierNodeWithAnchorPoint:CGPointMake(x + initialPoint.x, y + initialPoint.y)]];
        }
        
        WDPath *path = [[WDPath alloc] init];
        path.nodes = nodes;
        path.closed = YES;
        return path;
    } else if (shapeMode_ == WDShapeStar) {
        float   outerRadius = WDDistance(pt, initialPoint);
        
        if (outerRadius == 0) {
            return nil;
        }
        
        if (constrain) {
            float tempInner = starInnerRadiusRatio_ * lastStarRadius_;
            starInnerRadiusRatio_ = WDClamp(0.05, 2.0, tempInner / outerRadius);
        }
        lastStarRadius_ = outerRadius;
        
        float   ratioToUse = starInnerRadiusRatio_;
        float   kappa = (M_PI * 2) / numStarPoints_;
        float   optimalRatio = cos(kappa) / cos(kappa / 2);
        
        if ((numStarPoints_ > 4) && (starInnerRadiusRatio_ / optimalRatio > 0.95) && (starInnerRadiusRatio_ / optimalRatio < 1.05)) {
            ratioToUse = optimalRatio;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:ratioToUse forKey:WDShapeToolStarInnerRadiusRatio];
        
        NSMutableArray  *nodes = [NSMutableArray array];
        CGPoint         delta = WDSubtractPoints(pt, initialPoint);
        float           innerRadius = outerRadius * ratioToUse;
        float           angle, x, y;
        float           theta = M_PI / numStarPoints_; // == (360 degrees / numPoints) / 2.0
        float           offsetAngle = atan2(delta.y, delta.x);
        
        for(int i = 0; i < numStarPoints_ * 2; i += 2) {
            angle = theta * i + offsetAngle;
            x = cos(angle) * outerRadius;
            y = sin(angle) * outerRadius;
            
            [nodes addObject:[WDBezierNode bezierNodeWithAnchorPoint:CGPointMake(x + initialPoint.x, y + initialPoint.y)]];
            
            angle = theta * (i+1) + offsetAngle;
            x = cos(angle) * innerRadius;
            y = sin(angle) * innerRadius;
            
            [nodes addObject:[WDBezierNode bezierNodeWithAnchorPoint:CGPointMake(x + initialPoint.x, y + initialPoint.y)]];
        }
        
        WDPath *path = [[WDPath alloc] init];
        path.nodes = nodes;
        path.closed = YES;
        return path;
    } else if (shapeMode_ == WDShapeSpiral) {
        float       radius = WDDistance(pt, initialPoint);
        CGPoint     delta = WDSubtractPoints(pt, initialPoint);
        float       offsetAngle = atan2(delta.y, delta.x) + M_PI;
        int         segments = 20;
        float       b = 1.0f - (decay_ / 100.f);
        float       a = radius / pow(M_E, b * segments * M_PI_4);
        
        NSMutableArray  *nodes = [NSMutableArray array];
        
        for (int segment = 0; segment <= segments; segment++) {
            float t = segment * M_PI_4;
            float f = a * pow(M_E, b * t);
            float x = f * cos(t);
            float y = f * sin(t);
            
            CGPoint P3 = CGPointMake(x, y);
            
            // derivative
            float t0 = t - M_PI_4;
            float deltaT = (t - t0) / 3;
            
            float xPrime = a*b*pow(M_E,b*t)*cos(t) - a*pow(M_E,b*t)*sin(t);
            float yPrime = a*pow(M_E,b*t)*cos(t) + a*b*pow(M_E,b*t)*sin(t);
            
            CGPoint P2 = WDSubtractPoints(P3, WDMultiplyPointScalar(CGPointMake(xPrime, yPrime), deltaT));
            CGPoint P1 = WDAddPoints(P3, WDMultiplyPointScalar(CGPointMake(xPrime, yPrime), deltaT));
            
            [nodes addObject:[WDBezierNode bezierNodeWithInPoint:P2 anchorPoint:P3 outPoint:P1]];
        }
        
        WDPath *path = [[WDPath alloc] init];
        path.nodes = nodes;
        
        CGAffineTransform transform = CGAffineTransformMakeTranslation(initialPoint.x, initialPoint.y);
        transform = CGAffineTransformRotate(transform, offsetAngle);
        
        [path transform:transform];
        return path;
    }
    
    return nil;
}

- (BOOL) createsObject
{
    return YES;
}

- (BOOL) constrain
{
    return ((self.flags & WDToolShiftKey) || (self.flags & WDToolSecondaryTouch)) ? YES : NO;
}

- (BOOL) shouldSnapPointsToGuides
{
    return YES;
}

- (void)moveWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{
    if (!self.moved) {
        [canvas.drawingController selectNone:nil];
    }
    
    WDPath  *temp = [self pathWithPoint:theEvent.snappedLocation constrain:[self constrain]];
    
    if (canvas.drawing.dynamicGuides) {
        WDDynamicGuideController *guideController = canvas.drawingController.dynamicGuideController;
        
        if (shapeMode_ < WDShapeStar) {
            // ovals and rectangles
            canvas.dynamicGuides = [guideController snappedGuidesForRect:temp.bounds];
        } else {
            // snapping to the bounding box doesn't really make sense for the rest of the shapes...
            NSMutableArray *snapped = [NSMutableArray array];
            [snapped addObjectsFromArray:[guideController snappedGuidesForPoint:self.initialEvent.snappedLocation]];
            [snapped addObjectsFromArray:[guideController snappedGuidesForPoint:theEvent.snappedLocation]];
            canvas.dynamicGuides = snapped;
        }
    }
    
    canvas.shapeUnderConstruction = temp;
}

- (void)endWithEvent:(WDEvent *)theEvent inCanvas:(WDCanvas *)canvas
{    
    if (self.moved) {
        if (!CGPointEqualToPoint(self.initialEvent.snappedLocation, theEvent.snappedLocation)) {
            WDPath  *path = [self pathWithPoint:theEvent.snappedLocation constrain:[self constrain]];
            
            WDStrokeStyle *stroke = [canvas.drawingController.propertyManager activeStrokeStyle];
            path.strokeStyle = (shapeMode_ == WDShapeLine) ? stroke : [stroke strokeStyleSansArrows];
            
            if (shapeMode_ != WDShapeLine) {
                path.fill = [canvas.drawingController.propertyManager activeFillStyle];
            }
            
            path.opacity = [[canvas.drawingController.propertyManager defaultValueForProperty:WDOpacityProperty] floatValue];
            path.shadow = [canvas.drawingController.propertyManager activeShadow];
            
            [canvas.drawing addObject:path];
            [canvas.drawingController selectObject:path];
        }
        
        canvas.shapeUnderConstruction = nil;
        canvas.dynamicGuides = nil;
    }
    
    if ([canvas.drawing dynamicGuides]) {
        [canvas.drawingController.dynamicGuideController endGuideOperation];
    }
}

- (void) flagsChangedInCanvas:(WDCanvas *)canvas
{
    WDPath  *temp = [self pathWithPoint:self.previousEvent.snappedLocation constrain:[self constrain]];
    canvas.shapeUnderConstruction = temp;
}

#if TARGET_OS_IPHONE
- (void) updateOptionsSettings
{
    if (shapeMode_ == WDShapeRectangle) {
        int displayRadius = round(rectCornerRadius_);
        optionsValue_.text = [NSString stringWithFormat:@"%d pt", displayRadius];
        optionsSlider_.value = rectCornerRadius_;
    } else if (shapeMode_ == WDShapePolygon) {
        optionsValue_.text = [NSString stringWithFormat:@"%d", numPolygonPoints_];
        optionsSlider_.value = numPolygonPoints_;
    } else if (shapeMode_ == WDShapeStar) {
        optionsValue_.text = [NSString stringWithFormat:@"%d", numStarPoints_];
        optionsSlider_.value = numStarPoints_;
    } else if (shapeMode_ == WDShapeSpiral) {
        optionsValue_.text = [NSString stringWithFormat:@"%d%%", decay_];
        optionsSlider_.value = decay_;
    }
}

- (IBAction) takeFinalSliderValueFrom:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (shapeMode_ == WDShapeRectangle) {
        rectCornerRadius_ = optionsSlider_.value;
        [defaults setFloat:rectCornerRadius_ forKey:WDShapeToolRectCornerRadius];
    } else if (shapeMode_ == WDShapePolygon) {
        numPolygonPoints_ = optionsSlider_.value;
        [defaults setInteger:numPolygonPoints_ forKey:WDShapeToolPolygonSideCount];
    } else if (shapeMode_ == WDShapeStar) {
        numStarPoints_ = optionsSlider_.value;
        [defaults setInteger:numStarPoints_ forKey:WDShapeToolStarPointCount];
    } else if (shapeMode_ == WDShapeSpiral) {
        decay_ = optionsSlider_.value;
        [defaults setInteger:decay_ forKey:WDShapeToolSpiralDecay];
    }
    
    [self updateOptionsSettings];
}

- (IBAction) takeSliderValueFrom:(id)sender
{
    if (shapeMode_ == WDShapeRectangle) {
        rectCornerRadius_ = optionsSlider_.value;
    } else if (shapeMode_ == WDShapePolygon) {
        numPolygonPoints_ = optionsSlider_.value;
    } else if (shapeMode_ == WDShapeStar) {
        numStarPoints_ = optionsSlider_.value;
    } else if (shapeMode_ == WDShapeSpiral) {
        decay_ = optionsSlider_.value;
    }
    
    [self updateOptionsSettings];
}

- (IBAction)increment:(id)sender
{
    optionsSlider_.value = optionsSlider_.value + 1;
    [optionsSlider_ sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (IBAction)decrement:(id)sender
{
    optionsSlider_.value = optionsSlider_.value - 1;
    [optionsSlider_ sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (UIView *) optionsView
{
    if (shapeMode_ == WDShapeOval || shapeMode_ == WDShapeLine) {
        // no options for these guys
        return nil;
    }
    
    if (!optionsView_) {
        [[NSBundle mainBundle] loadNibNamed:@"ShapeOptions" owner:self options:nil];
        [self configureOptionsView:optionsView_];
        
        if (shapeMode_ == WDShapeRectangle) {
            optionsSlider_.minimumValue = 0;
            optionsSlider_.maximumValue = 100;
        } else if (shapeMode_ == WDShapePolygon) {
            optionsSlider_.minimumValue = 3;
            optionsSlider_.maximumValue = 20;
        } else if  (shapeMode_ == WDShapeStar) {
            optionsSlider_.minimumValue = 3;
            optionsSlider_.maximumValue = 50;
        } else if  (shapeMode_ == WDShapeSpiral) {
            optionsSlider_.minimumValue = 10;
            optionsSlider_.maximumValue = 99;
        }
        optionsSlider_.exclusiveTouch = YES;
        
        if (shapeMode_ == WDShapeRectangle) {
            optionsTitle_.text = NSLocalizedString(@"Corner Radius", @"Corner Radius");
        } else if (shapeMode_ == WDShapePolygon) {
            optionsTitle_.text = NSLocalizedString(@"Number of Sides", @"Number of Sides");
        } else if (shapeMode_ == WDShapeStar) {
            optionsTitle_.text = NSLocalizedString(@"Number of Points", @"Number of Points");
        } else if (shapeMode_ == WDShapeSpiral) {
            optionsTitle_.text = NSLocalizedString(@"Decay", @"Decay");
        }
    }
    
    [self updateOptionsSettings];
    
    return optionsView_;
}

#endif

@end
