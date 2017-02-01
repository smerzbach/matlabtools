% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-01-09
% *
% * This file is part of smml.
% *
% * smml is free software: you can redistribute it and/or modify it under
% * the terms of the GNU Lesser General Public License as published by the
% * Free Software Foundation, either version 3 of the License, or (at your
% * option) any later version.
% *
% * smml is distributed in the hope that it will be useful, but WITHOUT
% * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
% * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
% * License for more details.
% *
% * You should have received a copy of the GNU Lesser General Public
% * License along with smml.  If not, see <http://www.gnu.org/licenses/>.
% *
% *************************************************************************
%
% Find the highest precision data type in the elements of a cell array.
% Return boolean flag if the elements are of the same type or not.
function [type, differ] = get_common_type(varargin)
    types = cellfun(@class, varargin, 'UniformOutput', false);
    
    differ = ~all(strcmp(types, types{1}));
    
    if any(strcmp(types, 'double'))
        type = 'double';
    elseif any(strcmp(types, 'single'))
        type = 'single';
    elseif any(strcmp(types, 'int64'))
        type = 'int64';
    elseif any(strcmp(types, 'int32'))
        type = 'int32';
    elseif any(strcmp(types, 'int16'))
        type = 'int16';
    elseif any(strcmp(types, 'int8'))
        type = 'int8';
    elseif any(strcmp(types, 'uint64'))
        type = 'uint64';
    elseif any(strcmp(types, 'uint32'))
        type = 'uint32';
	elseif any(strcmp(types, 'uint16'))
        type = 'uint16';
    elseif any(strcmp(types, 'uint8'))
        type = 'uint8';
    end
end
