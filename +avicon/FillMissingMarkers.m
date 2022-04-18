function [markerTable, nowMissingMarkers, filledMarkers] = FillMissingMarkers(vicon, subject, staticFilePath, varargin)
narginchk(3, 9);
p = inputParser;
addRequired(p, 'vicon');
addRequired(p, 'subject', @(x) ischar(x) | isstring(x));
addRequired(p, 'staticFilePath', @(x) ischar(x) | isstring(x));
addParameter(p,'StaticFrame', 1, @isnumeric);
addParameter(p, 'MarkerTable', table(), @istable);
addParameter(p, 'SegmentMarkers', struct(), @isstruct);
% addParameter(p, 'Timeout', 60, @isnumeric);

p.parse(vicon, subject, staticFilePath, varargin{:});

staticFrame = p.Results.StaticFrame;
markerTable = p.Results.MarkerTable;
if isempty(markerTable); markerTable = avicon.GetMarkerTable(vicon, subject); end
segmentMarkerStruct = p.Results.SegmentMarkers;
if isempty(fieldnames(segmentMarkerStruct)); segmentMarkerStruct = avicon.lib.BuildConservativeSegmentMarkerStruct(vicon, subject); end
% timeout = p.Results.Timeout;
% timeoutLong = timeout * 10;

% [viconDir, viconTrialName] = vicon.GetTrialName();
% viconFileName = [viconTrialName '.c3d'];
% viconTrialPath = [viconDir viconTrialName];
% viconFilePath = [viconDir viconFileName];

[startFrame, endFrame] = vicon.GetTrialRegionOfInterest();

if ~endsWith(staticFilePath, '.c3d'); staticFilePath = [staticFilePath '.c3d']; end
staticMarkerTable = avicon.thirdparty.C3DtoTRC(staticFilePath);

segments = fieldnames(segmentMarkerStruct);
missingMarkers = avicon.lib.GetMissingMarkersFromMarkerTable(markerTable);
nowMissingMarkers = missingMarkers;
filledMarkers = {};

for ii=1:length(missingMarkers)
    candidateMarker = missingMarkers{ii};
    candidateTrajNames = avicon.lib.GetTrajectoryNames({candidateMarker});
    
    for jj=1:length(segments)
        segment = segments{jj};
        segmentMarkers = segmentMarkerStruct.(segment);
        if ~any(strcmp(segmentMarkers, candidateMarker))
            continue;
        end
        donorMarkers = segmentMarkers(~strcmp(segmentMarkers, candidateMarker));
        
        % Find first frame where at least 3 of the parent markers exist
        donorTrajNames = avicon.lib.GetTrajectoryNames(donorMarkers);
        validFrames = find(sum(markerTable{:, donorTrajNames} ~= 0, 2) >= 9);
        if length(validFrames) < 2
            fprintf("Could not find enough valid frames for %s using %s.\n", candidateMarker, segment);
            continue;
        end
        
        % Verify first valid frame is early enough (heuristic)
        sValidFrame = validFrames(1);
        if startFrame + 10 < sValidFrame
            fprintf("Valid start frame too late for %s using %s.\n", candidateMarker, segment);
            continue;
        end
        
        % Verify first valid frame is late enough (heuristic)
        eValidFrame = validFrames(end);
        if endFrame - 10 > eValidFrame
            fprintf("Valid end frame too early for %s using %s.\n", candidateMarker, segment);
            continue;
        end
        
        % Verify all frames can be filled using segment
        if max(diff(validFrames)) > 1
            fprintf("Cannot fill all intermediate frames for %s using %s.\n", candidateMarker, segment);
            continue;
        end
        
%         % Get static frame data
%         staticCandidateTraj = staticMarkerTable{staticFrame, candidateTrajNames}';
%         staticDonorTraj = staticMarkerTable{staticFrame, donorTrajNames};
%         staticDonorTraj = reshape(staticDonorTraj, 3, length(donorMarkers));
        
