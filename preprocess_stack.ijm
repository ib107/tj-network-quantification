// Run with ONE image open in Fiji

outputSuffix = "_preprocessed";
overwrite = false;

// IMAGE INFO
origTitle = getTitle();
imageDir = getDirectory("image");

if (imageDir == "")
    exit("Image must be saved before running this macro.");

isStack = (nSlices > 1);

// DUPLICATE FULL IMAGE / STACK 
run("Duplicate...", "title=PROC duplicate");
selectWindow("PROC");

// PREPROCESSING
if (isStack)
    run("Subtract Background...", "rolling=15 stack");
else
    run("Subtract Background...", "rolling=15");

if (isStack)
    run("Median...", "radius=5 stack");
else
    run("Median...", "radius=5");

if (isStack)
    run("Gaussian Blur...", "sigma=2 stack");
else
    run("Gaussian Blur...", "sigma=2");

if (isStack)
    run("Enhance Contrast", "saturated=0.35 normalize stack");
else
    run("Enhance Contrast", "saturated=0.35 normalize");

// BUILD OUTPUT NAME 
dot = lastIndexOf(origTitle, ".");
base = substring(origTitle, 0, dot);
outName = base + outputSuffix + ".tif";

// SAVE ENTIRE STACK
selectWindow("PROC");

if (overwrite)
    saveAs("Tiff", imageDir + origTitle);
else
    saveAs("Tiff", imageDir + outName);

// LOG OUTPUT
if (isStack)
    print("Saved full stack: " + outName);
else
    print("Saved single image: " + outName);
