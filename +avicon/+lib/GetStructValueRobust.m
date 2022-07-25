function [val] = GetStructValueRobust(s, fields, default)
val = default;
for ii=1:length(fields)
    f = fields{ii};
    if ~isfield(s, f); return; end
    s = s.(f);
end
val = s;
end