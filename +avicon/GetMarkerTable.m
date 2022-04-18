function [markerTable, missingMarkers] = GetMarkerTable(vicon, subject)
    markerTable = table();
    missingMarkers = {};
    
    markerNames = vicon.GetMarkerNames(subject);
    for ii=1:length(markerNames)
        markerName = markerNames{ii};
        try
            [x, y, z, e] = vicon.GetTrajectory(subject, markerName);
        catch
            fprintf("Warning - Missing %s in trial.\n", markerName);
            x = zeros(1, vicon.GetFrameCount());
            y = x;
            z = x;
            missingMarkers{end+1} = markerName;
        end
        markerTable = [markerTable, array2table([x',y',z'], 'VariableNames', strcat(markerName, {'_x','_y','_z'}))];
    end
    
    [startFrame, endFrame] = vicon.GetTrialRegionOfInterest();
    
    if startFrame > 1
        markerTable{1:startFrame-1, :} = 0;
    end
    
    if endFrame < height(markerTable)
        markerTable{endFrame+1:end, :} = 0;
    end
end