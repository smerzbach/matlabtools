% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-09-24
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
% Extract patches from image with automatic or no padding and strides. When
% padding is desired, the same options as in Matlab's padarray() are
% supported, i.e. 'circular', 'replicate' or 'symmetric'.
%
% Example:
%
% patch_size = [3, 3];
% strides = [1, 1];
% patches = impatches(im, patch_size, 'symmetric', strides);
function patches = impatches(im, patch_size, pad_type, strides)
    if isa(im, 'img')
        im = im.cdata;
    end
    [h, w, ~] = size(im);
    
    if ~exist('patch_size', 'var') || isempty(patch_size)
        patch_size = [3, 3];
    end
    
    if isscalar(patch_size)
        patch_size = [patch_size, patch_size];
    end
    
    if ~exist('pad_type', 'var') || isempty(pad_type)
        pad_type = 'replicate';
    end
    
    if ~exist('strides', 'var') || isempty(strides)
        strides = [1, 1];
    end
    
    pw2 = (patch_size - 1) / 2;
    
    switch lower(pad_type)
        case {'circular', 'replicate', 'symmetric'}
            im = padarray(im, [pw2, 0], pad_type);
            [ys, xs] = ndgrid(pw2(1) + 1 : strides(1) : h + pw2(1), ...
                pw2(2) + 1 : strides(2) : w + pw2(2));
        case 'none'
            [ys, xs] = ndgrid(pw2(1) + 1 : strides(1) : h - pw2(1), ...
                pw2(2) + 1 : strides(2) : w - pw2(2));
        otherwise
            error('impatches:invalid_pad_type', 'unsupported padding type %s', pad_type);
    end
    patches = afun(@(y, x) im(y - pw2(1) : y + pw2(1), x - pw2(2) : x + pw2(2), :), ys, xs);
end
