// ============================================
// CONFIGURATION
// ============================================
//rootDir = "E:\\Isha\\Ready to Stitch\\250331_161908_K14 20X PL FL Phase\\";  // Root folder
rootDir = "C:\\Users\\AlpaughLab\\Desktop\\Tool\\Data\\P15 Images\\250329_142249_B11 20X PL FL Phase\\"

channel = "GFP";                    // Channel to process
positions = 15;                      // Number of positions
cols = 5;                            // Columns in snake grid
overlap = 0.06;                      // Estimated overlap (6%)
outputSuffix = "_ChannelOnly";      // Output folder suffix

// ============================================
// STEP 1 — Prepare output folder
// ============================================
outputDir = rootDir + outputSuffix + channel + "\\";
File.makeDirectory(outputDir);
print("Output directory: " + outputDir);

tileWidth = 0;
tileHeight = 0;

// ============================================
// STEP 2 — Open each position, convert to 8-bit, save stack
// ============================================
for (p = 1; p <= positions; p++) {
    posName = "P" + p;
    posDir = rootDir + channel + "\\" + posName + "\\";
    list = getFileList(posDir);
    if (list.length == 0) {
        print("⚠️ No files found in " + posDir);
        continue;
    }

    run("Image Sequence...", "open=[" + posDir + "] sort");

    if (p == 1) {
        tileWidth = getWidth();
        tileHeight = getHeight();
        print("Tile size detected: " + tileWidth + " x " + tileHeight);
    }

    run("8-bit");

    tilePath = outputDir + "P" + p + "_" + channel + "_stack.tif";
    saveAs("Tiff", tilePath);
    close();
    print("✅ Saved 8-bit stack for position " + p);
}

// ============================================
// STEP 3 — Generate TileConfiguration.txt
// ============================================
tileConfig = outputDir + "TileConfiguration.txt";
File.delete(tileConfig);
f = File.open(tileConfig);

print(f, "# TileConfiguration for channel " + channel);
print(f, "# Format: image_filename; series_number; (x,y,z)");
print(f, "dim = 3");

for (i = 0; i < positions; i++) {
    x = (i % cols) * tileWidth * (1 - overlap);
    y = Math.floor(i / cols) * tileHeight * (1 - overlap);
    z = 0;
    fileName = "P" + (i + 1) + "_" + channel + "_stack.tif";
    print(f, fileName + ";0;(" + x + "," + y + "," + z + ")");
}

File.close(f);
print("✅ TileConfiguration.txt created at: " + tileConfig);

// ============================================
// STEP 4 — Run 3D stitching with automatic overlap
// ============================================
print("🔍 Starting 3D stitching for channel " + channel + "...");
run("Grid/Collection stitching",
    "type=[Positions from file] " +
    "order=[Defined by TileConfiguration] " +
    "directory=[" + outputDir + "] " +
    "fusion_method=[Linear Blending] " +
    "regression_threshold=0.30 " +
    "max/avg_displacement_threshold=2.50 " +
    "absolute_displacement_threshold=3.50 " +
    "compute_overlap " +
    "subpixel_accuracy " +
    "image_output=[Fuse and display]");

wait(5000);

// ============================================
// STEP 5 — Save stitched stack and refined config
// ============================================
if (nImages > 0) {
    stitchedPath = outputDir + "Stitched_" + channel + "_3D.tif";
    saveAs("Tiff", stitchedPath);
    print("✅ Stitched 3D image saved at: " + stitchedPath);

    srcConfig = outputDir + "TileConfiguration.registered.txt";
    dstConfig = outputDir + "TileConfiguration_refined_" + channel + ".txt";
    if (File.exists(srcConfig)) {
        File.copy(srcConfig, dstConfig);
        print("✅ Refined TileConfiguration saved at: " + dstConfig);
    } else {
        print("⚠️ No registered TileConfiguration found.");
    }
} else {
    print("⚠️ No stitched image open to save.");
}

print("🎉 Channel stitching completed!");

// ============================================
// STEP 6 — Optional slice trimming
// ============================================
totalSlices = nSlices;
print("Total slices in stitched stack: " + totalSlices);

print("⏳ Review the stack now — trim dialog will appear in 45 seconds...");
for (i = 45; i > 0; i--) {
    if (i == 1) {
        showStatus("Trim dialog opening in 1 second — scroll the stack now!");
    } else {
        showStatus("Trim dialog opening in " + i + " seconds — scroll the stack now!");
    }
    wait(1000);
}
showStatus("");

doTrim = getBoolean("Would you like to trim slices from the stitched stack?\n(Total slices: " + totalSlices + ")");

if (doTrim) {
    trimStart = getNumber("How many slices to remove from the BEGINNING?", 0);
    trimEnd   = getNumber("How many slices to remove from the END?", 0);

    firstKeep = 1 + trimStart;
    lastKeep  = totalSlices - trimEnd;

    if (firstKeep > lastKeep) {
        print("⚠️ Invalid trim range — no slices would remain. Skipping trim.");
    } else if (trimStart == 0 && trimEnd == 0) {
        print("ℹ️ No slices trimmed.");
    } else {
        run("Make Substack...", "slices=" + firstKeep + "-" + lastKeep);
        trimmedTitle = "Stitched_" + channel + "_3D_trimmed.tif";
        saveAs("Tiff", outputDir + trimmedTitle);
        print("✅ Trimmed stack saved (" + trimStart + " from start, " + trimEnd + " from end)");
        print("   Kept slices " + firstKeep + " to " + lastKeep + " → " + (lastKeep - firstKeep + 1) + " slices total");
    }
}