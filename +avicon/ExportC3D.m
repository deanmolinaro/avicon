function [] = ExportC3D(inputPath, inputTrials, outputPath, outputTrials, vicon)
if nargin<5
    vicon = ViconNexus();
end

timeout = 60;
timeoutLong = timeout*10;

if isempty(inputTrials)
    inputTrials = erase(mlutils.GetFileNames(inputPath, '.system'), '.system');
elseif ~iscell(inputTrials)
    inputTrials = {inputTrials};
end

if isempty(outputTrials)
    outputTrials = inputTrials;
elseif ~iscell(outputTrials)
    outputTrials = {outputTrials};
end

if isempty(outputPath)
    outputPath = inputPath;
end

if length(inputTrials) ~= length(outputTrials)
    fprintf("ExportC3D.m Error - Lenght of output trials doesn't equal length of input trials.\n");
    return;
end

vicon.SaveTrial(timeoutLong);
for ii=1:length(inputTrials)
    inputTrial = inputTrials{ii};
    inputTrialPath = [inputPath '\' inputTrial];
    outputTrial = outputTrials{ii};
    outputTrialPath = [outputPath '\' outputTrial];
    
    fprintf("\nLoading %s.\n", inputTrial);
    vicon.OpenTrial(inputTrialPath, timeout);
    
    pause(1);
    
    fprintf("Exporting to %s.\n", outputTrialPath);
    vicon.SaveTrial(timeoutLong);
    
    while true
        try
            copyfile([inputTrialPath '.c3d'], [outputTrialPath, '.c3d']);
            break;
        catch
            continue;
        end
    end
end

end

