% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-08-08
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
% Concatenate a cell array of images in an as-square-like manner as
% possible. Similar to Matlab's montage(), but just produces a single
% concatenated image as output.
%
% Usage: imcollage = collage(images, ...),
%
% with the following optional name-value pairs:
%
% - 'transpose': when set to true, the array of images is transposed
% - 'nc' or 'nr': specify a fixed number of columns or rows
% - 'border_width': nonnegative integer specifying th number of pixels to
%    add between two images
% - 'border_value': scalar value or function handle returning a scalar that
%    is applied to all images to determine the pixel value that is assigned
%    to all channels in the border between two images
function imcollage = collage(ims, varargin)
    [varargin, transpose] = arg(varargin, 'transpose', true, false); % set to true to unroll row-wise
    [varargin, nc] = arg(varargin, 'nc', [], false); % desired number of columns
    [varargin, nr] = arg(varargin, 'nr', [], false); % desired number of rows
    [varargin, border_width] = arg(varargin, 'border_width', 0, false); % border width between the frames
    [varargin, border_value] = arg(varargin, 'border_value', 0, false); %#ok<ASGLU> % pixel value of border between the frames
    
    non_img = cellfun(@(im) ~isa(im, 'img'), ims);
    ims(non_img) = cfun(@(im) img(im), ims(non_img));
    
    assert(all(cellfun(@(im) isequal(im.wls, ims{1}.wls), ims(:))), ...
        'all input wavelength samplings must be the same.');
    
    % initialize output
    imcollage = ims{1}.copy_without_cdata();
    
    n = numel(ims);
    if ~isempty(nr)
        if isempty(nc)
            nc = ceil(n / nr);
        end
    elseif ~isempty(nc)
        if isempty(nr)
            nr = ceil(n / nc);
        end
    else
        nc = ceil(sqrt(n));
        nr = ceil(n / nc);
    end
    n2 = nr * nc;
    
    imempty = ims{1}.copy();
    imempty.set_zero();
    
    ims(end + 1 : n2) = repmat({imempty}, n2 - n, 1);
    ims = reshape(ims, nr, nc);
    if transpose
        ims = ims';
    end
    ims = cfun(@(im) im.cdata, ims);
    
    if border_width ~= 0
        if isa(border_value, 'function_handle')
            border_value = border_value(ims);
        end
        ims = cfun(@(im) padarray(im, [border_width, border_width, 0], ...
            border_value), ims);
    end
    
    imcollage.assign(cell2mat(ims));
end