%         % Update first valid frame
%         trialDonorTrajStart = markerTable{sValidFrame, donorTrajNames};
%         trialDonorTrajStart = reshape(trialDonorTrajStart, 3, length(donorMarkers));
%         trialCandidateTraj = FillMissingMarkerAtSingleFrame(staticCandidateTraj, staticDonorTraj, trialDonorTrajStart);
%         vicon.SetTrajectoryAtFrame(subject, candidateMarker, sValidFrame, ...
%             trialCandidateTraj(1), trialCandidateTraj(2), trialCandidateTraj(3), true);
%         markerTable{sValidFrame, candidateTrajNames} = trialCandidateTraj';
%         clear trialCandidateTraj
%         
%         % Update last valid frame
%         trialDonorTrajEnd = markerTable{eValidFrame, donorTrajNames};
%         trialDonorTrajEnd = reshape(trialDonorTrajEnd, 3, length(donorMarkers));
%         trialCandidateTraj = FillMissingMarkerAtSingleFrame(staticCandidateTraj, staticDonorTraj, trialDonorTrajEnd);
%         vicon.SetTrajectoryAtFrame(subject, candidateMarker, eValidFrame, ...
%             trialCandidateTraj(1), trialCandidateTraj(2), trialCandidateTraj(3), true);
%         markerTable{eValidFrame, candidateTrajNames} = trialCandidateTraj';
%         clear trialCandidateTraj

        % Update all frames
        staticCandidateTraj = staticMarkerTable{staticFrame, candidateTrajNames};
        staticDonorTraj = staticMarkerTable{staticFrame, donorTrajNames};
        trialDonorTraj = markerTable{sValidFrame:eValidFrame, donorTrajNames};
        [trialCandidateTraj, e] = FillMissingMarker(staticCandidateTraj, staticDonorTraj, trialDonorTraj);
        
        trialCandidateTrajNexus = zeros(height(markerTable), 3);
        trialCandidateTrajNexus(sValidFrame:eValidFrame, :) = trialCandidateTraj;
        
        eNexus = false(height(markerTable), 1);
        eNexus(sValidFrame:eValidFrame) = e;
        
        vicon.SetTrajectory(subject, candidateMarker, ...
            trialCandidateTrajNexus(:, 1), trialCandidateTrajNexus(:, 2), trialCandidateTrajNexus(:, 3), eNexus);
        markerTable{sValidFrame:eValidFrame, candidateTrajNames} = trialCandidateTraj;
        
        nowMissingMarkers(strcmp(nowMissingMarkers, candidateMarker)) = [];
        filledMarkers{end+1} = candidateMarker;
        break;
    end
end
end


function [trialCandidateTraj, e] = FillMissingMarkerAtSingleFrame(staticCandidateTraj, staticDonorTraj, trialDonorTraj)
badMarkerCols = find(all(trialDonorTraj, 1) == 0);
if any(badMarkerCols)
    trialDonorTraj(:, badMarkerCols) = [];
    staticDonorTraj(:, badMarkerCols) = [];
end

if size(trialDonorTraj, 2) < 3
    trialCandidateTraj = zeros(3, 1);
    e = false;
    return;
end

regParams = avicon.thirdparty.absor(staticDonorTraj, trialDonorTraj);
trialCandidateTraj = regParams.M * [staticCandidateTraj; 1];
trialCandidateTraj = trialCandidateTraj(1:3);
e = true;
end

function [trialCandidateTraj, e] = FillMissingMarker(staticCandidateTraj, staticDonorTraj, trialDonorTraj)
trialCandidateTraj = zeros(size(trialDonorTraj, 1), 3);
e = false(size(trialDonorTraj, 1), 1);

numDonorMarkers = size(trialDonorTraj, 2) / 3;
staticCandidateTraj = staticCandidateTraj';
staticDonorTraj = reshape(staticDonorTraj, 3, numDonorMarkers);

nextPrint = 0;
for ii=1:size(trialDonorTraj, 1)
    pComplete = (ii / size(trialDonorTraj, 1)) * 100;
    if pComplete > nextPrint
        fprintf("%i%s,", nextPrint, '%');
        nextPrint = nextPrint + 10;
    end
    
    trialDonorTrajFrame = trialDonorTraj(ii, :);
    trialDonorTrajFrame = reshape(trialDonorTrajFrame, 3, numDonorMarkers);
    
    [trialCandidateTrajFrame, eFrame] = FillMissingMarkerAtSingleFrame(staticCandidateTraj, staticDonorTraj, trialDonorTrajFrame);
    trialCandidateTraj(ii, :) = trialCandidateTrajFrame';
    e(ii) = eFrame;
end
fprintf("100%s\n", '%');
end