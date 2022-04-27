function [names] = GetFieldNamesRobust(s, name)
if ~isfield(s, name); names = {};
elseif ~isstruct(s.(name)); names = {};
else; names = fieldnames(s.(name));
end