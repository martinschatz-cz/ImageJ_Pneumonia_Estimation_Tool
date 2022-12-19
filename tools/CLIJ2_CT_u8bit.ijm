//	V 0.3clean
ver = "0.5C"
//  update: 17.11.2022
// by: Olga Rubesova
//based on work of : Martin Schätz
//
// CLIJ2 is used for the image processing, matematical and statistic operations

/////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////

print("\\Clear");
run("Close All");
print("Version: " + ver + ", last edit 17.11.2022");


print("ImageJ version: " + IJ.getFullVersion);
run("Bio-Formats Macro Extensions");
Ext.getVersionNumber(version)
print("Bio-formats version: " + version);


if (IJ.getFullVersion!="1.53t99") {
	print("WARNING! You are using untested ImageJ version");
	print("\n");
	print("This macro was created for:");
	print("ImageJ version: 1.53t99");
	print("Bio-formats version: 6.11.0");
}

//Open files
////////////////////////////
#@ File (label = "Input directory", style = "directory") input
//#@ File (label = "Output directory", style = "directory") output
#@ boolean(label = "TIF") bTiff
#@ boolean(label = "DICOM") bDICOM
#@ boolean(label = "Siemens DICOM") bSDICOM
#@ boolean(label = "Compressed Dicom") bCDICOM

if ((bTiff & bDICOM) | (bDICOM & bCDICOM) | (bCDICOM & bTiff)) {
	print("\\Clear");
	exit("Only one file type can be selected");
}

openSequenceFolder(input,bCDICOM,bDICOM,bTiff,bSDICOM);
// get image name
title=getTitle();
orig = "orig";
//////////////////////////
start=getTime();

setBatchMode("show");
// set window and level, with LUT, no pixel brightness change
run("Window/Level...");
waitForUser("Windwo/Level", "Please select Window/Level");
run("Apply LUT");

imgDir = input;
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
acTime="";
acTime = "" + year + "_" + month + "_" + dayOfMonth + "_" + hour + "_" + minute + "";
print(acTime);

dirArray=split(imgDir, File.separator());
dirName=dirArray[dirArray.length-1];

getDimensions(width, height, channels, slices, frames);

//select lung parts
waitForUser("Lung selection", "Please find start of lungs in stack");
start=getSliceNumber();
waitForUser("Lung selection", "Please find end of lungs in stack");
end=getSliceNumber();
setBatchMode(true);
print("Start of lungs: "+start);
print("End of lungs: "+end);
run("Duplicate...", "duplicate range="+start+"-"+end);
rename(orig);
selectImage(title);
close(title);
selectImage(orig);

// get voxel size
getVoxelSize(Vwidth, Vheight, Vdepth, Vunit);

// get iamge location
maskDir = imgDir+"masks_"+acTime+File.separator;
if (!File.exists(maskDir))
	File.makeDirectory(maskDir);
	
print("Image directory: "+imgDir);
saveAs("tiff",maskDir+replace(title,".tiff","")+"_lungs_subpart");
rename(orig);

// start CLIJJ Macro Extensions 
run("CLIJ2 Macro Extensions", "cl_device=");
Ext.CLIJ2_clear();

// push CT into GPU
Ext.CLIJ2_push(orig);
// apply median filter
Ext.CLIJ2_medianSliceBySliceSphere(orig, stack_filtered, 2, 2);
Ext.CLIJ2_pull(stack_filtered);
selectImage(stack_filtered);

// enhance contrast for better details
run("Enhance Contrast", "saturated=0.35");
stack_filtered = getTitle();
run("Apply LUT", stack_filtered);
orig=getTitle();

// duplicate stack for lung thresholding
run("Duplicate...", "duplicate");
rename("lungs");
lungs = "lungs";

// duplicate stack for covid thresholding
run("Duplicate...", "duplicate");
rename("covid");
covid = "covid";

//processing
/////////////////////////////////////////////////
selectImage(lungs);
run("Original Scale");

