//
//  StencilRoutingTestView.m
//  StencilRoutingTest
//
//  Created by Patrick Walton on 6/19/16.
//  Copyright © 2016 Mozilla Corporation. All rights reserved.
//

#import "StencilRoutingTestView.h"
#import "DisplayListItem.h"
#import <OpenGL/gl3.h>
#import <OpenGL/gl.h>

@implementation StencilRoutingTestView

const CompiledDisplayListItem initialDisplayList[] = {
    { { { 0.0f,   0.0f    }, { 400.0f, 400.0f } }, { { 2.0f, 0.0f }, { 1.0f, 1.0f } }, NO },
    { { { 400.0f, 0.0f    }, { 400.0f, 400.0f } }, { { 2.0f, 0.0f }, { 1.0f, 1.0f } }, NO },
    { { { 0.0f,   400.0f  }, { 400.0f, 400.0f } }, { { 2.0f, 0.0f }, { 1.0f, 1.0f } }, NO },
    { { { 400.0f, 400.0f  }, { 400.0f, 400.0f } }, { { 2.0f, 0.0f }, { 1.0f, 1.0f } }, NO },
    { { { 200.0f, 200.0f  }, { 400.0f, 400.0f } }, { { 2.0f, 0.0f }, { 1.0f, 1.0f } }, NO }
};

const GLfloat quadVertices[] = {
    -1.0f, -1.0f,
    1.0f, -1.0f,
    -1.0f, 1.0f,
    1.0f, 1.0f
};

enum DisplayListParsingState {
    DisplayListParsingStateBegin,
    DisplayListParsingStateParsingItems,
    DisplayListParsingStateParsingStackingContexts
};

struct Vertex {
    GLfloat x;
    GLfloat y;
    GLfloat z;
    GLfloat u;
    GLfloat v;
};

typedef struct Vertex Vertex;

typedef enum DisplayListParsingState DisplayListParsingState;

- (GLuint)samples {
    return [[self->samplesField titleOfSelectedItem] intValue];
}

- (NSOpenGLContext *)openGLContext {
    if (self->context == nil) {
        NSOpenGLPixelFormatAttribute attributes[] = {
            NSOpenGLPFAAlphaSize, 8,
            NSOpenGLPFAColorSize, 24,
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFADepthSize, 16,
            NSOpenGLPFAMultisample,
            NSOpenGLPFASamples, [self samples],
            NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
            0
        };
        NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
        self->context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
        [self->context makeCurrentContext];
    }
    return self->context;
}

- (void)createOpenGLProgram:(GLuint *)program
           withVertexShader:(GLuint *)vertexShader
             fragmentShader:(GLuint *)fragmentShader
                       name:(NSString *)name {
    *vertexShader = glCreateShader(GL_VERTEX_SHADER);
    NSData *vertexShaderData = [[NSFileManager defaultManager] contentsAtPath:[[NSBundle mainBundle]pathForResource:name ofType:@"vs.glsl"]];
    const GLchar *vertexShaderBytes = [vertexShaderData bytes];
    GLint vertexShaderLength = (GLint)[vertexShaderData length];
    glShaderSource(*vertexShader, 1, &vertexShaderBytes, &vertexShaderLength);
    glCompileShader(*vertexShader);
    
    *fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    NSData *fragmentShaderData = [[NSFileManager defaultManager] contentsAtPath:[[NSBundle mainBundle] pathForResource:name ofType:@"fs.glsl"]];
    const GLchar *fragmentShaderBytes = [fragmentShaderData bytes];
    GLint fragmentShaderLength = (GLint)[fragmentShaderData length];
    glShaderSource(*fragmentShader,
                   1,
                   &fragmentShaderBytes,
                   &fragmentShaderLength);
    glCompileShader(*fragmentShader);
    
    *program = glCreateProgram();
    glAttachShader(*program, *vertexShader);
    glAttachShader(*program, *fragmentShader);
    glLinkProgram(*program);
}

- (int)tileSize {
    return [self->tileSizeField intValue];
}

