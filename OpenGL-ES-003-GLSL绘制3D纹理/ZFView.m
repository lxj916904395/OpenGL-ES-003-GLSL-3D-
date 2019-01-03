//
//  ZFView.m
//  OpenGL-ES-003-GLSL绘制3D纹理
//
//  Created by zhongding on 2019/1/2.
//

#import "ZFView.h"

#import <OpenGLES/ES3/gl.h>
#import "GLESMath.h"
#import "GLESUtils.h"

@interface ZFView(){
    CGFloat xrot;
    CGFloat yrot;
    CGFloat zrot;
    
    BOOL xEnable;
    BOOL yEnable;
    BOOL zEnable;
}
@property(strong ,nonatomic) CAEAGLLayer *eaglLayer;
@property(strong ,nonatomic) EAGLContext *context;

@property(assign ,nonatomic) GLuint renderBuffer;
@property(assign ,nonatomic) GLuint frameBuffer;

@property(assign ,nonatomic) GLuint program;

@property(strong ,nonatomic) NSTimer *timer;


@property(assign ,nonatomic) GLuint textureID;
@end
@implementation ZFView

- (void)layoutSubviews{
    [self setLayer];
    [self setupContext];
    [self cleanBuffer];
    [self setupRenderBuffer];
    [self setupFrameBuffer];
    [self setupRender];
}

- (void)setupRender{
    glClearColor(0.1, 0.5, 0.8, 1);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);

    CGFloat scale = [UIScreen mainScreen].scale;
    glViewport(self.frame.origin.x * scale, self.frame.origin.y * scale, self.frame.size.width * scale, self.frame.size.height * scale);

    if (self.program) {
        glDeleteProgram(self.program);
        self.program = 0;
    }
  self.program = [self loadProgram];
    
    glLinkProgram(self.program);
    
    GLint linkStatus ;
    glGetProgramiv(self.program, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        
        char message[1024];
        glGetProgramInfoLog(self.program, sizeof(message), NULL, &message[0]);
        
        NSString *err = [NSString stringWithUTF8String:message];
        NSLog(@"program链接出错:%@",err);
        return;
    }
    
    glUseProgram(self.program);
    
    [self setupVertex];
}

- (void)setupVertex{
 
    GLfloat vertexs[] = {
        -0.5,0.5,0,     0.1,0,0.54,     1,0,
        0.5,0.5,0,      0.3,0.1,0.5,    0,0,
        -0.5,-0.5,0,    0.4,0.1,0.3,    1,1,
        0.5,-0.5,0,     0.5,0.2,0.5,    0,1,
        0,0,0.8,        0.1,1,1,        0.5,0.5
    };
    
    GLuint indexs[] = {
        0,1,3,
        0,3,2,
        0,2,4,
        0,4,1,
        2,3,4,
        1,4,3
    };
 
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertexs), vertexs, GL_DYNAMIC_DRAW);
    
    
    GLuint position = glGetAttribLocation(self.program, "position");
    glEnableVertexAttribArray(position);
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*8, (GLfloat*)NULL+0);
    
    
    GLuint textureCoordinate = glGetAttribLocation(self.program, "textureCoordinate");
    glEnableVertexAttribArray(textureCoordinate);
    glVertexAttribPointer(textureCoordinate, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*8, (GLfloat*)NULL+6);
    [self setupTexture];
    
    
    GLuint projectionMatrix = glGetUniformLocation(self.program, "projectionMatrix");
    GLuint modelviewMatrix = glGetUniformLocation(self.program, "modelViewMatrix");
    
    
    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;
    
    //投影矩阵
    KSMatrix4 _projectionMatrix;
    ksMatrixLoadIdentity(&_projectionMatrix);
    float aspect = width/height;
    //透视变换，视角30°
    ksPerspective(&_projectionMatrix, 30.0, aspect, 5.0f, 20.0f);

    //设置glsl里面的投影矩阵
    /*
     void glUniformMatrix4fv(GLint location,  GLsizei count,  GLboolean transpose,  const GLfloat *value);
     参数列表：
     location:指要更改的uniform变量的位置
     count:更改矩阵的个数
     transpose:是否要转置矩阵，并将它作为uniform变量的值。必须为GL_FALSE
     value:执行count个元素的指针，用来更新指定uniform变量
     */
    glUniformMatrix4fv(projectionMatrix, 1, GL_FALSE, &_projectionMatrix.m[0][0]);
  
    glEnable(GL_CULL_FACE);

    //模型视图矩阵
    KSMatrix4 _modelviewMatrix;
    ksMatrixLoadIdentity(&_modelviewMatrix);
    ksTranslate(&_modelviewMatrix, 0.0, 0.0, -10.0);

    //旋转矩阵
    KSMatrix4 _rotateMatrix;
    ksMatrixLoadIdentity(&_rotateMatrix);
    
    //围绕X轴旋转
    ksRotate(&_rotateMatrix, xrot, 1, 0, 0);
    //围绕Y轴旋转
    ksRotate(&_rotateMatrix, yrot, 0, 1, 0);
    //围绕Z轴旋转
    ksRotate(&_rotateMatrix, zrot, 0, 0, 1);
    
    //模型视图矩阵与旋转矩阵相乘
    ksMatrixMultiply(&_modelviewMatrix, &_rotateMatrix, &_modelviewMatrix);
    
    glUniformMatrix4fv(modelviewMatrix, 1, GL_FALSE, &_modelviewMatrix.m[0][0]);
    
    glDrawElements(GL_TRIANGLES, sizeof(indexs) / sizeof(GLuint), GL_UNSIGNED_INT, indexs);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];

}

