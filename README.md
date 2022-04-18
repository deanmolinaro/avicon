# avicon
avicon - A Matlab Toolbox for Automatic Marker Labeling Using Vicon Nexus.

# Setup
1) This toolbox is added to your matlab path.
2) Add btk to matlab path (included in avicon.thirdparty but must be added to path separately).
3) C:\Program Files (x86)\Vicon\Nexus<version>\SDK\MATLAB is added to your matlab path (e.g., version = 2.12).
4) Your gap fill pipeline has been added to C:\Users\Public\Documents\Vicon\Nexus2.x\Configurations\Pipelines.

# Main/AutomaticViconProcessing.m
A script designed to do all the heavy lifting for you! Run this first before doing anything manually - other than the required setup steps below.

Checklist before running.
1) Process your static trial & run Autoinitialize in Nexus.
2) (Optional) Process your range of motion trial & run Functional Skeleton Calibration in Nexus.
3) Make sure a setup .xml file has been created and is in the vicon parent directory.
4) Vicon Nexus is open with the correct directory selected. 
5) A (small) trial is open in Nexus.

# Main/ManualViconProcessing.m
A script designed to make manual Vicon processing much easier. Run this after running Main/AutomaticViconProcessing to complete any trials that were not finished from the previous script.

Checklist before running.
1) AutoViconProcessing has completed.
2) Vicon Nexus is open with the correct directory selected. 
3) A (small) trial is open in Nexus.
4) The "Forward" option is selected in the Nexus Manual Labeling Section.

# Example
Example data of a subject walking up and down a ramp with a robotic hip exoskeleton. The gap filling pipeline can be found in Example/Pipelines.

# Suggested Workflow for Manual Processing 1
1) Select 0 to open a new trial.
2) Iteratively click "Find Next Unlabeled Trajectory" in Nexus.
	a) Either correctly label the trajectory or delete until none remain.
3) Select 2 to check for bad marker labels.
	a) Correct any incorrectly labeled markers flagged using this option. To unlabeled a marker, right click and use one of the "Unlabel Trajectory" options.
4) Repeat Step 3 until all bad labels are corrected.
5) Select 3 to run your gap filler.
6) Manually fill any remaining gaps.
7) Repeat Step 3 in case gap filling caused any bad trajectories.
8) Select 4 to export trial as finished.

# Suggested Workflow for Manual Processing 2 (Beta)
1) Select 0 to open a new trial.
2) Select 2 to check for bad marker labels.
	- Correct any incorrectly labeled markers flagged using this option. To unlabeled a marker, right click and use one of the "Unlabel Trajectory" options.
3) Repeat Step 2 until all bad labels are corrected.
4) Select 7 to run automated labeling based on gap filling trajectories.
	a) If "Bad labels remaining. Continue? (0=No, 1=Yes): " appears, correct any incorrectly labeled markers, then select 1.
	b) If "Please fill all gaps, then press enter." appears, manually fill remaining gaps in Nexus, then press enter.
	c) If "Missing marker(s) remaining in trial. Continue? (0=No, 1=Yes): " appears, select 1 to continue without the missing marker(s).
	d) If "Bad labels remaining after gap filling. Continue? (0=No, 1=Yes): " appeaks, select 1 to keep bad labels to fix them later or select 0 to reload the trial before selecting option 7.
5) Iteratively click "Find Next Unlabeled Trajectory" in Nexus.
	a) Either correctly label the trajectory or delete until none remain.
6) Repeat Steps 2-3.
7) Select 3 to run your gap filler.
8) Manually fill any remaining gaps.
9) Repeat Steps 2-3 in case gap filling caused any bad trajectories.
10) Select 4 to export trial as finished.