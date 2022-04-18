function [markerTable, gapTableOrig, gapTableFinal] = GapFillRobust(vicon, subject, pipeline, varargin)
narginchk(3, 7);
p = inputParser;
addRequired(p, 'vicon');
addRequired(p, 'subject', @(x) ischar(x) | isstring(x));
addRequired(p, 'pipeline', @(x) ischar(x) | isstring(x));
addParameter(p,'Timeout', 60, @isnumeric);
addParameter(p, 'MarkerTable', table(), @istable);

p.parse(vicon, subject, pipeline, varargin{:});
timeout = p.Results.Timeout;
markerTable = p.Results.MarkerTable;
if isempty(markerTable); markerTable = avicon.GetMarkerTable(vicon, subject); end

[startFrame, endFrame] = vicon.GetTrialRegionOfInterest();
[gapMarkers, gapTableOrig] = avicon.GapCheck(vicon, subject, markerTable, startFrame, endFrame);

if isempty(gapMarkers)
    fprintf("Gaps already filled!\n");
    gapTableFinal = gapTableOrig;
    return;
end

gapTableOld = gapTableOrig;

while true
    avicon.GapFill(vicon, pipeline, timeout);
    markerTable = avicon.GetMarkerTable(vicon, subject);
    [~, gapTableNew] = avicon.GapCheck(vicon, subject, markerTable, startFrame, endFrame);
    
    if isempty(gapTableNew)
        break;
    elseif (width(gapTableOld) ~= width(gapTableNew)) || (any(any(gapTableOld{:,:} - gapTableNew{:,:})))
        gapTableOld = gapTableNew;
    else
        break;
    end
end

gapTableFinal = gapTableNew;
end

