function [delCheck] = DeleteTrialRobust(filePath, timeout)

narginchk(2,2);

delCheck = false;
startTime = tic;

while ~delCheck && ((tic-startTime)*(10^-7) < timeout)
    try
        if exist(filePath, 'file'); delete(filePath); 
        else; fprintf("%s does not exist.\n", filePath); 
        end
        delCheck = true;
    catch
        fprintf("Failed to delete trial. Trying again.\n");
        pause(1);
    end
end

end