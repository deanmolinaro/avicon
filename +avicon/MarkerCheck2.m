function [badLabels] = MarkerCheck2(vicon, subject, varargin)

narginchk(2,20);
p = inputParser;
addRequired(p,'vicon');
addRequired(p, 'subject', @(x) ischar(x) || isstring(x));
addParameter(p,'CheckGapFilling',true,@islogical);
addParameter(p,'MaxAllowableDist',20,@isnumeric);
addParameter(p,'MinAllowableDist',30,@isnumeric); % was 40
addParameter(p,'ModMaxDist',30,@isnumeric);
addParameter(p,'ModMaxDistNames',{},@iscell);
addParameter(p,'ModMinDist',15,@isnumeric);
addParameter(p,'ModMinDistNames',{},@iscell);
addParameter(p,'MarkerTable',table(),@istable);
addParameter(p,'Verbose',true,@islogical);

p.parse(vicon,subject,varargin{:});

checkGapFilling = p.Results.CheckGapFilling;
maxAllowableDist = p.Results.MaxAllowableDist;
minAllowableDist = p.Results.MinAllowableDist;
exemptMaxAllowableDist = p.Results.ModMaxDist;
exemptMaxNames = p.Results.ModMaxDistNames;
exemptMinAllowableDist = p.Results.ModMinDist;
exemptMinNames = p.Results.ModMinDistNames;
markerTable = p.Results.MarkerTable;
verbose = p.Results.Verbose;

if isempty(markerTable); markerTable = avicon.GetMarkerTable(vicon, subject); end

markerNames = vicon.GetMarkerNames(subject);

% exemptNames = {'LTOE', 'LMT5', 'LHEE', 'LANK', 'LMMA', 'RTOE', 'RMT5', 'RHEE', 'RANK', 'RMMA'};
% exemptMaxAllowableDist = 30;

% % kneeNames = {'LMFC', 'RMFC'};
% exemptMinAllowableDist = 15; % Was 30

% maxAllowableDist = 20;
% minAllowableDist = 30; % Was 40

badLabels = table();

% if nargin < 4
%     markerTable = GetMarkerTable(vicon, subject);
% end

% if nargin < 5; verbose = true; end

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
%     dist = abs([0; diff(sqrt(x.^2 + y.^2 + z.^2))']);
    dist = [0; sqrt(diff(x).^2 + diff(y).^2 + diff(z).^2)'];
    if any(contains(exemptMaxNames, markerName))
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
%             if (strcmp(markerName1, 'LMFC') && strcmp(markerName2, 'RMFC')) || (strcmp(markerName1, 'RMFC') && strcmp(markerName2, 'LMFC'))
            if any(cellfun(@(x) (strcmp(x{1},markerName1) & strcmp(x{2},markerName2)) | (strcmp(x{1},markerName2) & strcmp(x{2},markerName1)), exemptMinNames))
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

