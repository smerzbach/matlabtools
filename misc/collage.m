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
    [varargin, transpose] = arg(varargin, 'transpose', false, false); % set to true to unroll row-wise
    [varargin, nc] = arg(varargin, 'nc', [], false); % desired number of columns
    [varargin, nr] = arg(varargin, 'nr', [], false); % desired number of rows
    [varargin, border_width] = arg(varargin, 'border_width', 0, false); % border width between the frames
    [varargin, border_value] = arg(varargin, 'border_value', 0, false); % pixel value of border between the frames
    [varargin, pad] = arg(varargin, 'pad', true, false); % add padding to match the largest input dimensions
    [varargin, pad_channels] = arg(varargin, 'pad_channels', true, false); % add padding to channels as well to allow concatenation
    [varargin, pad_value] = arg(varargin, 'pad_value', 0, false); % value to put into padded areas
    [varargin, missing_value] = arg(varargin, 'missing_value', 0, false); % value to put into padded areas
    [varargin, annotate] = arg(varargin, 'annotate', false, false); % true / false / cell array of strings
    [varargin, annot_color] = arg(varargin, 'annot_color', [0, 1, 0], false);
    [varargin, annot_font] = arg(varargin, 'annot_font', 'sans', false);
    [varargin, annot_font_size] = arg(varargin, 'annot_font_size', 10, false);
    [varargin, annot_pos] = arg(varargin, 'annot_pos', [1, 1], false);
    [varargin, annot_show_progress] = arg(varargin, 'annot_show_progress', false, false);
    arg(varargin);
    
    % input checks
    is_img = cellfun(@(im) isa(im, 'img'), ims);
    [heights, widths, ncs, higher] = cellfun(@(im) size(im), ims);
    if all(is_img)
        % ensure that wavelength sampling is the same
        assert(all(cellfun(@(im) isequal(im.wls, ims{1}.wls), ims(:))), ...
            'all input wavelength samplings must be the same.');
    else
        assert(all(ncs(:) == ncs(1)), 'all inputs must have the same number of channels.');
    end
    assert(all(higher(:) == 1), 'arrays can at most be 3D!');
    
    % compute padding if necessary
    paddings = zeros(numel(ims), 2);
    target_height = max(heights(:));
    target_width = max(widths(:));
    target_nc = max(ncs(:));
    with_target_nc = ncs == target_nc;
    if pad
        paddings = [target_height - heights(:), target_width - widths(:)];
    end
    if pad_channels
        paddings(:, 3) = col(target_nc - ncs); %#ok<NASGU>
    end
    
    % initialize output
    if nnz(is_img)
        tmp = find(is_img & with_target_nc, 1);
        imcollage = ims{tmp}.copy_without_cdata();
    else
        tmp = find(with_target_nc, 1);
        imcollage = img(zeros(0, 0, target_nc, class(ims{tmp})));
    end
    
    % convert to standard arrays
    ims(is_img) = cfun(@(im) im.cdata, ims(is_img));
    
    if isa(annotate, 'cell') || isa(annotate, 'string') || annotate
        % add text labels to images
        if isa(annotate, 'cell') || isa(annotate, 'string')
            annot_labels = annotate;
        else
            ndigits = floor(log10(numel(ims))) + 1;
            annot_labels = utils.sprintf2(['%0', num2str(ndigits), 'd'], col(1 : numel(ims)));
        end
        for ii = 1 : numel(ims)
            if annot_show_progress
                utils.multiWaitbar('annotating images', (ii - 1) / numel(ims));
            end
            ims{ii} = AddTextToImage(ims{ii}, annot_labels{ii}, ...
                annot_pos, annot_color, annot_font, annot_font_size);
        end
        if annot_show_progress
            utils.multiWaitbar('annotating images', 'Close');
        end
    end
    
    missing_value = repmat(cast(missing_value, class(ims{1})), 1, 1, target_nc);
    
    % perform the actual padding
    if pad || pad_channels
        for ii = 1 : numel(ims)
            ims{ii}(heights(ii) + 1 : target_height, ...
                widths(ii) + 1 : target_width, ...
                ncs(ii) + 1 : target_nc) = pad_value;
        end
    end
    
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
    
    imempty = reshape(missing_value, 1, 1, size(ims{1}, 3)) .* ones(size(ims{1}), class(ims{1}));
    
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
        ims(2 : end, :) = cfun(@(im) padarray(im, [border_width, 0, 0], ...
            border_value, 'pre'), ims(2 : end, :));
        ims(:, 2 : end) = cfun(@(im) padarray(im, [0, border_width, 0], ...
            border_value, 'pre'), ims(:, 2 : end));
    end
    
    imcollage.assign(cell2mat(ims));
    
    if all(~is_img(:))
        imcollage = imcollage.cdata;
    end
end
