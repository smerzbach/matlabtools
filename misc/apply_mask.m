% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-12-14
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
% Apply logical indexing to an arbitrary number of arrays and return the
% masked arrays. The last return argument is an array of linear indices
% for indexing back into the original arrays from every element of the
% masked arrays. The mask can be specified as a cell array of subscripts to
% explicitly index into multiple dimensions instead of a logical array.
%
% Examples:
% 
% % create 5 random noise images for testing
% arrays = afun(@(i) i * rand(10, 20, 3), 1 : 5);
%
% % create random mask
% mask = repmat(rand(10, 20) < 0.5, 1, 1, 3);
%
% % apply mask to all arrays
% [masked_arrays, indices] = apply_mask(mask, arrays{:});
%
% % use subscripts instead of logical mask for indexing
% im1 = rand(10, 20, 3);
% im2 = rand(10, 20, 3);
% im3 = rand(10, 20, 3);
% [im1_cropped, im2_cropped, im3_cropped, indices] = apply_mask({1 : 5, ...
%     5 : 15, ':'}, im1, im2, im3);
function varargout = apply_mask(mask, varargin)
    if ~iscell(mask)
        % convert logical masks to cell array as well for convenience
        mask = {mask};
    end
    
    if numel(varargin) == 1 && iscell(varargin{1})
        % inputs specified as cell array of arrays
        varargin = varargin{1};
    end
    
    % make sure the mask can be applied to all inputs
    sizes = cfun(@(input) size(input), varargin);
    s1 = sizes{1};
    assert(all(cellfun(@(s) isequal(s1, s), sizes)), ...
        'input arrays must all be of the same dimensionality and size');
    
    % return array for indexing back into the unmasked arrays from every
    % element of the masked arrays
    inds_to_orig = reshape(1 : prod(s1), s1);
    inds_to_orig = inds_to_orig(mask{:});
    
    % apply mask to all inputs
    varargout = cell(1, numel(varargin));
    for ii = 1 : numel(varargin)
        varargout{ii} = varargin{ii}(mask{:});
    end
    if nargout < numel(varargin)
        varargout{1} = varargout;
        varargout(2 : end) = [];
    end
    
    varargout{end + 1} = inds_to_orig;
end
