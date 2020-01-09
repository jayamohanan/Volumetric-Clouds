using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(MeshRenderer))]
public class NoiseGenerator : MonoBehaviour
{
    [HideInInspector]
    public RenderTexture texture;
    public RenderTexture texture2D;
    public ComputeShader computeShader;
    public ComputeShader copy;
    public float densityThreshold = 0.4f;
    public float densityMultiplier = 1.07f;
    public float lightAbsorptionThroughCloud = 0.75f;
    public float lightAbsorptionTowardSun = 1.21f;
    Vector4 phaseParams = new Vector4(0.83f, 0.3f, 0.8f, 0.15f);
    //public Shader shader;
    private Texture3D tex3d;

    int resolution = 128;
    int noiseResolution = 5;
    const int numThreads = 8;
    int[] minMax;

    int threadGroupSize;
    Clouds clouds;

    float[] temp;

    private RenderTexture r2d;
    // Start is called before the first frame update
    void Start()
        
    {
        minMax = new int[] {int.MaxValue, 0 };
        temp = new float[resolution*resolution];
        clouds = FindObjectOfType<Clouds>();
        threadGroupSize = Mathf.CeilToInt(resolution / numThreads);

        RenderTexture tex = CreateTexture(texture, resolution);
        //RenderTexture tex2D = CreateTexture2D(texture2D, resolution);
        //CSMain
        Vector3[] cellData = CreateNoise(noiseResolution, new System.Random(5));
        CreateComputeBuffer(cellData, sizeof(float)*3, 0, "points");//applies data to a buffer and attaches it to compute buffer
        ComputeBuffer minMaxBuffer =  CreateComputeBuffer(minMax, sizeof(int), 0, "minMax");
        computeShader.SetTexture(0, "Result", tex);
        //Delete it
        //computeShader.SetTexture(0, "Result2D", tex2D);
        computeShader.SetInt("resolution", resolution);
        computeShader.SetInt("numCells", noiseResolution);
        computeShader.Dispatch(0, threadGroupSize, threadGroupSize, threadGroupSize);

        int[] arrays = new int[2];
        minMaxBuffer.GetData(arrays);
        bool csNormalize = false;
        if (csNormalize)
        {   
            CopyTexture(tex, ref tex3d, resolution);
            Debug.Log("Min= " + arrays[0] + " max = " + arrays[1]);
            //CSNormalize
            computeShader.SetBuffer(1, "minMax", minMaxBuffer);
            computeShader.SetTexture(1, "ResultA", tex);
            computeShader.SetTexture(1, "tempTex", tex3d);

            computeShader.Dispatch(1, threadGroupSize, threadGroupSize, threadGroupSize);
        }
        //now setting 2d texture to material, replace later

        //clouds.mat.SetTexture("_cloudNoise", tex);
        clouds.mat.SetTexture("_cloudNoise", tex);
        clouds.mat.SetFloat("densityThreshold", densityThreshold);

        clouds.mat.SetFloat("lightAbsorptionThroughCloud", lightAbsorptionThroughCloud);
        clouds.mat.SetFloat("lightAbsorptionTowardSun", lightAbsorptionTowardSun);
        clouds.mat.SetVector("phaseParams", phaseParams);
        clouds.mat.SetFloat("densityMultiplier", densityMultiplier);
    }

    ComputeBuffer CreateComputeBuffer(System.Array data, int stride, int kernelIndex, string destination)
    {
        ComputeBuffer buffer = new ComputeBuffer(data.Length, stride, ComputeBufferType.Structured);
        buffer.SetData(data);
        computeShader.SetBuffer(kernelIndex, destination, buffer);
        return buffer;
    }

    Vector3[] CreateNoise(int gridSize, System.Random prng)
    {
        Vector3[] points = new Vector3[gridSize*gridSize*gridSize];
        for (int k  = 0; k < gridSize; k++)
        {
            for (int j = 0; j < gridSize; j++)
            {
                for (int i = 0; i < gridSize; i++)
                {
                    Vector3 cell = new Vector3(i,j,k);
                    float pointX = (float)prng.NextDouble();
                    float pointY = (float)prng.NextDouble();
                    float pointZ = (float)prng.NextDouble();
                    points[i + (j+ k * gridSize) * gridSize] = new Vector3(i+pointX, j + pointY, k + pointZ)/gridSize;
                }
            }
        }//verified points array within [0,1]
        return points;
    }

    RenderTexture CreateTexture(RenderTexture texture, int resolution)
    {
        //var format = UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_UNorm;
        var format = UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_UNorm;
        if (texture == null)
        {
            texture = new RenderTexture(resolution, resolution, 0);
            texture.graphicsFormat = format;
            texture.volumeDepth = resolution;
            texture.enableRandomWrite = true;
            
            texture.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;

            texture.Create();
        }
        texture.wrapMode = TextureWrapMode.Repeat;
        texture.filterMode = FilterMode.Bilinear;
        //Create3DTexandCopyToTexture(texture, resolution);
        return texture;
    }
    //delete 2d render texture
    RenderTexture CreateTexture2D(RenderTexture texture, int resolution)
    {
        //var format = UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_UNorm;
        var format = UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_UNorm;
        if (texture == null)
        {
            texture = new RenderTexture(resolution, resolution, 0);
            texture.graphicsFormat = format;
            texture.enableRandomWrite = true;

            texture.dimension = UnityEngine.Rendering.TextureDimension.Tex2D;

            texture.Create();
        }
        texture.wrapMode = TextureWrapMode.Repeat;
        texture.filterMode = FilterMode.Bilinear;
        //Create3DTexandCopyToTexture(texture, resolution);
        return texture;
    }
    Texture3D CopyTexture(RenderTexture r,ref Texture3D tex3d, int resolution)
    {
        tex3d = new Texture3D(resolution, resolution, resolution, TextureFormat.ARGB32, false); ;

        copy.SetTexture(0, "Result", r);
        copy.SetTexture(0, "Source", tex3d);
        int numThreadGroups = Mathf.CeilToInt(resolution/8.0f);
        int[] test = new int[] { 1};
        ComputeBuffer copyBuffer = new ComputeBuffer(1, sizeof(int), ComputeBufferType.Structured);
        copyBuffer.SetData(test);
        copy.SetBuffer(0, "abc", copyBuffer);

        copy.Dispatch(0, numThreadGroups, numThreadGroups, numThreadGroups);
        int[] getArray = new int[1];
        copyBuffer.GetData(getArray);
        return tex3d;
    }
}
