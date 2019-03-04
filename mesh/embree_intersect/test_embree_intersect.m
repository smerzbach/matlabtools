% *************************************************************************
% * Copyright 2019 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2019-03-04
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
% Script for testing ray triangle intersections with embree_intersect().

%% create a simple scene out of 3 meshes
% generate first mesh
w = 50;
h = 50;
[y0, x0] = ndgrid(4 * ((0.5 : h - 0.5) - h / 2) / h, 4 * ((0.5 : w - 0.5) - w / 2) / w);
z0 = 0.2 * rand(size(y0));
x0 = x0 + 2.0;
V0 = [x0(:), y0(:), z0(:)];

faces1 = reshape(1 : h * w, h, w);
faces1 = cat(3, faces1, faces1([2 : end, 1], :), faces1(:, [2 : end, 1]), ...
faces1([2 : end, 1], :), faces1([2 : end, 1], [2 : end, 1]), faces1(:, [2 : end, 1]));
faces1 = faces1(1 : end - 1, 1 : end - 1, :);
faces1 = reshape(permute(faces1, [3, 1, 2]), 3, [])';

% generate second mesh
n = 11;
[x1, y1, z1] = sphere(n - 1);
x1 = x1 - 1;
y1 = y1 - 1;
V1 = [x1(:), y1(:), z1(:)];

faces2 = reshape(1 : n * n, n, n);
faces2 = cat(3, faces2, faces2([2 : end, 1], :), faces2(:, [2 : end, 1]), ...
faces2([2 : end, 1], :), faces2([2 : end, 1], [2 : end, 1]), faces2(:, [2 : end, 1]));
faces2 = faces2(1 : end - 1, 1 : end - 1, :);
faces2 = reshape(permute(faces2, [3, 1, 2]), 3, [])';

% generate third mesh
n = 11;
r = 0.75;
[x2, y2, z2] = cylinder([r, 0.5 * r], n - 1);
x2 = x2 - 1;
y2 = y2 + 1.0;
V2 = [x2(:), y2(:), z2(:)];

faces3 = reshape(1 : 2 * n, 2, n);
faces3 = cat(3, faces3, faces3([2 : end, 1], :), faces3(:, [2 : end, 1]), ...
faces3([2 : end, 1], :), faces3([2 : end, 1], [2 : end, 1]), faces3(:, [2 : end, 1]));
faces3 = faces3(1 : end - 1, 1 : end - 1, :);
faces3 = reshape(permute(faces3, [3, 1, 2]), 3, [])';

% visualize meshes
figure;
trimesh(faces1, x0(:), y0(:), z0(:), 'EdgeColor', 0.5 * [1, 0, 0], 'FaceColor', 'none');
axis equal;
hold on;
trimesh(faces2, x1(:), y1(:), z1(:), 'EdgeColor', 0.5 * [0, 1, 0], 'FaceColor', 'none');
trimesh(faces3, x2(:), y2(:), z2(:), 'EdgeColor', 0.5 * [0, 0, 1], 'FaceColor', 'none');
xlabel x;
ylabel y;

%% move camera around scene
nn = 10;
cam_thetas = col(linspace(10, 70, nn));
cam_poss = [repmat(0.5, nn, 1), -5 * sind(cam_thetas), 5 * cosd(cam_thetas)];

embree_intersect('vertices', {single(V0); single(V1); single(V2)}, ...
    'faces', {int32(faces1 - 1); int32(faces2 - 1); int32(faces3 - 1)});
