% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-06-08
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
% Given an image in the form of a 3D array and a 2D logical array with
% dimensions matching the image height and width, this function either
% extracts the pixels where the mask is true as a #channels x nnz(mask)
% array, or it assigns the contents of a #channels x nnz(mask) array to the
% image in the positions where the mask is true.
function im = immask(im, mask, assignment)
    im = permute(im, [3, 1, 2]);
    
    if exist('assignment', 'var')
        im(:, mask) = assignment;
        im = permute(im, [2, 3, 1]);
    else
        im = im(:, mask);
    end
end
