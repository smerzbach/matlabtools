% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-02-09
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
% Given a cell array of img objects, this function returns an array with
% size num_channels x total_num_pixels array, along with their wavelength
% sampling.
function [specs, wls] = ims2specs(ims)
    assert(all(cellfun(@(im) all(im.wls == ims{1}.wls), ims)), ...
        'all images must have the same wavelength sampling');
    specs = cat2(1, cfun(@(im) reshape(single(im), [], im.nc), ims))';
    wls = ims{1}.wls;
end
