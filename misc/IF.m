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
% Helper function emulating an if ... else ... end statement for usage in
% anonymous functions.
%
% Usage:
%
% IF(condition, exp_true, expr_false), where
%
% - condition is either an expression evaluating to a logical or a function
%   handle returning a logical
% - fcn_true and fcn_false are two function handles with empty argument
%   lists that are executed when the condition evaluates to true or false
%   respectively
function varargout = IF(condition, fcn_true, fcn_false)
    varargout = cell(1, nargout);
    if isa(condition, 'function_handle')
        if condition()
            [varargout{:}] = fcn_true();
        else
            [varargout{:}] = fcn_false();
        end
    elseif islogical(condition)
        if condition
            [varargout{:}] = fcn_true();
        else
            [varargout{:}] = fcn_false();
        end
    else
        error('IF:invalid_input', ...
            'condition needs to be either a scalar logical or a function handle');
    end
end
