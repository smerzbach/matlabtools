% *************************************************************************
% * Copyright 2016 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2016-12-28
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
% Convenience wrapper around size() that allows to specify multiple
% dimensions at once.
function sizes = size2(arr, dims)
    if ~exist('dims', 'var')
        dims = 1 : ndims(arr);
    end
    
    s = size(arr);
    md = max(dims);
    s = [s, ones(1, md - numel(s))];
    sizes = s(dims);
end
