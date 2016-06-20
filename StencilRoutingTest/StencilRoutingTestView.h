//
//  StencilRoutingTestView.h
//  StencilRoutingTest
//
//  Created by Patrick Walton on 6/19/16.
//  Copyright © 2016 Mozilla Corporation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface StencilRoutingTestView : NSOpenGLView {
    NSRect *displayList;
    size_t displayListSize;
    NSOpenGLContext *context;
    GLint compositeVertexShader;
    GLint compositeFragmentShader;
    GLint compositeProgram;
    GLint compositePositionAttribute;
    GLint compositeTextureUniform;
    GLint compositeTileSizeUniform;
    GLint clearVertexShader;
    GLint clearFragmentShader;
    GLint clearProgram;
    GLint clearPositionAttribute;
    GLint clearColorUniform;
    GLuint quadVertexBuffer;
    GLuint quadVertexArrayObject;
    GLuint displayListVertexBuffer;
    GLuint displayListVertexArrayObject;
    GLuint multisampleTexture;
    GLuint multisampleRenderbuffer;
    GLuint multisampleFramebuffer;
    GLuint timeElapsedQuery;
    BOOL framebufferValid;
    IBOutlet NSTextField *timeLabel;
    IBOutlet NSTextField *tileSizeField;
}

- (IBAction)openDisplayList:(id)sender;

@end
