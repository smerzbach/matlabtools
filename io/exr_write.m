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
% Function for writing images in OpenEXR format. Usage:
%
% exr.write(image, filename[, write_half[, channel_names[, compression]]]),
% where
% - image is is a 2D or 3D array of floats, uint32s or uint16s (for half
%   precision floats) 
% - the optional argument precision enforces the data to be interpreted as the
%   specified data type, possible values are 'single', 'half' or 'uint'
% - channel_names is a cell array of strings holding the names of each channel
% - compression is a string with one of the following values:
%   - none:  no compression
%   - rle:   run length encoding
%   - zips:  zlib compression, one scan line at a time
% 	- zip:   zlib compression, in blocks of 16 scan lines
% 	- piz:   piz-based wavelet compression
function exr_write(im, filename, precision, channel_names, compression)
    mex_auto('sources', {'exr_write_mex.cpp'}, 'headers', {'tinyexr.h'});
    
    if ~exist('precision', 'var') || isempty(precision)
        if isa(im, 'uint16')
            precision = 'half';
        elseif isa(im, 'uint32')
            precision = 'uint';
        else
            precision = 'single';
        end
    end
    
    if ~ismember(precision, {'uint', 'uint32', 'half', 'single', 'float'})
        error('exrwrite:precision', ...
            'The precision argument must be one of ''uint'', ''half'' or ''single''.');
    end
    
    % scalars are so much nicer than strings :)
    if strcmpi(precision, 'uint') || strcmpi(precision, 'uint32')
        precision = 0;
    elseif strcmpi(precision, 'half')
        precision = 1;
    else
        precision = 2;
    end
    
    % OpenEXR only supports single floats as highest precision data type
    if isa(im, 'double')
        im = single(im);
    end
    
    if exist('channel_names', 'var') && isnumeric(channel_names) && numel(channel_names) == size(im, 3)
        channel_names = cellfun(@num2str, num2cell(channel_names), 'UniformOutput', false);
    end
    if exist('channel_names', 'var') && ~iscell(channel_names)
        if ischar(channel_names) && numel(channel_names) == size(im, 3)
            channel_names = num2cell(channel_names);
        else
            channel_names = {channel_names};
        end
    end
    
    if ~exist('channel_names', 'var')
        if size(im, 3) == 1
            channel_names = {'L'};
        elseif size(im, 3) == 3
            channel_names = {'R', 'G', 'B'};
        else
            channel_names = cellfun(@(n) sprintf('C%d', n), num2cell(1 : size(im, 3)), ...
                'UniformOutput', false);
        end
    end
    
    % ensure image is handed to c++ in the right format
    if precision == 0 && ~isa(im, 'uint32')
        im = uint32(im);
    elseif precision == 1 && ~isa(im, 'uint16')
        if isfloat(im)
            im = halfprecision(im);
        elseif isa(im, 'int16')
            warning('exrwrite:halfprecision', ...
                'converting int16 to uint16');
            im = typecast(im, 'uint16');
        else
            error('exrwrite:nohalfprecision', ...
                'image is not in float or uint16 format');
        end
    elseif precision == 2 && ~isa(im, 'single')
        im = single(im);
    end
    
    if ~exist('compression', 'var') || isempty(compression)
        compression = 'none';
    end
    
    if ~(ismember(lower(compression), ...
            {'no', 'none', 'rle', 'zips', 'zip', 'piz'}) ...
            || isscalar(compression) && ismember(compression, 0 : 4))
        error('exrwrite:compression_format', ...
            ['unknown compression format (%s), please select one of: ', ...
            'none, rle, zips, zip, piz'], compression);
    end
    
    if ischar(compression)
        switch lower(compression)
            case {'no', 'none'}
                compression = 0;
            case 'rle'
                compression = 1;
            case 'zips'
                compression = 2;
            case 'zip'
                compression = 3;
            case 'piz'
                compression = 4;
            otherwise
                error('exr_write:unsupported_compression', ...
                    ['compression ', compression, ' not supported']);
        end
    end
    
    exr_write_mex(im, filename, precision(1), channel_names, compression);
end