// set same voxel size
setVoxelSize(Vwidth, Vheight, Vdepth, Vunit);
run("8-bit");
run("Threshold...");
		setAutoThreshold("Default dark");
        getThreshold(lower,upper);
        setThreshold(0, lower);
setBatchMode("show");
waitForUser("Setup threshold for all but body");
setBatchMode("hide");
getThreshold(lowerLungs,upperLungs); 

// push the latest changes into CPU
lungs = getTitle();
Ext.CLIJ2_release(stack_filtered);
Ext.CLIJ2_push(lungs);

// get mask for all but body with CLIJ2
Ext.CLIJ2_threshold(lungs, threshold_lower, lowerLungs);
Ext.CLIJ2_threshold(lungs, threshold_upper, upperLungs);
Ext.CLIJ2_subtractImages(threshold_lower, threshold_upper, stack_filtered_threshold);

Ext.CLIJ2_release(threshold_upper);
Ext.CLIJ2_release(threshold_lower);

Ext.CLIJ2_pull(stack_filtered_threshold);
selectImage(stack_filtered_threshold);

setThreshold(lowerLungs, upperLungs);
run("Analyze Particles...", "size=800-Infinity pixel circularity=0.12-1.00 show=Masks display exclude clear add stack");

Ext.CLIJ2_dilateSphereSliceBySlice(stack_filtered_threshold, stack_dilated);
Ext.CLIJ2_dilateSphereSliceBySlice(stack_dilated, stack_dilated_2);
Ext.CLIJ2_binaryFillHoles(stack_dilated_2, stack_filled);
Ext.CLIJ2_erodeSphereSliceBySlice(stack_filled, stack_erode);
Ext.CLIJ2_erodeSphereSliceBySlice(stack_erode, stack_erode_2);
Ext.CLIJ2_invert(stack_erode_2, stack_inverted);

// release images from CPU
Ext.CLIJ2_release(stack_dilated);
Ext.CLIJ2_release(stack_dilated_2);
Ext.CLIJ2_release(stack_erode);
Ext.CLIJ2_release(stack_erode_2);

Ext.CLIJ2_pull(stack_inverted);
Ext.CLIJ2_release(stack_filtered_threshold);

selectImage(stack_inverted);

// save mask
saveAs("tiff",maskDir+replace(title,".tiff","")+"_lung_mask");
rename("mask_lungs");
mask_lungs=getTitle();
Ext.CLIJ2_release(stack_inverted);



/////////////////////////
selectImage(covid);
run("Original Scale");

// set same voxel size
setVoxelSize(Vwidth, Vheight, Vdepth, Vunit);
run("8-bit");
run("Threshold...");
		setAutoThreshold("Default dark");
        getThreshold(lower,upper);
setThreshold(38, 126);
setBatchMode("show");
waitForUser("Setup threshold for Covid");
setBatchMode("hide");
getThreshold(lowerCov,upperCov); 

// push the latest changes into CPU
covid = getTitle();
Ext.CLIJ2_push(covid);

// get mask for Covid with CLIJ2
Ext.CLIJ2_threshold(covid, threshold_lower, lowerCov);
Ext.CLIJ2_threshold(covid, threshold_upper, upperCov);
Ext.CLIJ2_subtractImages(threshold_lower, threshold_upper, stack_filtered_threshold);

Ext.CLIJ2_release(threshold_upper);
Ext.CLIJ2_release(threshold_lower);

Ext.CLIJ2_pull(stack_filtered_threshold);
selectImage(stack_filtered_threshold);

setBatchMode(true);

setThreshold(lowerCov, upperCov);
run("Analyze Particles...", "size=0-Infinity pixel circularity=0.00-1.00 show=Masks display exclude clear add stack");
Ext.CLIJ2_invert(stack_filtered_threshold, stack_inverted);

// get rid of small parts //needs to be optimised
Ext.CLIJ2_dilateSphereSliceBySlice(stack_inverted, stack_dilated);
Ext.CLIJ2_release(stack_inverted);

