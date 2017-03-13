#include "shader/math.fxsub"
#include "shader/common.fxsub"
#include "shader/phase.fxsub"
#include "shader/atmospheric.fxsub"
#include "shader/cloud.fxsub"

static const float3 moonScaling = 2000;
static const float3 moonTranslate = -float3(10000, -5000,10000);

static const float3 jupiterScaling = 4000;
static const float3 jupiterTranslate = float3(10000, 5000, 10000);

texture MoonMap<string ResourceName = "Shader/Textures/moon.jpg";>;
sampler MoonMapSamp = sampler_state
{
	texture = <MoonMap>;
	MINFILTER = LINEAR; MAGFILTER = LINEAR; MIPFILTER = LINEAR;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
texture JupiterMap<string ResourceName = "Shader/Textures/jupiter.jpg";>;
sampler JupiterMapSamp = sampler_state
{
	texture = <JupiterMap>;
	MINFILTER = LINEAR; MAGFILTER = LINEAR; MIPFILTER = LINEAR;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};

void SphereVS(
	in float4 Position : POSITION,
	in float4 Texcoord : TEXCOORD0,
	out float4 oTexcoord0 : TEXCOORD0,
	out float4 oTexcoord1 : TEXCOORD1,
	out float3 oTexcoord2 : TEXCOORD2,
	out float4 oPosition : POSITION,
	uniform float3 translate, uniform float3 scale)
{
	oTexcoord0 = Texcoord;
	oTexcoord1 = normalize(Position);
	oPosition = mul(float4(oTexcoord1.xyz * scale + translate, 1), matViewProject);
}

float4 SpherePS(
	in float2 coord : TEXCOORD0,
	in float3 normal : TEXCOORD1,
	uniform sampler source) : COLOR
{
	float4 diffuse = tex2D(source, coord + float2(time / 200, 0));
	diffuse.rgb *= saturate(dot(normal, -LightDirection) + 0.15);
	return diffuse;
}

void ScatteringVS(
	in float4 Position   : POSITION,
	out float3 oTexcoord0 : TEXCOORD0,
	out float4 oPosition : POSITION)
{
	oTexcoord0 = normalize(Position.xyz - CameraPosition);
	oPosition = mul(Position + float4(CameraPosition, 0), matWorldViewProject);
}

float4 ScatteringPS(in float3 viewdir : TEXCOORD0) : COLOR
{
	float3 V = normalize(viewdir);
	
	float scaling = 1000;

	ScatteringParams setting;
	setting.sunSize = mSunRadius;
	setting.sunRadiance = mSunRadiance;
	setting.mieG = mMiePhase;
	setting.mieHeight = mMieHeight * scaling;
	setting.rayleighHeight = mRayleighHeight * scaling;
	setting.earthRadius = 6360 * scaling;
	setting.earthAtmTopRadius = 6380 * scaling;
	setting.earthCenter = float3(0, -setting.earthRadius, 0);
	setting.waveLambdaMie = ComputeWaveLengthMie(mWaveLength, mMieColor, mMieTurbidity * scaling, 3);
	setting.waveLambdaRayleigh = ComputeWaveLengthRayleigh(mWaveLength) * mRayleighColor;
	setting.cloud = mCloudDensity;
	setting.cloudMie = 0.5;
	setting.cloudBias = mCloudBias;
    setting.cloudTop = 8 * scaling;
    setting.cloudBottom = 5 * scaling;
	setting.clouddir = float3(23175.7, 0, -3e+3 * mCloudSpeed);

	float4 insctrColor = ComputeCloudsInscattering(setting, CameraPosition + float3(0, scaling, 0), V, LightDirection);

	return linear2srgb(insctrColor);
}

#define SKYBOX_TEC(name, mmdpass) \
	technique name<string MMDPass = mmdpass; string Subset="0";>\
	{ \
		pass DrawJupiter { \
			AlphaBlendEnable = true; AlphaTestEnable = false;\
			ZEnable = false; ZWriteEnable = false;\
			SrcBlend = SRCALPHA; DestBlend = INVSRCALPHA;\
			VertexShader = compile vs_3_0 SphereVS(jupiterTranslate, jupiterScaling); \
			PixelShader  = compile ps_3_0 SpherePS(JupiterMapSamp); \
		} \
		pass DrawMoon { \
			AlphaBlendEnable = true; AlphaTestEnable = false;\
			ZEnable = false; ZWriteEnable = false;\
			SrcBlend = SRCALPHA; DestBlend = INVSRCALPHA;\
			VertexShader = compile vs_3_0 SphereVS(moonTranslate, moonScaling); \
			PixelShader  = compile ps_3_0 SpherePS(MoonMapSamp); \
		} \
		pass DrawScattering { \
			AlphaBlendEnable = true; AlphaTestEnable = false;\
			ZEnable = false; ZWriteEnable = false;\
			SrcBlend = ONE; DestBlend = SRCALPHA;\
			VertexShader = compile vs_3_0 ScatteringVS(); \
			PixelShader  = compile ps_3_0 ScatteringPS(); \
		} \
	}

SKYBOX_TEC(ScatteringTec0, "object")
SKYBOX_TEC(ScatteringTecBS0, "object_ss")

technique EdgeTec<string MMDPass = "edge";> {}
technique ShadowTec<string MMDPass = "shadow";> {}
technique ZplotTec<string MMDPass = "zplot";> {}