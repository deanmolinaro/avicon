function [] = RemoveUnlabeledTrajectories(c3dFilePath)
c3dHandle = btkReadAcquisition(c3dFilePath);
markerData = btkGetMarkersValues(c3dHandle);
markerResiduals = btkGetMarkersResiduals(c3dHandle);
meta = btkGetMetaData(c3dHandle);
labels = meta.children.POINT.children.LABELS.info.values;

unlabeledNames = labels(contains(labels, '*'));
for ii=1:length(unlabeledNames)
    markerIdx = str2double(erase(unlabeledNames{ii}, '*'))+1;
    markerData(:, markerIdx*3-2:markerIdx*3) = 0.0;
    markerResiduals(:, markerIdx) = -1;
end

btkSetMarkersValues(c3dHandle, markerData);
btkSetMarkersResiduals(c3dHandle, markerResiduals);
btkWriteAcquisition(c3dHandle, c3dFilePath);
btkCloseAcquisition(c3dHandle);
end