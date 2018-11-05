% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-11-04
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
% Given an arbitrary string, return a string that is a valid variable name,
% e.g. to be used as a field name in a struct. All illegal characters are
% replaced by underscores, and strings starting with those, are prepended
% with 'f_'.
function fieldname = make_valid_fieldname(input)
    fieldname = input;
    
    % prepend letter to strings starting with numbers
    fieldname = regexprep(fieldname, '^([\d_])', 'f$1');
    
    % replace all non alpha numeric characters by 
    fieldname = regexprep(fieldname, '[\W]', '_');
end
