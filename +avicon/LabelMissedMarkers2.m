function [missedMarkers, markerTable] = LabelMissedMarkers2(vicon, subject, markerTable, minGapLengthThreshold, minDistThreshold)

getTrajectoryNames = @(x) {[x '_x'], [x '_y'], [x '_z']};
getDist = @(x,y) sqrt((x(:,1)-y(:,1)).^2 + (x(:,2)-y(:,2)).^2 + (x(:,3)-y(:,3)).^2);

if nargin < 3
    markerTable = GetMarkerTable(vicon, subject);
end

if nargin < 4
    minGapLengthThreshold = 1;
end

if nargin < 5
    minDistThreshold = 10;
end

% minDistThreshold = minDistThresholdSingle*outIdx;
gapCount = 0;
missedMarkers = {};
markerNames = vicon.GetMarkerNames(subject);

[startFrame, endFrame] = vicon.GetTrialRegionOfInterest();

fprintf("Labeling missed markers.\n");
for ii=1:vicon.GetUnlabeledCount()

    [x, y, z, e] = vicon.GetUnlabeled(ii);
    gapStartIdxArr = find(diff(e)>0)+1;
    gapEndIdxArr = find(diff(e)<0);
    
    if isempty(gapStartIdxArr) && isempty(gapEndIdxArr)
        gapStartIdxArr = startFrame;
        gapEndIdxArr = endFrame;
    end
    
    if ~isempty(gapEndIdxArr)
        if isempty(gapStartIdxArr) || gapEndIdxArr(1) < gapStartIdxArr(1)
            gapStartIdxArr = [1, gapStartIdxArr];
        end
    end
    
    if ~isempty(gapStartIdxArr)
        if isempty(gapEndIdxArr) || gapStartIdxArr(end) > gapEndIdxArr(end)
            gapLastFrame = find(e);
            gapEndIdxArr = [gapEndIdxArr, gapLastFrame(end)];
        end
    end

    % Quick fix, slow implementation
    % We need to check to see if unlabeleled trajectories are strung
    % together but violate the minDistThreshold
    correctedGapStartIdxArr = [];
    correctedGapEndIdxArr = [];
    for jj=1:length(gapStartIdxArr)
        gapStartIdx = gapStartIdxArr(jj);
        gapEndIdx = gapEndIdxArr(jj);
        gapLength = gapEndIdx - gapStartIdx + 1;

        if gapLength < 2
            correctedGapStartIdxArr = [correctedGapStartIdxArr, gapStartIdx];
            correctedGapEndIdxArr = [correctedGapEndIdxArr, gapEndIdx];
            continue; 
        end

        xTraj = x(gapStartIdx:gapEndIdx);
        yTraj = y(gapStartIdx:gapEndIdx);
        zTraj = z(gapStartIdx:gapEndIdx);
        dTraj = sqrt(diff(xTraj).^2 + diff(yTraj).^2 + diff(zTraj).^2);
        missedEndIdxArr = find(dTraj > minDistThreshold) + gapStartIdx - 1;

        correctedGapStartIdxArr = [correctedGapStartIdxArr, gapStartIdx];
        for kk=1:length(missedEndIdxArr)
            correctedGapStartIdxArr = [correctedGapStartIdxArr, missedEndIdxArr + 1];
            correctedGapEndIdxArr = [correctedGapEndIdxArr, missedEndIdxArr];
        end
        correctedGapEndIdxArr = [correctedGapEndIdxArr, gapEndIdx];
    end

    gapStartIdxArr = correctedGapStartIdxArr;
    gapEndIdxArr = correctedGapEndIdxArr;

    for jj=1:length(gapStartIdxArr)
        gapStartIdx = gapStartIdxArr(jj);
        gapEndIdx = gapEndIdxArr(jj);
        gapLength = gapEndIdx-gapStartIdx+1;

        if gapLength>5000
            gapCount = gapCount + 1;
            fprintf("Frame: %i-%i\n", gapStartIdx, gapEndIdx);
            continue;
        end

