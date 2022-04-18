function [badLabels] = MarkerCheck(vicon, subject, checkGapFilling, markerTable, verbose)

if nargin < 3; checkGapFilling = true; end

markerNames = vicon.GetMarkerNames(subject);

exemptNames = {'LTOE', 'LMT5', 'LHEE', 'LANK', 'LMMA', 'RTOE', 'RMT5', 'RHEE', 'RANK', 'RMMA'};
exemptMaxAllowableDist = 30;

% kneeNames = {'LMFC', 'RMFC'};
exemptMinAllowableDist = 15; % Was 30

maxAllowableDist = 20;
minAllowableDist = 30; % Was 40

badLabels = table();

if nargin < 4
    markerTable = GetMarkerTable(vicon, subject);
end

if nargin < 5; verbose = true; end

%% Check for max marker distance traveled.
fprintf("Check for bad labeling.\n");
for ii=1:length(markerNames)
    markerName = markerNames{ii};
    
%     if checkGapFilling
%         x = markerTable.([markerName '_x'])';
%         y = markerTable.([markerName '_y'])';
%         z = markerTable.([markerName '_z'])';
%     else
%         [x, y, z, e] = vicon.GetTrajectory(subject, markerName);
%     end
    
    x = markerTable.([markerName '_x'])';
    y = markerTable.([markerName '_y'])';
    z = markerTable.([markerName '_z'])';
    
    x(x==0) = NaN;
    y(y==0) = NaN;
    z(z==0) = NaN;
    dist = abs([0; diff(sqrt(x.^2 + y.^2 + z.^2))']);
    if any(contains(exemptNames, markerName))
        badIdx = find(dist>=exemptMaxAllowableDist);
    else
        badIdx = find(dist>=maxAllowableDist);
    end
    if any(badIdx)
        for jj=1:length(badIdx)
            badLabels = [badLabels; cell2table({markerName, badIdx(jj), dist(badIdx(jj))}, ...
                'VariableNames', {'MarkerName', 'Idx', 'Dist'})];
        end
    end
end

%% Check for bad gap filling
if checkGapFilling
    fprintf("Check for bad gap filling.\n");
    for ii=1:length(markerNames)-1
        markerName1 = markerNames{ii};
        x1 = markerTable.([markerName1 '_x']);
        y1 = markerTable.([markerName1 '_y']);
        z1 = markerTable.([markerName1 '_z']);
        x1(x1==0) = NaN;
        y1(y1==0) = NaN;
        z1(z1==0) = NaN;
        for jj=ii+1:length(markerNames)
            markerName2 = markerNames{jj};
            x2 = markerTable.([markerName2 '_x']);
            y2 = markerTable.([markerName2 '_y']);
            z2 = markerTable.([markerName2 '_z']);
            x2(x2==0) = NaN;
            y2(y2==0) = NaN;
            z2(z2==0) = NaN;
            dist = abs(sqrt((x1-x2).^2 + (y1-y2).^2 + (z1-z2).^2));
            [minDist, minIdx] = min(dist);
            if (strcmp(markerName1, 'LMFC') && strcmp(markerName2, 'RMFC')) || (strcmp(markerName1, 'RMFC') && strcmp(markerName2, 'LMFC'))
                if minDist <= exemptMinAllowableDist
                    badLabels = [badLabels; cell2table({[markerName1 '-' markerName2], minIdx, minDist}, ...
                        'VariableNames', {'MarkerName', 'Idx', 'Dist'})];
                end
            elseif minDist <= minAllowableDist
%                 fprintf("TOO CLOSE: %s & %s Frame = %i, Dist = %.1f/%.1f\n", markerName1, markerName2, minIdx, minDist, minAllowableDist);
                badLabels = [badLabels; cell2table({[markerName1 '-' markerName2], minIdx, minDist}, ...
                    'VariableNames', {'MarkerName', 'Idx', 'Dist'})];
            end
        end
    end
end

%% Sort then print bad marker labels.
if ~isempty(badLabels)
    [sortedBadIdx, sortIdx] = sort(badLabels.Idx);
    badLabels.MarkerName = badLabels.MarkerName(sortIdx);
    badLabels.Idx = badLabels.Idx(sortIdx);
    badLabels.Dist = badLabels.Dist(sortIdx);
    if verbose
        for ii=1:height(badLabels)
            fprintf("%s Frame = %i, Dist = %.1f/%.1f\n", badLabels.MarkerName{ii}, badLabels.Idx(ii), badLabels.Dist(ii), maxAllowableDist);
        end
    end
%     fprintf("Waiting to correct incorrect labels. ");
%     input('');
elseif verbose
        fprintf("Did not find any bad marker labels.\n");
end
end

