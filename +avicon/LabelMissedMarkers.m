function [missedMarkers, markerTable] = LabelMissedMarkers(vicon, subject, markerTable, outIdx, minDistThresholdSingle)

if nargin < 3
    markerTable = GetMarkerTable(vicon, subject);
end

if nargin < 4
    outIdx = 1;
end

if nargin < 5
    minDistThresholdSingle = 10;
end

minDistThreshold = minDistThresholdSingle*outIdx;
gapCount = 0;
missedMarkers = {};
markerNames = vicon.GetMarkerNames(subject);

fprintf("Labeling missed markers.\n");
for ii=1:vicon.GetUnlabeledCount()

    [x, y, z, e] = vicon.GetUnlabeled(ii);
    gapStartIdxArr = find(diff(e)>0)+1;
    gapEndIdxArr = find(diff(e)<0);
    
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

    for jj=1:length(gapStartIdxArr)
        gapStartIdx = gapStartIdxArr(jj);
        gapEndIdx = gapEndIdxArr(jj);
        gapLength = gapEndIdx-gapStartIdx+1;

        if gapLength>5000
            gapCount = gapCount + 1;
            fprintf("Frame: %i-%i\n", gapStartIdx, gapEndIdx);
            continue;
        end

        minStartDist = 99999;
        minEndDist = 99999;
        minMarker = '';
        for kk=1:length(markerNames)
            markerName = markerNames{kk};
            startDist = 99999;
            endDist = 99999;
            missingStart = false;
            missingEnd = false;
            
            if gapStartIdx-outIdx+1 > 1 % Currently, if the unlabeled marker is first frame, I do not check if the labeled marker (markerName) already exists in frame 1 which could be a bug
                xMarker = markerTable.([markerName '_x'])(gapStartIdx);
                yMarker = markerTable.([markerName '_y'])(gapStartIdx);
                zMarker = markerTable.([markerName '_z'])(gapStartIdx);
                eMarker = xMarker | yMarker | zMarker; % Assume marker doesn't exist if it's location is zero for all components

                if eMarker; continue; end
                
                xMarker = markerTable.([markerName '_x'])(gapStartIdx-outIdx);
                yMarker = markerTable.([markerName '_y'])(gapStartIdx-outIdx);
                zMarker = markerTable.([markerName '_z'])(gapStartIdx-outIdx);
                eMarker = xMarker | yMarker | zMarker;

                if ~eMarker
                    missingStart = true;
                else
                    startDist = sqrt((xMarker-x(gapStartIdx))^2 + (yMarker-y(gapStartIdx))^2 + (zMarker-z(gapStartIdx))^2);
                end
            else
                missingStart = true;
            end
            
            if gapEndIdx+outIdx-1 < height(markerTable) % Currently, if the unlabeled marker is last frame, I do not check if the labeled marker (markerName) already exists in the last frame which could be a bug
                xMarker = markerTable.([markerName '_x'])(gapEndIdx);
                yMarker = markerTable.([markerName '_y'])(gapEndIdx);
                zMarker = markerTable.([markerName '_z'])(gapEndIdx);
                eMarker = xMarker | yMarker | zMarker; % Assume marker doesn't exist if it's location is zero for all components
                
                if eMarker; continue; end
                
                xMarker = markerTable.([markerName '_x'])(gapEndIdx+outIdx);
                yMarker = markerTable.([markerName '_y'])(gapEndIdx+outIdx);
                zMarker = markerTable.([markerName '_z'])(gapEndIdx+outIdx);
                eMarker = xMarker | yMarker | zMarker; % Assume marker doesn't exist if it's location is zero for all components
                
                if ~eMarker
                    missingEnd = true;
                else
                    endDist = sqrt((xMarker-x(gapEndIdx))^2 + (yMarker-y(gapEndIdx))^2 + (zMarker-z(gapEndIdx))^2);
                end
            else
                missingEnd = true;
            end
            
            if missingStart
                startDist = endDist;
            end
            if missingEnd
                endDist = startDist;
            end
            
            if startDist < minStartDist && endDist < minEndDist
                minStartDist = startDist;
                minEndDist = endDist;
                minMarker = markerName;
            end
        end
        
        if minStartDist < minDistThreshold && minEndDist < minDistThreshold
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

