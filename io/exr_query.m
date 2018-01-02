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
% Function for querying meta data from images in OpenEXR format.
%
% Usage:
% 
% meta = exr_query(filename), where meta is a struct with the fields:
%
% - width, height, num_channels: image dimensions
% - compression_type: number indicating the compression type, see the
%   documentation of exr_write()
% - channel_names: cell array of strings of channel names
% - channel_types: cell array of strings indicating the pixel format of
%   each channel
% - comments: a string with the contents of a custom header attribute
%   called comments, if available
function meta = exr_query(fname)
    mex_auto();
    
    meta = exr_query_mex(fname);
end
