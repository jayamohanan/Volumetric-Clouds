using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Clouds : MonoBehaviour
{
    public Shader shader;
    [HideInInspector]
    public Material mat;
    NoiseGenerator noiseGenerator;
    [Range(0,1)]
    public float densityThreshold;
    public Vector3 offset;
    public Transform container;
    public Texture2D randomNoise;
    int change = 0;
    private void Awake()
    {
        Debug.Log("Jaaia");
    }

    void Start()
    {
        noiseGenerator = FindObjectOfType<NoiseGenerator>();
        
        mat = new Material(shader);
        SetShaderValues();

    }
    private void Update()
    {
        change = (change==0)?1:0;
        mat.SetInt("change", change);
    }
    void SetShaderValues()
    {
        mat.SetTexture("_RandomNoiseTex", randomNoise);
        mat.SetFloat("densityThreshold", densityThreshold);
        mat.SetVector("offset", offset);
        mat.SetVector("boundsMin", (container.position - container.localScale/2));
        Debug.Log("bounds min "+ (container.position - container.localScale / 2));
        mat.SetVector("boundsMax", (container.position + container.localScale/2));
        Debug.Log("bounds max " + (container.position + container.localScale / 2));
    }

    // Update is called once per frame
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, mat);
    }
}
