#!/usr/bin/env python3
"""
Build the CoreML models Metal Quake ships with.

These aren't trained Real-ESRGAN weights — a real super-resolution
network would require a full training pipeline (dataset, GPU hours,
validation loop) that lives outside this repo. What this script builds
are deterministic multi-layer convolutional networks whose weights are
hand-chosen to approximate the behavior we want:

  * MQ_Denoiser: 3×3 depthwise conv with soft-Gaussian weights, fed
    residually back into the input so the identity path dominates and
    only mild neighborhood smoothing leaks in. Mathematically legitimate
    (sums to 1, preserves flat patches), runs on the ANE at float16.

  * MQ_RealESRGAN: bilinear 4× upsample followed by a 3×3 depthwise
    unsharp-mask conv (center 3, 4-neighbour -0.5). Numerically
    equivalent to the MPSGraph fallback in MQ_CoreML.m — just runs
    through Apple Neural Engine instead of the GPU compute path.

When a user drops real trained weights into id1/MQ_RealESRGAN.mlmodelc
the MLModel loader in MQ_CoreML_Init picks them up in place of these.
"""

import coremltools as ct
from coremltools.models.neural_network import NeuralNetworkBuilder
from coremltools.models import datatypes
import numpy as np
import os
import shutil
import subprocess

IN_W, IN_H = 320, 240

# ─── MQ_Denoiser: 3×3 residual bilateral-flavor denoiser ───────────────────

print("Creating MQ_Denoiser (3×3 residual conv)...")

input_features  = [("input",  datatypes.Array(3, IN_H, IN_W))]
output_features = [("output", datatypes.Array(3, IN_H, IN_W))]
builder = NeuralNetworkBuilder(input_features, output_features)

# Soft-Gaussian 3×3. Positive-only weights so flat patches pass through.
k = np.array([
    [0.025, 0.1,   0.025],
    [0.1,   0.5,   0.1  ],
    [0.025, 0.1,   0.025],
], dtype=np.float32)
k /= k.sum()

# NeuralNetworkBuilder's add_convolution wants weights in
# (kH, kW, kernel_channels, output_channels) layout. For depthwise
# (groups==output_channels), kernel_channels is 1.
weights_denoise = np.zeros((3, 3, 1, 3), dtype=np.float32)
for c in range(3):
    weights_denoise[:, :, 0, c] = k

builder.add_convolution(
    name="denoiseConv1",
    kernel_channels=1, output_channels=3,
    height=3, width=3,
    stride_height=1, stride_width=1,
    border_mode="same", groups=3,
    W=weights_denoise, b=None, has_bias=False,
    input_name="input", output_name="d1",
)
# Residual: add conv output (weighted 0.5) + input (weighted 0.5) via
# two-input ADD with scaled identity. NeuralNetworkBuilder doesn't
# expose AVERAGE mode, so we scale each side to 0.5 via linear
# activation and ADD them.
builder.add_activation("inHalf", "LINEAR", "input", "inHalf",
                        params=[0.5, 0.0])
builder.add_activation("d1Half", "LINEAR", "d1",    "d1Half",
                        params=[0.5, 0.0])
builder.add_elementwise(
    name="residual",
    input_names=["inHalf", "d1Half"],
    output_name="output",
    mode="ADD",
)

model_denoise = ct.models.MLModel(builder.spec)
model_denoise.short_description = (
    "Metal Quake real-time denoiser — 3×3 bilateral-weighted residual"
)
model_denoise.author  = "Metal Quake engine"
model_denoise.license = "GPL-2.0 (engine) / user-provided (weights)"

denoiser_path = "MQ_Denoiser.mlmodel"
model_denoise.save(denoiser_path)
print(f"  saved {denoiser_path}")

# ─── MQ_RealESRGAN: bilinear 4× + depthwise 3×3 unsharp ────────────────────

print("Creating MQ_RealESRGAN (bilinear + sharpen)...")

OUT_W, OUT_H = IN_W * 4, IN_H * 4
in_features2  = [("input",  datatypes.Array(3, IN_H, IN_W))]
out_features2 = [("output", datatypes.Array(3, OUT_H, OUT_W))]
builder2 = NeuralNetworkBuilder(in_features2, out_features2)

builder2.add_upsample(
    name="bilinear4x",
    scaling_factor_h=4, scaling_factor_w=4,
    input_name="input", output_name="up",
    mode="BILINEAR",
)

sharp_k = np.array([
    [ 0.0, -0.5,  0.0],
    [-0.5,  3.0, -0.5],
    [ 0.0, -0.5,  0.0],
], dtype=np.float32)
weights_sharp = np.zeros((3, 3, 1, 3), dtype=np.float32)
for c in range(3):
    weights_sharp[:, :, 0, c] = sharp_k

builder2.add_convolution(
    name="sharpen",
    kernel_channels=1, output_channels=3,
    height=3, width=3,
    stride_height=1, stride_width=1,
    border_mode="same", groups=3,
    W=weights_sharp, b=None, has_bias=False,
    input_name="up", output_name="sharp",
)
# add_clip requires CoreML spec v4 (iOS 13+), which collides with the
# NeuralNetworkBuilder's default input shape mapping. Use a linear
# activation as a no-op — the uint8 conversion in MQ_CoreML.m saturates
# any out-of-range values back to [0, 255] anyway, so per-pixel clamp
# happens there.
builder2.add_activation(
    name="passthrough",
    non_linearity="LINEAR",
    input_name="sharp", output_name="output",
    params=[1.0, 0.0],
)

model_up = ct.models.MLModel(builder2.spec)
model_up.short_description = (
    "Metal Quake 4× upscaler — bilinear + unsharp depthwise conv"
)
model_up.author  = "Metal Quake engine"
model_up.license = "GPL-2.0 (engine) / user-provided (weights)"

esrgan_path = "MQ_RealESRGAN.mlmodel"
model_up.save(esrgan_path)
print(f"  saved {esrgan_path}")

# ─── Compile .mlmodel → .mlmodelc ──────────────────────────────────────────

print("\nCompiling to .mlmodelc bundles via xcrun coremlcompiler…")
for src in (denoiser_path, esrgan_path):
    out_dir = os.path.dirname(os.path.abspath(src)) or "."
    compiled = os.path.splitext(src)[0] + ".mlmodelc"
    if os.path.isdir(compiled):
        shutil.rmtree(compiled)
    subprocess.check_call([
        "xcrun", "coremlcompiler", "compile", src, out_dir
    ])
    print(f"  {compiled} ready")

print("\nDone. MQ_CoreML_Init picks these up via MLModel.modelWithContentsOfURL:.")
