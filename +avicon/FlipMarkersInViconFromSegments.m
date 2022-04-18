function [markerTable] = FlipMarkersInViconFromSegments(vicon, subject, segmentOrders, markerTable)
checkFlags = zeros(length(segmentOrders), 1);
while ~all(checkFlags)
    for ii=1:length(segmentOrders)
        order = segmentOrders{ii};
        markerSmall = order{1};
        markerLarge = order{2};
        coord = order{3}{1};
        
        markerSmall = cellfun(@(x) strcat(x, {'_x','_y','_z'}), markerSmall, 'UniformOutput', false);
        markerSmall = [markerSmall{:}];
        markerLarge = cellfun(@(x) strcat(x, {'_x','_y','_z'}), markerLarge, 'UniformOutput', false);
        markerLarge = [markerLarge{:}];
        
        posSmall = array2table(GetCentroid(markerTable(:, markerSmall)), ...
            'VariableNames', {'x','y','z'});
        posLarge = array2table(GetCentroid(markerTable(:, markerLarge)), ...
            'VariableNames', {'x','y','z'});
        
%         if ~any(posSmall)
%             fprintf("No %s data. Skipping flip check.\n", markerSmall);
%             checkFlags(ii, 1) = 1;
%             continue;
%         end
%         if ~any(posLarge)
%             fprintf("No %s data. Skipping flip check.\n", markerLarge);
%             checkFlags(ii, 1) = 1;
%             continue;
%         end
%         
%         [posSmallStart, posSmallEnd] = GetStartAndEnd(posSmall);
%         [posLargeStart, posLargeEnd] = GetStartAndEnd(posLarge);
%         posStart = max([posSmallStart, posLargeStart]);
%         posEnd = min([posSmallEnd, posLargeEnd]);
%         
%         avgPosSmall = mean(posSmall(posStart:posEnd));
%         avgPosLarge = mean(posLarge(posStart:posEnd));

        avgPosSmall = mean(posSmall.(coord), 'omitnan');
        avgPosLarge = mean(posLarge.(coord), 'omitnan');
        
        if avgPosSmall > avgPosLarge
            fprintf("Flipping %s with %s.\n", strjoin(order{1}, ','), ...
                strjoin(order{2}, ','));
            checkFlags = zeros(length(segmentOrders), 1);
            checkFlags(ii, 1) = 1;
            
            for kk=1:length(order{1})
                x = markerTable.([order{1}{kk} '_x']);
                y = markerTable.([order{1}{kk} '_y']);
                z = markerTable.([order{1}{kk} '_z']);
                vicon.SetTrajectory(subject, order{2}{kk}, x, y, z, x | y | z);
                
                x = markerTable.([order{2}{kk} '_x']);
                y = markerTable.([order{2}{kk} '_y']);
                z = markerTable.([order{2}{kk} '_z']);
                vicon.SetTrajectory(subject, order{1}{kk}, x, y, z, x | y | z);
            end
%             x = markerTable.([markerLarge '_x']);
%             y = markerTable.([markerLarge '_y']);
%             z = markerTable.([markerLarge '_z']);
%             vicon.SetTrajectory(subject, markerSmall, x, y, z, x | y | z);
%             
%             x = markerTable.([markerSmall '_x']);
%             y = markerTable.([markerSmall '_y']);
%             z = markerTable.([markerSmall '_z']);
%             vicon.SetTrajectory(subject, markerLarge, x, y, z, x | y | z);
%             
            markerTable = avicon.GetMarkerTable(vicon, subject);
        else
            checkFlags(ii, 1) = 1;
        end        
    end
end
end

% function [iStart, iEnd] = GetStartAndEnd(x)
%     iStart = find(x~=0, 1);
%     iEnd = find(x(iStart:end)==0, 1);
%     iEnd = iStart + iEnd - 2;
% end

function [centroidPos] = GetCentroid(dataTable)
    tableHeaders = dataTable.Properties.VariableNames;
    markerNames = split(tableHeaders, '_');
    markerNames = unique(markerNames(:,:,1));
    for ii=1:length(markerNames)
        h = cellfun(@(x) [markerNames{ii} '_' x], {'x','y','z'}, 'UniformOutput', false);
        e = ~all(dataTable{:, h}, 2);
        dataTable{e, h} = NaN;
    end
    centroidX = mean(dataTable{:, tableHeaders(contains(tableHeaders, '_x'))}, 2, 'omitnan');
    centroidY = mean(dataTable{:, tableHeaders(contains(tableHeaders, '_y'))}, 2, 'omitnan');
    centroidZ = mean(dataTable{:, tableHeaders(contains(tableHeaders, '_z'))}, 2, 'omitnan');
    centroidPos = [centroidX, centroidY, centroidZ];
end