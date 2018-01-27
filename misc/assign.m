% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-01-25
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
% Function for performing assignment to an arbitrary array, e.g. in
% anonymous functions. Both subscripts (specified as a cell array of
% indices or ':') or linear indices are supported.
%
% Example:
%
% input = {rand(50, 75, 3), rand(25, 40, 3)};
% % add fixed width black border to cell array of images
% output = cfun(@(im) assign(im, {':', 1 : 10, ':'}, 0), input);
% iv(output);
% 
% % add a white diagonal in each image
% output = cfun(@(im) assign(im, sub2ind(size(im), ...
%     repmat(1 : min(tb.size2(im, 1 : 2)), 1, size(im, 3)), ...
% 	repmat(1 : min(tb.size2(im, 1 : 2)), 1, size(im, 3)), ...
%     repmat(1 : size(im, 3), 1, min(tb.size2(im, 1 : 2)))), 1), output);
% iv(output);
function mat = assign(mat, inds, vals)
    if iscell(inds)
        mat(inds{:}) = vals;
    else
        mat(inds) = vals;
    end
end
