function [missedMarkers, markerTable] = ReplaceGapFillWithUnlabeledMarkers2(vicon,subject,gapTable,varargin)
narginchk(3, 11);

p = inputParser;
addRequired(p, 'vicon');
addRequired(p, 'subject', @(x) ischar(x) || isstring(x));
addRequired(p, 'gapTable', @istable);
addParameter(p, 'MaxAllowableDist', 20, @isnumeric);
addParameter(p, 'Timeout', 600, @isnumeric);
addParameter(p, 'SaveTrial', true, @islogical);
addParameter(p, 'MarkerTable', table(), @istable);
addParameter(p, 'EnableSingleFrameMatching', true, @isboolean);

p.parse(vicon, subject, gapTable, varargin{:});
maxAllowableDist = p.Results.MaxAllowableDist;
timeout = p.Results.Timeout;
enableSingleFrameMatching = p.Results.EnableSingleFrameMatching;
saveTrial = p.Results.SaveTrial;
if saveTrial; avicon.SaveTrialRobust(vicon, timeout); end
markerTable = p.Results.MarkerTable;
if isempty(markerTable); markerTable = avicon.GetMarkerTable(vicon, subject); end

GetDist = @(x,y) sqrt(sum((x-y).^2, 2));

missedMarkers = {};

% c3dMarkerTable is relative to start frame but markerTable and gapTable
% are relative to frame 1 so just crop them to match c3dMarkerTable.
if isempty(gapTable)
    fprintf("No gaps in trial!\n");
    return;
end
[startFrame, endFrame] = vicon.GetTrialRegionOfInterest();
gapTable = gapTable(startFrame:endFrame, :);
markerTable = markerTable(startFrame:endFrame, :);

gapMarkerNames = gapTable.Properties.VariableNames;
markerNames = vicon.GetMarkerNames(subject);

[viconDir, viconTrialName] = vicon.GetTrialName();
viconTrialPath = [viconDir viconTrialName];
viconFileName = [viconTrialName '.c3d'];
viconFilePath = [viconDir viconFileName];

c3dHandle = btkReadAcquisition(viconFilePath);
markerData = btkGetMarkersValues(c3dHandle);
residuals = btkGetMarkersResiduals(c3dHandle);
labels = btkGetMetaData(c3dHandle, 'POINT', 'LABELS');
labels = labels.info.values;
labels = strrep(labels, '*', 'C_');
uLabels = labels(contains(labels, 'C_'));

c3dMarkerTable = array2table(markerData, 'VariableNames', avicon.lib.GetTrajectoryNames(labels));
markerResiduals = array2table(residuals, 'VariableNames', labels);

newDataTable = gapTable;
newDataTable{:,:} = 0;

% Find first and last frame where all markers are available since gap fill approach may not be valid outside of these frames.
gapFillStartIdx = 1;
gapFillEndIdx = height(c3dMarkerTable);
for ii=1:length(labels)
    if any(strcmp(labels{ii}, uLabels)); continue; end

    dataIdx = find(any(c3dMarkerTable{:, c3dMarkerTable.Properties.VariableNames(contains(c3dMarkerTable.Properties.VariableNames, labels{ii}))}, 2));

    if isempty(dataIdx)
        fprintf("Warning - %s is missing from trial.\n", labels{ii});
    else
        if dataIdx(1) > gapFillStartIdx
            gapFillStartIdx = dataIdx(1);
        end
        if dataIdx(end) < gapFillEndIdx
            gapFillEndIdx = dataIdx(end);
        end
    end
end

