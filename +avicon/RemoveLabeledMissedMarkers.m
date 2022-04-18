function [] = RemoveLabeledMissedMarkers(vicon, subject, viconTrialPathC3D, startFrame, missedMarkers, markerTable, removeLengthOne)

if nargin < 6
    GetTrajectoryAtFrame = @(x,y,z) vicon.GetTrajectoryAtFrame(x, y, z);
else
    GetTrajectoryAtFrame = @(x,y,z) GetTrajectoryAtFrameFromTable(y, z, markerTable);
    GetTrajectoryOverSegment = @(x,y,z) GetTrajectoryOverSegmentFromTable(x, y, z, markerTable);
    markerNames = vicon.GetMarkerNames(subject);
end

if nargin < 7
    removeLengthOne = false;
end

%% Remove the corrected unlabeled trajectories using BTK
labelDistThreshold = 1;
c3dHandle = btkReadAcquisition(viconTrialPathC3D);
markerData = btkGetMarkersValues(c3dHandle);
markerResiduals = btkGetMarkersResiduals(c3dHandle);
meta = btkGetMetaData(c3dHandle);
labels = meta.children.POINT.children.LABELS.info.values;

unlabeledNames = labels(contains(labels, '*'));
for ii=1:length(unlabeledNames)
    markerIdx = str2double(erase(unlabeledNames{ii}, '*'))+1;
    x = markerData(:, markerIdx*3-2);
    y = markerData(:, markerIdx*3-1);
    z = markerData(:, markerIdx*3);

    markerStartIdxArr = find([diff(abs(x))>0; 0] & x==0)+1;
    markerEndIdxArr = find([0; diff(abs(x))<0] & x==0)-1;

    if isempty(markerEndIdxArr) % Unlabeled trajectory ends at endFrame
        markerEndIdxArr = [markerEndIdxArr; size(markerData, 1)];
    end
    if isempty(markerStartIdxArr) % Unlabeled trajectory starts at startFrame
        markerStartIdxArr = [1; markerStartIdxArr];
    end
    if markerStartIdxArr(end) > markerEndIdxArr(end) % Unlabeled trajectory ends at endFrame
        markerEndIdxArr = [markerEndIdxArr; size(markerData, 1)];
    end
    if markerEndIdxArr(1) < markerStartIdxArr(1) % Unlabeled trajectory starts at startFrame
        markerStartIdxArr = [1; markerStartIdxArr];
    end
    
    for jj=1:length(markerStartIdxArr)
        markerStartIdx = markerStartIdxArr(jj);
        markerEndIdx = markerEndIdxArr(jj);
        markerLength = markerEndIdx-markerStartIdx+1;
        removeMarker = false;

        for kk=1:length(missedMarkers)
            startCheck = false;
            endCheck = false;
            labelName = missedMarkers{kk};

            % Check start of labeled marker
%             [xLabel, yLabel, zLabel, eLabel] = vicon.GetTrajectoryAtFrame(subject, labelName, markerStartIdx+startFrame-1);
            [xLabel, yLabel, zLabel, eLabel] = GetTrajectoryAtFrame(subject, labelName, markerStartIdx+startFrame-1);
            if ~eLabel; continue; end
            dist = sqrt((x(markerStartIdx)-xLabel)^2 + (y(markerStartIdx)-yLabel)^2 + (z(markerStartIdx)-zLabel)^2);
            if dist < labelDistThreshold; startCheck = true; end

            % Check end of labeled marker
%             [xLabel, yLabel, zLabel, eLabel] = vicon.GetTrajectoryAtFrame(subject, labelName, markerEndIdx+startFrame-1);
            [xLabel, yLabel, zLabel, eLabel] = GetTrajectoryAtFrame(subject, labelName, markerEndIdx+startFrame-1);
            if ~eLabel; continue; end
            dist = sqrt((x(markerEndIdx)-xLabel)^2 + (y(markerEndIdx)-yLabel)^2 + (z(markerEndIdx)-zLabel)^2);
            if dist < labelDistThreshold; endCheck = true; end
            
            if startCheck && endCheck
                markerData(markerStartIdx:markerEndIdx, markerIdx*3-2:markerIdx*3) = 0.0;
                markerResiduals(markerStartIdx:markerEndIdx, markerIdx) = -1;
                removeMarker = true;
                break;
            end
        end
        
        % If we have the markerTable, then remove unlabeled marker if all
        % labels are assigned to markers for the entire unlabeled segment.
        labeledMarkerCount = 0;
        if ~removeMarker && nargin >= 6 % nargin>=6 is used b/c I don't have GetTrajectoryOverSegment() defined w/o markerTable
            for kk=1:length(markerNames)
                markerName = markerNames{kk};
                [~, ~, ~, e] = GetTrajectoryOverSegment(markerName, ...
                    markerStartIdx+startFrame-1, markerEndIdx+startFrame-1);
                if all(e)
                    labeledMarkerCount = labeledMarkerCount + 1;
                else
                    break;
                end
            end
            if labeledMarkerCount == length(markerNames)
                markerData(markerStartIdx:markerEndIdx, markerIdx*3-2:markerIdx*3) = 0.0;
                markerResiduals(markerStartIdx:markerEndIdx, markerIdx) = -1;
                removeMarker = true;
            end
        end
        
        % If the marker still isn't removed, just remove it if it is only
        % there for one frame.
        if removeLengthOne && ~removeMarker && markerLength == 1
            markerData(markerStartIdx:markerEndIdx, markerIdx*3-2:markerIdx*3) = 0.0;
            markerResiduals(markerStartIdx:markerEndIdx, markerIdx) = -1;
            removeMarker = true;
        end
    end
end

btkSetMarkersValues(c3dHandle, markerData);
btkSetMarkersResiduals(c3dHandle, markerResiduals);
btkWriteAcquisition(c3dHandle, viconTrialPathC3D);
btkCloseAcquisition(c3dHandle);
end


%% Helper function
function [x, y, z, e] = GetTrajectoryAtFrameFromTable(labelName, frame, markerTable)
    x = markerTable.([labelName '_x'])(frame);
    y = markerTable.([labelName '_y'])(frame);
    z = markerTable.([labelName '_z'])(frame);
    e = x | y | z;
end

function [x, y, z, e] = GetTrajectoryOverSegmentFromTable(labelName, startIdx, endIdx, markerTable)
    x = markerTable.([labelName '_x'])(startIdx:endIdx);
    y = markerTable.([labelName '_y'])(startIdx:endIdx);
    z = markerTable.([labelName '_z'])(startIdx:endIdx);
    e = x | y | z;
end