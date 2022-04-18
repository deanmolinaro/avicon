function [segmentMarkerStruct] = BuildConservativeSegmentMarkerStruct(vicon, subject)
segments = vicon.GetSegmentNames(subject);
segmentMarkerStruct = struct();
for ii=1:length(segments)
    [~, ~, segmentMarkers] = vicon.GetSegmentDetails(subject, segments{ii});
    segmentMarkerStruct.(segments{ii}) = segmentMarkers;
end
end