function [centroidPos] = GetCentroid(dataTable, omitnan, useNames)
if nargin < 2; omitnan = false; end
if nargin < 3; useNames = true; end

if useNames
    tableHeaders = dataTable.Properties.VariableNames;
    if omitnan
        centroidX = mean(dataTable{:, tableHeaders(contains(tableHeaders, '_x'))}, 2, 'omitnan');
        centroidY = mean(dataTable{:, tableHeaders(contains(tableHeaders, '_y'))}, 2, 'omitnan');
        centroidZ = mean(dataTable{:, tableHeaders(contains(tableHeaders, '_z'))}, 2, 'omitnan');
    else
        centroidX = mean(dataTable{:, tableHeaders(contains(tableHeaders, '_x'))}, 2);
        centroidY = mean(dataTable{:, tableHeaders(contains(tableHeaders, '_y'))}, 2);
        centroidZ = mean(dataTable{:, tableHeaders(contains(tableHeaders, '_z'))}, 2);
    end
    centroidPos = [centroidX, centroidY, centroidZ];
else
    if istable(dataTable)
        centroidPos = mean(dataTable{:,:}, 2);
    else
        centroidPos = mean(dataTable(:,:), 2);
    end
end
end