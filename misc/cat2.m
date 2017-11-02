% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-11-01
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
% Convenience wrapper around cat() that automatically expands a cell array
% argument using {:}. Since it is sometimes not possible chaining {:} after
% a function call, this function performs this task.
% As an additional argument, all elements in the cell array can be
% transposed or passed through a function handle.
%
% Usage:
%
% >> cell_array = {[1, 2], [3, 4], [5, 6]};
% >> cat2(1, cell_array)
% ans =
%      1     2
%      3     4
%      5     6
%
% >> cat2(2, cell_array, 'transpose', true)
% ans = 
%      1     3     5
%      2     4     6
%
% >> cat2(3, cell_array, 'fcn', @(x) repmat(reshape(x, 1, 2), 2, 1))
% ans(:,:,1) =
%      1     2
%      1     2
% ans(:,:,2) =
%      3     4
%      3     4
% ans(:,:,3) =
%      5     6
%      5     6
function C = cat2(dim, cell_array, varargin)
    [varargin, transpose] = arg(varargin, 'transpose', false);
    [varargin, fcn] = arg(varargin, 'fcn', []); %#ok<ASGLU>
    
    if transpose
        cell_array = cfun(@(x) x', cell_array);
    end
    
    if ~isempty(fcn)
        cell_array = cfun(fcn, cell_array);
    end
    
    C = cat(dim, cell_array{:});
end
