using Godot;
using System;

// Presentation-only numeric kernel. No world, nodes, events or mutable snapshots.
public partial class ArtBufferKernel : RefCounted
{
    private float[] _body = Array.Empty<float>();
    private float[] _weapon = Array.Empty<float>();

    // Nine doubles: x, y, cosine, deploy, enabled, flash, recoil x/y, sine.
    // Godot retains its trigonometry, Vector2 recoil rounding and exact AABB.
    public Godot.Collections.Array Fill(double[] input, int count, int capacity)
    {
        if (count < 0 || capacity < count || input.Length < count * 9)
            throw new ArgumentException("Invalid art buffer dimensions");
        if (_body.Length != capacity * 16)
        {
            _body = new float[capacity * 16];
            _weapon = new float[capacity * 16];
            for (int i = 0; i < capacity; i++)
            {
                int o = i * 16;
                for (int j = 8; j < 12; j++) _body[o + j] = _weapon[o + j] = 1;
                _body[o + 15] = _weapon[o + 15] = 1;
            }
        }
        for (int i = 0; i < count; i++)
        {
            int p = i * 9, o = i * 16;
            double c = input[p + 2], s = input[p + 8];
            double sx = 1.0 - input[p + 3] * 0.35, sy = 1.0 + input[p + 3] * 0.5;
            _body[o] = (float)c; _body[o + 1] = (float)-s;
            _body[o + 3] = (float)input[p]; _body[o + 4] = (float)s;
            _body[o + 5] = (float)c; _body[o + 7] = (float)input[p + 1];
            _weapon[o] = (float)(c * sx); _weapon[o + 1] = (float)(-s * sy);
            _weapon[o + 3] = (float)input[p + 6]; _weapon[o + 4] = (float)(s * sx);
            _weapon[o + 5] = (float)(c * sy); _weapon[o + 7] = (float)input[p + 7];
            _weapon[o + 11] = (float)input[p + 4];
            _body[o + 12] = _weapon[o + 12] = (float)input[p + 5];
            _body[o + 13] = _weapon[o + 13] = input[p + 4] == 0.0 ? 1 : 0;
        }
        return new Godot.Collections.Array { _body, _weapon };
    }
}
