function [segmentTable] = GetTrialSegmentsFromeForcePlates(vicon, forcePlateNames, framePadding)
%% Get force plate data to segment start and stop of each pass.
% forcePlateNames = {'Amp1', 'Amp6'}; % For Ramps
% forcePlateNames = {'Amp7', 'Amp5'}; % Stairs
% forcePlateNames = {'Amp7', 'Amp9'}; % Level ground

if nargin < 3
    framePadding = 30;
end

[hsTable, toTable, rate] = GetForcePlateEvents(vicon, forcePlateNames);

startFrameArr = [];
endFrameArr = [];
startFP = {};
endFP = {};
endFrameFP = 0;
while true
    % Find next segment start.
    [maxVal, startIdxArr] = max(hsTable{endFrameFP+1:end, :});
    if all(maxVal < 1); break; end
    startIdxArr(maxVal == 0) = NaN; % Make sure to ignore force plates with no heel srikes remaining.
    [startFrameFP, startFPNum] = min(startIdxArr + endFrameFP);
    startFrame = ceil(startFrameFP*(200/rate)); % Convert back to vicon frames
    startFrame = startFrame - framePadding; % Actually start processing trial before heel strike
    
    % Find next segment end.
    [maxVal, endIdxArr] = max(toTable{startFrameFP+1:end, :});
    maxVal(startFPNum) = 0; % If only toe off is from same FP as HS then we want to ignore it.
    if all(maxVal < 1); break; end
    endIdxArr(startFPNum) = NaN; % Don't use same force plate to start trial from heel strike and end trial from toe off
    endIdxArr(maxVal == 0) = NaN; % Make sure to ignore force plates with no toe offs remaining.
    [endFrameFP, endFPNum] = min(endIdxArr + startFrameFP);
    endFrame = ceil(endFrameFP*(200/rate));
    endFrame = endFrame + framePadding;
    
    % Save segmented trial information.
    startFrameArr = [startFrameArr; startFrame];
    endFrameArr = [endFrameArr; endFrame];
    startFP{end+1} = hsTable.Properties.VariableNames{startFPNum};
    endFP{end+1} = toTable.Properties.VariableNames{endFPNum};
end

segmentTable = array2table([startFrameArr, endFrameArr], 'VariableNames', {'startFrame', 'endFrame'});
segmentTable = [segmentTable, cell2table([startFP', endFP'], 'VariableNames', {'startFP', 'endFP'})];
end

%% Helper Functions
function [hsArr, toArr, rate] = GetForcePlateEvents(vicon, forcePlateNames)
% This function currently assumes all force plates are sampled at same
% frequency.
outputName = 'Force';
channelName = 'Fz';

hsArr = [];
toArr = [];
for ii=1:length(forcePlateNames)
    forcePlateName = forcePlateNames{ii};
    forcePlateID = vicon.GetDeviceIDFromName(forcePlateName);
    outputID = vicon.GetDeviceOutputIDFromName(forcePlateID, outputName);
    channelID = vicon.GetDeviceChannelIDFromName(forcePlateID, outputID, channelName);
    [FzNew, ready, rate] = vicon.GetDeviceChannel(forcePlateID, outputID, channelID);
    FzNew = FzNew'*-1;
    
    FS=rate; 
    fcut=20;
    wn=2*fcut/FS; order=5;
    [b,a]=butter(order,wn);
    FzNew=filtfilt(b,a,FzNew);
    FzNew(FzNew<25) = 0;
    
    hs = [diff(FzNew)>0; 0] & FzNew==0;
    to = [0; diff(FzNew)<0] & FzNew==0;
    hsArr = [hsArr, hs];
    toArr = [toArr, to];
    
%     figure
%     hold on
%     plot(FzNew)
%     plot(find(hs), FzNew(hs), 'o')
%     plot(find(to), FzNew(to), 'x')
end

hsArr = array2table(hsArr, 'VariableNames', forcePlateNames);
toArr = array2table(toArr, 'VariableNames', forcePlateNames);
end