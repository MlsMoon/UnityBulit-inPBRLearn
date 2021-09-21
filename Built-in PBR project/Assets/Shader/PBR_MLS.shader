Shader "Custom/MYPBR/PBR_Forward"
{
    Properties
    {
        _Albedo ("albedo", 2D) = "white" {}
        _BaseCol("物体固有色",Color) = (1.,1.,1.,1.)
        [Space(30)]
        [Normal]_Normal("法线贴图",2D) = "bump"{}
        [Space(30)]
        _RoughnessTex("粗糙度贴图",2D) = "white"{}
        _Roughness("粗糙度系数",Range(0.,1.)) = 1.0
        [Space(30)]
        _MentalnessTex("金属度贴图",2D) = "white"{}
        _Mentalness("金属度系数",Range(0.,1.)) = 1.0
        [Space(30)]
        _EmissiveTex("自发光贴图",2D) = "black"{}
        _Emissive("自发光强度" ,Range(0,4)) = 1.0
        [Space(50)]
        _LUT("LUT查找图",2D) = "red"{}
    }
    SubShader
    {
        Tags 
        {
            "LightMode" = "ForwardBase"
            "RenderType"="Opaque" 
        }
        //forward rendering
        //base
        Pass
        {
            Tags{"LightMode" = "ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "PBR_LIGHT.cginc"
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fwdadd

            sampler2D _Albedo;float4 _Albedo_ST;
            fixed4 _BaseCol;
            sampler2D _Normal;float4 _Normal_ST;
            sampler2D _RoughnessTex;float4 _RoughnessTex_ST;
            float _Roughness;
            sampler2D _MentalnessTex;float4 _MentalnessTex_ST;
            float _Mentalness;
            sampler2D _LUT;
            sampler2D _EmissiveTex;
            float _Emissive;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.posWS = mul(unity_ObjectToWorld , v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Albedo);
                o.nDirWS = UnityObjectToWorldNormal(v.normal);
                o.tDirWS = normalize( mul(unity_ObjectToWorld,float4(v.tangent.xyz,0.0)).xyz);
                o.bDirWS = normalize( cross(o.nDirWS , o.tDirWS) * v.tangent.w );
                o.lightmapUV = getVertexGI(v.uv1,v.uv2,o.posWS,o.nDirWS);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //get the var
                half3 lDirWS = normalize(_WorldSpaceLightPos0.xyz);
                half3 vDirWS = normalize( _WorldSpaceCameraPos.xyz -i.posWS.xyz )  ;
                half3 hDirWS = normalize( lDirWS + vDirWS );
                float3x3 TBN = float3x3(i.tDirWS,i.bDirWS,i.nDirWS);
                // sample the texture
                fixed4 albedo = tex2D(_Albedo, i.uv)*_BaseCol;
                half3 var_normal = UnpackNormal( tex2D(_Normal , i.uv ) );
                half var_roughness = max(0.01 , tex2D(_RoughnessTex , i.uv).r * _Roughness );
                half var_metallic = tex2D(_MentalnessTex , i.uv).r * _Mentalness;
                float3 nDirWS = normalize( mul(var_normal ,TBN ));
                //caculate var
                float NdotL = max(0, dot(nDirWS , lDirWS ) );
                float NdotH = max(0, dot(nDirWS , hDirWS ) );
                float NdotV = dot(nDirWS , vDirWS ) ;
                float R = var_roughness*var_roughness ;
                float3 F0 = getF0(var_metallic,albedo);
                //direct light
                float3 directLightRes = Get_DirectLight_Res( var_metallic , R , F0 , albedo ,_BaseCol ,NdotV,NdotL ,NdotH );
                //get indirect light==================================
                float3 IndirectRes = Get_IndirectLight_Res( nDirWS , vDirWS , _LUT , albedo , var_metallic ,R , F0 ,NdotV);
                // return float4(var_metallic,var_metallic,var_metallic,var_metallic);
                float3 Emissive = tex2D(_EmissiveTex , i.uv) * _Emissive;
                return  float4(IndirectRes + directLightRes + Emissive ,1. );
            }
            ENDCG
        }
        //add
        Pass
        {
            Tags{"LightMode" = "ForwardAdd"}    
            //混合模式，表示该Pass计算的光照结果可以在帧缓存中与之前的光照结果进行叠加，否则会覆盖之前的光照结果
			Blend One One
            
            CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			//multi_compile_fwdadd指令可以保证我们在shader中使用光照衰减等光照变量可以被正确赋值
            #pragma multi_compile_fwdadd
            
            #include "Lighting.cginc"
            #include  "AutoLight.cginc"
            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
 
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
			};

            v2f vert(a2v v)
            {
                v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                return fixed4(1.,1.,0.5,1.);
            }
            ENDCG
        }
        //deffer rendering
        Pass
        {
            Tags
            {
                "LightMode" = "Deferred"
            }    
            
            CGPROGRAM
                #pragma target 3.0
            ENDCG
        }
    }
}
