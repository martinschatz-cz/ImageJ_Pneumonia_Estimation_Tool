//	V 0.1
ver = "0.1p"
//  update: 10.11.2022
//	by: Martin Schätz
//
// based on V 0.3clean 27.12.2021 Clean version
/////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////

/*
 * # General info
 */

print("\\Clear");
run("Close All");
print("Version: " + ver + ", last edit 10.11.2022");

print("ImageJ version: " + IJ.getFullVersion);
run("Bio-Formats Macro Extensions");
Ext.getVersionNumber(version)
print("Bio-formats version: " + version);


if (IJ.getFullVersion!="1.52v99") {
	print("WARNING! You are using untested ImageJ version");
	print("\n");
	print("This macro was created for:");
	print("ImageJ version: 1.52v99");
	print("Bio-formats version: 6.1.1");
}

//Open files
////////////////////////////
//#@ boolean(label = "MM protocol") MMp
MMp=false;
//#@ File (label = "Input directory", style = "directory") input
//input = "C:/Projekty/FNKV/reproducibility_test/CT2/CT2_DICOM";
input = "K:/FNKV/repeatability/data/CT4/CT4_DICOM";
//#@ File (label = "Output directory", style = "directory") output
//#@ boolean(label = "TIF u16-bit") bTiff
bTiff=true;
//#@ boolean(label = "DICOM u16-bit") bDICOM
//#@ boolean(label = "Siemens DICOM") bSDICOM
//#@ boolean(label = "Compressed Dicom") bCDICOM
bDICOM = false;
bSDICOM = false;
bCDICOM = false;

if ((bTiff & bDICOM) | (bDICOM & bCDICOM) | (bCDICOM & bTiff)) {
	print("\\Clear");
	exit("Only one file type can be selected");
}



times = newArray(0,0,0,0,0,0,0,0,0,0);



start=7; // starting stack
end=69; // starting stack
lowerLungs=0; // lungs lower threshold
upperLungs=99; // covid lower threshold
lowerCov=50; // pneumonia lower threshold
upperCov=108; // covid upper threshold

