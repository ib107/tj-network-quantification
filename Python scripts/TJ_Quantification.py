# ============================================================
# Tight Junction (TJ) Segmentation from 3D BBB Confocal Images
# VS Code — Cellpose-based pipeline
# ============================================================
#
# USAGE:
#   python tj_segmentation.py --input path/to/image.tif
#   python tj_segmentation.py --input path/to/image.tif --output ./results
#
# INSTALL DEPENDENCIES:
#   pip install cellpose scikit-image matplotlib pandas torch
# ============================================================

# ── 0. IMPORTS ──────────────────────────────────────────────
import os
import argparse
import numpy as np
import torch
import matplotlib.pyplot as plt
import pandas as pd
from skimage import io, measure
from cellpose import models

# ── 1. CONFIGURATION ────────────────────────────────────────
PIXEL_SCALE_UM        = 0.16   # microns per pixel (XY)
MIN_AREA_PX           = 100    # minimum object area to keep (pixels)
BORDER_MARGIN_PX      = 50     # centroid must be at least this far from image edge
Z_INDEX               = 0      # which Z slice to use if image is 3D
CELLPOSE_DIAMETER     = None   # None = auto-detect cell diameter
NOISE_MAX_AREA_PX     = 300    # objects above this size are never removed by shape
NOISE_MIN_CIRCULARITY = 0.80   # circularity score (0–1); 1 = perfect circle


