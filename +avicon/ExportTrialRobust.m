function [] = ExportTrialRobust(vicon,filePath,varargin)
narginchk(2, 4);

p = inputParser;
addRequired(p, 'vicon');
addRequired(p, 'filePath', @(x) ischar(x) || isstring(x));
addParameter(p, 'Timeout', 600, @isnumeric);

p.parse(vicon, filePath, varargin{:});
timeout = p.Results.Timeout;

[viconDir, viconTrialName] = vicon.GetTrialName();
viconFilePath = [viconDir viconTrialName '.c3d'];

avicon.SaveTrialRobust(vicon, timeout);
copyfile(viconFilePath, filePath);
end

