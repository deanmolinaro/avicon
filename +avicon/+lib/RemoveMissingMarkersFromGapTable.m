function [gapTable] = RemoveMissingMarkersFromGapTable(gapTable)
h = height(gapTable);
missingMarkerIdx = sum(gapTable{:,:}, 1) == h;
gapTable(:, missingMarkerIdx) = [];
end