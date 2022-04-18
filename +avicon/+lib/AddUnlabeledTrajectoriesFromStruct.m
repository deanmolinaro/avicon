function [] = AddUnlabeledTrajectoriesFromStruct(uStruct, c3dFilePath)
markers = fieldnames(uStruct);
markers(strcmp(markers, 'meta')) = [];

c3dHandle = btkReadAcquisition(c3dFilePath);

labels = btkGetMetaData(c3dHandle, 'POINT', 'LABELS');
labels = labels.info.values';
uLabelStart = length(labels);
uLabelEnd = uLabelStart + length(markers) - 1;
uLabels = strcat('*', strsplit(num2str(uLabelStart:uLabelEnd)));

for ii=1:length(markers)
    marker = markers{ii};
    uLabel = uLabels{ii};
    btkAppendPoint(c3dHandle, 'marker', uLabel, uStruct.(marker).data, uStruct.(marker).res);
end

% uMarkerData = [];
% uResiduals = [];
% for ii=1:length(markers)
%     marker = markers{ii};
%     uMarkerData = [uMarkerData, uStruct.(marker).data];
%     uResiduals = [uResiduals, uStruct.(marker).res];
% end
%
% c3dHandle = btkReadAcquisition(c3dFilePath);
% 
% labels = btkGetMetaData(c3dHandle, 'POINT', 'LABELS');
% labels = labels.info.values';
% uLabelStart = length(labels);
% uLabelEnd = uLabelStart + length(markers) - 1;
% uLabels = strcat('*', strsplit(num2str(uLabelStart:uLabelEnd)));
% labels = [labels, uLabels];
% 
% btkSetPointNumber(c3dHandle, length(labels));
% info = btkMetaDataInfo('Char', labels);
% btkSetMetaData(c3dHandle, 'POINT', 'LABELS', info);
% 
% for ii=1:length(labels)
%     btkSetPointLabel(c3dHandle, ii, labels{ii});
% end
% 
% markerData = btkGetMarkersValues(c3dHandle);
% markerData = [markerData, uMarkerData];
% 
% info = btkMetaDataInfo('Integer', length(labels));
% btkSetMetaData(c3dHandle, 'POINT', 'USED', info);
% 
% description = cell(length(labels), 1);
% description(:) = {char()};
% info = btkMetaDataInfo('Char', description);
% btkSetMetaData(c3dHandle, 'POINT', 'DESCRIPTIONS', info);
% 
% btkSetMarkersValues(c3dHandle, markerData);
% 
% residuals = btkGetMarkersResiduals(c3dHandle);
% residuals = [residuals, uResiduals];
% btkSetMarkersResiduals(c3dHandle, residuals);

btkWriteAcquisition(c3dHandle, c3dFilePath);
btkCloseAcquisition(c3dHandle);
end