- (NSSize)framebufferSize {
    NSSize viewSize = [self frame].size;
    viewSize.width *= [self window].backingScaleFactor;
    viewSize.height *= [self window].backingScaleFactor;
    float tileSize = (float)[self tileSize];
    return NSMakeSize(ceilf(viewSize.width / tileSize), ceilf(viewSize.height / tileSize));
}

- (void)getTextureUniformLocations:(GLint *)uniforms forProgram:(GLint)program {
    for (unsigned i = 0; i < FRAMEBUFFER_COUNT; i++) {
        NSString *uniformName = [NSString stringWithFormat:@"uTexture%u", i];
        uniforms[i] = glGetUniformLocation(program, [uniformName cStringUsingEncoding:NSUTF8StringEncoding]);
    }
}

- (void)ensureFramebufferValid:(unsigned)index {
    while (self->validFramebufferCount <= index) {
        unsigned framebufferIndex = self->validFramebufferCount;
        glGenTextures(1, &self->multisampleTextures[framebufferIndex]);
        glGenRenderbuffers(1, &self->multisampleRenderbuffers[framebufferIndex]);
        glGenFramebuffers(1, &self->multisampleFramebuffers[framebufferIndex]);
    
        NSSize framebufferSize = [self framebufferSize];

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, self->multisampleTextures[framebufferIndex]);
        glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE,
                                [self samples],
                                GL_RGBA,
                                (GLint)framebufferSize.width,
                                (GLint)framebufferSize.height,
                                GL_TRUE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glBindRenderbuffer(GL_RENDERBUFFER, self->multisampleRenderbuffers[framebufferIndex]);
        glRenderbufferStorageMultisample(GL_RENDERBUFFER,
                                         [self samples],
                                         GL_DEPTH_STENCIL,
                                         (GLint)framebufferSize.width,
                                         (GLint)framebufferSize.height);
        glBindFramebuffer(GL_FRAMEBUFFER, self->multisampleFramebuffers[framebufferIndex]);
        glFramebufferTexture2D(GL_FRAMEBUFFER,
                               GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D_MULTISAMPLE,
                               self->multisampleTextures[framebufferIndex],
                               0);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                                  GL_DEPTH_STENCIL_ATTACHMENT,
                                  GL_RENDERBUFFER,
                                  self->multisampleRenderbuffers[framebufferIndex]);
    
        self->validFramebufferCount++;
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
}

- (void)invalidateFramebuffers {
    glDeleteFramebuffers(self->validFramebufferCount, self->multisampleFramebuffers);
    for (unsigned i = 0; i < self->validFramebufferCount; i++)
        self->multisampleFramebuffers[i] = 0;
    glDeleteRenderbuffers(self->validFramebufferCount, self->multisampleRenderbuffers);
    for (unsigned i = 0; i < self->validFramebufferCount; i++)
        self->multisampleRenderbuffers[i] = 0;
    glDeleteTextures(self->validFramebufferCount, self->multisampleTextures);
    for (unsigned i = 0; i < self->validFramebufferCount; i++)
        self->multisampleTextures[i] = 0;

    self->validFramebufferCount = 0;
}

- (void)frameChanged:(NSNotification *)notification {
    [self invalidateFramebuffers];
}

- (void)fillVertex:(Vertex *)vertex withPosition:(NSPoint)position uv:(NSPoint)uv opaque:(BOOL)opaque {
    NSSize viewSize = [self frame].size;
    vertex->x = position.x / viewSize.width;
    vertex->y = position.y / viewSize.height;
    vertex->z = opaque ? 1.0 : 0.0;
    vertex->u = uv.x;
    vertex->v = uv.y;
}

- (void)loadInitialDisplayList {
    self->displayList = (CompiledDisplayListItem *)malloc(sizeof(initialDisplayList));
    memcpy(self->displayList, initialDisplayList, sizeof(initialDisplayList));
    self->displayListSize = sizeof(initialDisplayList) / sizeof(initialDisplayList[0]);

    NSImage *initialSourceImage = [self createNewSourceImage];
    [[NSColor blueColor] setFill];
    NSRectFill(NSMakeRect(2.0, 255.0, 1.0, 1.0));
    [self finalizeSourceImage:initialSourceImage];
    self->sourceImage = initialSourceImage;
}

