function [fileNames] = GetFileNames(inputDir, ext)
fileNames = dir(inputDir);
fileNames = {fileNames(:).name};
if ~strcmpi(ext, 'dir')
    fileNames(~contains(fileNames, ext)) = [];
else
    fileNames(contains(fileNames, '.')) = [];
end
end

