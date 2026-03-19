// ============================================
// CONFIGURATION
// ============================================
rootDir = " "
channel = "CY5";
positions = 10;
cols = 5;
approxOverlap = 0.08;   // coarse estimate only
outputDir = rootDir + "Channel_Only_" + channel + "\\";

// ============================================
// STEP 1 — Prepare output folder
// ============================================
File.makeDirectory(outputDir);
print("Output directory: " + outputDir);

// ============================================
// STEP 2 — Process each position (8-bit stacks)
// ============================================
tileWidth = 0;
tileHeight = 0;
for (p = 1; p <= positions; p++) {
    posDir = rootDir + channel + "\\P" + p + "\\";
    list = getFileList(posDir);
    if (list.length == 0) {
        print("No files in " + posDir);
        continue;
    }
    run("Image Sequence...", "open=[" + posDir + "] sort");
    if (p == 1) {
        tileWidth = getWidth();
        tileHeight = getHeight();
        print("Tile size: " + tileWidth + " x " + tileHeight);
    }
    run("8-bit");
    saveAs("Tiff", outputDir + "P" + p + "_" + channel + "_stack.tif");
    close();
}

// ============================================
// STEP 3 — Generate COARSE TileConfiguration
// ============================================
tileConfig = outputDir + "TileConfiguration.txt";
File.delete(tileConfig);
f = File.open(tileConfig);
print(f, "# Coarse grid + pixel refinement");
print(f, "dim = 3");
for (i = 0; i < positions; i++) {
    col = i % cols;
    row = floor(i / cols);
    x = col * tileWidth * (1 - approxOverlap);
    y = row * tileHeight * (1 - approxOverlap);
    fileName = "P" + (i + 1) + "_" + channel + "_stack.tif";
    print(f, fileName + ";0;(" + x + "," + y + ",0)");
}
File.close(f);
print("Coarse TileConfiguration written");

// ============================================
// STEP 4 — Robust pixel-based stitching
// ============================================
run("Grid/Collection stitching",
    "type=[Positions from file] " +
    "order=[Defined by TileConfiguration] " +
    "directory=[" + outputDir + "] " +
    "fusion_method=[Linear Blending] " +
    "compute_overlap " +
    "subpixel_accuracy " +
    "regression_threshold=0.30 " +
    "max/avg_displacement_threshold=2.50 " +
    "absolute_displacement_threshold=3.50 " +
    "image_output=[Fuse and display]");

// ============================================
// STEP 5 — Save outputs
// ============================================
if (nImages > 0) {
    saveAs("Tiff", outputDir + "Stitched_" + channel + "_3D.tif");
    print("Stitched image saved");
    if (File.exists(outputDir + "TileConfiguration.registered.txt")) {
        File.copy(
            outputDir + "TileConfiguration.registered.txt",
            outputDir + "TileConfiguration_refined_" + channel + ".txt"
        );
    }
}

// ============================================
// STEP 6 — Optional slice trimming
// ============================================
totalSlices = nSlices;
print("Total slices in stitched stack: " + totalSlices);

// Give the user time to scroll through the stack before the dialog appears
print("Review the stack now — trim dialog will appear in 30 seconds...");
for (i = 40; i > 0; i--) {
    if (i == 1) {
        showStatus("Trim dialog opening in 1 second — scroll the stack now!");
    } else {
        showStatus("Trim dialog opening in " + i + " seconds — scroll the stack now!");
    }
    wait(1000);
}

doTrim = getBoolean("Would you like to trim slices from the stitched stack?\n(Total slices: " + totalSlices + ")");

if (doTrim) {
    trimStart = getNumber("How many slices to remove from the BEGINNING?", 0);
    trimEnd   = getNumber("How many slices to remove from the END?", 0);

    firstKeep = 1 + trimStart;
    lastKeep  = totalSlices - trimEnd;

    if (firstKeep > lastKeep) {
        print("Invalid trim range — no slices would remain. Skipping trim.");
    } else if (trimStart == 0 && trimEnd == 0) {
        print("No slices trimmed.");
    } else {
        run("Make Substack...", "slices=" + firstKeep + "-" + lastKeep);
        trimmedTitle = "Stitched_" + channel + "_3D_trimmed.tif";
        saveAs("Tiff", outputDir + trimmedTitle);
        print("Trimmed stack saved (" + trimStart + " from start, " + trimEnd + " from end)");
        print("Kept slices " + firstKeep + " to " + lastKeep + " → " + (lastKeep - firstKeep + 1) + " slices total");
    }
}
