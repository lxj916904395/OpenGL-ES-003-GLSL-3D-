
varying lowp vec2 varyTextureCoordinate;

uniform sampler2D colorMap;

void main()
{
    gl_FragColor = texture2D(colorMap,varyTextureCoordinate);
}
