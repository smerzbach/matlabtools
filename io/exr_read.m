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
function [im, channel_names] = exr_read(fname, varargin)
    % avoid expensive checks in mex_auto when it's not necessary
    [varargin, dontbuild] = arg(varargin, 'dontbuild', false, false);
    [varargin, pixel_type] = arg(varargin, 'pixel_type', 'single', false);
    [varargin, as_img] = arg(varargin, 'as_img', false, false);
    [varargin, imroi] = arg(varargin, 'imroi', [0, 0, 0, 0], false);
    [varargin, strides] = arg(varargin, 'imroi', [1, 1], false);
    [varargin, channel_mask] = arg(varargin, 'channel_mask', [], false);
    arg(varargin);
    
    % get folder containing this script
    mdir = fileparts(mfilename('fullpath'));
    header_dir = fullfile(mdir, '..', 'external', 'tinyexr');
    
    % initiate automatic MEX compilation
    mex_auto(...
        'dontbuild', dontbuild, ...
        'sources', {'exr_read_mex.cpp'}, ...
        'headers', {'tinyexr.h'}, ...
        ['-I', header_dir]);
    
    assert(numel(imroi) == 4, 'exr_read:invalid_roi', ...
        'roi must be specified as [x_min, y_min, x_max, y_max].');
    assert(numel(strides) == 2, 'exr_read:invalid_strides', ...
        'strides must be specified as [stride_x, stride_y, stride_channels].');
    
    if any(imroi < 1)
        meta = exr_query(fname);
        if imroi(1) < 1
            imroi(1) = 1;
        end
        if imroi(2) < 1
            imroi(2) = 1;
        end
        if imroi(3) < 1
            imroi(3) = meta.width + imroi(3);
        end
        if imroi(4) < 1
            imroi(4) = meta.height + imroi(4);
        end
    end
    
    if isempty(channel_mask)
        if ~exist('meta', 'var')
            meta = exr_query(fname);
        end
        channel_mask = 1 : meta.num_channels;
    end
    
    % C++ 0-based indexing
    imroi = imroi - 1;
    channel_mask = channel_mask - 1;
    
    switch lower(pixel_type)
        case 'uint'
            pixel_type = 0;
        case 'half'
            pixel_type = 1;
        case {'single', 'float'}
            pixel_type = 2;
        otherwise
            error('exr_read:invalid_requested_pixel_type', ...
                'requested_pixel_type must be one of ''uint'', ''half'' or ''single''.');
    end
    
    [im, channel_names] = exr_read_mex(fname, pixel_type, imroi, strides, channel_mask);
    
    if as_img
        im = img(im, 'wls', channel_names);
        im.storeUserData(struct('filename', fname));
    end
end
