function [markerTable] = FlipMarkersInVicon(vicon, subject, markerOrders, markerTable)
checkFlags = zeros(length(markerOrders), 1);
while ~all(checkFlags)
    for ii=1:length(markerOrders)
        order = markerOrders{ii};
        markerSmall = order{1};
        markerLarge = order{2};
        coord = order{3};
        
        posSmall = markerTable.([markerSmall '_' coord]);
        posLarge = markerTable.([markerLarge '_' coord]);
        
        if ~any(posSmall)
            fprintf("No %s data. Skipping flip check.\n", markerSmall);
            checkFlags(ii, 1) = 1;
            continue;
        end
        if ~any(posLarge)
            fprintf("No %s data. Skipping flip check.\n", markerLarge);
            checkFlags(ii, 1) = 1;
            continue;
        end
        
        [posSmallStart, posSmallEnd] = GetStartAndEnd(posSmall);
        [posLargeStart, posLargeEnd] = GetStartAndEnd(posLarge);
        posStart = max([posSmallStart, posLargeStart]);
        posEnd = min([posSmallEnd, posLargeEnd]);
        
        avgPosSmall = mean(posSmall(posStart:posEnd));
        avgPosLarge = mean(posLarge(posStart:posEnd));
        
        if avgPosSmall > avgPosLarge
            fprintf("Flipping %s with %s.\n", markerSmall, markerLarge);
            checkFlags = zeros(length(markerOrders), 1);
            checkFlags(ii, 1) = 1;
            
            x = markerTable.([markerLarge '_x']);
            y = markerTable.([markerLarge '_y']);
            z = markerTable.([markerLarge '_z']);
            vicon.SetTrajectory(subject, markerSmall, x, y, z, x | y | z);
            
            x = markerTable.([markerSmall '_x']);
            y = markerTable.([markerSmall '_y']);
            z = markerTable.([markerSmall '_z']);
            vicon.SetTrajectory(subject, markerLarge, x, y, z, x | y | z);
            
            markerTable = avicon.GetMarkerTable(vicon, subject);
        else
            checkFlags(ii, 1) = 1;
        end        
    end
end
end

function [iStart, iEnd] = GetStartAndEnd(x)
    iStart = find(x~=0, 1);
    iEnd = find(x(iStart:end)==0, 1);
    iEnd = iStart + iEnd - 2;
end