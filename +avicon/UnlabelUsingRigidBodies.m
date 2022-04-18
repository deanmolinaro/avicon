function [markerTable, badMarkersTable] = UnlabelUsingRigidBodies(vicon, subject, staticFilePath, varargin)

narginchk(3, 9);
p = inputParser;
addRequired(p, 'vicon');
addRequired(p, 'subject', @(x) ischar(x) | isstring(x));
addRequired(p, 'staticFilePath', @(x) ischar(x) | isstring(x));
addParameter(p,'StaticFrame', 1, @isnumeric);
addParameter(p, 'MaxAllowableDist', 45, @isnumeric);
addParameter(p, 'MarkerTable', table(), @istable);
addParameter(p, 'Timeout', 60, @isnumeric);

p.parse(vicon, subject, staticFilePath, varargin{:});

staticFrame = p.Results.StaticFrame;
maxAllowableDist = p.Results.MaxAllowableDist;
markerTable = p.Results.MarkerTable;
if isempty(markerTable); markerTable = avicon.GetMarkerTable(vicon, subject); end
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
    [~, ~, segmentMarkers] = vicon.GetSegmentDetails(subject, segment);
    segmentMarkers(cellfun(@(x) isempty(x), segmentMarkers)) = [];
    
    for jj=0:numFrames - 1
        frame = startFrame + jj;
        
        if jj == 0 || jj == numFrames - 1 || mod(jj, 500) == 0
            fprintf("%s: %i/%i\n", segment, frame, endFrame);
        end
        
        while true
            distArr = zeros(length(segmentMarkers), 1);
            for kk=1:length(segmentMarkers)
                candidateMarker = segmentMarkers{kk};
                
                candidateTrajNames = GetTrajectoryNames({candidateMarker});
                staticCandidateTraj = staticMarkerTable{staticFrame, candidateTrajNames}';
                trialCandidateTraj = markerTable{frame, candidateTrajNames}';

                if any(trialCandidateTraj == 0)
%                     fprintf("Gap in candidate marker trajectory!\n");
                    continue;
                end

                donorMarkers = segmentMarkers(~strcmp(segmentMarkers, candidateMarker));
                donorTrajNames = GetTrajectoryNames(donorMarkers);
                staticDonorTraj = staticMarkerTable{staticFrame, donorTrajNames};
                staticDonorTraj = reshape(staticDonorTraj, 3, length(donorMarkers));
                trialDonorTraj = markerTable{frame, donorTrajNames};
                trialDonorTraj = reshape(trialDonorTraj, 3, length(donorMarkers));

                if any(any(trialDonorTraj == 0))
%                     fprintf("Gap in donor marker trajectory!\n");
                    badMarkerCols = find(any(trialDonorTraj==0));
                    trialDonorTraj(:, badMarkerCols) = [];
                    staticDonorTraj(:, badMarkerCols) = [];
                end

                if size(trialDonorTraj, 2) < 3
%                     fprintf("Insufficient number of donor trajectories!\n");
                    continue;
                end

                regParams = avicon.thirdparty.absor(staticDonorTraj, trialDonorTraj);
                transformedStaticCandidateTraj = regParams.M * [staticCandidateTraj; 1];

                d = sqrt(sum((transformedStaticCandidateTraj(1:3) - trialCandidateTraj).^2));
                distArr(kk) = d;
            end

            [dMax, dIdx] = max(distArr);
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


