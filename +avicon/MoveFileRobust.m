function [success] = MoveFileRobust(inputFilePath, outputFilePath, timeout)

narginchk(3,3);
startTime = tic;
success = false;

if ~exist(inputFilePath, 'file')
    fprintf("%s does not exist.\n", inputFilePath);
    return;
end

while ((tic-startTime)*(10^-7) < timeout)
    try
        movefile(inputFilePath, outputFilePath);
        success = true;
        break;
    catch
        fprintf("Failed to move file. Trying again.\n");
        pause(1);
    end
end

end