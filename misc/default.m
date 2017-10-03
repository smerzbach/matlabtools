% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-08-17
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
% Convenience wrapper that achieves the following functionality:
%
% if ~exist('variable', 'var') || isempty(variable)
%     variable = default_expression;
% end
%
% The usage is:
%
% default_variable = 'test';
% default('variable', default_variable);
%
% or
%
% default('variable', 1 + 1);
%
% or
% 
% variable = default('variable', some_class('arg1', 12));
function p = default(name, default)
    var_name = inputname(1);
    default_var_name = inputname(2);
    stack = dbstack(0, '-completenames');
    
    % input variable name or string representing a variable name?
    if isempty(var_name)
        var_name = name;
    end
    
    % default value a variable name?
    if ~isempty(default_var_name)
        default = default_var_name;
    else
        if ischar(default)
            default_str = ['''', default, ''''];
        else
            try
                if isempty(default)
                    default_str = '[]';
                else
                    default_str = string(default);
                end
            catch
                try
                    % parse expression for default arg from source code
                    fid = fopen(stack(end).file, 'r');
                    for li = 1 : stack(end).line
                        line = fgets(fid);
                    end
                    fclose(fid);
                    tokens = regexp(line, 'default\(.*, (.*)\)', 'tokens');
                catch
                    error('default:unsupported_input', ...
                        ['default value input type ''%s'' not supported. ', ...
                        'please store it in a variable and use this ', ...
                        'as the second argument to default().'], ...
                        class(default));
                end
                default_str = tokens{1}{1};
            end
        end
        default = default_str;
    end
    
    evalin('caller', sprintf('if ~exist(''%s'', ''var'') || isempty(%s); %s = %s; end', ...
        var_name, var_name, var_name, default));
    
    p = evalin('caller', var_name);
end
