
// Sorts images into: Channel / Position / Z-stack order
// Expected filename example: E5_01_4_1Z0_Confocal CY5_001.tif

dir = getDirectory("Choose experiment folder");
list = getFileList(dir);

setBatchMode(true);

for (i = 0; i < list.length; i++) {

    name = list[i];

    // Skip directories and non-image files
    if (File.isDirectory(dir + name)) continue;
    if (!(endsWith(name, ".tif") || endsWith(name, ".tiff"))) continue;

    // Split filename by underscores
    parts = split(name, "_");

    // Safety check
    if (parts.length < 5) {
        print("Skipping malformed filename: " + name);
        continue;
    }

    plate    = parts[0];       // E5
    position = parts[1];       // 01
    channel  = parts[4];       // CY5, DAPI, GFP, TRITC

    // Extract Z index (e.g. 1Z0 → Z0)
    zPart = parts[3];
    zIndex = substring(zPart, indexOf(zPart, "Z"));

    // Build output directories
    channelDir  = dir + channel + "/";
    positionDir = channelDir + "P" + position + "/";
    zDir        = positionDir + zIndex + "/";

    if (!File.exists(channelDir))  File.makeDirectory(channelDir);
    if (!File.exists(positionDir)) File.makeDirectory(positionDir);
    if (!File.exists(zDir))        File.makeDirectory(zDir);

    // Move file
    File.rename(dir + name, zDir + name);
}

setBatchMode(false);
print("Image organization complete.");
