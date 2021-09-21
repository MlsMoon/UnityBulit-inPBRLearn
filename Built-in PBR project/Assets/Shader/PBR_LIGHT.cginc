#ifndef MY_PBR_LIGHT
#define MY_PBR_LIGHT
#define PI 3.1415926535898
#include "UnityCG.cginc"
#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
#pragma multi_compile UNITY_COLORSPACE_GAMMA



            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 nDirWS : TEXCOORD1;
                float3 tDirWS : TEXCOORD2;
                float3 bDirWS : TEXCOORD3;
                float3 posWS : TEXCOORD4;
                half4 lightmapUV : TEXCOORD5;
            };

            //lightmap
            inline half4 getVertexGI(float2 uv1 , float2 uv2 ,float3 posWS , float3 nDirWS )
            {
                half4 lightmapUV = half4( 0.,0.,0.,0.);

                //开启光照贴图
                #ifdef LIGHTMAP_ON
                    //静态物体
                    lightmapUV.xy = uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                
                #elif UNITY_SHOULD_SAMPLE_SH
                    //非静态物体
                    
                
                #endif

                return  lightmapUV;
            }



            //PBR
            //F
//直接光相关


            float getF0(float mentalness,float3 albedo)
            {
                float3 F0 = float3(0.04,0.04,0.04);
                return lerp(F0 , albedo , mentalness);
            }
            float3 Fresnel_Schlick ( float3 F0 , float3 costheta_hdotv )
            {
                return F0+(1.-F0) * pow((1-costheta_hdotv),5.0 );
            }
            //D
            float Trowbridge_Reitz_GGX(float3 ndoth , float roughness )
            {
                float roughness2 = roughness * roughness;
                float ndoth2 = ndoth * ndoth ;
                float result = roughness2 / pow(  ndoth2 *(roughness2 -1 ) + 1  ,2) / PI;
                return result;
            }
            //G
            float Geometry_Schlick_GGX(float therta , float k)
            {
                return therta / ( therta * (1-k) +k );
            }
            float Geometry_Smith(float ndotl ,float ndotv ,float k)
            {
                return Geometry_Schlick_GGX(ndotl , k) * Geometry_Schlick_GGX(ndotv,k);
            }

            //获得直接光计算结果
            inline  float3 Get_DirectLight_Res
                (
                    float metalic ,
                    float roughness ,
                    float3 F0,
                    float3 albedo ,
                    float3 basecolor ,
                    float NdotV,
                    float NdotL,
                    float NdotH
                )
            {
                //get direct specluar================================
                float denominator = 4.0 * NdotV * NdotL +0.005; 
                float3 Fresnel = Fresnel_Schlick(F0,NdotV);
                float Distribution = Trowbridge_Reitz_GGX(NdotH , roughness );
                float Geometry = Geometry_Smith(NdotL , NdotV , pow(roughness+1,2)/8);
                float3 specluar = max(0,  Distribution * Fresnel * Geometry  / denominator) ;
                //====================================================
                //get direct diffuse==================================
                float3 diffuse = OneMinusReflectivityFromMetallic(metalic) * basecolor * albedo / UNITY_PI;
                //====================================================
                float3 directLightRes = (diffuse + specluar )*_LightColor0.rgb*NdotL;
                return  directLightRes;
            }
            

            //实时环境光相关
            //环境光F
            inline float3 Fresnel_Schlick_Env(float cosTheta, float3 F0, float roughness)
            {
                return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
            }
            inline float3 Get_IndirectLight_Res
                (
                    float3 nDirWS ,
                    float3 vDirWS ,
                    sampler2D _LUT ,
                    float albedo ,
                    float metalic ,
                    float roughness ,
                    float F0,
                    float NdotV
                )
            {
                //==============indirect diffuse======================
                half3 SH = ShadeSH9( float4( nDirWS , 1. ) );
                half3 ambient=UNITY_LIGHTMODEL_AMBIENT;
                half3 iblDiffuse = max(half3(0,0,0),ambient+SH);
                // LUT采样
                float2 envBDRF = tex2D(_LUT, float2(lerp(0, 0.99, NdotV), lerp(0, 0.99, roughness))).rg;
                float3 F_env = Fresnel_Schlick_Env(NdotV, F0, roughness);
                float kd_env = (1 - F_env) * OneMinusReflectivityFromMetallic(metalic);
                float3 iblDiffuseResult = iblDiffuse * kd_env *albedo *0.03 ;
                //===============indirect specular====================
                float mip_roughness = roughness * (1.7 - 0.7 * roughness);
                float3 reflectDir = reflect( -vDirWS , nDirWS);
                half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
                half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectDir, mip);
                /*rgbm是一个4通道的值，最后一个m存的是一个参数，解码时将前三个通道表示的颜色乘上xM^y，
                x和y都是由环境贴图定义的系数，存储在unity_SpecCube0_HDR这个结构中*/
                //颜色从HDR编码下解码 解码环境采样数据
                float3 iblSpecular = DecodeHDR(rgbm, unity_SpecCube0_HDR);
                float3 iblSpecular_final = iblSpecular *(F_env * envBDRF.r + envBDRF.g);
                //=============================res====================
                half3 IndirectRes = iblDiffuseResult + iblSpecular_final;
                return  IndirectRes;
            }

#endif