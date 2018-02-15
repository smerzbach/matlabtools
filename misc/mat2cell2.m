% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-12-11
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
% Convenience wrapper around mat2cell that allows both omitting dimensions
% (which are then replaced by the full size along the corresponding
% dimension), as well as omitting the unnecessary replication of desired
% output sizes.
%
% Examples:
% 
% mat = rand(3, 4);
% 
% % the following is equivalent to mat2cell(mat, 3, [1, 2, 1]):
% mat2cell2(mat, [], [1, 2, 1])
%
% ans =
%   1×3 cell array
%     {3×1 double}    {3×2 double}    {3×1 double}
%
%
% % the following is equivalent to mat2cell(mat, [1, 1, 1], [1, 2, 1]):
%
% mat2cell(mat, 1, [1, 2, 1])
%
% ans =
%   1×3 cell array
%     {3×1 double}    {3×2 double}    {3×1 double}
function cell_array = mat2cell2(mat, varargin)
    n = numel(varargin);
    dims = [size(mat), ones(1, n - ndims(mat))];
    
    % omitted dimensions default to 1
    varargin = [varargin, repmat({1}, 1, ndims(mat) - n)];
    
    % replace empty size specifications with full length along that
    % dimension
    empty_inds = cellfun(@isempty, varargin);
    varargin(empty_inds) = num2cell(dims(empty_inds));
    
    % replicate anything that is smaller than the actual matrix dimensions
    % with multiples thereof
    smaller_inds = cellfun(@(din, d) numel(din) == 1 && din < d, ...
        varargin, num2cell(dims));
    varargin(smaller_inds) = cfun(@(din, d) repmat(din, d / din, 1), ...
        varargin(smaller_inds), num2cell(dims(smaller_inds)));
    
    cell_array = mat2cell(mat, varargin{:});
end
