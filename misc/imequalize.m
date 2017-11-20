% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-11-21
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
% Given a reference image and another image as input, this function
% performs a contrast stretching such that the 1st and 99th percentiles of
% the two images match.
function im = imequalize(imref, im)
    if ~isa(imref, 'img')
        imref = img(imref);
    end
    
    was_img = true;
    if ~isa(im, 'img')
        was_img = false;
        im = img(im);
    end
    
    % compute image limits and ranges
    lims_ref = prctile(double(imref.cdata(:)), [1, 99]);
    lims = prctile(double(im.cdata(:)), [1, 99]);
    
    range_ref = lims_ref(2) - lims_ref(1);
    range = lims(2) - lims(1);
    
    % avoid division by too small numbers
    if range_ref < eps(1) || range < eps(1)
        % fallback to identity mapping
        range_ref = 1;
        range = 1;
    end
    
    im = ((im - lims(1)) ./ range) .* range_ref + lims(1);
    
    if ~was_img
        im = im.cdata;
    end
end
