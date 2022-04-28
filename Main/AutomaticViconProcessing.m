% Checklist before running:
% 1) This toolbox is added to your matlab path.
% 2) Add btk to matlab path (included in avicon.thirdparty but must be added to path separately).
% 3) C:\Program Files (x86)\Vicon\Nexus<version>\SDK\MATLAB is added to your matlab path (e.g., version = 2.12).
% 4) Your gap fill pipeline has been added to C:\Users\Public\Documents\Vicon\Nexus2.x\Configurations\Pipelines.
% 5) Make sure a setup .xml file has been created and is in the vicon parent directory.
% 6) Vicon Nexus is open with the correct directory selected. 
% 7) A (small) trial is open in Nexus.

% TODO
% 4) Comment code.
% 9) Consider using segmentMarkerStruct for rigid body labeling too.

% clear; clc;

timeout = 60;
timeoutLong = timeout*200;

vicon = ViconNexus();
[viconDir, ~] = vicon.GetTrialName();
viconDir = viconDir(1:end-1);

setupDir = [viconDir '\..'];
[setupXml, setupFilePath] = avicon.lib.LoadSetupXml(setupDir);

gapFiller = setupXml.gapFiller;
markerCheckOpts = GetMarkerCheckOptions(setupXml);
labelMissedMarkersOpts = GetLabelMissedMarkersOptions(setupXml);

finishedDir = [viconDir '-C3D'];
unfinishedDir = [viconDir '-C3D_unfinished'];
tempDir = [viconDir '\temp'];

if ~exist(finishedDir, 'dir'); mkdir(finishedDir); end
if ~exist(unfinishedDir, 'dir'); mkdir(unfinishedDir); end
if ~exist(tempDir, 'dir'); mkdir(tempDir); end

viconTrialNames = avicon.GetFileNames(viconDir, '.x1d');
viconTrialNames = erase(viconTrialNames, '.x1d');

% segmentedTrials = fieldnames(setupXml.segmentedTrials);
segmentedTrials = avicon.lib.GetFieldNamesRobust(setupXml, 'segmentedTrials');

