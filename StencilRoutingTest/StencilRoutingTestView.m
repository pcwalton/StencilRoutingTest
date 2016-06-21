//
//  StencilRoutingTestView.m
//  StencilRoutingTest
//
//  Created by Patrick Walton on 6/19/16.
//  Copyright © 2016 Mozilla Corporation. All rights reserved.
//

#import "StencilRoutingTestView.h"
#import <OpenGL/gl3.h>
#import <OpenGL/gl.h>

@implementation StencilRoutingTestView

const NSRect initialDisplayList[] = {
    { { 0.0f,   0.0f    }, { 400.0f, 400.0f } },
    { { 400.0f, 0.0f    }, { 400.0f, 400.0f } },
    { { 0.0f,   400.0f  }, { 400.0f, 400.0f } },
    { { 400.0f, 400.0f  }, { 400.0f, 400.0f } },
    { { 200.0f, 200.0f  }, { 400.0f, 400.0f } }
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

- (void)createOpenGLProgram:(GLint *)program
           withVertexShader:(GLint *)vertexShader
             fragmentShader:(GLint *)fragmentShader
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

- (void)rebuildFramebuffers {
    if (self->multisampleFramebuffers[0] != 0) {
        glDeleteFramebuffers(FRAMEBUFFER_COUNT, self->multisampleFramebuffers);
        for (unsigned i = 0; i < FRAMEBUFFER_COUNT; i++)
            self->multisampleFramebuffers[i] = 0;
    }
    if (self->multisampleRenderbuffers[0] != 0) {
        glDeleteRenderbuffers(FRAMEBUFFER_COUNT, self->multisampleRenderbuffers);
        for (unsigned i = 0; i < FRAMEBUFFER_COUNT; i++)
            self->multisampleRenderbuffers[i] = 0;
    }
    if (self->multisampleTextures[0] != 0) {
        glDeleteTextures(FRAMEBUFFER_COUNT, self->multisampleTextures);
        for (unsigned i = 0; i < FRAMEBUFFER_COUNT; i++)
            self->multisampleTextures[i] = 0;
    }

    glGenTextures(FRAMEBUFFER_COUNT, self->multisampleTextures);
    glGenRenderbuffers(FRAMEBUFFER_COUNT, self->multisampleRenderbuffers);
    glGenFramebuffers(FRAMEBUFFER_COUNT, self->multisampleFramebuffers);
    
    NSSize framebufferSize = [self framebufferSize];

    for (unsigned i = 0; i < FRAMEBUFFER_COUNT; i++) {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, self->multisampleTextures[i]);
        glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE,
                                [self samples],
                                GL_RGBA,
                                (GLint)framebufferSize.width,
                                (GLint)framebufferSize.height,
                                GL_TRUE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glBindRenderbuffer(GL_RENDERBUFFER, self->multisampleRenderbuffers[i]);
        glRenderbufferStorageMultisample(GL_RENDERBUFFER,
                                         [self samples],
                                         GL_DEPTH_STENCIL,
                                         (GLint)framebufferSize.width,
                                         (GLint)framebufferSize.height);
        glBindFramebuffer(GL_FRAMEBUFFER, self->multisampleFramebuffers[i]);
        glFramebufferTexture2D(GL_FRAMEBUFFER,
                               GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D_MULTISAMPLE,
                               self->multisampleTextures[i],
                               0);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                                  GL_DEPTH_STENCIL_ATTACHMENT,
                                  GL_RENDERBUFFER,
                                  self->multisampleRenderbuffers[i]);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
    }
    
    self->framebuffersValid = YES;
}

- (void)frameChanged:(NSNotification *)notification {
    self->framebuffersValid = NO;
}

- (void)fillVertex:(GLfloat *)vertex withPoint:(NSPoint)point {
    NSSize viewSize = [self frame].size;
    vertex[0] = point.x / viewSize.width;
    vertex[1] = point.y / viewSize.height;
}