- (void)prepareOpenGL {
    if (self->displayList == NULL)
        [self loadInitialDisplayList];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(frameChanged:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:self];
    
    [self createOpenGLProgram:&self->compositeProgram
             withVertexShader:&self->compositeVertexShader
               fragmentShader:&self->compositeFragmentShader
                         name:@"composite"];
    
    [self createOpenGLProgram:&self->clearProgram
             withVertexShader:&self->clearVertexShader
               fragmentShader:&self->clearFragmentShader
                         name:@"clear"];
    
    [self createOpenGLProgram:&self->tileProgram
             withVertexShader:&self->tileVertexShader
               fragmentShader:&self->tileFragmentShader
                         name:@"tile"];
    
    self->compositePositionAttribute = glGetAttribLocation(self->compositeProgram, "aPosition");
    self->compositeTileSizeUniform = glGetUniformLocation(self->compositeProgram, "uTileSize");
    self->compositeDepthUniform = glGetUniformLocation(self->compositeProgram, "uDepth");
    [self getTextureUniformLocations:self->compositeTextureUniforms forProgram:self->compositeProgram];
    self->compositeSourceTextureUniform = glGetUniformLocation(self->compositeProgram, "uSourceTexture");
    
    self->clearPositionAttribute = glGetAttribLocation(self->clearProgram, "aPosition");
    self->clearColorUniform = glGetUniformLocation(self->clearProgram, "uColor");
    
    self->compositeTileSizeUniform = glGetUniformLocation(self->compositeProgram, "uTileSize");
    self->compositeDepthUniform = glGetUniformLocation(self->compositeProgram, "uDepth");
    
    self->tilePositionAttribute = glGetAttribLocation(self->tileProgram, "aPosition");
    self->tileSourceUVAttribute = glGetAttribLocation(self->tileProgram, "aSourceUV");
    self->tileFramebufferSizeUniform = glGetUniformLocation(self->tileProgram, "uFramebufferSize");
    
    glGenBuffers(1, &self->quadVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, self->quadVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);

    glGenBuffers(1, &self->displayListVertexBuffer);
    
    glGenVertexArrays(1, &self->clearQuadVertexArrayObject);
    glBindVertexArray(self->clearQuadVertexArrayObject);
    glUseProgram(self->clearProgram);
    glBindBuffer(GL_ARRAY_BUFFER, self->quadVertexBuffer);
    glVertexAttribPointer(self->clearPositionAttribute, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid *)0);
    glEnableVertexAttribArray(self->clearPositionAttribute);
    
    glGenVertexArrays(1, &self->clearDisplayListVertexArrayObject);
    glBindVertexArray(self->clearDisplayListVertexArrayObject);
    glUseProgram(self->clearProgram);
    glBindBuffer(GL_ARRAY_BUFFER, self->displayListVertexBuffer);
    glVertexAttribPointer(self->clearPositionAttribute, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid *)0);
    glEnableVertexAttribArray(self->clearPositionAttribute);

    glGenVertexArrays(1, &self->tileDisplayListVertexArrayObject);
    glBindVertexArray(self->tileDisplayListVertexArrayObject);
    glUseProgram(self->tileProgram);
    glBindBuffer(GL_ARRAY_BUFFER, self->displayListVertexBuffer);
    glVertexAttribPointer(self->tilePositionAttribute,
                          3,
                          GL_FLOAT,
                          GL_FALSE,
                          sizeof(Vertex),
                          (const GLvoid *)0);
    glVertexAttribPointer(self->tileSourceUVAttribute,
                          2,
                          GL_FLOAT,
                          GL_FALSE,
                          sizeof(Vertex),
                          (const GLvoid *)offsetof(Vertex, u));
    glEnableVertexAttribArray(self->tilePositionAttribute);
    glEnableVertexAttribArray(self->tileSourceUVAttribute);
    
    glGenTextures(1, &self->sourceTexture);
    glBindTexture(GL_TEXTURE_2D, self->sourceTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

    glGenQueries(1, &self->samplesPassedQuery);
    glGenQueries(1, &self->tilingTimeElapsedQuery);
    glGenQueries(1, &self->compositingTimeElapsedQuery);
}