for jj=1:length(viconTrialNames)
    % Get trial names and set up paths
    viconTrialName = viconTrialNames{jj};
    viconTrialPath = [viconDir '\' viconTrialName];
    viconFileName = [viconTrialName '.c3d'];
    viconFilePath = [viconDir '\' viconFileName];
    tempFilePath = [tempDir '\' viconFileName];
    fprintf("Processing %s.\n", viconTrialName);
    
    % This will skip all the trials that aren't segmented as needed.
    if exist([finishedDir '\' viconFileName], 'file') || exist([unfinishedDir '\' viconFileName], 'file')
        continue;
    end

    subject = GetSubjectFromTrialName(setupXml, viconTrialName);
    if isempty(subject)
        fprintf("Warning - Trial not in setup file. Skipping.\n");
        continue;
    end
    markerNames = vicon.GetMarkerNames(subject);
    fprintf("Using %s as subject.\n", subject);

    segmentMarkerStruct = BuildSegmentMarkerStruct(vicon, subject, setupXml);
    
    fprintf("Deleting history file.\n");
    avicon.DeleteTrialRobust([viconTrialPath '.history'], timeout);

    % Open trial to be processed
    [~, currTrialName] = vicon.GetTrialName();
    if ~strcmp(viconTrialName, currTrialName) || exist(viconFilePath, 'file') % If wrong trial is open or trial to be processed is already saved, then delete and reopen
        avicon.SaveTrialRobust(vicon, timeoutLong);
        avicon.DeleteTrialRobust(viconFilePath, timeout);
        avicon.OpenTrialRobust(vicon, viconTrialPath, timeoutLong, 'SaveTrial', false);
    end

    if any(strcmp(segmentedTrials, viconTrialName))
        fprintf("Segmenting trial based on force plates.\n");
        fpNames = strsplit(setupXml.segmentedTrials.(viconTrialName).fps);
        padding = setupXml.segmentedTrials.(viconTrialName).padding;
        segmentTable = avicon.GetTrialSegmentsFromForcePlates(vicon, fpNames, padding);
    else
        [startFrame, endFrame] = vicon.GetTrialRegionOfInterest();
        segmentTable = cell2table({startFrame, endFrame, 'N/A', 'N/A'}, 'VariableNames', {'startFrame', 'endFrame', 'startFP', 'endFP'});
    end

    for ii=1:height(segmentTable)
        if height(segmentTable) == 1
            finishedFilePath = [finishedDir '\' viconFileName];
            unfinishedFilePath = [unfinishedDir '\' viconFileName];
        else
            finishedFilePath = [finishedDir '\' viconTrialName '_' num2str(ii) '.c3d'];
            unfinishedFilePath = [unfinishedDir '\' viconTrialName '_' num2str(ii) '.c3d'];
        end

        % Check if trial has already been processed
        if exist(finishedFilePath, 'file') || exist(unfinishedFilePath, 'file')
            continue;
        end
        
        % If viconFilePath already exists, we need to delete and reopen to
        % preserve GRFs if segmenting trials.
        if exist(viconFilePath, 'file')
            avicon.SaveTrialRobust(vicon, timeoutLong);
            avicon.DeleteTrialRobust(viconFilePath, timeout);
            avicon.OpenTrialRobust(vicon, viconTrialPath, timeoutLong, 'SaveTrial', false);
        end

        startFrame = segmentTable.startFrame(ii);
        endFrame = segmentTable.endFrame(ii);
        vicon.SetTrialRegionOfInterest(startFrame, endFrame);

        % Make sure correct subject is active
        allSubjects = vicon.GetSubjectNames();
        for kk=1:length(allSubjects)
            s = allSubjects{kk};
            if strcmp(s, subject)
                vicon.SetSubjectActive(s, 1);
            else
                vicon.SetSubjectActive(s, 0);
            end
        end

        fprintf("Running Reconstruct & Label.\n");
        vicon.RunPipeline('Reconstruct and Label', '', timeoutLong);

        fprintf("Updating marker table.\n");
        markerTable = avicon.GetMarkerTable(vicon, subject);

        % Unlabel markers that are likely incorrect based on rigid bodies
        staticFilePath = [viconDir '\' setupXml.(subject).static.trial '.c3d'];
        staticFrame = setupXml.(subject).static.frame;
        avicon.SaveTrialRobust(vicon, timeoutLong);
        [markerTable, badLabels] = avicon.UnlabelUsingRigidBodies_offline(vicon, subject, staticFilePath, ...
            'StaticFrame', staticFrame, 'MarkerTable', markerTable, 'SegmentMarkers', segmentMarkerStruct);

        % Correct missed labels using trajectories and rigid bodies
        rigidBody = false;
        runStart = false;
        while true
            if rigidBody
                [missedMarkers, markerTable] = avicon.LabelMissedMarkersRigidBody2(vicon, subject, 'MarkerTable', markerTable, labelMissedMarkersOpts{:});
                rigidBody = false;
                runStart = true;
            else
                [missedMarkers, markerTable] = avicon.LabelMissedMarkers2(vicon, subject, 'MarkerTable', markerTable, labelMissedMarkersOpts{:});
                rigidBody = true;
            end

            if ~isempty(missedMarkers)
                avicon.SaveTrialRobust(vicon, timeoutLong);
                avicon.RemoveLabeledMissedMarkers(vicon, subject, viconFilePath, startFrame, ...
                    missedMarkers, markerTable);
                vicon.OpenTrial(viconTrialPath, timeoutLong);
            elseif runStart
                break;
            end
        end

        badLabels = avicon.MarkerCheck2(vicon, subject, 'MarkerTable', markerTable, markerCheckOpts{:});
        if ~isempty(badLabels)
            if vicon.GetUnlabeledCount > 0
                avicon.RemoveFarUnlabeledTrajectories(vicon, subject, 'MarkerTable', markerTable);
            end

            fprintf("Exporting as %s unfinished trial.\n", viconTrialName);
            avicon.ExportTrialRobust(vicon, unfinishedFilePath, 'Timeout', timeoutLong);
            continue;
        end

        % Before running gap fill, save the current trial to a temp directory
        % to use that if gap filling doesn't complete. This is easier to use in
        % post processing.
        fprintf("Saving to temp dir before gap filling.\n");
        avicon.SaveTrialRobust(vicon, timeoutLong);
        copyfile(viconFilePath, tempFilePath);
            
        % Run gap fill
        fprintf("Filling gaps.\n");
        [markerTable, gapTableOrig, gapTableFinal] = avicon.GapFillRobust(vicon, subject, gapFiller, 'Timeout', timeoutLong, 'MarkerTable', markerTable);
        
        missingMarkers = avicon.lib.GetMissingMarkersFromMarkerTable(markerTable);
        gapTableFinal(:, missingMarkers) = [];
        
        badLabels = avicon.MarkerCheck2(vicon, subject, 'MarkerTable', markerTable, markerCheckOpts{:});
        if ~isempty(badLabels) || ~isempty(gapTableFinal)
            fprintf("Reverting to trial before gap filling.\n");
            avicon.SaveTrialRobust(vicon, timeoutLong);
            avicon.DeleteTrialRobust(viconFilePath, timeoutLong);
            avicon.MoveFileRobust(tempFilePath, viconFilePath, timeout);
            avicon.OpenTrialRobust(vicon, viconTrialPath, timeoutLong, 'SaveTrial', false);

            if vicon.GetUnlabeledCount > 0
                avicon.RemoveFarUnlabeledTrajectories(vicon, subject, 'MarkerTable', markerTable);
            end

            fprintf("Exporting as %s unfinished trial.\n", viconTrialName);
            avicon.ExportTrialRobust(vicon, unfinishedFilePath, 'Timeout', timeoutLong);
            continue;
        end
        
        % If there are any markers missing from entire trial, try to fill
        % them at the start and end of trial for gap filling.
        % Note: This takes a really long time so only run it if we're sure
        % no other gaps or bad labels.
        missingMarkers = avicon.lib.GetMissingMarkersFromMarkerTable(markerTable);
        if ~isempty(missingMarkers)
            fprintf("Filling missing markers based on rigid bodies.\n");
            [markerTable, missingMarkers, ~] = avicon.FillMissingMarkers(vicon, subject, staticFilePath, 'StaticFrame', staticFrame, 'MarkerTable', markerTable, 'SegmentMarkers', segmentMarkerStruct);
            [~, gapTableFinal] = avicon.GapCheck(vicon, subject, markerTable, startFrame, endFrame);
        end
        
        badLabels = avicon.MarkerCheck2(vicon, subject, 'MarkerTable', markerTable, markerCheckOpts{:});
        if ~isempty(badLabels) || ~isempty(gapTableFinal) || ~isempty(missingMarkers) % Technically third argument is redundant to second argument.
            fprintf("Reverting to trial before gap filling and marker filling.\n");
            avicon.SaveTrialRobust(vicon, timeoutLong);
            avicon.DeleteTrialRobust(viconFilePath, timeoutLong);
            avicon.MoveFileRobust(tempFilePath, viconFilePath, timeout);
            avicon.OpenTrialRobust(vicon, viconTrialPath, timeoutLong, 'SaveTrial', false);

            if vicon.GetUnlabeledCount > 0
                avicon.RemoveFarUnlabeledTrajectories(vicon, subject, 'MarkerTable', markerTable);
            end

            fprintf("Exporting as %s unfinished trial.\n", viconTrialName);
            avicon.ExportTrialRobust(vicon, unfinishedFilePath, 'Timeout', timeoutLong);
            continue;
        end

        % Only do this if there are still unlabeled trajectories
        if vicon.GetUnlabeledCount == 0
            fprintf("Exporting as %s finished trial.\n", viconTrialName);
            avicon.ExportTrialRobust(vicon, finishedFilePath, 'Timeout', timeoutLong);
            continue;
        end

        % At this point, no bad labels and all gaps filled but unlabeled trajetories remaining.
        [missedMarkers, markerTable] = avicon.ReplaceGapFillWithUnlabeledMarkers2(vicon, subject, gapTableOrig, 'MarkerTable', markerTable);

        % It's possible that unlabeled trajectories start and end
        % outside of possible gap filled sections, in which case they are
        % not deleted.
        if vicon.GetUnlabeledCount > 0
            avicon.RemoveFarUnlabeledTrajectories(vicon, subject, 'MarkerTable', markerTable);
            markerTable = avicon.GetMarkerTable(vicon, subject);
        end

        if vicon.GetUnlabeledCount > 0
            fprintf("Exporting as %s unfinished trial.\n", viconTrialName);
            avicon.ExportTrialRobust(vicon, unfinishedFilePath, 'Timeout', timeoutLong);
            continue;
        end

        badLabels = avicon.MarkerCheck2(vicon, subject, 'MarkerTable', markerTable, markerCheckOpts{:});
        if ~isempty(badLabels)
            fprintf("Exporting as %s unfinished trial.\n", viconTrialName);
            avicon.ExportTrialRobust(vicon, unfinishedFilePath, 'Timeout', timeoutLong);
            continue;
        end

        % Run gap fill
        fprintf("Filling gaps.\n");
        [markerTable, gapTableOrig, gapTableFinal] = avicon.GapFillRobust(vicon, subject, gapFiller, 'Timeout', timeoutLong, 'MarkerTable', markerTable);
        if ~isempty(gapTableFinal)
            fprintf("Exporting as %s unfinished trial.\n", viconTrialName);
            avicon.ExportTrialRobust(vicon, unfinishedFilePath, 'Timeout', timeoutLong);
            continue;
        end

        badLabels = avicon.MarkerCheck2(vicon, subject, 'MarkerTable', markerTable, markerCheckOpts{:});
        if ~isempty(badLabels)
            fprintf("Exporting as %s unfinished trial.\n", viconTrialName);
            avicon.ExportTrialRobust(vicon, unfinishedFilePath, 'Timeout', timeoutLong);
            continue;
        end

        fprintf("Exporting as %s finished trial.\n", viconTrialName);
        avicon.ExportTrialRobust(vicon, finishedFilePath, 'Timeout', timeoutLong);
    end
end

%% Helper Functinos
function [subject] = GetSubjectFromTrialName(setupXml, trialName)
subject = '';
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

function [segmentMarkerStruct] = BuildSegmentMarkerStruct(vicon, subject, setupXml)
viconDir = vicon.GetTrialName();
vsk = avicon.thirdparty.xml_read([viconDir subject '.vsk']);
sticks = vsk.MarkerSet.Sticks;
segments = vicon.GetSegmentNames(subject);

segmentMarkerStruct = struct();
for ii=1:length(segments)
    segment = segments{ii};
    [~, ~, segmentMarkersOrig] = vicon.GetSegmentDetails(subject, segment);

    segmentMarkersAll = {};
    for jj=1:length(sticks.Stick)
        segmentMarker = sticks.Stick(jj).ATTRIBUTE.MARKER2;
        if any(contains(segmentMarkersOrig, segmentMarker))
            segmentMarkersAll{end+1} = sticks.Stick(jj).ATTRIBUTE.MARKER1;
        end
    end
    segmentMarkerStruct.(segment) = unique([segmentMarkersOrig segmentMarkersAll]);
end

if isfield(setupXml, 'rigidBodies')
%     specifiedSegments = fieldnames(setupXml.rigidBodies);
    specifiedSegments = avicon.lib.GetFieldNamesRobust(setupXml, 'rigidBodies');

    for ii=1:length(specifiedSegments)
        segment = specifiedSegments{ii};

        if ~any(strcmp(segments, segment))
            warning("%s not in subject model!", segment);
            continue;
        end

        if isfield(setupXml.rigidBodies.(segment), 'include')
            includes = setupXml.rigidBodies.(segment).include;
            if ~isempty(includes)
                includes = strsplit(includes);
            end

            for kk=1:length(includes)
                include = includes{kk};

                if any(strcmp(segmentMarkerStruct.(segment), include))
                    warning("%s already included in %s by default!", include, segment);
                else
                    segmentMarkerStruct.(segment){end+1} = include;
                end
            end
        end

        if isfield(setupXml.rigidBodies.(segment), 'ignore')
            ignores = setupXml.rigidBodies.(segment).ignore;
            if ~isempty(ignores)
                ignores = strsplit(ignores);
            end

            for kk=1:length(ignores)
                ignore = ignores{kk};

                if ~any(strcmp(segmentMarkerStruct.(segment), ignore))
                    warning("%s not in %s by default!", ignore, segment);
                else
                    segmentMarkerStruct.(segment)(strcmp(segmentMarkerStruct.(segment), ignore)) = [];
                end
            end
        end
    end
end
end

function [labelMissedMarkersOpts] = GetLabelMissedMarkersOptions(setupXml)
labelMissedMarkersOpts = GetDefaultLabelMissedMarkersOptions(setupXml);
if isfield(setupXml, 'labelMissedMarkers')
    specOpts = fieldnames(setupXml.labelMissedMarkers);
    for ii=1:length(specOpts)
        specOpt = specOpts{ii};
        val = setupXml.labelMissedMarkers.(specOpt);
        
        if isstring(val) || ischar(val)
            val  = strsplit(val);
        end
        
        % Make first letter capitilized for varargin formatting.
        specOpt(1) = upper(specOpt(1));
        
        labelMissedMarkersOpts = [labelMissedMarkersOpts, {specOpt, val}];
    end
end
end

function [labelMissedMarkersOpts] = GetDefaultLabelMissedMarkersOptions(setupXml)
labelMissedMarkersOpts = {};
specOpts = avicon.lib.GetFieldNamesRobust(setupXml, 'labelMissedMarkers');
if ~any(strcmp(specOpts, 'maxGapLengthThreshold')) || isempty(setupXml.labelMissedMarkers.maxGapLengthThreshold)
    labelMissedMarkersOpts = [labelMissedMarkersOpts, {'MaxGapLengthThreshold', 2}];
end
if ~any(strcmp(specOpts, 'maxDistThreshold')) || isempty(setupXml.labelMissedMarkers.maxDistThreshold)
    labelMissedMarkersOpts = [labelMissedMarkersOpts, {'MaxDistThreshold', 30}];
end
end

function [markerCheckOpts] = GetMarkerCheckOptions(setupXml)
markerCheckOpts = GetDefaultMarkerCheckOptions(setupXml);
if isfield(setupXml, 'markerCheck')
    specOpts = fieldnames(setupXml.markerCheck);
    for ii=1:length(specOpts)
        specOpt = specOpts{ii};
        val = setupXml.markerCheck.(specOpt);
        
        if strcmp(specOpt, 'modMinDistNames')
            val = GetModMinDistNames(val);
        else
            if isstring(val) || ischar(val)
                val  = strsplit(val);
            end
        end
        
        % Make first letter capitilized for varargin formatting.
        specOpt(1) = upper(specOpt(1));
        
        markerCheckOpts = [markerCheckOpts, {specOpt, val}];
    end
end
end

function [markerCheckOpts] = GetDefaultMarkerCheckOptions(setupXml)
markerCheckOpts = {};
specOpts = avicon.lib.GetFieldNamesRobust(setupXml, 'markerCheck');
if ~any(strcmp(specOpts, 'maxAllowableDist')) || isempty(setupXml.markerCheck.maxAllowableDist)
    markerCheckOpts = [markerCheckOpts, {'MaxAllowableDist', 50}];
end
end

function [modMinDistNames] = GetModMinDistNames(val)
modMinDistNames = {};

if ~isfield(val, 'pair')
    return
end

if ~iscell(val.pair)
    modMinDistNames = {strsplit(val.pair)};
    return
end

for ii=1:length(val.pair)
    modMinDistNames = [modMinDistNames, {strsplit(val.pair{ii})}];
end

end



