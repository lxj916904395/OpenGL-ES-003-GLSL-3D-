attribute vec4 position;
attribute vec2 textureCoordinate;


uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

varying lowp vec2 varyTextureCoordinate;

void main()
{
    varyTextureCoordinate = textureCoordinate;
    
    vec4 vPos;
    vPos = projectionMatrix * modelViewMatrix * position;
    
    //    vPos = position;
    
    gl_Position = vPos;
}