Ext.CLIJ2_dilateSphereSliceBySlice(stack_dilated, stack_dilated_2);
Ext.CLIJ2_release(stack_dilated);

Ext.CLIJ2_erodeSphereSliceBySlice(stack_dilated_2, stack_erode);
Ext.CLIJ2_release(stack_dilated_2);

Ext.CLIJ2_erodeSphereSliceBySlice(stack_erode, stack_erode_2);
Ext.CLIJ2_release(stack_erode);

// Invert
Ext.CLIJ2_invert(stack_erode_2, stack_inverted_erode);
Ext.CLIJ2_release(stack_erode_2);

Ext.CLIJ2_pull(stack_inverted_erode);
selectImage(stack_inverted_erode);
run("Invert LUT");

// save mask
saveAs("tiff",maskDir+replace(title,".tiff","")+"_covid_mask");
rename("mask_covid");
Ext.CLIJ2_release(stack_inverted_erode);
mask_covid=getTitle();

//////////////////////////////////
//get only information inside of lungs
selectImage(mask_lungs);
run("Original Scale");
selectImage(mask_covid);
setVoxelSize(Vwidth, Vheight, Vdepth, Vunit);
//imageCalculator("Multiply create stack", "mask_covid","mask_lungs");

Ext.CLIJ2_push(mask_covid);
Ext.CLIJ2_push(mask_lungs);
Ext.CLIJ2_multiplyImages(mask_covid,mask_lungs, mask_covid_final);
Ext.CLIJ2_invert(mask_covid_final, mask_covid_finale_invert);
Ext.CLIJ2_release(mask_covid_final);
setBatchMode("show");

Ext.CLIJ2_release(mask_covid);
// save mask
Ext.CLIJ2_pull(mask_covid_finale_invert);
selectImage(mask_covid_finale_invert);

saveAs("tiff",maskDir+replace(title,".tiff","")+"_mask_covid_finale");
run("Invert LUT");
mask_covid_finale_invert = getTitle();
selectImage(mask_covid_finale_invert);
//////////////////////////////////
//get covid area
print("lowerCov: "+ lowerCov +" upperCov: "+upperCov); 
setThreshold(lowerCov, upperCov);
run("Analyze Particles...", "pixel display exclude clear add stack");
CareaSum=0;
CIntInt=0;
print("Covid nResults: "+nResults);
for (i = 0; i < nResults; i++) {
	if (getResult("Area", i)>-1) {
		CareaSum=CareaSum+getResult("Area", i);
		CIntInt=CIntInt+getResult("RawIntDen", i);
		print("i: "+ i+" Area: "+getResult("Area", i)+" RawIntDen: "+getResult("RawIntDen", i));
	}
}
print("Covid area: " + CareaSum);
mask_covid_final = getTitle();

//////////////////////////////////
//get lungs area
selectImage(mask_lungs);
setThreshold(lowerLungs,upperLungs);
run("Analyze Particles...", "pixel display exclude clear add stack");
LareaSum=0;
LIntInt=0;
print("Lungs nResults: "+nResults);
for (i = 0; i < nResults; i++) {
	if (getResult("Area", i)>-1) {
		LareaSum=LareaSum+getResult("Area", i);
		LIntInt=LIntInt+getResult("RawIntDen", i);
	}
}
print("Lungs area: " + LareaSum);

selectImage(orig);
// if original data were 16 bit, we need to convert to 8-bit
run("8-bit");
run("Clear Results");

Ext.CLIJ2_pull(mask_lungs);
selectImage(mask_lungs);
run("8-bit");
run("Clear Results");

/*
Ext.CLIJ2_pull(mask_covid_finale_invert);
selectImage(mask_covid_finale_invert);
run("8-bit");
run("Clear Results");
*/

Ext.CLIJ2_pull(mask_covid_final);
selectImage(mask_covid_final);
run("8-bit");
run("Clear Results");


//make visualization
run("Merge Channels...", "c1="+orig+ " c2="+ mask_lungs + " c3="+ mask_covid_final+" create");
saveAs("tiff",maskDir+replace(title,".tiff","")+"_composite_results.tiff");

