function [markerTable, badMarkersTable] = UnlabelUsingRigidBodies_test(vicon, subject, staticFilePath, varargin)

narginchk(3, 9);
p = inputParser;
addRequired(p, 'vicon');
addRequired(p, 'subject', @(x) ischar(x) | isstring(x));
addRequired(p, 'staticFilePath', @(x) ischar(x) | isstring(x));
addParameter(p,'StaticFrame', 1, @isnumeric);
addParameter(p, 'MaxAllowableDist', 45, @isnumeric);
addParameter(p, 'MarkerTable', table(), @istable);
addParameter(p, 'SegmentMarkers', struct(), @isstruct);
addParameter(p, 'Timeout', 60, @isnumeric);

p.parse(vicon, subject, staticFilePath, varargin{:});

staticFrame = p.Results.StaticFrame;
maxAllowableDist = p.Results.MaxAllowableDist;
markerTable = p.Results.MarkerTable;
if isempty(markerTable); markerTable = avicon.GetMarkerTable(vicon, subject); end
segmentMarkerStruct = p.Results.SegmentMarkers;
if isempty(fieldnames(segmentMarkerStruct)); segmentMarkerStruct = BuildConservativeSegmentMarkerStruct(vicon, subject); end
timeout = p.Results.Timeout;
timeoutLong = timeout * 10;

[viconDir, viconTrialName] = vicon.GetTrialName();
viconFileName = [viconTrialName '.c3d'];
viconTrialPath = [viconDir viconTrialName];
viconFilePath = [viconDir viconFileName];


if ~endsWith(staticFilePath, '.c3d'); staticFilePath = [staticFilePath '.c3d']; end
staticMarkerTable = avicon.thirdparty.C3DtoTRC(staticFilePath);

segments = vicon.GetSegmentNames(subject);

[startFrame, endFrame] = vicon.GetTrialRegionOfInterest();
numFrames = endFrame - startFrame + 1;

% The trick is that ViconNexus() uses absolute frames but .c3d files use relative frames.
unlabeledStruct = avicon.lib.InitUnlabeledStruct(vicon);
badMarkersTable = table();

% segments = {'LeftShank'};

for ii=1:length(segments)
    segment = segments{ii};
%     [~, ~, segmentMarkers] = vicon.GetSegmentDetails(subject, segment);
    segmentMarkers = segmentMarkerStruct.(segment);
    segmentMarkers(cellfun(@(x) isempty(x), segmentMarkers)) = [];
    
    for jj=0:numFrames - 1
        frame = startFrame + jj;
        
        if jj == 0 || jj == numFrames - 1 || mod(jj, 500) == 0
            fprintf("%s: %i/%i\n", segment, frame, endFrame);
        end
        
        while true
            segmentTrajNames = GetTrajectoryNames(segmentMarkers);
            staticSegmentTraj = staticMarkerTable(staticFrame, segmentTrajNames);
            trialSegmentTraj = markerTable(frame, segmentTrajNames);

            badMarkerCols = FindBadMarkerCols(trialSegmentTraj);
            numValidMarkers = length(segmentMarkers) - length(badMarkerCols);

            if numValidMarkers < 4
                break;
            end

            % If we have access to more than 4 markers on the rigid body then just check for marker movement.
            if numValidMarkers > 4 % 4 markers with 3 dimensions
                [dMax, dIdx] = GetMaxDistFromCandidate(trialSegmentTraj, staticSegmentTraj, segmentMarkers);

            % Otherwise, decide based on the movement of the estimated centroid.
            else
                [dMax, dIdx] = GetMaxDistFromCentroid(trialSegmentTraj, staticSegmentTraj, segmentMarkers);
            end

            if dMax > maxAllowableDist
                badMarker = segmentMarkers{dIdx};
                badTrajNames = GetTrajectoryNames({badMarker});
                fprintf("Removing %s at frame %i (%.1f).\n", badMarker, frame, dMax);
                
                badTraj = markerTable{frame, badTrajNames};
%                 unlabeledStruct = AddUnlabeledTraj(unlabeledStruct, badMarker, frame, badTraj);
                unlabeledStruct = avicon.lib.AddUnlabeledTrajectoriesToStruct(unlabeledStruct, badMarker, frame, badTraj);
                
                markerTable{frame, badTrajNames} = 0;
                vicon.SetTrajectoryAtFrame(subject, badMarker, frame, 0, 0, 0, false);
                
                badMarkersTable = [badMarkersTable; cell2table({badMarker, frame, dMax}, 'VariableNames', {'marker', 'frame', 'dist'})];
            else
                break;
            end
        end
    end
