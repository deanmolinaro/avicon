% Checklist before running:
% 1) This toolbox is added to your matlab path.
% 2) Add btk to matlab path (included in avicon.thirdparty but must be added to path separately).
% 3) C:\Program Files (x86)\Vicon\Nexus<version>\SDK\MATLAB is added to your matlab path (e.g., version = 2.12).
% 4) Your gap fill pipeline has been added to C:\Users\Public\Documents\Vicon\Nexus2.x\Configurations\Pipelines.
% 5) Make sure a setup .xml file has been created and is in the vicon parent directory.
% 6) Vicon Nexus is open with the correct directory selected. 
% 7) A (small) trial is open in Nexus.

clear; clc;

%%
global timeout timeoutLong
timeout = 60;
timeoutLong = timeout*200;

vicon = ViconNexus();
[viconDir, ~] = vicon.GetTrialName();
viconDir = viconDir(1:end-1);
viconDirC3D = [viconDir '-C3D'];
viconDirC3D_temp = [viconDir '-C3D_unfinished'];
if ~exist(viconDirC3D, 'dir'); mkdir(viconDirC3D); end

try
    setupDir = [viconDir '\..'];
    [setupXml, setupFilePath] = avicon.lib.LoadSetupXml(setupDir);
    gapFiller = setupXml.gapFiller;
catch e
    PrintError(e);
    fprintf("Failed while parsing %s.\n", setupFilePath);    
%     subject = uigetfile([viconDir '\*.mp'], 'Please select subject file.\n');
%     subject = erase(subject, '.mp');
end

cmd = -1;
nextCmd = 0;
gapCheck = false;

