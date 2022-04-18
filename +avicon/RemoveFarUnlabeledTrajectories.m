function [] = RemoveFarUnlabeledTrajectories(vicon, subject, varargin)
narginchk(2, 10);

p = inputParser;
addRequired(p, 'vicon');
addRequired(p, 'subject', @(x) ischar(x) || isstring(x));
addParameter(p, 'MaxAllowableDist', 200, @isnumeric);
addParameter(p, 'Timeout', 600, @isnumeric);
addParameter(p, 'SaveTrial', true, @islogical);
addParameter(p, 'MarkerTable', table(), @istable);

p.parse(vicon, subject, varargin{:});
maxAllowableDist = p.Results.MaxAllowableDist;
timeout = p.Results.Timeout;
saveTrial = p.Results.SaveTrial;
if saveTrial; avicon.SaveTrialRobust(vicon, timeout); end
markerTable = p.Results.MarkerTable;
if isempty(markerTable); markerTable = avicon.GetMarkerTable(vicon, subject); end

[viconDir, viconTrialName] = vicon.GetTrialName();
viconTrialPath = [viconDir viconTrialName];
viconFileName = [viconTrialName '.c3d'];
viconFilePath = [viconDir viconFileName];

markerNames = vicon.GetMarkerNames(subject);

c3dHandle = btkReadAcquisition(viconFilePath);
markerData = btkGetMarkersValues(c3dHandle);
residuals = btkGetMarkersResiduals(c3dHandle);
labels = btkGetMetaData(c3dHandle, 'POINT', 'LABELS');
labels = labels.info.values;
labels = strrep(labels, '*', 'C_');
uLabels = labels(contains(labels, 'C_'));

c3dMarkerTable = array2table(markerData, 'VariableNames', avicon.lib.GetTrajectoryNames(labels));
markerResiduals = array2table(residuals, 'VariableNames', labels);

% c3dMarkerTable is relative to start frame but markerTable and gapTable
% are relative to frame 1 so just crop them to match c3dMarkerTable.
[startFrame, endFrame] = vicon.GetTrialRegionOfInterest();
markerTable = markerTable(startFrame:endFrame, :);

fprintf("Removing far away unlabeled trajectories.\n");
for ii=1:length(uLabels)
    uLabel = uLabels{ii};
    uTraj = c3dMarkerTable{:, avicon.lib.GetTrajectoryNames({uLabel})};
    e = markerResiduals.(uLabel);
    
    dataStartIdxArr = find([0; diff(e~=-1)]>0);
    dataEndIdxArr = find([diff(e~=-1); 0]<0);
    
    if isempty(dataStartIdxArr) && isempty(dataEndIdxArr)
        warning('No data for unlabeled marker!\n');
        continue;
    end
    
    if isempty(dataStartIdxArr); dataStartIdxArr = 1; end
    if isempty(dataEndIdxArr); dataEndIdxArr = length(e); end
    if dataEndIdxArr(1) < dataStartIdxArr(1); dataStartIdxArr = [1; dataStartIdxArr]; end
    if dataStartIdxArr(end) > dataEndIdxArr(end); dataEndIdxArr = [dataEndIdxArr; length(e)]; end
    
    for jj=1:length(dataStartIdxArr)
        dataStartIdx = dataStartIdxArr(jj);
        dataEndIdx = dataEndIdxArr(jj);
        dataLength = dataEndIdx - dataStartIdx + 1;
        if dataLength > 100
            fprintf("Warning - Unlabeled trajectory with length %i.\n", dataLength);
        end
        data = uTraj(dataStartIdx:dataEndIdx, :);
        keep = false;
        
        for kk=1:length(markerNames)
            markerName = markerNames{kk};
            markerTrajNames = avicon.lib.GetTrajectoryNames({markerName});
            markerTraj = markerTable{dataStartIdx:dataEndIdx, markerTrajNames};
            
            dist = sqrt(sum((data - markerTraj).^2, 2));
            dist = min(dist);
            if dist < maxAllowableDist
                keep = true;
                break;
            end
        end
        
        if ~keep
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
end

