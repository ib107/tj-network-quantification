# Installation & Setup

## Requirements Overview

| Component       | Version | Purpose                                      |
| --------------- | ------- | -------------------------------------------- |
| Python          | ≥ 3.8   | Segmentation & quantification                |
| Fiji (ImageJ)   | Latest  | Image organization, stitching, preprocessing |
| CUDA (optional) | ≥ 11.3  | GPU acceleration for Cellpose                |

---

## Fiji Setup

1. Download and install Fiji from https://fiji.sc

2. The **Grid/Collection Stitching** plugin is bundled by default

3. Place macro files:

   * `folder_organize.ijm`
   * `stitch_p10.ijm` / `stitch_p15.ijm`
   * `preprocess_single_image_stack_safe.ijm`

4. Open macros via:

   * `Plugins → Macros → Edit...`
   * or drag-and-drop into Fiji

---

## Python Setup — Google Colab (Recommended)

No local installation required.

1. Open the notebook from the README
2. Click `File → Save a copy in Drive`
3. Enable GPU:

   * `Runtime → Change runtime type → T4 GPU`
4. Run the **Installation and Imports** cell

---

## Python Setup — Local Installation

### Option A: Conda (Recommended for imaging workflows)

```bash
# Create environment
conda create -n bbb_py12 python=3.12
conda activate bbb_py12

# Install PyTorch (choose correct CUDA version)
# Example (CUDA 11.8):
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118

# Install remaining dependencies
pip install -r requirements.txt
```

---

### Option B: Virtual Environment (venv)

```bash
python -m venv venv

# Activate
venv\Scripts\activate       # Windows
source venv/bin/activate    # macOS/Linux

# Install dependencies
pip install -r requirements.txt
```

## Option C:  Conda Environment File (Reproducible Setup)

For exact reproduction of the development environment:

```bash
conda env create -f environment.yml
conda activate bbb_py12
```

### Launch the notebook

```bash 
jupyter notebook TJ_Quantification.ipynb
```

---

## Expected Inputs

### Raw Image Filenames

```
<PlateID>_<Position>_<Series>_<ZInfo>_Confocal <Channel>_<Frame>.tif
```

**Example:**

```
E5_01_4_1Z0_Confocal CY5_001.tif
```

| Field    | Example | Description          |
| -------- | ------- | -------------------- |
| PlateID  | E5      | Experiment ID        |
| Position | 01      | Tile position        |
| Series   | 4       | Acquisition series   |
| ZInfo    | 1Z0     | Z-slice index        |
| Channel  | CY5     | Fluorescence channel |
| Frame    | 001     | Frame number         |

---

### Folder Structure (after organization)

```
ExperimentFolder/
├── CY5/
│   ├── P1/
│   │   ├── Z0/
│   │   └── Z1/
│   └── P2/
├── GFP/
└── DAPI/
```

---

### Python Input

* Single `.tif` file (2D or 3D)
* Recommended: stitched CY5 channel
* Grayscale only (no RGB)
