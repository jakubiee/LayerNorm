![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# TinyTapeout LayerNorm

This project is a small hardware implementation of **Layer Normalization (LayerNorm)** built for **TinyTapeout**.

The design is intentionally simplified to fit within TinyTapeout's area and resource limits. LayerNorm is widely used in deep learning models to normalize values across features and help keep training stable.

The main goal here isn't to build the fastest or most optimized LayerNorm accelerator, but to learn how to take a hardware idea from RTL and simulation all the way to a real fabricated chip.