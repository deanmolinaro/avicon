function [uStruct] = InitUnlabeledStruct(vicon)
[startFrame, endFrame] = vicon.GetTrialRegionOfInterest();
numFrames = endFrame - startFrame + 1;

uStruct = struct();
uStruct.meta.startFrame = startFrame;
uStruct.meta.numFrames = numFrames;
end