print("Pneumonia thr vs score");
print("thL,thU,Score,th_intDen");
for (lowerCov = 0; lowerCov < upperLungs; lowerCov=lowerCov+1) {
	for (upperCov = lowerCov; upperCov < upperLungs; upperCov=upperCov+1) {
	//for (upperCov = 118; upperCov < 119; upperCov++) {
openSequenceFolder(input,bCDICOM,bDICOM,bTiff,bSDICOM);

/*
 * # Processing
 */

// get image name
title=getTitle();
//////////////////////////


start_time=getTime();

setBatchMode("show");

imgDir = input;
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
acTime="";
acTime = "" + year + "_" + month + "_" + dayOfMonth + "_" + hour + "_" + minute + "";
//print(acTime);

dirArray=split(imgDir, File.separator());
dirName=dirArray[dirArray.length-1];

getDimensions(width, height, channels, slices, frames);

//print("Image path: "+replace(fileDir,title,""));
//select lung parts
/*waitForUser("Lung selection", "Please find start of lungs in stack");
start=getSliceNumber();
waitForUser("Lung selection", "Please find end of lungs in stack");
end=getSliceNumber();*/
setBatchMode(true);
//print("Start of lungs: "+start);
//print("End of lungs: "+end);
run("Duplicate...", "duplicate range="+start+"-"+end);
rename("orig");
selectImage(title);
close(title);
selectImage("orig");

// get voxel size
getVoxelSize(Vwidth, Vheight, Vdepth, Vunit);

// get iamge location
/*maskDir = imgDir+"masks_"+acTime+File.separator;
if (!File.exists(maskDir))
	File.makeDirectory(maskDir);*/
	
//print("Image directory: "+imgDir);
//saveAs("tiff",maskDir+replace(title,".tiff","")+"_lungs_subpart");
rename("orig");

// apply median filter
run("Median...", "radius=2 stack");
selectImage("orig");

// enhance contrast for better details
run("Enhance Contrast", "saturated=0.35");
run("Apply LUT", "stack");

// duplicate stack for lung thresholding
run("Duplicate...", "duplicate");
rename("lungs");

// duplicate stack for covid thresholding
run("Duplicate...", "duplicate");
rename("covid");

//processing
/////////////////////////////////////////////////
//setBatchMode(false);
selectImage("lungs");
run("Original Scale");

// set same voxel size
setVoxelSize(Vwidth, Vheight, Vdepth, Vunit);
run("8-bit");
run("Threshold...");
		setAutoThreshold("Default dark");
        getThreshold(lower,upper);
        setThreshold(0, lower);
setBatchMode("show");
//waitForUser("Setup threshold for all but body");
setBatchMode("hide");
setThreshold(lowerLungs,upperLungs);

run("Convert to Mask", "method=Default background=Light black");

run("Analyze Particles...", "size=800-Infinity pixel circularity=0.12-1.00 show=Masks display exclude clear add stack");

if (IJ.getFullVersion!="1.52v99") {
	run("Dilate", "stack");
	run("Dilate", "stack");
	run("Fill Holes", "stack");
	run("Erode", "stack");
	run("Erode", "stack");
	run("Invert", "stack");
	run("Convert to Mask", "method=Default background=Light black");
} else {
	run("Invert LUT");
	//run("Invert", "stack");
	run("Dilate", "stack");
	run("Dilate", "stack");
	run("Fill Holes", "stack");
	run("Erode", "stack");
	run("Erode", "stack");
	run("Invert", "stack");
	run("Convert to Mask", "method=Default background=Light black");
}

// save mask
//saveAs("tiff",maskDir+replace(title,".tiff","")+"_lung_mask");
rename("mask_lungs");
/////////////////////////
selectImage("covid");
run("Original Scale");

// set same voxel size
setVoxelSize(Vwidth, Vheight, Vdepth, Vunit);
run("8-bit");
run("Threshold...");
		setAutoThreshold("Default dark");
        getThreshold(lower,upper);

setThreshold(38, 126);
setBatchMode("show");
//waitForUser("Setup threshold for Covid");
setBatchMode("hide");
setThreshold(lowerCov,upperCov);
run("Convert to Mask", "method=Default background=Light black");
setBatchMode(true);
run("Analyze Particles...", "size=0-Infinity pixel circularity=0.00-1.00 show=Masks display exclude clear add stack");


// get rid of small parts //needs to be optimised
if (IJ.getFullVersion!="1.52v99") {
	run("Invert", "stack");
	run("Dilate", "stack");
	run("Dilate", "stack");
	run("Erode", "stack");
	run("Erode", "stack");
	
	//run("Invert", "stack");
	run("Invert", "stack");
	run("Invert LUT");

} else {
	run("Invert LUT");
	run("Erode", "stack");
	run("Erode", "stack");
	run("Dilate", "stack");
	run("Dilate", "stack");
	
	//run("Invert", "stack");
	//run("Invert", "stack");
	//run("Invert LUT");
}

// save mask
//saveAs("tiff",maskDir+replace(title,".tiff","")+"_covid_mask");
rename("mask_covid");
//////////////////////////////////
//get only information inside of lungs
selectImage("mask_lungs");
 
run("Original Scale");
selectImage("mask_covid");
setVoxelSize(Vwidth, Vheight, Vdepth, Vunit);
imageCalculator("Multiply create stack", "mask_covid","mask_lungs");
rename("mask_covid_final");
if (IJ.getFullVersion!="1.52v99") {
	run("Invert LUT");
}
//////////////////////////////////
//get covid area
selectImage("mask_covid_final");
run("Analyze Particles...", "pixel display exclude clear add stack");
CareaSum=0;
CIntInt=0;
for (i = 0; i < nResults; i++) {
	if (getResult("Area", i)>-1) {
		CareaSum=CareaSum+getResult("Area", i);
		CIntInt=CIntInt+getResult("RawIntDen", i);
	}
}
//print("Covid area: " + CareaSum);

//////////////////////////////////
//get lungs area
selectImage("mask_lungs");
run("Analyze Particles...", "pixel display exclude clear add stack");
LareaSum=0;
LIntInt=0;
for (i = 0; i < nResults; i++) {
	if (getResult("Area", i)>-1) {
		LareaSum=LareaSum+getResult("Area", i);
		LIntInt=LIntInt+getResult("RawIntDen", i);
	}
}
//print("Lungs area: " + LareaSum);

selectImage("orig");
// if original data were 16 bit, we need to convert to 8-bit
run("8-bit");
run("Clear Results");

//make visualization
run("Merge Channels...", "c1=orig c2=mask_lungs c3=mask_covid_final create");
//saveAs("tiff",maskDir+replace(title,".tiff","")+"_composite_results.tiff");

close("\\Others");
setBatchMode("exit and display");

/////////////////////////////////
//print("Results: ");
//print((CareaSum/LareaSum)*100);
//print("Lung th:"+lowerLungs+", "+upperLungs);
//print("Covid th:"+lowerCov+", "+upperCov);
percentage=(CareaSum/LareaSum)*100;
if (isNaN(percentage)) {
		percentage=0;
	}
if (percentage<0) {
		percentage=0;
	}
//print("Voxel size, width: "+Vwidth+", height: "+Vheight+", depth: "+Vdepth+", units: "+Vunit);
//print(title + " COVID percentage is: " + percentage);
//print("A semi-quantitative CT score was calculated based on the extent oflobar involvement (0:0%; 1, < 5%; 2:5–25%; 3:26–50%; 4:51–75%; 5, > 75%; range 0–5");
//print("Score is: " + doScore(percentage));


print(lowerCov + ", " + upperCov + ", " + doScore(percentage) + ", " + CIntInt);


//print("");
//print("");


stop_time=getTime();
//print(irun + ", Time: " + (stop_time-start_time)/1000);
selectWindow("Log");
//saveAs("Text", imgDir+replace(title,".tiff","")+"_log_"+acTime+".txt"); 
//times[irun]=(stop_time-start_time)/1000;
run("Close All");
}} //end for cycles for cov_thr

setBatchMode(false);

/*print("Times");
for (i=0; i<times.length; i++){
	print(times[i]);
}
*/
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
		return 0;
	}
	
	if (percentage>0 && percentage<5) {
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
	//print("Opening: " + input+File.separator+list[0]);
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
	run("Bio-Formats Importer", "open=["+filePath+"] color_mode=Grayscale group_files rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT dimensions axis_1_number_of_images="+numImages+" axis_1_axis_first_image=0 axis_1_axis_increment=1 contains=[] name="+filePath);
	run("Enhance Contrast", "saturated=0.35");
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