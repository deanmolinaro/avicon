function [missedMarkers, markerTable] = LabelMissedMarkersRigidBody2(vicon, subject, markerTable)

getTrajectoryNames = @(x) {[x '_x'], [x '_y'], [x '_z']};
getDist = @(x,y) sqrt((x(:,1)-y(:,1)).^2 + (x(:,2)-y(:,2)).^2 + (x(:,3)-y(:,3)).^2);

syms xU yU zU real

if nargin < 3
    markerTable = GetMarkerTable(vicon, subject);
end

minDistThreshold = 20;

gapCount = 0;
missedMarkers = {};
markerNames = vicon.GetMarkerNames(subject);

[startFrame, endFrame] = vicon.GetTrialRegionOfInterest();

rigidBodies = vicon.GetSegmentNames(subject);

fprintf("Labeling missed markers from rigid bodies.\n");
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

        minDist = 99999;
        minMarker = '';
        for kk=1:length(markerNames)
            markerName = markerNames{kk};
            
            % Check if the label already exists during the unlabeled trajectory
            xMarker = markerTable.([markerName '_x'])(gapStartIdx:gapEndIdx);
            yMarker = markerTable.([markerName '_y'])(gapStartIdx:gapEndIdx);
            zMarker = markerTable.([markerName '_z'])(gapStartIdx:gapEndIdx);
            eMarker = xMarker | yMarker | zMarker; % Assume marker doesn't exist if it's location is zero for all components
            if any(eMarker); continue; end
            
            % Check if label exists at all in trial (otherwise we can't create the rigid body
            xMarker = markerTable.([markerName '_x'])(startFrame:endFrame);
            yMarker = markerTable.([markerName '_y'])(startFrame:endFrame);
            zMarker = markerTable.([markerName '_z'])(startFrame:endFrame);
            eMarker = xMarker | yMarker | zMarker; % Assume marker doesn't exist if it's location is zero for all components
            if ~any(eMarker); continue; end
            
            for mm=1:length(rigidBodies)
%                 bodyMarkers = rigidBodies{mm};
                [~, ~, bodyMarkers] = vicon.GetSegmentDetails(subject, rigidBodies{mm});
                if ~any(strcmp(bodyMarkers, markerName)); continue; end
                
                % Find where >=3 rigid body markers exist to locate expected marker
                eTable = table();
                for nn=1:length(bodyMarkers)
                    bodyMarker = bodyMarkers{nn};
                    markerTraj = markerTable(gapStartIdx:gapEndIdx, getTrajectoryNames(bodyMarker));
                    eTable = [eTable, array2table(logical(any(markerTraj{:,:},2)), 'VariableNames', {bodyMarker})];
                end
                rigidBodyExistIdx = find(sum(eTable{:,:},2)>=3, 1); % For now, just use first frame where rigid body exists
                if isempty(rigidBodyExistIdx); continue; end
                rigidBodyFrame = gapStartIdx + rigidBodyExistIdx - 1;
                parentMarkerNames = eTable.Properties.VariableNames(logical(eTable{rigidBodyExistIdx,:}));
                
                
                
                % Find closest frame where parent and child markers exist
                eTable = array2table(logical(any(markerTable{:, getTrajectoryNames(markerName)},2)), 'VariableNames', {markerName});                
                for nn=1:length(parentMarkerNames)
                    parentMarkerName = parentMarkerNames{nn};
                    eTable = [eTable, array2table(logical(any(markerTable{:, getTrajectoryNames(parentMarkerName)},2)), 'VariableNames', {parentMarkerName})];
                end
                
                eArr = find(all(eTable{:,:},2));
                [~, idx] = min(abs(eArr-rigidBodyFrame));
                closestCompleteFrame = eArr(idx);
                
%                 % Compute location of child marker relative to parent marker in closest complete frame
%                 parentTraj1 = markerTable(closestCompleteFrame, getTrajectoryNames(parentMarkerNames{1}));
%                 parentTraj2 = markerTable(closestCompleteFrame, getTrajectoryNames(parentMarkerNames{2}));
%                 parentTraj3 = markerTable(closestCompleteFrame, getTrajectoryNames(parentMarkerNames{3}));
%                 childTraj = markerTable(closestCompleteFrame, getTrajectoryNames(markerName));
%                 
%                 dist1 = getDist(parentTraj1{:,:}, childTraj{:,:});
%                 dist2 = getDist(parentTraj2{:,:}, childTraj{:,:});
%                 dist3 = getDist(parentTraj3{:,:}, childTraj{:,:});
%                 
%                 % Compute expected location of child marker in unlabeled frame
%                 parentTraj1 = markerTable(rigidBodyFrame, getTrajectoryNames(parentMarkerNames{1}));
%                 parentTraj2 = markerTable(rigidBodyFrame, getTrajectoryNames(parentMarkerNames{2}));
%                 parentTraj3 = markerTable(rigidBodyFrame, getTrajectoryNames(parentMarkerNames{3}));
%                 
%                 fun1 = dist1==sqrt((xU-parentTraj1{1,1})^2 + (yU-parentTraj1{1,2})^2 + (zU-parentTraj1{1,3})^2);
%                 fun2 = dist2==sqrt((xU-parentTraj2{1,1})^2 + (yU-parentTraj2{1,2})^2 + (zU-parentTraj2{1,3})^2);
%                 fun3 = dist3==sqrt((xU-parentTraj3{1,1})^2 + (yU-parentTraj3{1,2})^2 + (zU-parentTraj3{1,3})^2);
%                 [childTrajX, childTrajY, childTrajZ] = solve(fun1, fun2, fun3);
%                 childTraj = double([childTrajX, childTrajY, childTrajZ]);
%                 
%                 unlabeledTrajAtFrame = ones(size(childTraj)).*[x(rigidBodyFrame), y(rigidBodyFrame), z(rigidBodyFrame)];
                
                % Get location of donor and target markers at full frame
                donorLoc1 = markerTable(closestCompleteFrame, getTrajectoryNames(parentMarkerNames{1}));
                donorLoc2 = markerTable(closestCompleteFrame, getTrajectoryNames(parentMarkerNames{2}));
                donorLoc3 = markerTable(closestCompleteFrame, getTrajectoryNames(parentMarkerNames{3}));
                targetLoc = markerTable(closestCompleteFrame, getTrajectoryNames(markerName));
                
                donorLabeledFrame = [donorLoc1{:,:}', donorLoc2{:,:}', donorLoc3{:,:}'];
                targetLabeledFrame = targetLoc{:,:}';
                
                % Get location of donor markers at unlabeled frame
                donorLoc1 = markerTable(rigidBodyFrame, getTrajectoryNames(parentMarkerNames{1}));
                donorLoc2 = markerTable(rigidBodyFrame, getTrajectoryNames(parentMarkerNames{2}));
                donorLoc3 = markerTable(rigidBodyFrame, getTrajectoryNames(parentMarkerNames{3}));
                
                donorUnlabeledFrame = [donorLoc1{:,:}', donorLoc2{:,:}', donorLoc3{:,:}'];
                try
                    regParams = avicon.absor(donorLabeledFrame, donorUnlabeledFrame);
                catch
                    continue;
                end
                tMat = regParams.M;
                targetUnlabeledFrame = tMat*[targetLabeledFrame; 1];
                
                unlabeledTraj = [x(rigidBodyFrame), y(rigidBodyFrame), z(rigidBodyFrame)];
                
                dist = getDist(unlabeledTraj, targetUnlabeledFrame(1:3)');
                minMarkerDist = min(dist);
                if minMarkerDist < minDist % Could check if this dist is < minDistTreshold and just break to speed up code but for now I will keep it the most conservative (check all markers)
                    minDist = minMarkerDist;
                    minMarker = markerName;
                end
                
                % Right now there's also the chance that one of the parent
                % markers were mislabeled and therefore, minDist was messed
                % up from the rigid body. We could still use the other
                % rigid body data (potentially w/ different parent markers)
                % to account for this.
                
                % Also, I'm only looking at one frame of parent marker data
                % and one frame of unlabeled trajectory data. Both of these
                % could be extended to be average values to improve
                % robustness.
            end
            
        end
        
        if minDist < minDistThreshold
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

