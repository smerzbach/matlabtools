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
    arg(varargin);
    
    is_img = cellfun(@(im) isa(im, 'img'), ims);
    ncs = cellfun(@(im) size(im, 3), ims);
    if all(is_img)
        % ensure that wavelength sampling is the same
        assert(all(ncs(:) == ncs(1)) && all(cellfun(@(im) isequal(im.wls, ims{1}.wls), ims(:))), ...
            'all input wavelength samplings must be the same.');
    else
        assert(all(ncs(:) == ncs(1)), 'all inputs must have the same number of channels.');
    end
    
    % initialize output
    if nnz(is_img)
        imcollage = ims{is_img(1)}.copy_without_cdata();
    else
        imcollage = img(zeros(0, 0, size(ims{1}, 3), class(ims{1})));
    end
    
    % convert to standard arrays
    ims(is_img) = cfun(@(im) im.cdata, ims(is_img));
    
    n = numel(ims);
    if ~isempty(nr)
        if isempty(nc)
            nc = ceil(n / nr);
        end
    elseif ~isempty(nc)
        if isempty(nr)
            nr = ceil(n / nc);
        end
    elseif ismatrix(ims) && all(size(ims) > 1)
        [nr, nc] = size(ims);
    else
        nc = ceil(sqrt(n));
        nr = ceil(n / nc);
    end
    n2 = nr * nc;
    
    imempty = zeros(size(ims{1}), class(ims{1}));
    
    % "pad" with zero-images to match the number of rows and columns
    ims(end + 1 : n2) = repmat({imempty}, n2 - n, 1);
    ims = reshape(ims, nr, nc);
    if transpose
        ims = ims';
    end
    
    if border_width ~= 0
        if isa(border_value, 'function_handle')
            border_value = border_value(ims);
        end
        ims = cfun(@(im) padarray(im, [border_width, border_width, 0], ...
            border_value, 'pre'), ims);
    end
    
    imcollage.assign(cell2mat(ims));
end