- (void)prepareOpenGL {
    if (self->displayList == NULL) {
        self->displayList = (NSRect *)malloc(sizeof(initialDisplayList));
        memcpy(self->displayList, initialDisplayList, sizeof(initialDisplayList));
        self->displayListSize = sizeof(initialDisplayList) / sizeof(initialDisplayList[0]);
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(frameChanged:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:self];
    
    [self createOpenGLProgram:&self->compositeProgram
             withVertexShader:&self->compositeVertexShader
               fragmentShader:&self->compositeFragmentShader
                         name:@"composite"];
    glUseProgram(self->compositeProgram);
    self->compositePositionAttribute = glGetAttribLocation(self->compositeProgram, "aPosition");
    for (unsigned i = 0; i < FRAMEBUFFER_COUNT; i++) {
        NSString *uniformName = [NSString stringWithFormat:@"uTexture%u", i];
        self->compositeTextureUniforms[i] = glGetUniformLocation(self->compositeProgram,
                                                                 [uniformName cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    self->compositeTileSizeUniform = glGetUniformLocation(self->compositeProgram, "uTileSize");
    
    [self createOpenGLProgram:&self->clearProgram
             withVertexShader:&self->clearVertexShader
               fragmentShader:&self->clearFragmentShader
                         name:@"clear"];
    
    [self createOpenGLProgram:&self->tileProgram
             withVertexShader:&self->tileVertexShader
               fragmentShader:&self->tileFragmentShader
                         name:@"tile"];
    
    glGenVertexArrays(1, &self->quadVertexArrayObject);
    glBindVertexArray(self->quadVertexArrayObject);
    glUseProgram(self->clearProgram);
    self->clearPositionAttribute = glGetAttribLocation(self->clearProgram, "aPosition");
    self->clearColorUniform = glGetUniformLocation(self->clearProgram, "uColor");

    glGenBuffers(1, &self->quadVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, self->quadVertexBuffer);
    glVertexAttribPointer(self->clearPositionAttribute, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid *)0);
    glEnableVertexAttribArray(self->clearPositionAttribute);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);
    
    glGenVertexArrays(1, &self->clearDisplayListVertexArrayObject);
    glBindVertexArray(self->clearDisplayListVertexArrayObject);
    glUseProgram(self->clearProgram);
    
    glUseProgram(self->compositeProgram);
    self->compositeTileSizeUniform = glGetUniformLocation(self->compositeProgram, "uTileSize");

    glGenBuffers(1, &self->displayListVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, self->displayListVertexBuffer);
    glVertexAttribPointer(self->clearPositionAttribute, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid *)0);
    glEnableVertexAttribArray(self->clearPositionAttribute);

    glGenVertexArrays(1, &self->tileDisplayListVertexArrayObject);
    glBindVertexArray(self->tileDisplayListVertexArrayObject);
    glUseProgram(self->tileProgram);
    self->tilePositionAttribute = glGetAttribLocation(self->tileProgram, "aPosition");
    self->tileColorUniform = glGetUniformLocation(self->tileProgram, "uColor");
    self->tileFramebufferSizeUniform = glGetUniformLocation(self->tileProgram, "uFramebufferSize");
    
    glBindBuffer(GL_ARRAY_BUFFER, self->displayListVertexBuffer);
    glVertexAttribPointer(self->tilePositionAttribute, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid *)0);
    glEnableVertexAttribArray(self->tilePositionAttribute);
    
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

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [[self openGLContext] makeCurrentContext];
    [[self openGLContext] update];

    // Drawing code here.
    if (!self->framebuffersValid)
        [self rebuildFramebuffers];

    glBeginQuery(GL_TIME_ELAPSED_EXT, self->tilingTimeElapsedQuery);

    NSSize framebufferSize = [self framebufferSize];

    // Generate the display list vertices.
    glBindVertexArray(self->clearDisplayListVertexArrayObject);
    glBindBuffer(GL_ARRAY_BUFFER, self->displayListVertexBuffer);
    size_t displayListVerticesSize = sizeof(GLfloat) * self->displayListSize * 12;
    GLfloat *displayListVertices = (GLfloat *)malloc(displayListVerticesSize);
    for (unsigned i = 0; i < self->displayListSize; i++) {
        NSPoint topRight = NSMakePoint(NSMaxX(self->displayList[i]), self->displayList[i].origin.y);
        NSPoint bottomRight = NSMakePoint(NSMaxX(self->displayList[i]), NSMaxY(self->displayList[i]));
        NSPoint bottomLeft = NSMakePoint(self->displayList[i].origin.x, NSMaxY(self->displayList[i]));
        [self fillVertex: &displayListVertices[i * 12 + 0] withPoint: self->displayList[i].origin];
        [self fillVertex: &displayListVertices[i * 12 + 2] withPoint: topRight];
        [self fillVertex: &displayListVertices[i * 12 + 4] withPoint: bottomLeft];
        [self fillVertex: &displayListVertices[i * 12 + 6] withPoint: topRight];
        [self fillVertex: &displayListVertices[i * 12 + 8] withPoint: bottomRight];
        [self fillVertex: &displayListVertices[i * 12 + 10] withPoint: bottomLeft];
    }
    glBufferData(GL_ARRAY_BUFFER, displayListVerticesSize, displayListVertices, GL_DYNAMIC_DRAW);
    free(displayListVertices);

    unsigned framebuffersUsed = 0;
    while (framebuffersUsed < FRAMEBUFFER_COUNT) {
        // Clear.
        glBindFramebuffer(GL_FRAMEBUFFER, self->multisampleFramebuffers[framebuffersUsed]);
        glViewport(0, 0, (GLint)framebufferSize.width, (GLint)framebufferSize.height);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClearStencil(0);
        glClear(GL_COLOR_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

        // Initialize stencil buffer for routing.
        glUseProgram(self->clearProgram);
        glBindVertexArray(self->quadVertexArrayObject);
        glBindBuffer(GL_ARRAY_BUFFER, self->quadVertexBuffer);
        glEnable(GL_STENCIL_TEST);
        glEnable(GL_MULTISAMPLE);
        glEnable(GL_SAMPLE_MASK);
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
        glDisable(GL_MULTISAMPLE);
        glDisable(GL_SAMPLE_MASK);
        glEnable(GL_STENCIL_TEST);
        glSampleMaski(0, ~0);
        glStencilFunc(GL_EQUAL, 2, ~0);
        glStencilOp(GL_DECR, GL_DECR, GL_DECR);
        GLfloat genericColor = (GLfloat)1.0 / (GLfloat)([self samples] * MIN(FRAMEBUFFER_COUNT, 8));
        glUniform4f(self->tileColorUniform, genericColor, genericColor, genericColor, 1.0f);
        glUniform2f(self->tileFramebufferSizeUniform, framebufferSize.width, framebufferSize.height);
        glDrawArrays(GL_TRIANGLES, 0, (GLsizei)self->displayListSize * 6);

        // Check for overflow.
        glUseProgram(self->clearProgram);
        glBindVertexArray(self->quadVertexArrayObject);
        glBindBuffer(GL_ARRAY_BUFFER, self->quadVertexBuffer);
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glEnable(GL_MULTISAMPLE);
        glEnable(GL_SAMPLE_MASK);
        glEnable(GL_STENCIL_TEST);
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

    // Composite.
    glBeginQuery(GL_TIME_ELAPSED_EXT, self->compositingTimeElapsedQuery);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindVertexArray(self->quadVertexArrayObject);
    glBindBuffer(GL_ARRAY_BUFFER, self->quadVertexBuffer);
    float backingScaleFactor = [[self window] backingScaleFactor];
    glDisable(GL_MULTISAMPLE);
    glDisable(GL_SAMPLE_MASK);
    glDisable(GL_STENCIL_TEST);
    glViewport(0,
               0,
               (GLint)([self frame].size.width * backingScaleFactor),
               (GLint)([self frame].size.height * backingScaleFactor));
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glUseProgram(self->compositeProgram);
    
    for (unsigned i = 0; i < MIN(FRAMEBUFFER_COUNT, 8); i++) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, self->multisampleTextures[i]);
        glUniform1i(self->compositeTextureUniforms[i], i);
    }

    glUniform1f(self->compositeTileSizeUniform, (GLfloat)[self tileSize]);
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
                                      @"│  │  ├─ \\w+ [^@]*@ Rect\\(([0-9.-]+)px×([0-9.-]+)px at \\(([0-9.-]+)px,([0-9.-]+)px\\)\\) .* StackingContext: StackingContextId\\((\\d+)\\)"
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
    [string enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSTextCheckingResult *textCheckingResult = nil;
        NSNumber *stackingContextId = nil;
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
                if ([line containsString:@"SolidColor rgba(0, 0, 0, 0)"])
                    break;
                NSRect bounds = NSMakeRect(
                    [[line substringWithRange:[textCheckingResult rangeAtIndex:3]] floatValue],
                    [[line substringWithRange:[textCheckingResult rangeAtIndex:4]] floatValue],
                    [[line substringWithRange:[textCheckingResult rangeAtIndex:1]] floatValue],
                    [[line substringWithRange:[textCheckingResult rangeAtIndex:2]] floatValue]);
                stackingContextId = [NSNumber numberWithLongLong:
                                     [[line substringWithRange:[textCheckingResult rangeAtIndex:5]] longLongValue]];
                if ([stackingContextItems objectForKey:stackingContextId] == nil)
                    [stackingContextItems setObject:[[NSMutableArray alloc] init] forKey:stackingContextId];
                [[stackingContextItems objectForKey:stackingContextId]
                 addObject:[NSValue valueWithRect:bounds]];
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

    NSRect *displayListItems = (NSRect *)malloc(sizeof(NSRect) * displayListItemsSize);
    size_t nextDisplayListItem = 0;
    NSEnumerator *stackingContextIdEnumerator = [stackingContextOrdering objectEnumerator];
    NSNumber *stackingContextId = nil;
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
        NSValue *item = nil;
        while ((item = [itemEnumerator nextObject]) != nil) {
            NSAssert(nextDisplayListItem < displayListItemsSize, @"Out of display item space!");
            displayListItems[nextDisplayListItem] = NSOffsetRect([item rectValue],
                                                                 stackingContextOffset.x,
                                                                 stackingContextOffset.y);
            nextDisplayListItem++;
        }
    }

    NSAssert(nextDisplayListItem == displayListItemsSize, @"Didn't fill all display items!");
    free(self->displayList);
    self->displayList = displayListItems;
    self->displayListSize = displayListItemsSize;
    
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