//添加纹理
- (void)setupTexture{
    
    CGImageRef image = [UIImage imageNamed:@"test.jpg"].CGImage;
    
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    
    GLubyte *data = calloc(width*height*4, sizeof(GLubyte));
    
    CGContextRef context = CGBitmapContextCreate(data, width, height, 8, width*4, CGImageGetColorSpace(image), kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    
    CGContextRelease(context);
    
    glGenTextures(1, &_textureID);
    glBindTexture(GL_TEXTURE_2D, _textureID);
    
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_MIRRORED_REPEAT);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLint)width, (GLint)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    free(data);
}

- (GLuint)loadProgram{
    //顶点着色器路径
    NSString *verTexFile = [[NSBundle mainBundle] pathForResource:@"shaderv" ofType:@"glsl"];
    
    NSString *fragmentFile = [[NSBundle mainBundle] pathForResource:@"shaderf" ofType:@"glsl"];
    
    //定义2个临时着色器对象
    GLuint vertexShader, fragmentShader;
    
    //编译顶点着色程序、片元着色器程序
    [self compileShader:&vertexShader type:GL_VERTEX_SHADER file:verTexFile];
    [self compileShader:&fragmentShader type:GL_FRAGMENT_SHADER file:fragmentFile];
    
    //创建program
    GLint program = glCreateProgram();
    
    //创建最终的程序
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    
    //释放不需要的shader
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    
    return program;
}

//链接shader
- (void)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file{
    //获取着色器里面的字符串内容
    NSString *content = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    
    //转化为C字符串
    const GLchar * source = (GLchar*)[content UTF8String];
    
    //根据类型创建shader
    *shader = glCreateShader(type);
    
    //将着色器源码附加到着色器对象上。
    //参数1：shader,要编译的着色器对象 *shader
    //参数2：numOfStrings,传递的源码字符串数量 1个
    //参数3：strings,着色器程序的源码（真正的着色器程序源码）
    //参数4：lenOfStrings,长度，具有每个字符串长度的数组，或NULL，这意味着字符串是NULL终止的
    glShaderSource(*shader, 1, &source, NULL);
    
    //把着色器源代码编译成目标代码
    glCompileShader(*shader);
}

#pragma mark *****************
- (void)setupFrameBuffer{
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
}

#pragma mark *****************
- (void)setupRenderBuffer{
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
}

#pragma mark *****************
- (void)cleanBuffer{
    glDeleteBuffers(1, &_renderBuffer);
    glDeleteBuffers(1, & _frameBuffer);
    _renderBuffer = 0;
    _frameBuffer = 0;
}

#pragma mark *****************
- (void)setupContext{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:(kEAGLRenderingAPIOpenGLES3)];
    self.context = context;
    if (![EAGLContext setCurrentContext:self.context]) {
        NSLog(@"context err");
        return;
    }
}

#pragma mark *****************
- (void)setLayer{
    self.eaglLayer = (CAEAGLLayer*)self.layer;
    self.eaglLayer.opaque = YES;
    self.eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],kEAGLDrawablePropertyRetainedBacking,kEAGLColorFormatRGBA8,kEAGLDrawablePropertyColorFormat, nil];

    [self setContentScaleFactor:[UIScreen mainScreen].scale];
    
    glEnable(GL_DEPTH_TEST);
    
}

+ (Class)layerClass{
    return [CAEAGLLayer class];
}


- (IBAction)clickY:(id)sender {
    yEnable = !yEnable;
      [self setupTimer];
}
- (IBAction)clickX:(id)sender {
    xEnable = !xEnable;
      [self setupTimer];
}
- (IBAction)clickZ:(id)sender {
    zEnable = !zEnable;
    [self setupTimer];
}

- (void)setupTimer{
    if(!self.timer)
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(rotate) userInfo:nil repeats:YES];
}


- (void)rotate{
    xrot +=5*xEnable;
    yrot +=5*yEnable;
    zrot +=5*zEnable;
     [self setupRender];
}


@end
