//
//  WDSelectionView.h
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@class WDCanvas;
@class WDDrawing;

@interface WDSelectionView : UIView {
    
@private
    // The pixel dimensions of the backbuffer
    GLint backingWidth;
    GLint backingHeight;
    
    // OpenGL names for the renderbuffer and framebuffer used to render to this view
    GLuint colorRenderbuffer, defaultFramebuffer;
}

@property (nonatomic, weak) WDCanvas *canvas;
@property (nonatomic, strong) EAGLContext *context;
@property (weak, nonatomic, readonly) WDDrawing *drawing;

- (void) drawView;

@end
