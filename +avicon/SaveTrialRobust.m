function [success] = SaveTrialRobust(vicon, timeout)
success = false;
[path, name] = vicon.GetTrialName();
c3dFilePath = [path name '.c3d'];
startTime = tic;
while ~success
    vicon.SaveTrial(timeout);
    f = dir(c3dFilePath);
    if ~isempty(f) && f.bytes > 0; success = true;
    elseif (tic - startTime) >= timeout*10^7; break; 
    end
end
end