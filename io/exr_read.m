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
% - the optional argument pixel_type determines if the pixel values should
%   be converted to single or half precision floats, or to uint32
% - image is is a 2D or 3D array of floats or unsigned integers (also for
%   half precision floats)
% - channel_names is a cell array of strings holding the names of each
%   channel
function [im, channel_names] = exr_read(fname, requested_pixel_type, as_img) %#ok<INUSD>
    mex_auto('sources', {'exr_read_mex.cpp'}, 'headers', {'tinyexr.h'});
    
    requested_pixel_type = default('requested_pixel_type', 'single');
    as_img = default('as_img', false);
    
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
    
    [im, channel_names] = exr_read_mex(fname, requested_pixel_type);
    
    if as_img
        im = img(im, 'wls', channel_names);
        im.storeUserData(struct('filename', fname));
    end
end
