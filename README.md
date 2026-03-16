# Tight Junction Segmentation Pipeline for Blood-Brain Barrier Analysis
[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/drive/1oJCZdz_nOnk5cngrT1Jvl_kRdgeY15Ld?usp=sharing)

Associated paper: *Modeling the Blood-Brain Barrier: A Three-Dimensional Multicellular Microfluidic Approach with Bioinformatics*

---

## Pipeline Overview

```
folder_organize.ijm (organize z-stack for stitching in Fiji) 
       ↓
stitch_z_stack.ijm  (configure positions & channel in Fiji) 
       ↓
tj_network_analysis_pipeline.ipynb  (Google Colab)
       ↓
_tj_measurements.csv and segmentation overlay (output) 
```

---

## Requirements

**ImageJ / Fiji**
- Fiji with the Grid/Collection Stitching plugin (bundled by default)

**Google Colab**
- T4 GPU runtime recommended
- Dependencies installed automatically by the notebook:
  - `cellpose`
  - `scikit-image`
  - `matplotlib`
  - `pandas`

---

## Usage

### Step 1 — Organize raw images
Open `folder_organize.ijm` in Fiji and run it on your raw experiment folder.

Expected input filename format:
```
E5_01_4_1Z0_Confocal CY5_001.tif
```

Output structure:
```
ExperimentFolder/
  CY5/
    P1/
    P2/
    ...
  GFP/
    P1/
    ...
```

### Step 2 — Stitch z-stacks
Open `stitch_p#_.ijm` in Fiji, dependent on the number of positions (10/15). Edit the configuration block at the top to indicate the root directory of stored z-stack images:

```javascript
rootDir   = "path/to/experiment/folder/";

```

Run the script. You will be prompted to optionally trim slices from the stitched stack before saving.

**Outputs:**
- `Stitched_<channel>_3D.tif` — full stitched z-stack
- `Stitched_<channel>_3D_trimmed.tif` — trimmed version (if selected)
- `TileConfiguration_refined_<channel>.txt` — registered tile coordinates

### Step 3 — TJ network segmentation & quantification
Open `tj_network_analysis_pipeline.ipynb` in Google Colab with a T4 GPU runtime.

These parameters have been set as default and can be changed, if required:
```python
PIXEL_SCALE_UM        = 0.16   # microns per pixel (XY)
MIN_AREA_PX           = 100    # minimum object area (pixels)
BORDER_MARGIN_PX      = 50     # border exclusion margin (pixels)
Z_INDEX               = 0      # z-slice to use from 3D stack
NOISE_MAX_AREA_PX     = 300    # max area for noise removal
NOISE_MIN_CIRCULARITY = 0.80   # circularity threshold for noise removal
```

Upload your stitched `.tif` when prompted. The notebook will:
1. Segment TJ regions using [Cellpose](https://github.com/MouseLand/cellpose)
2. Filter by size, border proximity, and circularity
3. Display a 3-panel QC visualization
4. Export a segmentation overlay image
5. Download a CSV with per-object and summary statistics

**Outputs:**
- `<filename>_tj_pipeline_overview.tif` — 3-panel QC figure
- `<filename>_tj_area_overlay.tif` — final segmentation overlay
- `<filename>_tj_measurements.csv` — measurements (see below)

---

## CSV Output Format

**Summary block:**

| Column | Description |
|---|---|
| Total_Objects | Total TJ regions detected |
| Avg/Std_Area_Pixels | Mean and SD of region area in pixels |
| Avg/Std_Area_Microns2 | Mean and SD of region area in µm² |
| Avg_Circularity | Mean circularity (0–1; 1 = perfect circle) |
| Avg_Eccentricity | Mean eccentricity (0–1; 0 = circle) |
| PIXEL_SCALE_UM | Pixel scale used (µm/px) |
| Filter parameters | MIN_AREA_PX, BORDER_MARGIN_PX, NOISE_* |

**Per-object block:** Object_ID, Area_Pixels, Area_Microns2, Circularity, Eccentricity, Major_Axis_px, Minor_Axis_px, Centroid_Y, Centroid_X

---

## Notes

- Pseudocoloring in segmentation overlays denotes distinct segmented TJ regions and does not encode a quantitative value
- The stitching script uses Linear Blending fusion with subpixel accuracy and automatic overlap computation
- Cellpose diameter is set to `None` by default (auto-detect); adjust if segmentation quality is poor on your images
