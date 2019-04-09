/*
 * @file    Bloom.comp.glsl
 * @author  David Gallardo Moreno
 */

#version 430
precision highp float;

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(binding = 0, rgba8) uniform image2D uOutputBuffer0;
layout(binding = 1, rgba8) uniform image2D uInputBuffer0;
layout(binding = 2, rgba8) uniform image2D uInputBuffer1;

const float sKernelTableA[5][5] =  float[][](float[](0.003765,    0.015019,    0.023792,    0.015019,    0.003765),
                                            float[](0.015019,    0.059912,    0.094907,    0.059912,    0.015019),
                                            float[](0.023792,    0.094907,    0.150342,    0.094907,    0.023792),
                                            float[](0.015019,    0.059912,    0.094907,    0.059912,    0.015019),
                                            float[](0.003765,    0.015019,    0.023792,    0.015019,    0.003765));

const float sKernelTableB[5][5] =   float[][](float[](0.039021,	0.03975	,    0.039996,	0.03975	,    0.039021),
                                             float[](0.03975,	0.040492,	0.040742,	0.040492,	0.03975),
                                             float[](0.039996,	0.040742,	0.040995,	0.040742,	0.039996),
                                             float[](0.03975,	0.040492,	0.040742,	0.040492,	0.03975),
                                             float[](0.039021,	0.03975	,    0.039996,	0.03975	,    0.039021));


const float sKernelTable[9][9] =  float[][](float[](0.00401,	0.005895,	0.00776,	0.009157,	0.009675,	0.009157,	0.007763,	0.005895,	 0.00401),
                                            float[](0.005895,	0.008667,	0.01141,	0.013461,	0.014223,	0.013461,	0.011412,	0.008667,	0.005895),
                                            float[](0.007763,	0.011412,	0.01502,	0.017726,	0.018729,	0.017726,	0.015028,	0.011412,	0.007763),
                                            float[](0.009157,	0.013461,	0.01772,	0.020909,	0.022092,	0.020909,	0.017726,	0.013461,	0.009157),
                                            float[](0.009675,	0.014223,	0.01872,	0.022092,	0.023342,	0.022092,	0.018729,	0.014223,	0.009675),
                                            float[](0.009157,	0.013461,	0.01772,	0.020909,	0.022092,	0.020909,	0.017726,	0.013461,	0.009157),
                                            float[](0.007763,	0.011412,	0.01502,	0.017726,	0.018729,	0.017726,	0.015028,	0.011412,	0.007763),
                                            float[](0.005895,	0.008667,	0.01141,	0.013461,	0.014223,	0.013461,	0.011412,	0.008667,	0.005895),
                                            float[](0.00401,	0.005895,	0.00776,	0.009157,	0.009675,	0.009157,	0.007763,	0.005895,	 0.00401));



const float sKernelTableD[9][9] =  float[][](float[](0.010989,	0.011474,	0.011833,	0.012054,	0.012129,	0.012054,	0.011833,	0.011474,	0.010989),
                                            float[](0.011474,	0.01198	,   0.012355,	0.012586,	0.012664,	0.012586,	0.012355,	0.01198	,    0.011474),
                                            float[](0.011833,	0.012355,	0.012742,	0.01298,    0.01306,    0.01298,    0.012742,	0.012355,	0.011833),
                                            float[](0.012054,	0.012586,	0.01298	,    0.013222,	0.013304,	0.013222,	0.01298	,    0.012586,	0.012054),
                                            float[](0.012129,	0.012664,	0.01306	,    0.013304,	0.013386,	0.013304,	0.01306	,    0.012664,	0.012129),
                                            float[](0.012054,	0.012586,	0.01298	,    0.013222,	0.013304,	0.013222,	0.01298	,    0.012586,	0.012054),
                                            float[](0.011833,	0.012355,	0.012742,	0.01298	,    0.01306,    0.01298,    0.012742,	0.012355,	0.011833),
                                            float[](0.011474,	0.01198	,   0.012355,	0.012586,	0.012664,	0.012586,	0.012355,	0.01198	,    0.011474),
                                            float[](0.010989,	0.011474,	0.011833,	0.012054,	0.012129,	0.012054,	0.011833,	0.011474,	0.010989));

vec4 Blur(ivec2 aBufferCoord, ivec2 aBufferSize, float aArea)
{
    const ivec2 lBufferCoord = aBufferCoord;
    const int lKernelSize = 9;
    const int lHalfSize = lKernelSize / 2;
    const int lKernelStart = -lHalfSize;
    const int lKernelEnd = ((float(lKernelSize) * 0.5f) > float(lHalfSize)) ? lHalfSize + 1 : lHalfSize;

    vec4 lColorSum = vec4(0.f, 0.f, 0.f, 0.f);

    ivec2 lInputCoord = ivec2(0, 0);

    const ivec2 lAdjacentCoord = ivec2(1, 1); //max(ivec2(1, 1), ivec2(aBufferSize.x / 256.f, aBufferSize.y / 256.f));

    for (int itx = lKernelStart; itx < lKernelEnd; itx++) 
    { 
        for (int ity = lKernelStart; ity < lKernelEnd; ity++) 
        { 
            /*lInputCoord.x = (lBufferCoord.x + int(itx * uArea)) % int(gl_GlobalInvocationID.x);
            lInputCoord.y = (lBufferCoord.y + int(ity * uArea)) % int(gl_GlobalInvocationID.y);
            lInputCoord.x = (lInputCoord.x < 0) ? int(aBufferSize.x) - lInputCoord.x :  lInputCoord.x;
            lInputCoord.y = (lInputCoord.x < 0) ? int(aBufferSize.y) - lInputCoord.y :  lInputCoord.y;*/

            lInputCoord.x = lBufferCoord.x + int(itx * lAdjacentCoord.x * aArea);
            lInputCoord.y = lBufferCoord.y + int(ity * lAdjacentCoord.y * aArea);
            //lInputCoord.x = (lInputCoord.x < 0) ? int(aBufferSize.x) + lInputCoord.x :  lInputCoord.x;
            //lInputCoord.y = (lInputCoord.y < 0) ? int(aBufferSize.y) + lInputCoord.y :  lInputCoord.y;
            lInputCoord.x = clamp(lInputCoord.x, 0, int(aBufferSize.x));
            lInputCoord.y = clamp(lInputCoord.y, 0, int(aBufferSize.y));

            vec4 lInputColor = imageLoad(uInputBuffer1, lInputCoord);
            lColorSum += lInputColor * sKernelTable[itx + lHalfSize][ity + lHalfSize];
        } 
    }

    lColorSum.a = 1.0;

    return lColorSum;
}


void main(void)
{
    ivec2 lBufferCoord = ivec2(gl_GlobalInvocationID.xy);
    //vec2 tc = vec2(lBufferCoord.xy) / vec2(gl_NumWorkGroups.xy);
    vec4 lInputColor0 = imageLoad(uInputBuffer0, lBufferCoord);
    vec4 lInputColor1 = imageLoad(uInputBuffer1, lBufferCoord);
    vec4 lOutputColor = lInputColor0 + (Blur(lBufferCoord, ivec2(gl_NumWorkGroups.xy), 1.0));
    lOutputColor.a = 1.;
    imageStore (uOutputBuffer0, lBufferCoord, lOutputColor); 
}
 