- (void)waitForQueryToBeAvailable:(GLuint)query {
    GLint available = 0;
    while (available == 0) {
        usleep(100);
        glGetQueryObjectiv(query, GL_QUERY_RESULT_AVAILABLE, &available);
    }
}

- (double)getTimingFor:(GLuint)query {
    [self waitForQueryToBeAvailable:query];
    GLuint64 timeElapsed = 0;
    glGetQueryObjectui64vEXT(query, GL_QUERY_RESULT, &timeElapsed);
    return (double)timeElapsed / (double)1000000.0;
}

- (void)bindFramebufferTextures:(unsigned)usedFramebufferCount toUniforms:(GLint *)uniforms {
    for (unsigned i = 0; i < usedFramebufferCount; i++) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, self->multisampleTextures[i]);
        glUniform1i(uniforms[i], i);
    }
    for (unsigned i = usedFramebufferCount; i < FRAMEBUFFER_COUNT; i++) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
        glUniform1i(uniforms[i], 0);
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [[self openGLContext] makeCurrentContext];
    [[self openGLContext] update];

    // Drawing code here.
    glBeginQuery(GL_TIME_ELAPSED_EXT, self->tilingTimeElapsedQuery);

    NSSize framebufferSize = [self framebufferSize];

    // Generate the display list vertices.
    glBindVertexArray(self->clearDisplayListVertexArrayObject);
    glBindBuffer(GL_ARRAY_BUFFER, self->displayListVertexBuffer);
    size_t displayListVerticesSize = sizeof(Vertex) * self->displayListSize * 6;
    Vertex *displayListVertices = (Vertex *)malloc(displayListVerticesSize);
    for (unsigned i = 0; i < self->displayListSize; i++) {
        CompiledDisplayListItem *displayListItem = &self->displayList[self->displayListSize - i - 1];
        NSPoint topLeftPosition = displayListItem->bounds.origin;
        NSPoint topRightPosition = NSMakePoint(NSMaxX(displayListItem->bounds),
                                               displayListItem->bounds.origin.y);
        NSPoint bottomRightPosition = NSMakePoint(NSMaxX(displayListItem->bounds),
                                                  NSMaxY(displayListItem->bounds));
        NSPoint bottomLeftPosition = NSMakePoint(displayListItem->bounds.origin.x,
                                                 NSMaxY(displayListItem->bounds));
        NSPoint uv = NSMakePoint(NSMidX(displayListItem->sourceUV), NSMidY(displayListItem->sourceUV));
        BOOL opaque = self->displayList[i].opaque;
        [self fillVertex:&displayListVertices[i*6 + 0] withPosition:topLeftPosition uv:uv opaque:opaque];
        [self fillVertex:&displayListVertices[i*6 + 1] withPosition:topRightPosition uv:uv opaque:opaque];
        [self fillVertex:&displayListVertices[i*6 + 2] withPosition:bottomLeftPosition uv:uv opaque:opaque];
        [self fillVertex:&displayListVertices[i*6 + 3] withPosition:topRightPosition uv:uv opaque:opaque];
        [self fillVertex:&displayListVertices[i*6 + 4] withPosition:bottomRightPosition uv:uv opaque:opaque];
        [self fillVertex:&displayListVertices[i*6 + 5] withPosition:bottomLeftPosition uv:uv opaque:opaque];
    }
    glBufferData(GL_ARRAY_BUFFER, displayListVerticesSize, displayListVertices, GL_DYNAMIC_DRAW);
    free(displayListVertices);
    
    // Upload the texture.
    [self->sourceImage lockFocus];
    CGFloat backingScaleFactor = [[NSScreen mainScreen] backingScaleFactor];
    NSSize sourceImageSize = [self->sourceImage size];
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc]
                                  initWithFocusedViewRect:NSMakeRect(0.0,
                                                                     0.0,
                                                                     sourceImageSize.width,
                                                                     sourceImageSize.height)];
    NSAssert([imageRep bitmapFormat] == 0, @"Image in unexpected format!");
    glBindTexture(GL_TEXTURE_2D, self->sourceTexture);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RGBA,
                 sourceImageSize.width * backingScaleFactor,
                 sourceImageSize.height * backingScaleFactor,
                 0,
                 GL_RGBA,
                 GL_UNSIGNED_BYTE,
                 [imageRep bitmapData]);
    [self->sourceImage unlockFocus];

    unsigned framebuffersUsed = 0;
    while (framebuffersUsed < FRAMEBUFFER_COUNT) {
        // Initialize the framebuffer if necessary.
        [self ensureFramebufferValid:framebuffersUsed];
        
        // Clear.
        glBindFramebuffer(GL_FRAMEBUFFER, self->multisampleFramebuffers[framebuffersUsed]);
        glViewport(0, 0, (GLint)framebufferSize.width, (GLint)framebufferSize.height);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClearStencil(0);
        glClearDepth(0.0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

        // Initialize stencil buffer for routing.
        glUseProgram(self->clearProgram);
        glBindVertexArray(self->clearQuadVertexArrayObject);
        glBindBuffer(GL_ARRAY_BUFFER, self->quadVertexBuffer);
        glEnable(GL_STENCIL_TEST);
        glEnable(GL_MULTISAMPLE);
        glEnable(GL_SAMPLE_MASK);
        glDisable(GL_DEPTH_TEST);
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glUniform4f(self->clearColorUniform, 0.0f, 0.0f, 0.0f, 1.0f);
        for (unsigned sample = 0; sample < [self samples]; sample++) {
            glSampleMaski(0, 1 << sample);
            glStencilFunc(GL_ALWAYS, framebuffersUsed * [self samples] + sample + 2, ~0);
            glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        }

        // Perform routed drawing.
        glUseProgram(self->tileProgram);
        glBindVertexArray(self->tileDisplayListVertexArrayObject);
        glBindBuffer(GL_ARRAY_BUFFER, self->displayListVertexBuffer);
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        glDepthMask(GL_TRUE);
        glDisable(GL_MULTISAMPLE);
        glDisable(GL_SAMPLE_MASK);
        glEnable(GL_STENCIL_TEST);
        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_GEQUAL);
        glSampleMaski(0, ~0);
        glStencilFunc(GL_EQUAL, 2, ~0);
        glStencilOp(GL_DECR, GL_DECR, GL_DECR);
        glUniform2f(self->tileFramebufferSizeUniform, framebufferSize.width, framebufferSize.height);
        glDrawArrays(GL_TRIANGLES, 0, (GLsizei)self->displayListSize * 6);

        // Check for overflow.
        glUseProgram(self->clearProgram);
        glBindVertexArray(self->clearQuadVertexArrayObject);
        glBindBuffer(GL_ARRAY_BUFFER, self->quadVertexBuffer);
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glEnable(GL_MULTISAMPLE);
        glEnable(GL_SAMPLE_MASK);
        glEnable(GL_STENCIL_TEST);
        glDisable(GL_DEPTH_TEST);
        glSampleMaski(0, 1 << ([self samples] - 1));
        glStencilFunc(GL_EQUAL, 0, ~0);
        glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
        glBeginQuery(GL_ANY_SAMPLES_PASSED, self->samplesPassedQuery);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        glEndQuery(GL_ANY_SAMPLES_PASSED);
        [self waitForQueryToBeAvailable:self->samplesPassedQuery];

        framebuffersUsed++;

        GLuint overflowed = 0;
        glGetQueryObjectuiv(self->samplesPassedQuery, GL_QUERY_RESULT, &overflowed);
        if (!overflowed)
            break;
    }
    
    glEndQuery(GL_TIME_ELAPSED_EXT);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0,
               0,
               (GLint)([self frame].size.width * backingScaleFactor),
               (GLint)([self frame].size.height * backingScaleFactor));
    glBeginQuery(GL_TIME_ELAPSED_EXT, self->compositingTimeElapsedQuery);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Composite.
    glBindVertexArray(self->clearQuadVertexArrayObject);    // FIXME(pcwalton): Dodgy.
    glBindBuffer(GL_ARRAY_BUFFER, self->quadVertexBuffer);
    glDisable(GL_MULTISAMPLE);
    glDisable(GL_SAMPLE_MASK);
    glDisable(GL_STENCIL_TEST);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glUseProgram(self->compositeProgram);
    [self bindFramebufferTextures:framebuffersUsed toUniforms:self->compositeTextureUniforms];
    glActiveTexture(GL_TEXTURE0 + FRAMEBUFFER_COUNT);
    glBindTexture(GL_TEXTURE_2D, self->sourceTexture);
    glUniform1i(self->compositeSourceTextureUniform, FRAMEBUFFER_COUNT);
    glUniform1f(self->compositeTileSizeUniform, (GLfloat)[self tileSize]);
    glUniform1i(self->compositeDepthUniform, 8);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
    glEndQuery(GL_TIME_ELAPSED_EXT);

    glFlush();
    
    double tilingTimeElapsed = [self getTimingFor:self->tilingTimeElapsedQuery];
    double compositingTimeElapsed = [self getTimingFor:self->compositingTimeElapsedQuery];
    double totalTimeElapsed = tilingTimeElapsed + compositingTimeElapsed;

    [self->framebuffersUsedLabel setStringValue:[NSString stringWithFormat:@"%u framebuffer%s used",
                                                 framebuffersUsed,
                                                 framebuffersUsed == 1 ? "" : "s"]];

    [self->tilingTimeLabel setStringValue:[NSString stringWithFormat:@"%.03f ms (%.02f%%) GPU tiling time",
                                           tilingTimeElapsed,
                                           (tilingTimeElapsed / totalTimeElapsed) * 100.0f]];
    [self->compositingTimeLabel setStringValue:
     [NSString stringWithFormat:@"%.03f ms (%.02f%%) GPU compositing time",
                                compositingTimeElapsed,
                                (compositingTimeElapsed / totalTimeElapsed) * 100.0f]];
    [self->totalTimeLabel setStringValue:[NSString stringWithFormat:@"%.03f ms total GPU time",
                                          totalTimeElapsed]];
    
    [[NSOpenGLContext currentContext] flushBuffer];
}