while true
    try
        if nextCmd == cmd
            cmd = GetMenuInput();
        else
            cmd = nextCmd;
        end

        if cmd == 0
            [finishedFilePath, unfinishedFilePath] = SelectAndLoadTrial(vicon, setupXml);
            
            [~, viconTrialName] = vicon.GetTrialName();
            viconFileName = [viconTrialName '.c3d'];

            viconTrialPath = [viconDir '\' viconTrialName];
            viconFilePath = [viconDir '\' viconFileName];

            subject = GetSubjectFromTrialName(setupXml, viconTrialName);
            fprintf("Using %s as subject.\n", subject);
            
            staticFilePath = [viconDir '\' setupXml.(subject).static.trial '.c3d'];
            staticFrame = setupXml.(subject).static.frame;
            segmentMarkerStruct = avicon.lib.BuildSegmentMarkerStruct(vicon, subject, setupXml);

            fprintf("Updating marker table.\n");
            markerTable = avicon.GetMarkerTable(vicon, subject);

            gapCheck = false;
            nextCmd = cmd;

        elseif cmd == 1
            fprintf("Updating marker table.\n");
            markerTable = avicon.GetMarkerTable(vicon, subject);
            nextCmd = cmd;

        elseif cmd == 2
            fprintf("Updating marker table.\n\n");
            markerTable = avicon.GetMarkerTable(vicon, subject);

            badLabels = avicon.MarkerCheck2(vicon, subject, 'MaxAllowableDist', 50, 'MarkerTable', markerTable);
            if gapCheck && isempty(badLabels)
                fprintf("Gaps are filled and markers are correctly labeled!\n");
                nextCmd = 4;
            else
                nextCmd = cmd;
            end

        elseif cmd == 3
            unlabeledCount = vicon.GetUnlabeledCount();
            if vicon.GetUnlabeledCount() > 0
                fprintf("Unlabeled trajectories remaining. Please remove before gap filling.\n");
    %             fillGaps = input("Continue anyways? (y/n): ");
                fillGaps = 'n';
                fprintf("\n");
                nextCmd = cmd;
            else
                fillGaps = 'y';
            end

            if strcmpi(fillGaps, 'y')
                fprintf("Filling gaps.\n");
                markerTable = avicon.GapFillRobust(vicon, subject, gapFiller, 'MarkerTable', markerTable);

                % Check for remaining gaps.
                [startFrame, endFrame] = vicon.GetTrialRegionOfInterest();
                gapMarkers = avicon.GapCheck(vicon, subject, markerTable, startFrame, endFrame);
                if ~isempty(gapMarkers)
                    fprintf("Gaps still remaining.\n");
                    gapCheck = false;
                    nextCmd = cmd;
                else
                    fprintf("All gaps are filled! Running marker check.\n");
                    gapCheck = true;
                    nextCmd = 2;
                end
            end

        elseif cmd == 4
            if vicon.GetUnlabeledCount() > 0
                fprintf("Unlabeled trajectories remaining. Please remove before continuing.\n");
                response = input("Continue anyways? (y/n): ");
                fprintf("\n");
            else
                response = 'y';
            end
            
            if strcmpi(response, 'y')
                % If you made it this far than the trial is done!
                fprintf("Saving & exporting finished trial!\n");
                avicon.ExportTrialRobust(vicon, finishedFilePath, 'Timeout', timeoutLong);
                avicon.DeleteTrialRobust(viconFilePath, timeout);
                avicon.DeleteTrialRobust(unfinishedFilePath, timeout);
            end
            
            nextCmd = cmd;
            
        elseif cmd == 5
            fprintf("Saving & exporting unfinished trial!\n");
            avicon.ExportTrialRobust(vicon, unfinishedFilePath, 'Timeout', timeoutLong);
            avicon.DeleteTrialRobust(viconFilePath, timeout);
            nextCmd = cmd;
            
        elseif cmd == 6
            return;
            
        elseif cmd == 7
            fprintf("Checking unlabeled markers based on gap fill.\n");

            fprintf("Updating marker table.\n\n");
            markerTable = avicon.GetMarkerTable(vicon, subject);
            
            % First check for bad marker labels.
            badLabels = avicon.MarkerCheck2(vicon, subject, 'MaxAllowableDist', 50, 'MarkerTable', markerTable);
            if ~isempty(badLabels)
                response1 = input("Bad labels remaining. Continue? (0=No, 1=Yes): ");
                markerTable = avicon.GetMarkerTable(vicon, subject);
            else
                response1 = 1;
            end
            
            % Then fill gaps and make sure all of them are filled.
            response2 = 0;
            if response1 == 1
                tempDir = [viconDir '\temp'];
                tempFilePath = [tempDir '\' viconFileName];
                if ~exist(tempDir, 'dir'); mkdir(tempDir); end
                fprintf("Saving original version to %s.\n", tempFilePath);
                avicon.SaveTrialRobust(vicon, timeoutLong);
                copyfile(viconFilePath, tempFilePath);
                
                fprintf("Filling gaps.\n");
                [markerTable, gapTableOrig, gapTableFinal] = avicon.GapFillRobust(vicon, subject, gapFiller, 'Timeout', timeoutLong, 'MarkerTable', markerTable);
                missingMarkers = avicon.lib.GetMissingMarkersFromMarkerTable(markerTable);
                gapTableFinal(:, missingMarkers) = [];
                
                if ~isempty(gapTableFinal)
                    fprintf("Gaps remaining. Cannot continue.\n");
                    input("Please fill all gaps, then press enter. If you don't fill gaps here, trial will be reset to before gap filling.");
                    
                    markerTable = avicon.GetMarkerTable(vicon, subject);
                    [startFrame, endFrame] = vicon.GetTrialRegionOfInterest();
                    [~, gapTableFinal] = avicon.GapCheck(vicon, subject, markerTable, startFrame, endFrame);
                    gapTableFinal(:, missingMarkers) = [];
                    if ~isempty(gapTableFinal)
                        fprintf("Gaps still remaining. Loading original version.\n");
                        avicon.SaveTrialRobust(vicon, timeoutLong);
                        avicon.DeleteTrialRobust(viconFilePath, timeout);
                        avicon.MoveFileRobust(tempFilePath, viconFilePath, timeout);
                        avicon.OpenTrialRobust(vicon, viconTrialPath, timeoutLong, 'SaveTrial', false);
                        response2 = 0;
                    else
                        response2 = 1;
                    end
                else
                    response2 = 1;
                end
                
                if response2 == 1
                    % If there are any markers missing from entire trial, try to fill
                    % them.
                    missingMarkers = avicon.lib.GetMissingMarkersFromMarkerTable(markerTable);
                    if ~isempty(missingMarkers)
                        fprintf("Filling missing markers based on rigid bodies.\n");
                        [markerTable, missingMarkers, ~] = avicon.FillMissingMarkers(vicon, subject, staticFilePath, 'StaticFrame', staticFrame, 'MarkerTable', markerTable, 'SegmentMarkers', segmentMarkerStruct);
                        
                        if ~isempty(missingMarkers)
                            response2 = input("Missing marker(s) remaining in trial. Continue? (0=No, 1=Yes): ");
                        end
                    end
                    
                    if response2 == 0
                        fprintf("Missed markers still remaining. Loading original version.\n");
                        avicon.SaveTrialRobust(vicon, timeoutLong);
                        avicon.DeleteTrialRobust(viconFilePath, timeout);
                        avicon.MoveFileRobust(tempFilePath, viconFilePath, timeout);
                        avicon.OpenTrialRobust(vicon, viconTrialPath, timeoutLong, 'SaveTrial', false);
                    end
                end
            end
            
            % Then check again for bad labels after gap filling.
            response3 = 0;
            if response2 == 1
                badLabels = avicon.MarkerCheck2(vicon, subject, 'MaxAllowableDist', 50, 'MarkerTable', markerTable);
                if ~isempty(badLabels)
                    response3 = input("Bad labels remaining after gap filling.\nWarning: If you modify anything in Nexus during this prompt, tool may fail without erroring.\nContinue? (0=No, 1=Yes): ");
                else
                    response3 = 1;
                end
            end
            
            % Finally, replace gaps with unlabeled trajectories as needed.
            if response3 == 1
                if vicon.GetUnlabeledCount == 0
                    fprintf("No remaining unlabeled trajectories.\n");
                else
                    [missedMarkers, markerTable] = avicon.ReplaceGapFillWithUnlabeledMarkers2(vicon, subject, gapTableOrig, 'MarkerTable', markerTable);
                    
                    if vicon.GetUnlabeledCount > 0
                        avicon.RemoveFarUnlabeledTrajectories(vicon, subject, 'MarkerTable', markerTable);
                        markerTable = avicon.GetMarkerTable(vicon, subject);
                    end
                    
                    fprintf("Done!\n");
                end
            end
            nextCmd = cmd;
        end
    catch e
        PrintError(e)
        saveOpt = input("Would you like to save your progress (y\\n): ", 's');
        
        if strcmpi(saveOpt, 'y')
            fprintf("Saving unfinished trial!\n");
            avicon.ExportTrialRobust(vicon, unfinishedFilePath, 'Timeout', timeoutLong);
            avicon.DeleteTrialRobust(viconFilePath, timeout);
        end
        
        return;
    end
end



%% Helper Functions
function [cmd] = GetMenuInput()
    fprintf("\nPlease select command from the menu.\n");
    fprintf("0: Select new input file.\n");
    fprintf("1: (Deprecated) Update marker table.\n");
    fprintf("2: Run marker check.\n");
    fprintf("3: Fill gaps.\n");
    fprintf("4: Export finished file.\n");
    fprintf("5: Export unfinished file.\n");
    fprintf("6: Exit.\n");
    fprintf("7: (beta) Fill gaps to check unlabeled trajectories.\n");
    cmd = input("");
end

function [] = SaveTrial(vicon, inputPath, outputPath, timeout)
    vicon.SaveTrial(timeout);
    pause(0.1);
    copyfile(inputPath, outputPath);
    pause(0.1);
    delete(inputPath);
end

function [subject] = GetSubjectFromTrialName(setupXml, trialName)
subjectNames = fieldnames(setupXml);
for ii=1:length(subjectNames)
    if ~isfield(setupXml.(subjectNames{ii}), 'trials')
        continue;
    end
    subjectTrialNames = strsplit(setupXml.(subjectNames{ii}).trials);
    if any(strcmp(subjectTrialNames, trialName))
        subject = subjectNames{ii};
        break;
    end
end
end

function [] = PrintError(e)
fprintf("\n%s\n", e.identifier);
fprintf("%s\n", e.message);
fprintf("\nMatlab script crashed :(\n");
end

function [finishedFilePath, unfinishedFilePath] = SelectAndLoadTrial(vicon, setupXml)
global timeout timeoutLong

[viconDir, ~] = vicon.GetTrialName();
viconDir = viconDir(1:end-1);
finishedDir = [viconDir '-C3D'];
unfinishedDir = [viconDir '-C3D_unfinished'];

[unfinishedFileName, ~] = uigetfile([unfinishedDir '\*.c3d']);
outputTrialName = erase(unfinishedFileName, '.c3d');

segmentedTrialNames = fieldnames(setupXml.segmentedTrials);
if any(contains(outputTrialName, segmentedTrialNames))
    viconTrialName = strsplit(outputTrialName, '_');
    viconTrialName = strjoin(viconTrialName(1:end-1), '_');
else
    viconTrialName = outputTrialName;
end

viconFileName = [viconTrialName '.c3d'];
finishedFileName = unfinishedFileName;

viconTrialPath = [viconDir '\' viconTrialName];
viconFilePath = [viconDir '\' viconFileName];
finishedFilePath = [finishedDir '\' finishedFileName];
unfinishedFilePath = [unfinishedDir '\' unfinishedFileName];

avicon.SaveTrialRobust(vicon, timeoutLong);
avicon.CopyTrialRobust(unfinishedFilePath, viconFilePath, timeout);

fprintf("Opening %s\n", viconTrialName);
avicon.OpenTrialRobust(vicon, viconTrialPath, timeoutLong, 'SaveTrial', false);
end