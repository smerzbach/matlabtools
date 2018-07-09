% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-11-26
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
% Function for reading images in OpenEXR format. Usage:
%
% [image, channel_names] = exr.read_mex(filename, pixel_type), where
%
% - the optional argument requested_pixel_type determines if the pixel
%   values should be converted to single or half precision floats (stored
%   as uint16), or to uint32; defaults to 'single'
% - the boolean flag as_img causes the image to be returned as an img
%   object, if set to true; default is false
% - imroi is a 6 element array with [x_min, y_min, x_max, y_max, ch_min,
%   ch_max] specifying a sub-region of the pixels along all three
%   dimensions
% - strides is a 3 element array with [stride_x, stride_y, stride_channels]
%   specifying the step sizes along all three dimensions
% Returns:
% - image is is a 2D or 3D array of floats or unsigned integers (also for
%   half precision floats), or an img object if as_img is true
% - channel_names is a cell array of strings holding the names of each
%   channel
function [im, channel_names] = exr_read(fname, requested_pixel_type, as_img, imroi, strides) %#ok<INUSD>
    mex_auto('sources', {'exr_read_mex.cpp'}, 'headers', {'tinyexr.h'});
    
    requested_pixel_type = default('requested_pixel_type', 'single');
    as_img = default('as_img', false);
    imroi = default('imroi', [-1, -1, -1, -1, -1, -1]);
    strides = default('strides', [1, 1, 1]);
    
    if numel(imroi) ~= 6 || any(imroi < 1)
        meta = exr_query(fname);
        for ii = numel(imroi) + 1 : 6
            if ii == 1
                imroi(ii) = 1;
            elseif ii == 2
                imroi(ii) = 1;
            elseif ii == 3
                imroi(ii) = meta.width;
            elseif ii == 4
                imroi(ii) = meta.height;
            elseif ii == 5
                imroi(ii) = 1;
            elseif ii == 6
                imroi(ii) = meta.num_channels;
            else
                error('exr_read:invalid_roi', ...
                    'roi must be specified as [x_min, y_min, x_max, y_max, ch_min, ch_max].');
            end
        end
    end
    
    % C++ 0-based indexing
    imroi = imroi - 1;
    
    if numel(strides) ~= 3 || any(strides < 1)
        for ii = numel(strides) + 1 : 3
            strides(ii) = 1;
            if ii == 6
                error('exr_read:invalid_strides', ...
                    'strides must be specified as [stride_x, stride_y, stride_channels].');
            end
        end
    end
    
    switch lower(requested_pixel_type)
        case 'uint'
            requested_pixel_type = 0;
        case 'half'
            requested_pixel_type = 1;
        case {'single', 'float'}
            requested_pixel_type = 2;
        otherwise
            error('exr_read:invalid_requested_pixel_type', ...
                'requested_pixel_type must be one of ''uint'', ''half'' or ''single''.');
    end
    
    [im, channel_names] = exr_read_mex(fname, requested_pixel_type, imroi, strides);
    
    if as_img
        im = img(im, 'wls', channel_names);
        im.storeUserData(struct('filename', fname));
    end
end