- (IBAction)redraw:(id)sender {
    [self setNeedsDisplay:YES];
}

- (NSImage *)createNewSourceImage {
    // Create the source image.
    CGFloat factor = [[NSScreen mainScreen] backingScaleFactor];
    NSImage *newSourceImage = [[NSImage alloc] initWithSize:NSMakeSize(256.0 / factor, 256.0 / factor)];
    [newSourceImage lockFocus];
    [[[NSAffineTransform alloc] init] set];
    [[NSColor clearColor] setFill];
    NSRectFill(NSMakeRect(0.0, 0.0, 256.0, 256.0));
    
    // Create the "greeking" checkerboard for text.
    [[NSColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:0.2] setFill];
    NSRectFill(NSMakeRect(1.0, 255.0, 1.0, 1.0));
    NSRectFill(NSMakeRect(0.0, 254.0, 1.0, 1.0));
    
    return newSourceImage;
}

- (void)finalizeSourceImage:(NSImage *)image {
    [[NSGraphicsContext currentContext] flushGraphics];
    [image unlockFocus];
}

- (void)loadDisplayList:(NSFileHandle *)fileHandle {
    NSString *string = [[NSString alloc] initWithData:[fileHandle readDataToEndOfFile]
                                             encoding:NSUTF8StringEncoding];
    
    __block DisplayListParsingState state = DisplayListParsingStateBegin;
    NSMutableDictionary *stackingContextItems = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *stackingContextOffsets = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *stackingContextParents = [[NSMutableDictionary alloc] init];
    NSMutableArray *stackingContextOrdering = [[NSMutableArray alloc] init];
    NSMutableArray *parentStack = [[NSMutableArray alloc] init];
    NSError *error = nil;
    NSRegularExpression *itemRegex = [NSRegularExpression regularExpressionWithPattern:
                                      @"│  │  ├─ (\\w+) ([^@]*)@ Rect\\(([0-9.-]+)px×([0-9.-]+)px at \\(([0-9.-]+)px,([0-9.-]+)px\\)\\) .* StackingContext: StackingContextId\\((\\d+)\\)"
                                                                               options:0
                                                                                 error:&error];
    if (itemRegex == nil)
        @throw error;
    NSRegularExpression *stackingContextRegex = [NSRegularExpression regularExpressionWithPattern:
                                                 @"│  │  (.*)StackingContext at Rect\\([0-9.-]+px×[0-9.-]+px at \\(([0-9.-]+)px,([0-9.-]+)px\\)\\)[^:]+: StackingContextId\\((\\d+)\\)"
                                                                                          options:0
                                                                                            error:&error];
    if (stackingContextRegex == nil)
        @throw error;
    NSRegularExpression *solidColorDescriptionRegex = [NSRegularExpression regularExpressionWithPattern:@"rgba\\(([0-9.]+), ([0-9.]+), ([0-9.]+), ([0-9.]+)\\)"
                             options:0
                               error:&error];
    if (solidColorDescriptionRegex == nil)
        @throw error;
    
    [string enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSTextCheckingResult *textCheckingResult = nil;
        NSNumber *stackingContextId = nil;
        DisplayListItem *displayListItem = nil;
        NSString *itemType = nil;
        NSString *itemDescription = nil;
        BOOL newDisplayList = [line hasPrefix:@"┌ Display List"];
        if (state != DisplayListParsingStateBegin && newDisplayList) {
            *stop = YES;
            return;
        }
        switch (state) {
            case DisplayListParsingStateBegin:
                if (newDisplayList)
                    state = DisplayListParsingStateParsingItems;
                break;
            case DisplayListParsingStateParsingItems:
                if ([line hasPrefix:@"│  ├─ Stacking Contexts"]) {
                    state = DisplayListParsingStateParsingStackingContexts;
                    break;
                }
                textCheckingResult = [itemRegex firstMatchInString:line
                                                           options:0
                                                             range:NSMakeRange(0, [line length])];
                if (textCheckingResult == nil)
                    break;
                NSRect bounds = NSMakeRect(
                    [[line substringWithRange:[textCheckingResult rangeAtIndex:5]] floatValue],
                    [[line substringWithRange:[textCheckingResult rangeAtIndex:6]] floatValue],
                    [[line substringWithRange:[textCheckingResult rangeAtIndex:3]] floatValue],
                    [[line substringWithRange:[textCheckingResult rangeAtIndex:4]] floatValue]);
                stackingContextId = [NSNumber numberWithLongLong:
                                     [[line substringWithRange:[textCheckingResult rangeAtIndex:7]] longLongValue]];
                if ([stackingContextItems objectForKey:stackingContextId] == nil)
                    [stackingContextItems setObject:[[NSMutableArray alloc] init] forKey:stackingContextId];
                itemType = [line substringWithRange:[textCheckingResult rangeAtIndex:1]];
                itemDescription = [line substringWithRange:[textCheckingResult rangeAtIndex:2]];
                displayListItem = [DisplayListItem displayListItemWithBounds:bounds
                                                                        type:itemType
                                                                 description:itemDescription];
                [[stackingContextItems objectForKey:stackingContextId] addObject:displayListItem];
                break;
            case DisplayListParsingStateParsingStackingContexts:
                textCheckingResult = [stackingContextRegex firstMatchInString:line
                                                                      options:0
                                                                        range:NSMakeRange(0, [line length])];
                if (textCheckingResult == nil)
                    break;
                NSString *nestingIndicator = [line substringWithRange:[textCheckingResult rangeAtIndex:1]];
                NSUInteger nestingLevel = [[nestingIndicator componentsSeparatedByString:@"│"] count];
                while ([parentStack count] > nestingLevel)
                    [parentStack removeLastObject];
                stackingContextId = [NSNumber numberWithLongLong:
                                     [[line substringWithRange:[textCheckingResult rangeAtIndex:4]] longLongValue]];
                NSPoint offset = NSMakePoint(
                    [[line substringWithRange:[textCheckingResult rangeAtIndex:2]] floatValue],
                    [[line substringWithRange:[textCheckingResult rangeAtIndex:3]] floatValue]);
                [stackingContextOffsets setObject:[NSValue valueWithPoint:offset] forKey:stackingContextId];
                if ([parentStack count] > 0)
                    [stackingContextParents setObject:[parentStack lastObject] forKey:stackingContextId];
                [stackingContextOrdering addObject:stackingContextId];
                break;
        }
    }];
    
    size_t displayListItemsSize = 0;
    NSEnumerator *stackingContextItemsEnumerator = [stackingContextItems objectEnumerator];
    NSArray *items = nil;
    while ((items = [stackingContextItemsEnumerator nextObject]) != nil)
        displayListItemsSize += [items count];

    // Create the source image.
    NSImage *newSourceImage = [self createNewSourceImage];
    
    CompiledDisplayListItem *displayListItems = (CompiledDisplayListItem *)
        malloc(sizeof(CompiledDisplayListItem) * displayListItemsSize);
    size_t nextDisplayListItem = 0;
    NSEnumerator *stackingContextIdEnumerator = [stackingContextOrdering objectEnumerator];
    NSNumber *stackingContextId = nil;
    uint16_t nextSourceImageX = 2;
    while ((stackingContextId = [stackingContextIdEnumerator nextObject]) != nil) {
        NSPoint stackingContextOffset = [[stackingContextOffsets objectForKey:stackingContextId] pointValue];
        NSNumber *stackingContextParentId = [stackingContextParents objectForKey:stackingContextId];
        while (stackingContextParentId != nil) {
            NSPoint parentStackingContextOffset = [[stackingContextOffsets objectForKey:stackingContextParentId]
                                                    pointValue];
            stackingContextOffset.x += parentStackingContextOffset.x;
            stackingContextOffset.y += parentStackingContextOffset.y;
        }
        items = [stackingContextItems objectForKey:stackingContextId];
        NSEnumerator *itemEnumerator = [items objectEnumerator];
        DisplayListItem *item = nil;
        while ((item = [itemEnumerator nextObject]) != nil) {
            NSRect sourceUV;
            BOOL opaque = NO;
            if ([[item itemType] isEqualToString:@"SolidColor"]) {
                NSString *description = [item itemDescription];
                NSTextCheckingResult *textCheckingResult = [solidColorDescriptionRegex
                                                            firstMatchInString:description
                                                                       options:0
                                                                         range:NSMakeRange(0, [description length])];
                float r = [[description substringWithRange:[textCheckingResult rangeAtIndex:1]] floatValue];
                float g = [[description substringWithRange:[textCheckingResult rangeAtIndex:2]] floatValue];
                float b = [[description substringWithRange:[textCheckingResult rangeAtIndex:3]] floatValue];
                float a = [[description substringWithRange:[textCheckingResult rangeAtIndex:4]] floatValue];
                if (a == 0.0f)
                    continue;
                opaque = a == 1.0f;

                NSColor *color = [NSColor colorWithRed:(CGFloat)r
                                                 green:(CGFloat)g
                                                  blue:(CGFloat)b
                                                 alpha:(CGFloat)a];
                [color setFill];
                NSRectFill(NSMakeRect((CGFloat)nextSourceImageX, 255.0, 1.0, 1.0));
                sourceUV = NSMakeRect((CGFloat)nextSourceImageX, 0.0, 1.0, 1.0);
                nextSourceImageX++;
            } else {
                sourceUV = NSMakeRect(1.0, 0.0, 1.0, 1.0);
                opaque = NO;
            }

            NSRect bounds = NSOffsetRect([item bounds], stackingContextOffset.x, stackingContextOffset.y);
            CompiledDisplayListItem compiledDisplayListItem = { bounds, sourceUV, opaque };
            NSAssert(nextDisplayListItem < displayListItemsSize, @"Out of display item space!");
            displayListItems[nextDisplayListItem] = compiledDisplayListItem;
            nextDisplayListItem++;
        }
    }

    free(self->displayList);
    self->displayList = displayListItems;
    self->displayListSize = nextDisplayListItem;
    
    [self finalizeSourceImage:newSourceImage];
    self->sourceImage = newSourceImage;

    [self redraw:self];
}

- (IBAction)openDisplayList:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelCancelButton)
            return;
        NSError *error = nil;
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:[openPanel URL]
                                                                       error:&error];
        if (fileHandle == nil) {
            [[NSAlert alertWithError:error] runModal];
            return;
        }
        [self loadDisplayList:fileHandle];
    }];
}

- (IBAction)invalidateContextAndRedraw:(id)sender {
    self->context = nil;
    [self openGLContext];
    [self setNeedsDisplay:YES];
}

@end