%         minStartDist = 99999;
%         minEndDist = 99999;
        minDist = 99999;
        minGapLength = minGapLengthThreshold;
        minMarker = '';
        for kk=1:length(markerNames)
            markerName = markerNames{kk};
            startDist = 99999;
            endDist = 99999;
            missingStart = false;
            missingEnd = false;
            
            % Check if the candidate label already exists during the unlabeled trajectory
            markerTraj = markerTable(gapStartIdx:gapEndIdx, getTrajectoryNames(markerName));
            eMarker = any(markerTraj{:,:},2);
            if any(eMarker); continue; end
            
            % If unlabeled trajectory starts on frame 1 then we can't check for labeled marker before
            if gapStartIdx == 1
                missingStart = true; 
            else
                % Otherwise, find the closest instance of the labeled marker to the first frame of the unlabeled trajectory
                markerTraj = markerTable(1:gapStartIdx-1, getTrajectoryNames(markerName));
                eMarker = any(markerTraj{:,:},2);
                lastFrame = find(eMarker);
                
                % If the labeled trajectory does not exist before the first frame of the unlabeled trajectory then continue to end-side checking
                if isempty(lastFrame)
                    missingStart = true;
                else
                    % Get the last frame of labeled trajectory data and compute distance and gap length to unlabeled trajectory
                    lastFrame = lastFrame(end);
                    markerTrajAtLastFrame = markerTable(lastFrame, getTrajectoryNames(markerName));
                    unlabeledTrajAtFirstFrame = [x(gapStartIdx), y(gapStartIdx), z(gapStartIdx)];
                    startDist = getDist(markerTrajAtLastFrame{:,:}, unlabeledTrajAtFirstFrame);
                    startGapLength = gapStartIdx-lastFrame;
                    startDist = startDist / startGapLength;
                end
            end
            
            % If unlabeled trajectory ends on last frame then we can't check for labeled marker after
            if gapEndIdx == height(markerTable)
                missingEnd = true;
            else
                % Otherwise, find the closest instance of the labeled marker to the last frame of the unlabeled trajectory
                markerTraj = markerTable(gapEndIdx+1:end, getTrajectoryNames(markerName));
                eMarker = any(markerTraj{:,:},2);
                firstFrame = find(eMarker, 1);
                
                % If the labeled trajectory does not exist after the last frame of the unlabeled trajectory then continue
                if isempty(firstFrame)
                    missingEnd = true;
                else
                    % Get the first frame of labeled trajectory data and compute distance and gap length to unlabeled trajectory
                    firstFrame = gapEndIdx + firstFrame;
                    markerTrajAtFirstFrame = markerTable(firstFrame, getTrajectoryNames(markerName));
                    unlabeledTrajAtLastFrame = [x(gapEndIdx), y(gapEndIdx), z(gapEndIdx)];
                    endDist = getDist(markerTrajAtFirstFrame{:,:}, unlabeledTrajAtLastFrame);
                    endGapLength = firstFrame - gapEndIdx;
                    endDist = endDist / endGapLength;
                end
            end
            
            % Check labeled marker based on start of unlabeled trajectory
            % First only check trajectories that qualify based on thresholds
            if startDist < minDistThreshold && startGapLength <= minGapLengthThreshold
                % Now check for best marker
                if (startGapLength < minGapLength) || (startGapLength == minGapLength && startDist < minDist)
                    % Criteria 1: Select new label if it qualifies and has lower gapLength than previous selected label
                    % Criteria 2: Select new label if it qualifies and has same gap length and lower dist than previous selected label
                    minDist = startDist;
                    minGapLength = startGapLength;
                    minMarker = markerName;
                end
            end
            
            % Check labeled marker based on end of unlabeled trajectory
            % First only check trajectories that qualify based on thresholds
            if endDist < minDistThreshold && endGapLength <= minGapLengthThreshold
                % Now check for best marker
                if (endGapLength < minGapLength) || (endGapLength == minGapLength && endDist < minDist)
                    % Criteria 1: Select new label if it qualifies and has lower gapLength than previous selected label
                    % Criteria 2: Select new label if it qualifies and has same gap length and lower dist than previous selected label
                    minDist = endDist;
                    minGapLength = endGapLength;
                    minMarker = markerName;
                end
            end
        end
        
        if minDist <= minDistThreshold && minGapLength <= minGapLengthThreshold
            markerName = minMarker;
            
            xMarker = markerTable.([markerName '_x']);
            yMarker = markerTable.([markerName '_y']);
            zMarker = markerTable.([markerName '_z']);
            eMarker = xMarker | yMarker | zMarker;

            xMarker(gapStartIdx:gapEndIdx) = x(gapStartIdx:gapEndIdx);
            yMarker(gapStartIdx:gapEndIdx) = y(gapStartIdx:gapEndIdx);
            zMarker(gapStartIdx:gapEndIdx) = z(gapStartIdx:gapEndIdx);
            eMarker(gapStartIdx:gapEndIdx) = 1;

            markerTable.([markerName '_x']) = xMarker;
            markerTable.([markerName '_y']) = yMarker;
            markerTable.([markerName '_z']) = zMarker;

            vicon.SetTrajectory(subject, markerName, xMarker, yMarker, zMarker, eMarker);
            missedMarkers{end+1} = markerName;
            
        else
            gapCount = gapCount + 1;
            fprintf("Frame: %i-%i\n", gapStartIdx, gapEndIdx);
        end
    end
end
missedMarkers = unique(missedMarkers);
end

