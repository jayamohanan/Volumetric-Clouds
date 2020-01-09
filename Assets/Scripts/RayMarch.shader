Shader "Hidden/RayMarch"
{
	Properties
	{
		_cloudNoise("Texture", 3D) = "white" {}
		_MainTex("Texture", 2D) = "white" {}
	}
		SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 viewVector: TEXCOORD1;
			};

			v2f vert(appdata v)
			{
				v2f o;

				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				float3 viewVector = mul(unity_CameraInvProjection, float4((v.uv * 2 - 1),-0.985, -1));
				o.viewVector = mul(unity_CameraToWorld, float4(viewVector, 0));
				return o;
			}

			float3 boundsMin;
			float3 boundsMax;
			float3 offset;
			sampler2D _MainTex;
			Texture2D<float4> _RandomNoiseTex;
			SamplerState sampler_RandomNoiseTex;
			Texture3D<float4> _cloudNoise;
			SamplerState sampler_cloudNoise;
			float densityThreshold;
			float densityMultiplier;
			Texture3D<float4> noiseTex;
			SamplerState sampler_noiseTex;
			float4 phaseParams;
			int numStepsLight = 8;
			int change;//values are updated in every update of script, just to apply time in shader
			//light absorption
			float lightAbsorptionTowardSun;// used while calculating lightMarch 
			float lightAbsorptionThroughCloud;// used while marching through cloud along ray direction
			//Texture2D _cloudNoise;
		   //sampler2D _cloudNoise;


		   // Returns (dstToBox, dstInsideBox). If ray misses box, dstInsideBox will be zero
		   float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRaydir) {
			   //invRaydir is rayDir from origin
			   // Adapted from: http://jcgt.org/published/0007/03/04/
			   float3 t0 = (boundsMin - rayOrigin) * invRaydir;
			   float3 t1 = (boundsMax - rayOrigin) * invRaydir;
			   float3 tmin = min(t0, t1);
			   float3 tmax = max(t0, t1);

			   float dstA = max(max(tmin.x, tmin.y), tmin.z);
			   float dstB = min(tmax.x, min(tmax.y, tmax.z));

			   // CASE 1: ray intersects box from outside (0 <= dstA <= dstB)
			   // dstA is dst to nearest intersection, dstB dst to far intersection

			   // CASE 2: ray intersects box from inside (dstA < 0 < dstB)
			   // dstA is the dst to intersection behind the ray, dstB is dst to forward intersection

			   // CASE 3: ray misses box (dstA > dstB)

			   float dstToBox = max(0, dstA);
			   float dstInsideBox = max(0, dstB - dstToBox);
			   return float2(dstToBox, dstInsideBox);
		   }
		   float remap(float v, float minOld, float maxOld, float minNew, float maxNew) {
			   return minNew + (v - minOld) / (maxOld - minOld) * (maxNew - minNew);
		   }
		   float componentInRange(float a, float min, float max) {
			   return (a - min) / (max - min)*1000.0;
		   }
		   float3 posInRange(float3 pos) {
			   float posX = componentInRange(pos.x, boundsMin.x, boundsMax.x);
			   float posY = componentInRange(pos.y, boundsMin.y, boundsMax.y);
			   float posZ = componentInRange(pos.z, boundsMin.z, boundsMax.z);
			   return float3(posX, posY, posZ);
		   }
		   //enyey Greenstein
		   float hg(float a, float g) {
			   float g2 = g * g;
			   return (1 - g2) / (4*4.1415*pow(1+g2-2*g*a, 1.5));
		   }
		   float phase(float a) {
			   float blend = 0.5;
			   float hgBlend = hg(a, phaseParams.x) * (1 - blend) + hg(a, -phaseParams.y) * (blend);
			   return phaseParams.z + hgBlend * phaseParams.w;

		   }
		   float sampleDensity(float3 pos)
		   {
			   float time = _Time.x;
			   const float baseScale = 1 / 1000.0;
			   float3 size = boundsMax - boundsMin;
			   float3 uvw = posInRange(pos) * baseScale;
			   //float3 uvw = pos * baseScale;
			   /*float3 randomOffset = _RandomNoiseTex.SampleLevel(sampler_RandomNoiseTex, uvw.xyz, 0);
			   uvw = float3(uvw.x+ randomOffset.x*0.02, uvw.y + randomOffset.y * 0.02, uvw.z + randomOffset.z * 0.02);*/

			   float3 shapeSamplePos = uvw +float3(time , time * 0.5, time * 0.35);

			   //falloff along the edges, detail description in notebook
			   const float containerEdgeFadeDst = 50.0;
			   float dstFromEdgeX = min(containerEdgeFadeDst, min(pos.x - boundsMin.x, boundsMax.x - pos.x));
			   float dstFromEdgeZ = min(containerEdgeFadeDst, min(pos.z - boundsMin.z, boundsMax.z - pos.z));
			   float edgeWeight = min(dstFromEdgeX, dstFromEdgeZ) / containerEdgeFadeDst;

			   float gMin = 0.2;
			   float gMax = 0.7;
			   float heightPercent = (pos.y - boundsMin.y) / size.y;
			   float heightGradient = saturate(remap(heightPercent,0,gMin,0,1)) * saturate(remap(heightPercent, 1,gMax, 0,1));
			   //heightGradient *= edgeWeight;

			   //calculate base shape density
			   float4 shapeNoise = _cloudNoise.SampleLevel(sampler_cloudNoise, uvw, 0);
			   float shapeNoiseRChannel = shapeNoise.r;//taking R Channel noise only, at this point texture as one channel noise
			   float baseShapeDensity = shapeNoiseRChannel - densityThreshold/5.0;

			   if (baseShapeDensity > 0) {
				   return (baseShapeDensity) * densityMultiplier;
			   }
			   return 0;
		   }

		   float lightMarch(float3 position) {
			   float3 dirToLight = _WorldSpaceLightPos0.xyz;
			   float dstInsideBox = rayBoxDst(boundsMin, boundsMax, position, 1 / dirToLight).y;

			   float stepSize = dstInsideBox / numStepsLight;
			   float totalDensity = 0;
			   for (int step = 0; step < numStepsLight; step++) {
				   position += dirToLight * stepSize;//marching towards light by stepSize
				   totalDensity += max(0, sampleDensity(position)*stepSize);//not sure the logic behind applying step size, may be to reduce density values
			   }
			   float transmittance = exp(-totalDensity *lightAbsorptionTowardSun);
			   return transmittance;
		   }

		   fixed4 frag(v2f i) : SV_Target
		   {
			   float3 rayPos = _WorldSpaceCameraPos;//initially the tip of ray is set at cameraPos, later it will be incremented
			   							//by stepSize inside the box, along rayDirection
			   float3 viewDirection = (i.viewVector) / length(i.viewVector);

			   float dstTravelled =0.2;

			   float2 boxDist = rayBoxDst(boundsMin, boundsMax, rayPos, 1 / viewDirection);
			   float dstToBox = boxDist.x;
			   float dstInsideBox = boxDist.y;

			   const float stepSize = 3;
			   float transmittance = 1;
			   float3 lightEnergy = 0;
			   float3 entryPoint = rayPos + viewDirection * dstToBox;//Const for a particular ray, the point at whic the ray meets box
			   

			   float cosAngle = dot(viewDirection, _WorldSpaceLightPos0.xyz);
			   float phaseVal = phase(cosAngle);

			   while (dstTravelled < dstInsideBox) {
				   rayPos = entryPoint + viewDirection * dstTravelled;
				   float density = sampleDensity(entryPoint);
				   if (density>0)
				   {
					   float lightTransmittance = lightMarch(rayPos);
					   lightEnergy += density */* stepSize **/ transmittance * lightTransmittance * phaseVal;
					   transmittance *= exp(-density* lightAbsorptionThroughCloud);

					   if (transmittance < 0.01) {
						   break;
					   }
				   }
				   dstTravelled += stepSize;
				}
			   float3 backgroundColor = tex2D(_MainTex, i.uv);
			   float3 cloudCol = lightEnergy /** _LightColor0*/;//_LightColor0 variable to tint color
			   float3 col = backgroundColor * transmittance + cloudCol;
			   ///*float3 */col = _cloudNoise.SampleLevel(sampler_cloudNoise, float3(i.uv.x, 0, i.uv.y), 0)*3;
			   return fixed4(col/2.0,0);
		   }
		   ENDCG
	   }
	}
}