def run_pipeline(input_path: str, output_dir: str) -> None:
    """Run the full TJ segmentation pipeline on a single image."""

    os.makedirs(output_dir, exist_ok=True)

    # ── 2. LOAD IMAGE ───────────────────────────────────────
    filename = os.path.basename(input_path)
    base, _ = os.path.splitext(filename)

    img_stack = io.imread(input_path)
    print(f"Loaded: {filename}  |  shape: {img_stack.shape}  |  dtype: {img_stack.dtype}")

    if img_stack.ndim == 3:
        img = img_stack[Z_INDEX]
        print(f"Using Z slice {Z_INDEX}  →  shape: {img.shape}")
    elif img_stack.ndim == 2:
        img = img_stack
        print("2D image, using directly.")
    else:
        raise ValueError(f"Unexpected image dimensions: {img_stack.ndim}D. Expected 2D or 3D.")

    # ── 3. CELLPOSE SEGMENTATION ────────────────────────────
    USE_GPU = torch.cuda.is_available()
    print(f"GPU Available: {USE_GPU}" + (f"  ({torch.cuda.get_device_name(0)})" if USE_GPU else ""))

    model = models.CellposeModel(gpu=USE_GPU)
    masks, flows, styles = model.eval(img, diameter=CELLPOSE_DIAMETER, do_3D=False)
    n_raw = int(masks.max())
    print(f"Segmentation Complete — {n_raw} Objects Found.")

    # ── 4. FILTER 1: REMOVE SMALL OBJECTS ───────────────────
    mask_size = np.zeros_like(masks)

    for prop in measure.regionprops(masks):
        if prop.area >= MIN_AREA_PX:
            mask_size[masks == prop.label] = prop.label

    n_size = len(np.unique(mask_size)) - 1
    print(f"After Size Filter (≥{MIN_AREA_PX} px): {n_size} objects [{n_raw - n_size} removed]")

    # ── 5. FILTER 2: REMOVE BORDER-ADJACENT OBJECTS ─────────
    h, w = mask_size.shape
    mask_border = np.zeros_like(mask_size)

    for prop in measure.regionprops(mask_size):
        y, x = prop.centroid
        if min(y, x, h - y, w - x) >= BORDER_MARGIN_PX:
            mask_border[mask_size == prop.label] = prop.label

    n_border = len(np.unique(mask_border)) - 1
    print(f"After Border Filter (≥{BORDER_MARGIN_PX} px from edge): {n_border} objects [{n_size - n_border} removed]")

    # ── 6. FILTER 3: REMOVE SMALL CIRCULAR NOISE AREAS ──────
    mask_clean = np.zeros_like(mask_border)
    n_removed  = 0

    for prop in measure.regionprops(mask_border):
        circularity = (
            (4 * np.pi * prop.area) / (prop.perimeter ** 2)
            if prop.perimeter > 0 else 0
        )
        if prop.area < NOISE_MAX_AREA_PX and circularity > NOISE_MIN_CIRCULARITY:
            n_removed += 1
            continue
        mask_clean[mask_border == prop.label] = prop.label

    n_final = len(np.unique(mask_clean)) - 1
    print(f"After Noise Filter (area < {NOISE_MAX_AREA_PX} & circularity > {NOISE_MIN_CIRCULARITY}): {n_final} objects [{n_removed} removed]")
    print(f"\nTotal Removed across all filters: {n_raw - n_final} ({((n_raw - n_final)/n_raw*100):.1f}% difference)")

    # ── 7. MULTI-PANEL VISUALISATION ────────────────────────
    fig, axes = plt.subplots(1, 3, figsize=(18, 6))

    axes[0].imshow(img, cmap="gray")
    axes[0].imshow(masks, cmap="nipy_spectral", alpha=0.5)
    axes[0].set_title(f"1. Raw Segmentation\n{n_raw} objects", fontsize=12)
    axes[0].axis("off")

    axes[1].imshow(img, cmap="gray")
    axes[1].imshow(mask_border, cmap="nipy_spectral", alpha=0.5)
    axes[1].set_title(
        f"2. Size + Border Filtered\n{n_border} objects  "
        f"[−{n_raw - n_border} from raw]",
        fontsize=12
    )
    axes[1].axis("off")

    axes[2].imshow(img, cmap="gray")
    axes[2].imshow(mask_clean, cmap="nipy_spectral", alpha=0.5)
    axes[2].set_title(
        f"3. Noise Filtered \n{n_final} objects  "
        f"[−{n_raw - n_final} from raw  |  −{n_border - n_final} from filters]",
        fontsize=12
    )
    axes[2].axis("off")

    plt.suptitle(
        f"{filename}  |  Filters: min area={MIN_AREA_PX}px, border={BORDER_MARGIN_PX}px, "
        f"noise area<{NOISE_MAX_AREA_PX}px & circ>{NOISE_MIN_CIRCULARITY}",
        fontsize=9, y=1.01
    )
    plt.tight_layout()

    panel_path = os.path.join(output_dir, f"{base}_tj_pipeline_overview.tif")
    plt.savefig(panel_path, bbox_inches="tight", dpi=300)
    plt.show()
    print(f"Saved: {panel_path}")

    # ── 8. FINAL OVERLAY ────────────────────────────────────
    fig2, ax = plt.subplots(figsize=(8, 8))
    ax.imshow(img, cmap="gray")
    ax.imshow(mask_clean, cmap="nipy_spectral", alpha=0.5)
    ax.set_title(f"Segmentation Overlay ({n_final} objects)")
    ax.axis("off")
    plt.tight_layout()

    final_path = os.path.join(output_dir, f"{base}_tj_area_overlay.tif")
    plt.savefig(final_path, bbox_inches="tight", dpi=300)
    plt.show()
    print(f"Saved: {final_path}")

    # ── 9. MEASURE FINAL OBJECTS ─────────────────────────────
    pixel_area_um2 = PIXEL_SCALE_UM ** 2
    records = []

    for prop in measure.regionprops(mask_clean):
        circularity = (
            (4 * np.pi * prop.area) / (prop.perimeter ** 2)
            if prop.perimeter > 0 else 0
        )
        records.append({
            "Object_ID":      prop.label,
            "Area_Pixels":    prop.area,
            "Area_Microns2":  round(prop.area * pixel_area_um2, 4),
            "Circularity":    round(circularity, 4),
            "Eccentricity":   round(prop.eccentricity, 4),
            "Major_Axis_px":  round(prop.axis_major_length, 2),
            "Minor_Axis_px":  round(prop.axis_minor_length, 2),
            "Centroid_Y":     round(prop.centroid[0], 2),
            "Centroid_X":     round(prop.centroid[1], 2),
        })

    df = pd.DataFrame(records)

    print("\n── Final Object Statistics ──────────────────────────────")
    print(f"  Total TJ objects : {len(df)}")
    print(f"  Area  (px)       : {df['Area_Pixels'].mean():.1f} ± {df['Area_Pixels'].std():.1f}"
          f"  [{df['Area_Pixels'].min():.0f} – {df['Area_Pixels'].max():.0f}]")
    print(f"  Area  (µm²)      : {df['Area_Microns2'].mean():.2f} ± {df['Area_Microns2'].std():.2f}")
    print(f"  Circularity      : {df['Circularity'].mean():.3f} ± {df['Circularity'].std():.3f}")
    print(f"  Eccentricity     : {df['Eccentricity'].mean():.3f} ± {df['Eccentricity'].std():.3f}")

    # ── 10. EXPORT CSV ───────────────────────────────────────
    csv_path = os.path.join(output_dir, f"{base}_tj_measurements.csv")

    summary = pd.DataFrame([{
        "Total_Objects":          len(df),
        "Avg_Area_Pixels":        round(df["Area_Pixels"].mean(), 3),
        "Std_Area_Pixels":        round(df["Area_Pixels"].std(), 3),
        "Avg_Area_Microns2":      round(df["Area_Microns2"].mean(), 3),
        "Std_Area_Microns2":      round(df["Area_Microns2"].std(), 3),
        "Avg_Circularity":        round(df["Circularity"].mean(), 4),
        "Avg_Eccentricity":       round(df["Eccentricity"].mean(), 4),
        "PIXEL_SCALE_UM":         PIXEL_SCALE_UM,
        "MIN_AREA_PX":            MIN_AREA_PX,
        "BORDER_MARGIN_PX":       BORDER_MARGIN_PX,
        "NOISE_MAX_AREA_PX":      NOISE_MAX_AREA_PX,
        "NOISE_MIN_CIRCULARITY":  NOISE_MIN_CIRCULARITY,
    }])

    with open(csv_path, "w") as f:
        f.write("# SUMMARY\n")
    summary.to_csv(csv_path, mode="a", index=False)

    with open(csv_path, "a") as f:
        f.write("\n# PER-OBJECT DATA\n")
    df.to_csv(csv_path, mode="a", index=False)

    print(f"CSV saved: {csv_path}")
    print("\nPipeline complete. All outputs saved to:", output_dir)


# ── ENTRY POINT ─────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Tight Junction segmentation pipeline (Cellpose-based)"
    )
    parser.add_argument(
        "--input", "-i",
        required=True,
        help="Path to input image file (.tif, .png, etc.)"
    )
    parser.add_argument(
        "--output", "-o",
        default="./tj_results",
        help="Directory to save all outputs (default: ./tj_results)"
    )
    args = parser.parse_args()

    if not os.path.isfile(args.input):
        raise FileNotFoundError(f"Input file not found: {args.input}")

    run_pipeline(input_path=args.input, output_dir=args.output)