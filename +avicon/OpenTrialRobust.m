function [success] = OpenTrialRobust(vicon, trialPath, timeout, varargin)

narginchk(3,5);
p = inputParser;
addRequired(p,'vicon');
addRequired(p,'trialPath',@(x) ischar(x) | isstring(x));
addRequired(p,'timeout',@isnumeric);
addParameter(p,'SaveTrial',true,@islogical);
p.parse(vicon,trialPath,timeout,varargin{:});

if endsWith(trialPath, '.c3d'); trialPath = erase(trialPath, '.c3d'); end

saveTrial = p.Results.SaveTrial;

success = false;
startTime = tic;

if saveTrial
    saveSuccess = avicon.SaveTrialRobust(vicon, timeout);
    if ~saveSuccess; return; end
end

timeout = double(round(timeout - (tic - startTime)*(10^-7)));
vicon.OpenTrial(trialPath, timeout);
success = true;
return;
end