end

[viconDir, viconTrialName] = vicon.GetTrialName();
historyDir = [viconDir 'history'];
if ~exist(historyDir, 'dir'); mkdir(historyDir); end
avicon.MoveFileRobust([viconDir viconTrialName '.history'], [historyDir '\' viconTrialName '.history'], timeout);

avicon.SaveTrialRobust(vicon, timeoutLong);
avicon.lib.AddUnlabeledTrajectoriesFromStruct(unlabeledStruct, viconFilePath);
avicon.OpenTrialRobust(vicon, viconTrialPath, timeoutLong, 'SaveTrial', false);
end


%% Helper Functions
function [trajNames] = GetTrajectoryNames(markers)
trajNames = cell(3, length(markers));
for ii=1:length(markers)
    trajNames(:, ii) = strcat(markers{ii}, '_', {'x', 'y', 'z'})';
%     trajNames = [trajNames, strcat(markers{ii}, '_', {'x', 'y', 'z'})];
end
trajNames = reshape(trajNames, 1, length(markers) * 3);
end

function [badMarkerCols] = FindBadMarkerCols(traj)
if size(traj, 1) == 1
    traj = reshape(traj{:,:}, 3, size(traj, 2) / 3);
end

badMarkerCols = find(any(traj==0, 1));
end

function [dMax, dIdx] = GetMaxDistFromCandidate(trialSegmentTraj, staticSegmentTraj, segmentMarkers)
distArr = zeros(length(segmentMarkers), 1);

for kk=1:length(segmentMarkers)
    candidateMarker = segmentMarkers{kk};

    candidateTrajNames = GetTrajectoryNames({candidateMarker});
    staticCandidateTraj = staticSegmentTraj{1, candidateTrajNames}';
    trialCandidateTraj = trialSegmentTraj{1, candidateTrajNames}';

    if any(trialCandidateTraj == 0)
%         warning("How?????? Gap in donor marker trajectory! (Candidate)\n");
        continue;
    end

    donorMarkers = segmentMarkers(~strcmp(segmentMarkers, candidateMarker));
    donorTrajNames = GetTrajectoryNames(donorMarkers);
    staticDonorTraj = staticSegmentTraj{1, donorTrajNames};
    staticDonorTraj = reshape(staticDonorTraj, 3, length(donorMarkers));
    trialDonorTraj = trialSegmentTraj{1, donorTrajNames};
    trialDonorTraj = reshape(trialDonorTraj, 3, length(donorMarkers));

    if any(any(trialDonorTraj == 0))
%         fprintf("How???? Gap in donor marker trajectory!\n");
        badMarkerCols = find(any(trialDonorTraj==0));
        trialDonorTraj(:, badMarkerCols) = [];
        staticDonorTraj(:, badMarkerCols) = [];
    end

    if size(trialDonorTraj, 2) < 3
%         fprintf("Insufficient number of donor trajectories!\n");
        continue;
    end

    regParams = avicon.thirdparty.absor(staticDonorTraj, trialDonorTraj);
    transformedStaticCandidateTraj = regParams.M * [staticCandidateTraj; 1];
    d = sqrt(sum((transformedStaticCandidateTraj(1:3) - trialCandidateTraj).^2));
    distArr(kk) = d;
end

[dMax, dIdx] = max(distArr);
end


function [dMax, dIdx] = GetMaxDistFromCentroid(trialSegmentTraj, staticSegmentTraj, segmentMarkers)
distArr = ones(length(segmentMarkers), 1) * NaN;

for kk=1:length(segmentMarkers)
    candidateMarker = segmentMarkers{kk};

    candidateTrajNames = GetTrajectoryNames({candidateMarker});
    trialCandidateTraj = trialSegmentTraj{1, candidateTrajNames}';
    if any(trialCandidateTraj == 0)
%         warning("How?????? Gap in candidate marker trajectory! (Centroid)\n");
        continue;
    end

    donorMarkers = segmentMarkers(~strcmp(segmentMarkers, candidateMarker));
    donorTrajNames = GetTrajectoryNames(donorMarkers);
    staticDonorTraj = staticSegmentTraj{1, donorTrajNames};
    staticDonorTraj = reshape(staticDonorTraj, 3, length(donorMarkers));
    trialDonorTraj = trialSegmentTraj{1, donorTrajNames};
    trialDonorTraj = reshape(trialDonorTraj, 3, length(donorMarkers));

    if any(any(trialDonorTraj == 0))
%         warning("How?????? Gap in donor marker trajectory! (Centroid)\n");
        badMarkerCols = find(any(trialDonorTraj==0));
        trialDonorTraj(:, badMarkerCols) = [];
        staticDonorTraj(:, badMarkerCols) = [];
    end

    if size(trialDonorTraj, 2) < 3
%         fprintf("Insufficient number of donor trajectories!\n");
        continue;
    end

    regParams = avicon.thirdparty.absor(staticDonorTraj, trialDonorTraj);

%     % lol... absor equates the centroids of the two point clouds so d is always 0
%     trialCentroidTraj = avicon.lib.GetCentroid(trialDonorTraj, false, false);
%     staticCentroidTraj = avicon.lib.GetCentroid(staticDonorTraj, false, false);
%     transformedStaticCentroidTraj = regParams.M * [staticCentroidTraj; 1];
%     d = sqrt(sum((transformedStaticCentroidTraj(1:3) - trialCentroidTraj).^2));
    
    transformedStaticDonorTraj = regParams.M * [staticDonorTraj; ones(1, size(staticDonorTraj, 2))];
    d = mean(sqrt(sum((trialDonorTraj - transformedStaticDonorTraj(1:3, :)).^2, 1)));

    distArr(kk) = d;
end

[~, dIdx] = min(distArr);

% trialSegmentTraj = reshape(trialSegmentTraj{:,:}, 3, length(segmentMarkers));
% staticSegmentTraj = reshape(staticSegmentTraj{:,:}, 3, length(segmentMarkers));
% regParams = avicon.thirdparty.absor(staticSegmentTraj, trialSegmentTraj);

candidateMarker = segmentMarkers{dIdx};
candidateTrajNames = GetTrajectoryNames({candidateMarker});
staticCandidateTraj = staticSegmentTraj{1, candidateTrajNames}';
trialCandidateTraj = trialSegmentTraj{1, candidateTrajNames}';

if any(trialCandidateTraj == 0)
    error("How?????? Gap in candidate marker trajectory! (centroid)\n");
end

donorMarkers = segmentMarkers(~strcmp(segmentMarkers, candidateMarker));
donorTrajNames = GetTrajectoryNames(donorMarkers);
staticDonorTraj = staticSegmentTraj{1, donorTrajNames};
staticDonorTraj = reshape(staticDonorTraj, 3, length(donorMarkers));
trialDonorTraj = trialSegmentTraj{1, donorTrajNames};
trialDonorTraj = reshape(trialDonorTraj, 3, length(donorMarkers));

if any(any(trialDonorTraj == 0))
%         fprintf("How???? Gap in donor marker trajectory!\n");
    badMarkerCols = find(any(trialDonorTraj==0));
    trialDonorTraj(:, badMarkerCols) = [];
    staticDonorTraj(:, badMarkerCols) = [];
end

if size(trialDonorTraj, 2) < 3
    error("How?????? Gap in donor marker trajectory! (centroid)\n");
end

regParams = avicon.thirdparty.absor(staticDonorTraj, trialDonorTraj);
transformedStaticCandidateTraj = regParams.M * [staticCandidateTraj; 1];
dMax = sqrt(sum((transformedStaticCandidateTraj(1:3) - trialCandidateTraj).^2));

% trialSegmentCentroidTraj = avicon.lib.GetCentroid(trialSegmentTraj, false, false);
% staticSegmentCentroidTraj = avicon.lib.GetCentroid(staticSegmentTraj, false, false);
% transformedStaticSegmentCentroidTraj = regParams.M * [staticSegmentCentroidTraj; 1];
% dMax = sqrt(sum((transformedStaticSegmentCentroidTraj(1:3) - trialSegmentCentroidTraj).^2)) * 4;
end

function [segmentMarkerStruct] = BuildConservativeSegmentMarkerStruct(vicon, subject)
segments = vicon.GetSegmentNames(subject);
segmentMarkerStruct = struct();
for ii=1:length(segments)
    [~, ~, segmentMarkers] = vicon.GetSegmentDetails(subject, segments{ii});
    segmentMarkerStruct.(segments{ii}) = segmentMarkers;
end
end