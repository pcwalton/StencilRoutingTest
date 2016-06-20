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

- (NSOpenGLContext *)openGLContext {
    if (self->context == nil) {
        NSOpenGLPixelFormatAttribute attributes[] = {
            NSOpenGLPFAAlphaSize, 8,
            NSOpenGLPFAColorSize, 24,
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFADepthSize, 16,
            NSOpenGLPFAMultisample,
            NSOpenGLPFASamples, 4,
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

- (void)rebuildFramebuffer {
    if (self->multisampleFramebuffer != 0) {
        glDeleteFramebuffers(1, &self->multisampleFramebuffer);
        self->multisampleFramebuffer = 0;
    }
    if (self->multisampleRenderbuffer != 0) {
        glDeleteRenderbuffers(1, &self->multisampleRenderbuffer);
        self->multisampleRenderbuffer = 0;
    }
    if (self->multisampleTexture != 0) {
        glDeleteTextures(1, &self->multisampleTexture);
        self->multisampleTexture = 0;
    }

    NSSize framebufferSize = [self framebufferSize];
    NSLog(@"framebufferSize=%d %d",
          (int)framebufferSize.width,
          (int)framebufferSize.height);
    
    glGenTextures(1, &self->multisampleTexture);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, self->multisampleTexture);
    glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE,
                            4,
                            GL_RGBA,
                            (GLint)framebufferSize.width,
                            (GLint)framebufferSize.height,
                            GL_TRUE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glGenRenderbuffers(1, &self->multisampleRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, self->multisampleRenderbuffer);
    glRenderbufferStorageMultisample(GL_RENDERBUFFER,
                                     4,
                                     GL_DEPTH_STENCIL,
                                     (GLint)framebufferSize.width,
                                     (GLint)framebufferSize.height);
    glGenFramebuffers(1, &self->multisampleFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, self->multisampleFramebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER,
                           GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D_MULTISAMPLE,
                           self->multisampleTexture,
                           0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_DEPTH_STENCIL_ATTACHMENT,
                              GL_RENDERBUFFER,
                              self->multisampleRenderbuffer);
    NSLog(@"glCheckFramebufferStatus returns %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
    
    self->framebufferValid = YES;
}

- (void)frameChanged:(NSNotification *)notification {
    self->framebufferValid = NO;
}

- (void)fillVertex:(GLfloat *)vertex withPoint:(NSPoint)point {
    NSSize viewSize = [self frame].size;
    vertex[0] = point.x / viewSize.width * 2.0f - 1.0f;
    vertex[1] = point.y / viewSize.height * 2.0f - 1.0f;
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
    self->compositeTextureUniform = glGetUniformLocation(self->compositeProgram, "uTexture");
    self->compositeTileSizeUniform = glGetUniformLocation(self->compositeProgram, "uTileSize");
    
    [self createOpenGLProgram:&self->clearProgram
             withVertexShader:&self->clearVertexShader
               fragmentShader:&self->clearFragmentShader
                         name:@"clear"];
    
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
    
    glGenVertexArrays(1, &self->displayListVertexArrayObject);
    glBindVertexArray(self->displayListVertexArrayObject);
    glUseProgram(self->clearProgram);

    glGenBuffers(1, &self->displayListVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, self->displayListVertexBuffer);
    glVertexAttribPointer(self->clearPositionAttribute, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid *)0);
    glEnableVertexAttribArray(self->clearPositionAttribute);

    glGenQueries(1, &self->timeElapsedQuery);
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [[self openGLContext] makeCurrentContext];
    [[self openGLContext] update];
    
    glBeginQuery(GL_TIME_ELAPSED_EXT, self->timeElapsedQuery);
    
    // Drawing code here.
    if (!self->framebufferValid)
        [self rebuildFramebuffer];

    NSSize framebufferSize = [self framebufferSize];
    glBindFramebuffer(GL_FRAMEBUFFER, self->multisampleFramebuffer);
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
    glUniform4f(self->clearColorUniform, 0.0f, 0.0f, 0.0f, 1.0f);
    // TODO(pcwalton): Disable writing to the color buffer entirely.
    for (unsigned sample = 0; sample < 4; sample++) {
        glSampleMaski(0, 1 << sample);
        glStencilFunc(GL_ALWAYS, sample + 1, ~0);
        glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    // Generate the display list vertices.
    glBindVertexArray(self->displayListVertexArrayObject);
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

    // Perform routed drawing.
    glDisable(GL_MULTISAMPLE);
    glDisable(GL_SAMPLE_MASK);
    glEnable(GL_STENCIL_TEST);
    glSampleMaski(0, ~0);
    glStencilFunc(GL_EQUAL, 1, ~0);
    glStencilOp(GL_DECR, GL_DECR, GL_DECR);
    glUniform4f(self->clearColorUniform, 0.25f, 0.25f, 0.25f, 1.0f);
    glDrawArrays(GL_TRIANGLES, 0, (GLsizei)self->displayListSize * 6);
    
    // Composite.
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindVertexArray(self->quadVertexArrayObject);
    glBindBuffer(GL_ARRAY_BUFFER, self->quadVertexBuffer);
    float backingScaleFactor = [[self window] backingScaleFactor];
    glViewport(0,
               0,
               (GLint)([self frame].size.width * backingScaleFactor),
               (GLint)([self frame].size.height * backingScaleFactor));
    glUseProgram(self->compositeProgram);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, self->multisampleTexture);
    glUniform1i(self->compositeTextureUniform, 0); // FIXME(pcwalton): GL_TEXTURE0? I forget!
    glUniform1f(self->compositeTileSizeUniform, (GLfloat)[self tileSize]);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);

    glEndQuery(GL_TIME_ELAPSED_EXT);
    glFlush();
    [[NSOpenGLContext currentContext] flushBuffer];
    
    GLint available = 0;
    while (available == 0) {
        usleep(100);
        glGetQueryObjectiv(self->timeElapsedQuery, GL_QUERY_RESULT_AVAILABLE, &available);
    }
    GLuint64 timeElapsed = 0;
    glGetQueryObjectui64vEXT(self->timeElapsedQuery, GL_QUERY_RESULT, &timeElapsed);
    
    double timeElapsedMs = (double)timeElapsed / (double)1000000.0;
    [self->timeLabel setStringValue:[NSString stringWithFormat:@"%.03f ms GPU time", timeElapsedMs]];
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
            displayListItems[nextDisplayListItem] = [item rectValue];
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

@end