close("\\Others");
setBatchMode("exit and display");

/////////////////////////////////
print("Results: ");
print((CareaSum/LareaSum)*100);
print("Lung th:"+lowerLungs+", "+upperLungs);
print("Covid th:"+lowerCov+", "+upperCov);
percentage=(CareaSum/LareaSum)*100;
if (isNaN(percentage)) {
		percentage=0;
	}
if (percentage<0) {
		percentage=0;
	}
print("Voxel size, width: "+Vwidth+", height: "+Vheight+", depth: "+Vdepth+", units: "+Vunit);
print(title + " COVID percentage is: " + percentage);
print("A semi-quantitative CT score was calculated based on the extent oflobar involvement (0:0%; 1, < 5%; 2:5–25%; 3:26–50%; 4:51–75%; 5, > 75%; range 0–5");
print("Score is: " + doScore(percentage));

print("");
print("");


stop=getTime();
print("Time: " + (stop-start)/1000);
selectWindow("Log");
saveAs("Text", imgDir+replace(title,".tiff","")+"_log_"+acTime+".txt"); 

Ext.CLIJ2_clear();


////////////////////functions///////////////
//score function
function doScore(percentage) {
	if (isNaN(percentage)) {
		percentage=0;
	}
	
	helahtyLungPerc = (0.225+4.46+3.04)/3;
	percentage = percentage - helahtyLungPerc;
	if (percentage<0) {
		percentage=0;
	}
	
	if (percentage<5) {
		return 1;
	}
	if (percentage>5 && percentage<25) {
		return 2;
	}
	if (percentage>25 && percentage<50) {
		return 3;
	}
	if (percentage>50 && percentage<75) {
		return 4;
	} else {
		return 5;
	}
}

// opening specific version of file
function openSequenceFolder(input,bCDICOM,bDICOM,bTiff,bSDICOM) {
	list = getFileList(input);
	print("Opening: " + input+File.separator+list[0]);
	if (bCDICOM==true) {
		// open compressed DICOM with Bio-Formats Importer
		openCompressDICOMSequence(input+File.separator+list[0], list.length);
	} else {
			if (bDICOM==true) {
				// open DICOM
				openDICOMSequence(input+File.separator+list[0]);
			} else {
					// open TIFF
					if (bTiff==true) {
						openTiffSequence(input+File.separator+list[0]);
					} else { 
						if (bSDICOM==true) {
							openSiemensDICOM(input);
						} else {
						exit("No sequence type was selected");
						}
					}
				}
			}
			
	rename(list[0]);
}

function openCompressDICOMSequence(filePath, numImages){
	//run("Bio-Formats Importer", "open=I:/FNKV/dataset_paper2/patient_(13)/DICOM/21092312/34180000/66305440 color_mode=Grayscale group_files rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT dimensions axis_1_number_of_images=102");
	run("Bio-Formats Importer", "open=["+filePath+"] color_mode=Grayscale group_files rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT dimensions axis_1_number_of_images="+numImages);
	//run("Enhance Contrast", "saturated=0.35");
}
function openDICOMSequence(filePath){
	run("Bio-Formats Importer", "open=["+filePath+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
}

function openTiffSequence(filePath){
	run("Image Sequence...", "open=["+filePath+"] sort");
}

function openSiemensDICOM(input) {
	list = getFileList(input);
	//list = Array.sort(list);
	setBatchMode(true);
	for (i = 0; i < list.length; i++) {
		open(input + File.separator + list[i]);
	}
	title=getTitle();
	run("Images to Stack", "name="+title+" title=[] use");
	setBatchMode("show");
	setBatchMode(false);
}

/////////////LUT CHANGE////////////
//Can be be done with LUT, dont use
function updateWL(width, level) {
      min = level - width/2;
      max = level + width/2;
      setMinAndMax(min, max);
      showStatus("Window="+width+", Level="+level);
  }
  