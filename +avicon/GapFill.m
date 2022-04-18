function [] = GapFill(vicon, pipeline, timeout)
try
    vicon.RunPipeline(pipeline, 'shared', timeout);
catch e
    fprintf("Gap failing did not complete successfully.\n");
    fprintf("May need to complete gap filling manually.\n");
    fprintf("%s\n", e.identifier);
    fprintf("%s\n", e.message);
end
end

