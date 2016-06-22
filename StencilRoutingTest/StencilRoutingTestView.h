//
//  StencilRoutingTestView.h
//  StencilRoutingTest
//
//  Created by Patrick Walton on 6/19/16.
//  Copyright © 2016 Mozilla Corporation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define FRAMEBUFFER_COUNT 8

struct CompiledDisplayListItem {
    NSRect bounds;
    NSRect sourceUV;
    BOOL opaque;
};

typedef struct CompiledDisplayListItem CompiledDisplayListItem;

@interface StencilRoutingTestView : NSOpenGLView {
    CompiledDisplayListItem *displayList;
    size_t displayListSize;
    NSOpenGLContext *context;
    NSImage *sourceImage;
    GLuint compositeVertexShader;
    GLuint compositeFragmentShader;
    GLuint compositeProgram;
    GLint compositePositionAttribute;
    GLint compositeTextureUniforms[FRAMEBUFFER_COUNT];
    GLint compositeSourceTextureUniform;
    GLint compositeTileSizeUniform;
    GLint compositeDepthUniform;
    GLuint clearVertexShader;
    GLuint clearFragmentShader;
    GLuint clearProgram;
    GLint clearPositionAttribute;
    GLint clearColorUniform;
    GLuint tileVertexShader;
    GLuint tileFragmentShader;
    GLuint tileProgram;
    GLint tilePositionAttribute;
    GLint tileSourceUVAttribute;
    GLint tileFramebufferSizeUniform;
    GLuint quadVertexBuffer;
    GLuint clearQuadVertexArrayObject;
    GLuint displayListVertexBuffer;
    GLuint clearDisplayListVertexArrayObject;
    GLuint tileDisplayListVertexArrayObject;
    GLuint multisampleTextures[FRAMEBUFFER_COUNT];
    GLuint multisampleRenderbuffers[FRAMEBUFFER_COUNT];
    GLuint multisampleFramebuffers[FRAMEBUFFER_COUNT];
    GLuint sourceTexture;
    GLuint samplesPassedQuery;
    GLuint tilingTimeElapsedQuery;
    GLuint compositingTimeElapsedQuery;
    unsigned validFramebufferCount;
    IBOutlet NSTextField *framebuffersUsedLabel;
    IBOutlet NSTextField *tilingTimeLabel;
    IBOutlet NSTextField *compositingTimeLabel;
    IBOutlet NSTextField *totalTimeLabel;
    IBOutlet NSTextField *tileSizeField;
    IBOutlet NSPopUpButton *samplesField;
}

- (IBAction)openDisplayList:(id)sender;

@end
