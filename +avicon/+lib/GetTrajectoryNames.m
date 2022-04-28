function [trajNames] = GetTrajectoryNames(markers)
if ~iscell(markers)
    markers = {markers};
end

trajNames = cell(3, length(markers));
for ii=1:length(markers)
    trajNames(:, ii) = strcat(markers{ii}, '_', {'x', 'y', 'z'})';
end
trajNames = reshape(trajNames, 1, length(markers) * 3);
end

