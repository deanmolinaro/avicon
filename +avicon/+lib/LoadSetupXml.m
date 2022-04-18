function [setupXml, setupFilePath] = LoadSetupXml(setupDir)
% setupFileName = avicon.GetFileNames(setupDir, '.xml');
fprintf("Please select setup xml file.\n");
[setupFileName, setupDir] = uigetfile([setupDir '\*.xml']);
setupFilePath = [setupDir setupFileName];
fprintf("Using %s as setup file.\n", setupFilePath);
setupXml = avicon.thirdparty.xml_read(setupFilePath);
end