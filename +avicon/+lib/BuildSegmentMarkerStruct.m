function [segmentMarkerStruct] = BuildSegmentMarkerStruct(vicon, subject, setupXml)
viconDir = vicon.GetTrialName();
vsk = avicon.thirdparty.xml_read([viconDir subject '.vsk']);
sticks = vsk.MarkerSet.Sticks;
segments = vicon.GetSegmentNames(subject);

segmentMarkerStruct = struct();
for ii=1:length(segments)
    segment = segments{ii};
    [~, ~, segmentMarkersOrig] = vicon.GetSegmentDetails(subject, segment);

    segmentMarkersAll = {};
    for jj=1:length(sticks.Stick)
        segmentMarker = sticks.Stick(jj).ATTRIBUTE.MARKER2;
        if any(contains(segmentMarkersOrig, segmentMarker))
            segmentMarkersAll{end+1} = sticks.Stick(jj).ATTRIBUTE.MARKER1;
        end
    end
    segmentMarkerStruct.(segment) = unique([segmentMarkersOrig segmentMarkersAll]);
end

if isfield(setupXml, 'rigidBodies')
    specifiedSegments = fieldnames(setupXml.rigidBodies);

    for ii=1:length(specifiedSegments)
        segment = specifiedSegments{ii};

        if ~any(strcmp(segments, segment))
            warning("%s not in subject model!", segment);
            continue;
        end

        if isfield(setupXml.rigidBodies.(segment), 'include')
            includes = setupXml.rigidBodies.(segment).include;
            if ~isempty(includes)
                includes = strsplit(includes);
            end

            for kk=1:length(includes)
                include = includes{kk};

                if any(strcmp(segmentMarkerStruct.(segment), include))
                    warning("%s already included in %s by default!", include, segment);
                else
                    segmentMarkerStruct.(segment){end+1} = include;
                end
            end
        end

        if isfield(setupXml.rigidBodies.(segment), 'ignore')
            ignores = setupXml.rigidBodies.(segment).ignore;
            if ~isempty(ignores)
                ignores = strsplit(ignores);
            end

            for kk=1:length(ignores)
                ignore = ignores{kk};

                if ~any(strcmp(segmentMarkerStruct.(segment), ignore))
                    warning("%s not in %s by default!", ignore, segment);
                else
                    segmentMarkerStruct.(segment)(strcmp(segmentMarkerStruct.(segment), ignore)) = [];
                end
            end
        end
    end
end
end