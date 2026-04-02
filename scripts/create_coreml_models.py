#!/usr/bin/env python3
"""
Create CoreML models for Metal Quake using torch → coremltools pipeline.
Simpler approach: create .mlmodel files directly with the neural network builder.
"""

import coremltools as ct
from coremltools.models.neural_network import NeuralNetworkBuilder
from coremltools.models import datatypes

# ─── MQ_Denoiser: identity pass-through ────────────────────────────────────
print("Creating MQ_Denoiser...")

input_features = [("input", datatypes.Array(3, 200, 320))]
output_features = [("output", datatypes.Array(3, 200, 320))]

builder = NeuralNetworkBuilder(input_features, output_features)
# Identity: just add activation with linear (slope=1, intercept=0)
builder.add_activation("identity", "LINEAR", "input", "output",
                        params=[1.0, 0.0])

model = ct.models.MLModel(builder.spec)
model.save("MQ_Denoiser.mlmodel")
print("  Saved MQ_Denoiser.mlmodel")

# ─── MQ_RealESRGAN: 4x upscaler placeholder ───────────────────────────────
print("Creating MQ_RealESRGAN...")

input_features2 = [("input", datatypes.Array(3, 200, 320))]
output_features2 = [("output", datatypes.Array(3, 800, 1280))]

builder2 = NeuralNetworkBuilder(input_features2, output_features2)
# 4x upsample using bilinear interpolation
builder2.add_upsample("upsample4x", 4, 4, "input", "output",
                       mode="BILINEAR")

model2 = ct.models.MLModel(builder2.spec)
model2.save("MQ_RealESRGAN.mlmodel")
print("  Saved MQ_RealESRGAN.mlmodel")

print("\nNow compile:")
print("  xcrun coremlcompiler compile MQ_Denoiser.mlmodel .")
print("  xcrun coremlcompiler compile MQ_RealESRGAN.mlmodel .")
