function [copyCheck] = CopyTrialRobust(origFilePath, newFilePath, timeout)

narginchk(3,3);

copyCheck = false;
startTime = tic;

while ~copyCheck && ((tic-startTime)*(10^-7) < timeout)
    try
        copyfile(origFilePath, newFilePath);
        copyCheck = true;
    catch
        fprintf("Failed to copy trial. Trying again.\n");
        pause(1);
    end
end

end