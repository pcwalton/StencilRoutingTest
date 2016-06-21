//
//  StencilRoutingTestView.h
//  StencilRoutingTest
//
//  Created by Patrick Walton on 6/19/16.
//  Copyright © 2016 Mozilla Corporation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define FRAMEBUFFER_COUNT 8

@interface StencilRoutingTestView : NSOpenGLView {
    NSRect *displayList;
    size_t displayListSize;
    NSOpenGLContext *context;
    GLint compositeVertexShader;
    GLint compositeFragmentShader;
    GLint compositeProgram;
    GLint compositePositionAttribute;
    GLint compositeTextureUniforms[4];
    GLint compositeTileSizeUniform;
    GLint clearVertexShader;
    GLint clearFragmentShader;
    GLint clearProgram;
    GLint clearPositionAttribute;
    GLint clearColorUniform;
    GLint tileVertexShader;
    GLint tileFragmentShader;
    GLint tileProgram;
    GLint tilePositionAttribute;
    GLint tileFramebufferSizeUniform;
    GLint tileColorUniform;
    GLuint quadVertexBuffer;
    GLuint quadVertexArrayObject;
    GLuint displayListVertexBuffer;
    GLuint clearDisplayListVertexArrayObject;
    GLuint tileDisplayListVertexArrayObject;
    GLuint multisampleTextures[FRAMEBUFFER_COUNT];
    GLuint multisampleRenderbuffers[FRAMEBUFFER_COUNT];
    GLuint multisampleFramebuffers[FRAMEBUFFER_COUNT];
    GLuint samplesPassedQuery;
    GLuint tilingTimeElapsedQuery;
    GLuint compositingTimeElapsedQuery;
    BOOL framebuffersValid;
    IBOutlet NSTextField *framebuffersUsedLabel;
    IBOutlet NSTextField *tilingTimeLabel;
    IBOutlet NSTextField *compositingTimeLabel;
    IBOutlet NSTextField *totalTimeLabel;
    IBOutlet NSTextField *tileSizeField;
    IBOutlet NSPopUpButton *samplesField;
}

- (IBAction)openDisplayList:(id)sender;

@end
