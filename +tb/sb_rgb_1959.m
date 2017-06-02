% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-03-29
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
% Return the Stiles & Burch 10 degree RGB color matching functions.
function [rgb, wls] = sb_rgb_1959()
    wls = 390 : 5 : 830;
    rgb = [0.00150000, -0.00040000000,  0.0062000000000;
         0.00380000, -0.00100000000,  0.0161000000000;
         0.00890000, -0.00250000000,  0.0400000000000;
         0.01880000, -0.00590000000,  0.0906000000000;
         0.03500000, -0.01190000000,  0.1802000000000;
         0.05310000, -0.02010000000,  0.3088000000000;
         0.07020000, -0.02890000000,  0.4670000000000;
         0.07630000, -0.03380000000,  0.6152000000000;
         0.07450000, -0.03490000000,  0.7638000000000;
         0.05610000, -0.02760000000,  0.8778000000000;
         0.03230000, -0.01690000000,  0.9755000000000;
        -0.00440000,  0.00240000000,  1.0019000000000;
        -0.04780000,  0.02830000000,  0.9996000000000;
        -0.09700000,  0.06360000000,  0.9139000000000;
        -0.15860000,  0.10820000000,  0.8297000000000;
        -0.22350000,  0.16170000000,  0.7417000000000;
        -0.28480000,  0.22010000000,  0.6134000000000;
        -0.33460000,  0.27960000000,  0.4720000000000;
        -0.37760000,  0.34280000000,  0.3495000000000;
        -0.41360000,  0.40860000000,  0.2564000000000;
        -0.43170000,  0.47160000000,  0.1819000000000;
        -0.44520000,  0.54910000000,  0.1307000000000;
        -0.43500000,  0.62600000000,  0.0910000000000;
        -0.41400000,  0.70970000000,  0.0580000000000;
        -0.36730000,  0.79350000000,  0.0357000000000;
        -0.28450000,  0.87150000000,  0.0200000000000;
        -0.18550000,  0.94770000000,  0.0095000000000;
        -0.04350000,  0.99450000000,  0.0007000000000;
         0.12700000,  1.02030000000, -0.0043000000000;
         0.31290000,  1.03750000000, -0.0064000000000;
         0.53620000,  1.05170000000, -0.0082000000000;
         0.77220000,  1.03900000000, -0.0094000000000;
         1.00590000,  1.00290000000, -0.0097000000000;
         1.27100000,  0.96980000000, -0.0097000000000;
         1.55740000,  0.91620000000, -0.0093000000000;
         1.84650000,  0.85710000000, -0.0087000000000;
         2.15110000,  0.78230000000, -0.0080000000000;
         2.42500000,  0.69530000000, -0.0073000000000;
         2.65740000,  0.59660000000, -0.0063000000000;
         2.91510000,  0.50630000000, -0.0053700000000;
         3.07790000,  0.42030000000, -0.0044500000000;
         3.16130000,  0.33600000000, -0.0035700000000;
         3.16730000,  0.25910000000, -0.0027700000000;
         3.10480000,  0.19170000000, -0.0020800000000;
         2.94620000,  0.13670000000, -0.0015000000000;
         2.71940000,  0.09380000000, -0.0010300000000;
         2.45260000,  0.06110000000, -0.0006800000000;
         2.17000000,  0.03710000000, -0.0004420000000;
         1.83580000,  0.02150000000, -0.0002720000000;
         1.51790000,  0.01120000000, -0.0001410000000;
         1.24280000,  0.00440000000, -0.0000549000000;
         1.00700000,  0.00007800000, -0.0000022000000;
         0.78270000, -0.00136800000,  0.0000237000000;
         0.59340000, -0.00198800000,  0.0000286000000;
         0.44420000, -0.00216800000,  0.0000261000000;
         0.32830000, -0.00200600000,  0.0000225000000;
         0.23940000, -0.00164200000,  0.0000182000000;
         0.17220000, -0.00127200000,  0.0000139000000;
         0.12210000, -0.00094700000,  0.0000103000000;
         0.08530000, -0.00068300000,  0.0000073800000;
         0.05860000, -0.00047800000,  0.0000052200000;
         0.04080000, -0.00033700000,  0.0000036700000;
         0.02840000, -0.00023500000,  0.0000025600000;
         0.01970000, -0.00016300000,  0.0000017600000;
         0.01350000, -0.00011100000,  0.0000012000000;
         0.00924000, -0.00007480000,  0.0000008170000;
         0.00638000, -0.00005080000,  0.0000005550000;
         0.00441000, -0.00003440000,  0.0000003750000;
         0.00307000, -0.00002340000,  0.0000002540000;
         0.00214000, -0.00001590000,  0.0000001710000;
         0.00149000, -0.00001070000,  0.0000001160000;
         0.00105000, -0.00000723000,  0.0000000785000;
         0.00073900, -0.00000487000,  0.0000000531000;
         0.00052300, -0.00000329000,  0.0000000360000;
         0.00037200, -0.00000222000,  0.0000000244000;
         0.00026500, -0.00000150000,  0.0000000165000;
         0.00019000, -0.00000102000,  0.0000000112000;
         0.00013600, -0.00000068800,  0.0000000075300;
         0.00009840, -0.00000046500,  0.0000000050700;
         0.00007130, -0.00000031200,  0.0000000034000;
         0.00005180, -0.00000020800,  0.0000000022700;
         0.00003770, -0.00000013700,  0.0000000015000;
         0.00002760, -0.00000008800,  0.0000000009860;
         0.00002030, -0.00000005530,  0.0000000006390;
         0.00001490, -0.00000003360,  0.0000000004070;
         0.00001100, -0.00000001960,  0.0000000002530;
         0.00000818, -0.00000001090,  0.0000000001520;
         0.00000609, -0.00000000570,  0.0000000000864;
         0.00000455, -0.00000000277,  0.0000000000442]';
end