intersections = cell(nn, 1);
for ii = 1 : nn
    cam_fov = deg2rad(60);
    cam_focal_length = 1;
    cam_pos = cam_poss(ii, :);
    cam_look_at = [0, 0, 0];
    cam_forward = utils.normalize(cam_look_at - cam_pos);
    cam_up = utils.normalize(cross(cam_forward, [-1, 0, 0]));
    cam_side = utils.normalize(cross(cam_forward, cam_up));
    cam_mat_to_world = [cam_side; cam_up; cam_forward]';
    res_x = 1000;
    res_y = 750;
    aspect = res_x / res_y;

    cam_right = tan(cam_fov / 2) * cam_focal_length;
    cam_left = -cam_right;
    cam_top = cam_right / aspect;
    cam_bottom = -cam_top;

    cam_points_x = linspace(cam_left, cam_right, res_x);
    cam_points_y = linspace(cam_top, cam_bottom, res_y);
    [cam_points_y, cam_points_x] = ndgrid(cam_points_y, cam_points_x);
    cam_points_z = repmat(cam_focal_length, res_y, res_x); %#ok<REPMAT>
    cam_points = [cam_points_x(:), cam_points_y(:), cam_points_z(:)];
    cam_points_world = cam_points * cam_mat_to_world + cam_pos;
    cam_dirs_world = utils.normalize(cam_points_world - cam_pos);
    
    if ii == 1
        scatter3(cam_poss(:, 1), cam_poss(:, 2), cam_poss(:, 3), 100, 'o', 'filled');
        quiver3(cam_poss(1, 1), cam_poss(1, 2), cam_poss(1, 3), ...
            cam_side(1), cam_side(2), cam_side(3), 0, 'Color', 'red');
        quiver3(cam_poss(1, 1), cam_poss(1, 2), cam_poss(1, 3), ...
            cam_up(1), cam_up(2), cam_up(3), 0, 'Color', 'green');
        quiver3(cam_poss(1, 1), cam_poss(1, 2), cam_poss(1, 3), ...
            cam_forward(1), cam_forward(2), cam_forward(3), 0, 'blue');
        quiver3(repmat(cam_poss(1, 1), res_x, 1), ...
            repmat(cam_poss(1, 2), res_x, 1), ...
            repmat(cam_poss(1, 3), res_x, 1), ...
            cam_dirs_world(1 : res_y : end, 1), ...
            cam_dirs_world(1 : res_y : end, 2), ...
            cam_dirs_world(1 : res_y : end, 3), 0);
        quiver3(repmat(cam_poss(1, 1), res_x, 1), ...
            repmat(cam_poss(1, 2), res_x, 1), ...
            repmat(cam_poss(1, 3), res_x, 1), ...
            cam_dirs_world(res_y : res_y : end, 1), ...
            cam_dirs_world(res_y : res_y : end, 2), ...
            cam_dirs_world(res_y : res_y : end, 3), 0);
        quiver3(repmat(cam_poss(1, 1), res_y, 1), ...
            repmat(cam_poss(1, 2), res_y, 1), ...
            repmat(cam_poss(1, 3), res_y, 1), ...
            cam_dirs_world(1 : res_y, 1), ...
            cam_dirs_world(1 : res_y, 2), ...
            cam_dirs_world(1 : res_y, 3), 0);
        quiver3(repmat(cam_poss(1, 1), res_y, 1), ...
            repmat(cam_poss(1, 2), res_y, 1), ...
            repmat(cam_poss(1, 3), res_y, 1), ...
            cam_dirs_world(end - res_y + 1 : end, 1), ...
            cam_dirs_world(end - res_y + 1 : end, 2), ...
            cam_dirs_world(end - res_y + 1 : end, 3), 0);
        drawnow;
    end

    % raytracing
    ray_origins = repmat(cam_pos, res_x * res_y, 1);
    ray_dirs = utils.normalize(cam_dirs_world);

    intersections{ii} = embree_intersect('ray_origins', single(ray_origins), ...
        'ray_dirs', single(ray_dirs), ...
        'compute_points', true);
    disp(ii);
end
ts = cfun(@(is) reshape(is.t(:), res_y, res_x), intersections);
us = cfun(@(is) reshape(is.u(:), res_y, res_x), intersections);
vs = cfun(@(is) reshape(is.v(:), res_y, res_x), intersections);
pids = cfun(@(is) reshape(is.primitives(:), res_y, res_x), intersections);
tids = cfun(@(is) reshape(is.triangles(:), res_y, res_x), intersections);
points = cfun(@(is) reshape(is.points, res_y, res_x, 3), intersections);
normals = cfun(@(is) reshape(is.normals, res_y, res_x, 3), intersections);
sv([points, normals, ts, us, vs, pids, tids]);