fprintf("Labeling unlabeled trajectories based on gap fill or removing them.\n");
for ii=1:length(uLabels)
    uLabel = uLabels{ii};
    uTraj = c3dMarkerTable{:, avicon.lib.GetTrajectoryNames({uLabel})};
    e = markerResiduals.(uLabel);
    
    dataStartIdxArr = find([0; diff(e~=-1)]>0);
    dataEndIdxArr = find([diff(e~=-1); 0]<0);

    if isempty(dataStartIdxArr)
        dataStartIdxArr = 1;
    end

    if isempty(dataEndIdxArr)
        dataEndIdxArr = length(e);
    end
    
    if dataEndIdxArr(1) < dataStartIdxArr(1)
        dataStartIdxArr = [1; dataStartIdxArr];
    end
    
    if dataStartIdxArr(end) > dataEndIdxArr(end)
        dataEndIdxArr = [dataEndIdxArr; length(e)];
    end
    
    for jj=1:length(dataStartIdxArr)
        dataStartIdx = dataStartIdxArr(jj);
        dataEndIdx = dataEndIdxArr(jj);
        dataLength = dataEndIdx - dataStartIdx + 1;
        if dataLength > 100
            fprintf("Warning - Unlabeled trajectory with length %i.\n", dataLength);
        end
        
        data = uTraj(dataStartIdx:dataEndIdx, :);
        minAvgDist = Inf;
        minSingleDist = Inf;
        
        for kk=1:length(gapMarkerNames)
            markerName = gapMarkerNames{kk};
            gapData = gapTable.(markerName)(dataStartIdx:dataEndIdx); % 1 if gap existed in original data, 0 if not.
            if any(gapData==0); continue; end % Only interested in checking if gap exists for entire unlabeleled trajectory. TODO: Check only section of unlabeled trajectory within gap frames if there is overlap.
            markerNameXYZ = avicon.lib.GetTrajectoryNames({markerName});
            markerData = markerTable{dataStartIdx:dataEndIdx, markerNameXYZ};
            meanDist = mean(GetDist(data, markerData));
            
            if meanDist < minAvgDist
                minAvgDist = meanDist;
                minAvgMarkerName = markerName;
                minAvgMarkerNameXYZ = markerNameXYZ;
            end
            
            if enableSingleFrameMatching
                sDist = GetDist(data(1, :), markerData(1, :));
                eDist = GetDist(data(end, :), markerData(end, :));
                singleDist = min(sDist, eDist);
                if singleDist < minSingleDist
                    minSingleDist = singleDist;
                    minSingleMarkerName = markerName;
                    minSingleMarkerNameXYZ = markerNameXYZ;
                end
            end
            
        end
        
        removeTraj = true;
        if minAvgDist < maxAllowableDist || (enableSingleFrameMatching && minSingleDist < maxAllowableDist / 4)
            if minAvgDist < maxAllowableDist
                minMarkerName = minAvgMarkerName;
                minMarkerNameXYZ = minAvgMarkerNameXYZ;
            elseif enableSingleFrameMatching && minSingleDist < maxAllowableDist / 4
                minMarkerName = minSingleMarkerName;
                minMarkerNameXYZ = minSingleMarkerNameXYZ;
            end
                
            gapData = gapTable.(minMarkerName);
            gapStart = find(gapData(1:dataStartIdx) == 0);
            if isempty(gapStart); gapStart = 0; end
            gapStart = gapStart(end) + 1;
            gapEnd = find(gapData(dataEndIdx:end) == 0, 1);
            if isempty(gapEnd); gapEnd = height(c3dMarkerTable) + 2; end
            gapEnd = gapEnd + dataEndIdx - 2; % 1 extra since actually searching for the first time the gap isn't there
            
            % Remove entire filled gap and replace with unlabeled trajectory.
            % Have to be careful to not overwrite previously added
            % unlabeled trajectories to this gap so use newDataTable to
            % track what has already been changed.
            markerDataSection = c3dMarkerTable{gapStart:gapEnd, minMarkerNameXYZ};
            markerResidualsSection = markerResiduals{gapStart:gapEnd, minMarkerName};
            newDataSection = newDataTable{gapStart:gapEnd, minMarkerName};
            
            markerDataSection(~newDataSection, :) = 0;
            markerResidualsSection(~newDataSection, :) = -1;
            
            sectionStart = dataStartIdx - gapStart + 1;
            sectionEnd = sectionStart + size(data, 1) - 1;
            
            markerDataSection(sectionStart:sectionEnd, :) = data;
            markerResidualsSection(sectionStart:sectionEnd, :) = 0;
            newDataSection(sectionStart:sectionEnd, :) = 1;
            
            c3dMarkerTable{gapStart:gapEnd, minMarkerNameXYZ} = markerDataSection;
            markerResiduals{gapStart:gapEnd, minMarkerName} = markerResidualsSection;
            newDataTable{gapStart:gapEnd, minMarkerName} = newDataSection;
            
            % See comment above why we can't just do this.
%             markerData{gapStart:gapEnd, minMarkerNameXYZ} = 0;
%             markerResiduals{gapStart:gapEnd, minMarkerName} = -1;
            
            missedMarkers{end+1} = minMarkerName;
%         elseif dataEndIdx < gapFillStartIdx || dataStartIdx > gapFillEndIdx % This would be better but current approach ignores trajectories that exist outside of existing labeled marker.
        elseif dataStartIdx < gapFillStartIdx || dataEndIdx > gapFillEndIdx
            removeTraj = false;
        end
        
        % Remove unlabeled trajectory.
        if removeTraj
            c3dMarkerTable{dataStartIdx:dataEndIdx, avicon.lib.GetTrajectoryNames({uLabel})} = 0;
            markerResiduals{dataStartIdx:dataEndIdx, uLabel} = -1;
        end
    end
end

btkSetMarkersValues(c3dHandle, c3dMarkerTable{:,:});
btkSetMarkersResiduals(c3dHandle, markerResiduals{:,:});

btkWriteAcquisition(c3dHandle, viconFilePath);
btkCloseAcquisition(c3dHandle);

avicon.OpenTrialRobust(vicon, viconTrialPath, timeout, 'SaveTrial', false);
markerTable = avicon.GetMarkerTable(vicon, subject); % TODO: Track markerTable through function instead of just updating at end (slow).
end

