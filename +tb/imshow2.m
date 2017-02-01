% *************************************************************************
% * Copyright 2016 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2016-12-28
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
% This function displays an image in an axes object. The first argument is
% a handle to an existing image or axes object, or empty to create a new
% axes. If the dimensions of the 2D or 3D array in the second argument
% match those of the image in the axes object, the image object's CData is
% directly updated. Otherwise, the image object is deleted and imshow() is
% called with a subsequent update of the axis limits.
function [handle, axes_handle] = imshow2(handle, im, varargin)
    assert(isa(im, 'img') || (ismatrix(im) || ndims(im) == 3), ...
        'input must be image or 2D / 3D array!');
    
    if ~isa(im, 'img')
        im = img(im);
    end
    
    % create new axes object?
    create = true;
    size_old = [-1, -1, -1];
    
    % determine if image dimensions have changed
    if isa(handle, 'matlab.graphics.primitive.Image')
        create = false;
        size_old = tb.size2(handle.CData, 1 : 3);
    end
    size_new = [im.h, im.w, im.nc];
    
    if create
        if isa(handle, 'matlab.graphics.axis.Axes')
            axes_handle = handle;
        else
            axes_handle = axes();
        end
    else
        axes_handle = handle.Parent;
    end
    
    if create
        handle = imshow(im.cdata, 'Parent', axes_handle, varargin{:});
    else
        % we can simply update the image handle
        handle.CData = im.cdata;
    end

    if any(size_old ~= size_new) || numel(varargin) ~= 0
        axes_handle.XLim = [0.5, size_new(2) + 0.5];
        axes_handle.YLim = [0.5, size_new(1) + 0.5];
    end
end
