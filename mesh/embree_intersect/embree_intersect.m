% *************************************************************************
% * Copyright 2019 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2019-03-03
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
% Perform intersectoin tests between multiple triangle meshes and an array
% of rays, specified as ray origins and ray directions. This function is
% just a wrapper around a MEX file that makes use of Intel's Embree ray
% tracing kernels.
%
% In a first call, the geometry (vertices and triangle indices) need to be
% provided to be preprocessed by Embree.
%
% Afterwards, arrays of ray origins and directoins can be tested against
% the currently loaded geometry, potentially in multiple calls.
%
% Usage: each vertex array is NV x 3, each triangle index array is NF x 3,
% ray origins and directions are num_rays x 3
%
% embree_intersect('vertices', {vertices1; vertices2; vertices3}, ...
%     'faces', {faces1; faces2; faces3});
%
% intersections1 = embree_intersect('ray_origins', ray_origins1, ...
%     'ray_dirs', ray_dirs1);
%
% intersections2 = embree_intersect('ray_origins', ray_origins2, ...
%     'ray_dirs', ray_dirs2);
function varargout = embree_intersect(varargin)
    
    [varargin, vertices] = arg(varargin, 'vertices', {{}}, false);
    [varargin, faces] = arg(varargin, 'faces', {{}}, false);
    [varargin, ray_origins] = arg(varargin, 'ray_origins', {{}}, false);
    [varargin, ray_dirs] = arg(varargin, 'ray_dirs', {{}}, false);
    [varargin, compute_points] = arg(varargin, 'compute_points', {{}}, false);
    arg(varargin);
    
    if ~isempty(vertices) && ~isempty(faces)
        % geometry loading mode
        if ~iscell(vertices)
            vertices = {vertices};
        end
        if ~iscell(faces)
            faces = {faces};
        end
        vertices = cfun(@single, vertices);
        faces = cfun(@int32, faces);
        
        embree_intersect_mex(vertices, faces);
    elseif ~isempty(ray_origins) && ~isempty(ray_dirs)
        ray_origins = single(ray_origins);
        ray_dirs = single(ray_dirs);
        
        [prim_triangle_ids, uvts, normals] = embree_intersect_mex(ray_origins, ray_dirs);
        varargout = {struct(...
            'primitives', prim_triangle_ids(:, 1), ...
            'triangles', prim_triangle_ids(:, 2), ...
            'u', uvts(:, 1), ...
            'v', uvts(:, 2), ...
            't', uvts(:, 3), ...
            'normals', normals ./ sqrt(sum(normals .^ 2, 2)))};
        
        if compute_points
            varargout{1}.points = ray_origins + uvts(:, 3) .* ray_dirs;
            varargout{1}.points(prim_triangle_ids(:, 1) == -1, :) = nan;
        end
    else
        error('embree_intersect:invalid_inputs', ...
            'inputs must be either vertex & face arrays, or ray origins and ray directions.');
    end
end
