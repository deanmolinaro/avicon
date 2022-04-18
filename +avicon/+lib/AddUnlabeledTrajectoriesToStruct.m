function [uStruct] = AddUnlabeledTrajectoriesToStruct(uStruct, marker, frame, traj)
% Modify frame since input should be in absolute frames but need to store in relative frame.
frame = frame - uStruct.meta.startFrame + 1;

if ~isfield(uStruct, marker)
    uStruct.(marker) = struct();
    uStruct.(marker).data = zeros(uStruct.meta.numFrames, 3);
    uStruct.(marker).res = ones(uStruct.meta.numFrames, 1) * -1;
end

uStruct.(marker).data(frame, :) = traj;
uStruct.(marker).res(frame) = 0;
end