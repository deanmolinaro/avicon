function [missingMarkers] = GetMissingMarkersFromMarkerTable(markerTable)
missedMarkersIdx = sum(markerTable{:,:}, 1) == 0;
missingMarkers = markerTable.Properties.VariableNames(missedMarkersIdx);
missingMarkers = cellfun(@(x) x(1:end-2), missingMarkers(endsWith(missingMarkers, '_x')), 'UniformOutput', false);
end

