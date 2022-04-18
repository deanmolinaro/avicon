function [missedMarkers] = ReplaceGapFillWithUnlabeledMarkers(vicon,subject,gapTable,varargin)

narginchk(3,7);
p = inputParser;
addRequired(p,'vicon');
addRequired(p,'subject',@(x) ischar(x) || isstring(x));
addRequired(p,'gapTable',@istable);
addParameter(p,'MarkerTable',table(),@istable);
addParameter(p,'MinDistThreshold',5,@isnumeric);

p.parse(vicon,subject,gapTable,varargin{:});
markerTable = p.Results.MarkerTable;
minDistThreshold = p.Results.MinDistThreshold;

gapMarkerNames = gapTable.Properties.VariableNames;
markerNames = vicon.GetMarkerNames(subject);
missedMarkers = {};

if isempty(markerTable); markerTable = avicon.GetMarkerTable(vicon, subject); end

GetTrajectoryNames = @(x) {[x '_x'], [x '_y'], [x '_z']};
GetDist = @(x,y) sqrt(sum((x-y).^2, 2));

fprintf("Labeling missed markers.\n");
for ii=1:vicon.GetUnlabeledCount()

    [x, y, z, e] = vicon.GetUnlabeled(ii);
    
    dataStartIdxArr = find([0, diff(e)]>0);
    dataEndIdxArr = find([diff(e), 0]<0);
    
    for jj=1:length(dataStartIdxArr)
        dataStartIdx = dataStartIdxArr(jj);
        dataEndIdx = dataEndIdxArr(jj);
        dataLength = dataEndIdx - dataStartIdx + 1;
        if dataLength > 100; fprintf("Warning - Unlabeled trajectory with length %i.\n", dataLength); end
        data = [x', y', z'];
        data = data(dataStartIdx:dataEndIdx, :);
        minDist = Inf;
        
        for kk=1:length(gapMarkerNames)
            markerName = gapMarkerNames{kk};
            gapData = gapTable.(markerName)(dataStartIdx:dataEndIdx); % 1 if gap existed in original data, 0 if not.
            if any(gapData==0); continue; end % Only interested in checking if gap exists for entire unlabeleled trajectory. TODO: Check only section of unlabeled trajectory within gap frames if there is overlap.
            markerNameXYZ = GetTrajectoryNames(markerName);
            markerData = markerTable{dataStartIdx:dataEndIdx, markerNameXYZ};
            meanDist = mean(GetDist(data, markerData));
            if meanDist < minDist
                minDist = meanDist;
                minMarkerName = markerName;
                minMarkerNameXYZ = markerNameXYZ;
            end
        end
        
        if minDist < minDistThreshold
            missedMarkers{end+1} = minMarkerName; % TODO: Update so that unlabeleled trajectories can be labeled correctly.
        end
    end
    
end

end

