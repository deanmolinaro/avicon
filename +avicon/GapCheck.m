function [gapMarkers, gapTable] = GapCheck(vicon, subject, markerTable, startFrame, endFrame)
markerNames = vicon.GetMarkerNames(subject);
% gapMarkers = {};
gapTable = table();

for ii=1:length(markerNames)
    markerName = markerNames{ii};
    x = markerTable.([markerName '_x'])(startFrame:endFrame);
    y = markerTable.([markerName '_y'])(startFrame:endFrame);
    z = markerTable.([markerName '_z'])(startFrame:endFrame);
    e = x | y | z;
    
    markerEndIdx = find(e);
    if ~any(markerEndIdx)
        fprintf("Warning - Missing %s in trial.\n", markerName);
%         gapMarkers{end+1} = markerName;
        gapTable = [gapTable, array2table(zeros(height(markerTable),1), 'VariableNames', {markerName})];
        gapTable.(markerName)(startFrame:endFrame) = 1; % Entire trial is a gap
        continue;
    end
    markerStartIdx = markerEndIdx(1);
    markerEndIdx = markerEndIdx(end);
    
    if any(~e(markerStartIdx:markerEndIdx))
%         gapMarkers{end+1} = markerName;
        gapTable = [gapTable, array2table(zeros(height(markerTable),1), 'VariableNames', {markerName})];
        gapTable.(markerName)(startFrame+markerStartIdx-1:startFrame+markerEndIdx-1) = ~e(markerStartIdx:markerEndIdx);
    end
end

gapMarkers = gapTable.Properties.VariableNames;
end

