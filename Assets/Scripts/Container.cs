using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Container : MonoBehaviour
{
    public bool drawWireFrame = true;
    private void OnDrawGizmos()
    {
        //Color greenColor = Color.green;
        //greenColor.a = 0.35f;
        Gizmos.color = Color.green;
        if(drawWireFrame)
            Gizmos.DrawWireCube(transform.position, transform.localScale);
    }
}
