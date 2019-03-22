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
% Get directory listing without '.' and '..'.
function listing = dir_no_dots(input, as_struct, absolute) %#ok<INUSD>
    as_struct = default('as_struct', false);
    absolute = default('absolute', true);
    
    if verLessThan('matlab', '9.1')
        listing = rdir(input);
    else
        listing = dir(input);
    end
    dots = grep({listing.name}, '^\.{1,2}$');
    listing = listing(~dots);
    
    if ~as_struct
        if absolute
            if ~verLessThan('matlab', '9.1')
                listing = cfun(@(s) fullfile(s.folder, s.name), num2cell(listing));
            end
        else
            listing = {listing.name}';
        end
    end
end
