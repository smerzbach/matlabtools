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
% Return the CIE 1931 RGB color matching functions.
function [rgb, wls] = cie_rgb_1931()
    wls = 360 : 830;
    
    rgb = [0.000003523064308, -0.000001330760058, 0.000108115991987;
        0.000003925494975, -0.000001489375943, 0.000121454905663;
        0.000004372841561, -0.000001666994206, 0.000136486356252;
        0.000004871506371, -0.000001866097610, 0.000153408565801;
        0.000005427941601, -0.000002089114043, 0.000172419922652;
        0.000006048516296, -0.000002338521280, 0.000193720478082;
        0.000006743790106, -0.000002619740496, 0.000217726631427;
        0.000007524023348, -0.000002937427911, 0.000244865757403;
        0.000008395302372, -0.000003292897248, 0.000275342397217;
        0.000009363746783, -0.000003687412336, 0.000309359429138;
        0.000010435442931, -0.000004122286897, 0.000347124720248;
        0.000011609226758, -0.000004593712806, 0.000388468651009;
        0.000012910491309, -0.000005116274016, 0.000434497074286;
        0.000014385033858, -0.000005718839107, 0.000487321919614;
        0.000016078801344, -0.000006430326549, 0.000549060105335;
        0.000018037374860, -0.000007279621550, 0.000621828549795;
        0.000020341539870, -0.000008310559121, 0.000709096138824;
        0.000022977294445, -0.000009509120704, 0.000809996482434;
        0.000025848853436, -0.000010817253183, 0.000920134439082;
        0.000028860265399, -0.000012177003216, 0.001035114867229;
        0.000031916410357, -0.000013530434089, 0.001150542625331;
        0.000034945449448, -0.000014836571044, 0.001263494270776;
        0.000038131968639, -0.000016187889987, 0.001381629289730;
        0.000041763822262, -0.000017726738296, 0.001516423607950;
        0.000046127700595, -0.000019594881318, 0.001679349825320;
        0.000051511790556, -0.000021934799465, 0.001881895508154;
        0.000058176840612, -0.000024877532145, 0.002134445695774;
        0.000066080113291, -0.000028399133068, 0.002435919479362;
        0.000075044339546, -0.000032406477785, 0.002780579727508;
        0.000084894744737, -0.000036807273311, 0.003162672679437;
        0.000095455556461, -0.000041509060369, 0.003576494462469;
        0.000106514085121, -0.000046406076188, 0.004015542994340;
        0.000118462118591, -0.000051702861976, 0.004495649431870;
        0.000132035838920, -0.000057773245889, 0.005044485040759;
        0.000147971760748, -0.000064991056085, 0.005689737716074;
        0.000167005400950, -0.000073730287012, 0.006459062094150;
        0.000190058691600, -0.000084453401352, 0.007391587074142;
        0.000216667340787, -0.000096945547691, 0.008473626687497;
        0.000245486032770, -0.000110562836960, 0.009653796192019;
        0.000275171114743, -0.000124661380094, 0.010880710845510;
        0.000304380596836, -0.000138598618373, 0.012102952647040;
        0.000332138335242, -0.000151937033168, 0.013286730724072;
        0.000360178772877, -0.000165548335865, 0.014513113237838;
        0.000391217485276, -0.000180747909348, 0.015903045570215;
        0.000427988340274, -0.000198855626429, 0.017577406585612;
        0.000473206913407, -0.000221187202576, 0.019657241442106;
        0.000528403106385, -0.000248472666977, 0.022228307782256;
        0.000592792013112, -0.000280444286830, 0.025276470644616;
        0.000665621986227, -0.000316920802043, 0.028772961225302;
        0.000746154681862, -0.000357725941332, 0.032688844426766;
        0.000833630137971, -0.000402676781666, 0.036995351445125;
        0.000926920883513, -0.000451307700786, 0.041685331652825;
        0.001026502518367, -0.000503839869265, 0.046843761112203;
        0.001134069574969, -0.000561126373600, 0.052580892522536;
        0.001251313259883, -0.000624025289097, 0.059006645995773;
        0.001379908150306, -0.000693388039316, 0.066231107937527;
        0.001519448489699, -0.000768873722246, 0.074241806322993;
        0.001666162737759, -0.000848588253054, 0.083027599476678;
        0.001816691762473, -0.000931053281065, 0.092700901915492;
        0.001967669780080, -0.001014785466796, 0.103373795569017;
        0.002115804176032, -0.001098319763067, 0.115158694954161;
        0.002259348866855, -0.001180969377046, 0.128158868436312;
        0.002392799532269, -0.001259363536160, 0.142112569788227;
        0.002506876985820, -0.001327954683778, 0.156583777022720;
        0.002592401817249, -0.001381195263266, 0.171137798501919;
        0.002640094840104, -0.001413536055054, 0.185335951540014;
        0.002644967244461, -0.001421757613806, 0.198948750880590;
        0.002605372723047, -0.001405091662793, 0.211991162953414;
        0.002517486521587, -0.001361735578697, 0.224409973785984;
        0.002377317592144, -0.001289861794150, 0.236145317659237;
        0.002180974662980, -0.001187657708215, 0.247143980600670;
        0.001924100840095, -0.001053270809472, 0.257316164031687;
        0.001608139552493, -0.000886744334274, 0.266618631599630;
        0.001238071295413, -0.000689137573263, 0.275068012670906;
        0.000818888204651, -0.000461511480014, 0.282679273675282;
        0.000355567449573, -0.000204920356357, 0.289469043979163;
        -0.000150341445461, 0.000080994992021, 0.295430671835987;
        -0.000700580240287, 0.000395840449137, 0.300580786612162;
        -0.001295161573224, 0.000737435905054, 0.304960961723703;
        -0.001934194865503, 0.001103627856825, 0.308616096459910;
        -0.002617678454188, 0.001492232868638, 0.311586101300158;
        -0.003344697724125, 0.001901734342277, 0.313897583230698;
        -0.004116050884903, 0.002333416064831, 0.315602093287391;
        -0.004934431893879, 0.002789310144872, 0.316781115365630;
        -0.005802651113976, 0.003271478623836, 0.317521122170731;
        -0.006723369243819, 0.003781933655058, 0.317901934661446;
        -0.007697234828698, 0.004321656371156, 0.317961800380511;
        -0.008722751225637, 0.004889948338741, 0.317730652187457;
        -0.009799652364773, 0.005486343935553, 0.317278333421193;
        -0.010927655546876, 0.006110410798066, 0.316678013293908;
        -0.012106378296520, 0.006761683304020, 0.316001198081153;
        -0.013333974754034, 0.007439546166859, 0.315307753501991;
        -0.014607335227899, 0.008144465008842, 0.314547791457202;
        -0.015924364417948, 0.008877603885617, 0.313631513368190;
        -0.017283066800213, 0.009640160111565, 0.312467457719716;
        -0.018681263927693, 0.010433247854237, 0.310967488869826;
        -0.020117043423253, 0.011258413644707, 0.309080055782658;
        -0.021582589484681, 0.012113695217739, 0.306805158458213;
        -0.023066095261829, 0.012995035007931, 0.304136145149928;
        -0.024555587610882, 0.013898392079246, 0.301058049428036;
        -0.026039425975358, 0.014819708866280, 0.297564219545975;
        -0.027511956370677, 0.015756690516469, 0.293689577173199;
        -0.028968855161573, 0.016712014357805, 0.289379245400566;
        -0.030400976196524, 0.017688823340538, 0.284483559930415;
        -0.031799007030340, 0.018690576372881, 0.278856182338367;
        -0.033153967805163, 0.019720599328116, 0.272349111263401;
        -0.034457710131453, 0.020779889968227, 0.264849267013950;
        -0.035712894707836, 0.021868780880542, 0.256527932064006;
        -0.036926505868201, 0.022988103533381, 0.247662816832561;
        -0.038105527946441, 0.024139520863385, 0.238529968801967;
        -0.039256945276445, 0.025324196926203, 0.229403772517935;
        -0.040383751144167, 0.026542963190155, 0.220435555214768;
        -0.041483451144647, 0.027795653361576, 0.211577091729885;
        -0.042554714928570, 0.029082932615124, 0.202813415633521;
        -0.043596212146626, 0.030405299831789, 0.194129560495910;
        -0.044606945036829, 0.031763087598902, 0.185510559887284;
        -0.045587578773836, 0.033160120670734, 0.176988009603819;
        -0.046541439230928, 0.034595234991637, 0.168616786554654;
        -0.047471020813066, 0.036060947346729, 0.160416679685815;
        -0.048378152750555, 0.037550107108455, 0.152405149832029;
        -0.049265163154691, 0.039055397355595, 0.144601320764663;
        -0.050135876779750, 0.040573824802197, 0.137017664508523;
        -0.050994949848323, 0.042116032242760, 0.129676464414594;
        -0.051845541940029, 0.043696320932395, 0.122609815160040;
        -0.052690812634485, 0.045328493245218, 0.115849977715691;
        -0.053533921511307, 0.047026850436341, 0.109428880465047;
        -0.054375533745154, 0.048798543133318, 0.103369804521079;
        -0.055226125836860, 0.050648393852406, 0.097659280096997;
        -0.056103657502145, 0.052587045388106, 0.092274857548151;
        -0.057026421044056, 0.054624641653927, 0.087194253523557;
        -0.058012542471977, 0.056771991738032, 0.082394852084901;
        -0.059074660104377, 0.059040403609579, 0.077867507080660;
        -0.060209780655302, 0.061433036848184, 0.073608892637552;
        -0.061412582727504, 0.063947563342551, 0.069605871556116;
        -0.062677911217394, 0.066581654981382, 0.065845140343226;
        -0.064000278434060, 0.069332484772389, 0.062313395505758;
        -0.065369706757657, 0.072192236913360, 0.058995171732953;
        -0.066792349053756, 0.075174880072077, 0.055878495880997;
        -0.068286996506395, 0.078311344870056, 0.052954720679360;
        -0.069872440299616, 0.081632728222479, 0.050215697738502;
        -0.071567471617457, 0.085169960750861, 0.047652946081556;
        -0.073385061365717, 0.088944826925197, 0.045263472422568;
        -0.075290786755932, 0.092928557941601, 0.043023496767577;
        -0.077233263045906, 0.097077252272760, 0.040892776049879;
        -0.079161105493442, 0.101347174685024, 0.038830900909104;
        -0.081022264181687, 0.105694091063752, 0.036797628278549;
        -0.082784644433475, 0.110088567430403, 0.034768014108604;
        -0.084448246248808, 0.114537255531541, 0.032752368606440;
        -0.086010242635395, 0.119051629629985, 0.030763662677855;
        -0.087468305481940, 0.123642831401228, 0.028815199815975;
        -0.088819940383482, 0.128322168814427, 0.026919950926596;
        -0.090054837132848, 0.133085983408972, 0.025077250835063;
        -0.091149382029741, 0.137899852396402, 0.023287432128703;
        -0.092080792842184, 0.142728188932606, 0.021565461237282;
        -0.092826453631863, 0.147536237641793, 0.019925972003240;
        -0.093363415873138, 0.152288744267182, 0.018384263443669;
        -0.093680537890515, 0.156972571609311, 0.016946654717804;
        -0.093768008357814, 0.161564937436202, 0.015609404218204;
        -0.093605206860692, 0.166016286235964, 0.014372162728175;
        -0.093171845572132, 0.170276397322049, 0.013234481254822;
        -0.092447304077789, 0.174295715182564, 0.012195910805254;
        -0.091416782241562, 0.178037322624085, 0.011259028931264;
        -0.090092086913599, 0.181514523139739, 0.010415787019510;
        -0.088491510396948, 0.184763901335621, 0.009649871661547;
        -0.086634176462977, 0.187817053007903, 0.008944919560831;
        -0.084538543708397, 0.190707236889398, 0.008284633938284;
        -0.082210266117786, 0.193449419409873, 0.007660201229710;
        -0.079655829144043, 0.196026971202921, 0.007070972889820;
        -0.076896185788841, 0.198434903458621, 0.006512658542079;
        -0.073951623879195, 0.200666564430408, 0.005981067586154;
        -0.070842930123115, 0.202715302371721, 0.005471926274878;
        -0.067584405775710, 0.204579454345920, 0.004979963099100;
        -0.064175884543315, 0.206265672099565, 0.004504246814302;
        -0.060615537195627, 0.207785596189143, 0.004047055643681;
        -0.056902532264325, 0.209144215424576, 0.003610684439801;
        -0.053035040519105, 0.210353170362348, 0.003197411425860;
        -0.049016886714238, 0.211414123939099, 0.002807120196294;
        -0.044851396723008, 0.212327076154830, 0.002438081296995;
        -0.040536575021446, 0.213093689946182, 0.002090161693032;
        -0.036070426085581, 0.213712302376514, 0.001763244978842;
        -0.031450954391447, 0.214182913445825, 0.001457196456555;
        -0.026677661058049, 0.214505523154116, 0.001171775000359;
        -0.021753539371343, 0.214686783247950, 0.000906390267747;
        -0.016682081498272, 0.214726693727326, 0.000660436949781;
        -0.011466180948593, 0.214628580465526, 0.000433303085778;
        -0.006109329889249, 0.214394106399191, 0.000224388355610;
        -0.000613678497319, 0.214024934464961, 0.000033225640374;
        0.005020355830103, 0.213522727599477, -0.000141013867550;
        0.010792359021791, 0.212895800485942, -0.000299484911366;
        0.016701870444296, 0.212154130744200, -0.000443342234278;
        0.022748474363459, 0.211302707184174, -0.000573746399766;
        0.028936095309752, 0.210339866869222, -0.000691502269166;
        0.035259079298595, 0.209265609799345, -0.000797223466097;
        0.041714765631365, 0.208079935974543, -0.000891593457518;
        0.048300659903099, 0.206784508331456, -0.000975285732770;
        0.055014932883494, 0.205377663933444, -0.001048970455319;
        0.061857584572549, 0.203857739843866, -0.001113226327114;
        0.068824125041334, 0.202219747252800, -0.001168713534004;
        0.075905907019318, 0.200465349096886, -0.001216195363905;
        0.083095280997954, 0.198589556566204, -0.001256426790053;
        0.090384597468694, 0.196589043787470, -0.001290159459809;
        0.097768867621617, 0.194460484887404, -0.001318016974414;
        0.105237781249551, 0.192212194549210, -0.001340363516991;
        0.112786848423565, 0.189850824519450, -0.001357393651128;
        0.120411246627402, 0.187381363608045, -0.001369300277476;
        0.128106485932131, 0.184808800624919, -0.001376274633747;
        0.135865914591191, 0.182136461443352, -0.001378679240129;
        0.143678390929088, 0.179367671936626, -0.001376851672761;
        0.151532274389338, 0.176502432104741, -0.001370944921813;
        0.159416090709120, 0.173540741947697, -0.001361118629203;
        0.167318033038286, 0.170485927338774, -0.001347524122166;
        0.175226959701342, 0.167337988277974, -0.001330412504133;
        0.183132560491117, 0.164105738329491, -0.001310157935850;
        0.191021531914486, 0.160792503366608, -0.001287106308137;
        0.198882233414963, 0.157404768842222, -0.001261603511815;
        0.206706350309345, 0.153948853915569, -0.001233995437707;
        0.214482242041147, 0.150430412571226, -0.001204471660588;
        0.222191616307322, 0.146853435857131, -0.001173417981760;
        0.229814517868182, 0.143220418178246, -0.001141466317146;
        0.237330991484039, 0.139534519114187, -0.001109251908543;
        0.244719418978564, 0.135798565657243, -0.001077411660684;
        0.251964833921991, 0.132016382561689, -0.001046319734314;
        0.259052269884553, 0.128196284510728, -0.001015889656726;
        0.265971749246407, 0.124347750243210, -0.000986076528632;
        0.272709968514427, 0.120479925910661, -0.000956828798996;
        0.279253624195488, 0.116602290251932, -0.000928099905591;
        0.285582761049902, 0.112722326481907, -0.000900205806381;
        0.291685738521184, 0.108846852640810, -0.000872948611903;
        0.297557567799412, 0.104983185649863, -0.000845516809079;
        0.303191597138024, 0.101139473898604, -0.000817093896016;
        0.308581174790456, 0.097322868014588, -0.000786866696699;
        0.313731289566630, 0.093539188276057, -0.000754211609886;
        0.318608682733734, 0.089795917897895, -0.000719860327699;
        0.323165129129187, 0.086103699674601, -0.000685026793887;
        0.327350740653769, 0.082473176400677, -0.000650923289260;
        0.331113966271619, 0.078914990870622, -0.000618763757566;
        0.334416558440002, 0.075439286997944, -0.000589248295131;
        0.337273483588684, 0.072045565901652, -0.000561874695088;
        0.339724652197041, 0.068730002827472, -0.000536060929615;
        0.341801660061246, 0.065488606727465, -0.000511224970887;
        0.343542754724034, 0.062317386553696, -0.000486781465205;
        0.344967891425094, 0.059214845663186, -0.000462407802863;
        0.346047137304892, 0.056188467270819, -0.000438486459287;
        0.346737256010773, 0.053247064940791, -0.000415509663723;
        0.347000000000000, 0.050399452237297, -0.000393966319543;
        0.346790469983275, 0.047654442724532, -0.000374343667183;
        0.346087047784269, 0.045016858918756, -0.000357000900957;
        0.344918003325873, 0.042484372708670, -0.000341454106303;
        0.343314932404261, 0.040054489689314, -0.000326933343557;
        0.341317745498809, 0.037724715455726, -0.000312663684243;
        0.338959701342330, 0.035492721896610, -0.000297870199888;
        0.336255766364590, 0.033357843837310, -0.000282147133950;
        0.333200951755668, 0.031319416103169, -0.000265855343682;
        0.329796920452204, 0.029375942051211, -0.000249383956256;
        0.326045335390838, 0.027525259863802, -0.000233120435910;
        0.321944533634930, 0.025765706604303, -0.000217453909818;
        0.317516133360809, 0.024096118217064, -0.000202454221319;
        0.312763460441756, 0.022513501416132, -0.000188056515884;
        0.307674874321287, 0.021012867391586, -0.000174447042417;
        0.302233745632994, 0.019589726214495, -0.000161813879051;
        0.296426770883753, 0.018239089074938, -0.000150345769096;
        0.290255613010203, 0.016957630099632, -0.000140216323137;
        0.283763508365003, 0.015743752869404, -0.000131268227367;
        0.277003670920653, 0.014596792209597, -0.000123192840746;
        0.270034303459579, 0.013515733728860, -0.000115680857059;
        0.262906957017641, 0.012499662812040, -0.000108423468972;
        0.255644912707807, 0.011546733599467, -0.000101271178481;
        0.248281429262893, 0.010653936175821, -0.000094310125703;
        0.240884687085164, 0.009818593213110, -0.000087584378459;
        0.233522866576890, 0.009038010753976, -0.000081138503453;
        0.226265811076979, 0.008309544729162, -0.000075016901091;
        0.219166734557932, 0.007630950174201, -0.000069204106064;
        0.212212333526624, 0.006999832460332, -0.000063663866352;
        0.205371012186881, 0.006413214930967, -0.000058408986567;
        0.198611174742532, 0.005868137558886, -0.000053452603910;
        0.191904551270685, 0.005361607058136, -0.000048806857817;
        0.185244490024776, 0.004891145653122, -0.000044473244931;
        0.178654272117776, 0.004454990631005, -0.000040441122458;
        0.172132234613044, 0.004051296132115, -0.000036705834176;
        0.165681869677524, 0.003678166408680, -0.000033262723861;
        0.159306170597172, 0.003333755601029, -0.000030107135292;
        0.153005636252977, 0.003015985038363, -0.000027230254904;
        0.146788747621809, 0.002723374707069, -0.000024619444378;
        0.140667810434808, 0.002455093138829, -0.000022266222738;
        0.134655961891435, 0.002210258977222, -0.000020161776419;
        0.128765840310159, 0.001987957607096, -0.000018296792976;
        0.123002600794567, 0.001787191266468, -0.000016673267934;
        0.117372728797558, 0.001606135713841, -0.000015260470223;
        0.111891024455232, 0.001442782121754, -0.000014002824500;
        0.106572121610029, 0.001295131640365, -0.000012844323060;
        0.101430820398050, 0.001161158812845, -0.000011728875050;
        0.096478595082116, 0.001039332074549, -0.000010498301936;
        0.091709625383985, 0.000928904766925, -0.000009382870555;
        0.087113434802820, 0.000829096972689, -0.000008374715216;
        0.082679047956792, 0.000739142078048, -0.000007466086636;
        0.078395822051402, 0.000658276795085, -0.000006649252158;
        0.074260431213369, 0.000585533294675, -0.000005914466974;
        0.070275037260324, 0.000520169907077, -0.000005254231239;
        0.066436979493643, 0.000461719347094, -0.000004663822214;
        0.062744096095693, 0.000409725970086, -0.000004138633564;
        0.059193892661513, 0.000363739120225, -0.000003674142102;
        0.055784041079807, 0.000323261579454, -0.000003265275870;
        0.052513876175917, 0.000287666420661, -0.000002905715710;
        0.049384063124500, 0.000256255210455, -0.000002588427399;
        0.046395100806548, 0.000228344481878, -0.000002306509750;
        0.043547321809390, 0.000203259082653, -0.000002053128094;
        0.040837233966080, 0.000180395366781, -0.000001822179453;
        0.038264837276618, 0.000159610986883, -0.000001612233703;
        0.035835453138254, 0.000140872684229, -0.000001422956591;
        0.033554070360910, 0.000124143042743, -0.000001253970633;
        0.031426342929165, 0.000109393293621, -0.000001104983150;
        0.029452769724010, 0.000096462797184, -0.000000974371118;
        0.027623373125602, 0.000085069353084, -0.000000859285924;
        0.025926179990128, 0.000074993786272, -0.000000757512539;
        0.024349716054767, 0.000066019748690, -0.000000666865863;
        0.022882174469370, 0.000057933386688, -0.000000585185741;
        0.021519896773328, 0.000050557930099, -0.000000510686179;
        0.020254069402445, 0.000043842659357, -0.000000442856657;
        0.019064570823369, 0.000037751322442, -0.000000381326338;
        0.017932110971069, 0.000032248498804, -0.000000325742681;
        0.016836568312191, 0.000027300763417, -0.000000275766446;
        0.015763458668596, 0.000022818982877, -0.000000230494659;
        0.014717837367672, 0.000018764410760, -0.000000189539855;
        0.013710131022155, 0.000015172700427, -0.000000153259567;
        0.012750633209851, 0.000012073335745, -0.000000121952789;
        0.011849704026032, 0.000009502568734, -0.000000095985534;
        0.011009272477201, 0.000007467167544, -0.000000075425984;
        0.010223368620817, 0.000005887194813, -0.000000059466614;
        0.009490562331370, 0.000004665219081, -0.000000047123301;
        0.008809340336517, 0.000003707966233, -0.000000037454156;
        0.008178222622648, 0.000002920116741, -0.000000029496006;
        0.007596410980174, 0.000002244116367, -0.000000022667988;
        0.007061859997029, 0.000001679283308, -0.000000016962453;
        0.006571144023732, 0.000001215496931, -0.000000012277744;
        0.006120887298902, 0.000000842042934, -0.000000008505489;
        0.005707680802427, 0.000000547526878, -0.000000005530578;
        0.005329695304001, 0.000000308073979, -0.000000003111853;
        0.004984120440702, 0.000000108631336, -0.000000001097287;
        0.004666150325638, 0.000000046230137, 0;
        0.004370895925086, 0.000000013763944, 0;
        0.004093418317223, 0, 0;
        0.003830408258134, -0.000000120330262, 0;
        0.003581583048589, -0.000000112603094, 0;
        0.003347192129086, -0.000000105234622, 0;
        0.003127534828219, -0.000000098290863, 0;
        0.002922860586485, -0.000000091907847, 0;
        0.002732404453028, -0.000000085888682, 0;
        0.002554520120575, -0.000000080257812, 0;
        0.002388226456507, -0.000000075056978, 0;
        0.002232592216306, -0.000000070216169, 0;
        0.002086619637988, -0.000000065552962, 0;
        0.001949493882598, -0.000000061310146, 0;
        0.001820765957243, -0.000000057268046, 0;
        0.001700020127763, -0.000000053405210, 0;
        0.001586857289365, -0.000000049861160, 0;
        0.001480893303685, -0.000000046572370, 0;
        0.001381597693933, -0.000000043456525, 0;
        0.001288564703571, -0.000000040506143, 0;
        0.001201569836150, -0.000000037740846, 0;
        0.001120393584036, -0.000000035180422, 0;
        0.001044808124907, -0.000000032844994, 0;
        0.000974544063029, -0.000000030615495, 0;
        0.000909200630670, -0.000000028546968, 0;
        0.000848352116051, -0.000000026647894, 0;
        0.000791577796202, -0.000000024835792, 0;
        0.000738450296405, -0.000000023209939, 0;
        0.000688637029334, -0.000000021623664, 0;
        0.000641963386640, -0.000000020140491, 0;
        0.000598241456483, -0.000000018826605, 0;
        0.000557284989960, -0.000000017500246, 0;
        0.000518911064040, -0.000000016277705, 0;
        0.000482900171086, -0.000000015198725, 0;
        0.000449110961484, -0.000000014091542, 0;
        0.000417468603085, -0.000000013089274, 0;
        0.000387904915487, -0.000000012234075, 0;
        0.000360343403605, -0.000000011322487, 0;
        0.000334680965366, -0.000000010516461, 0;
        0.000310787891713, -0.000000009770052, 0;
        0.000288559417637, -0.000000009065449, 0;
        0.000267892441066, -0.000000008419082, 0;
        0.000248678871120, -0.000000007818064, 0;
        0.000230817268663, -0.000000007255160, 0;
        0.000214236127418, -0.000000006729788, 0;
        0.000198870592858, -0.000000006251561, 0;
        0.000184660799264, -0.000000005800705, 0;
        0.000171540229169, -0.000000005391723, 0;
        0.000159443529164, -0.000000005008848, 0;
        0.000148293206401, -0.000000004661877, 0;
        0.000138011934326, -0.000000004335376, 0;
        0.000128522885267, -0.000000004043347, 0;
        0.000119748732670, -0.000000003765487, 0;
        0.000111625287180, -0.000000003507848, 0;
        0.000104103991048, -0.000000003276368, 0;
        0.000097131796595, -0.000000003055097, 0;
        0.000090655656141, -0.000000002851770, 0;
        0.000084622355715, -0.000000002659984, 0;
        0.000078980843162, -0.000000002479372, 0;
        0.000073703347439, -0.000000002318633, 0;
        0.000068771742537, -0.000000002160537, 0;
        0.000064168068741, -0.000000002017774, 0;
        0.000059874366335, -0.000000001878204, 0;
        0.000055864693507, -0.000000001752885, 0;
        0.000052116268025, -0.000000001641575, 0;
        0.000048616451571, -0.000000001527291, 0;
        0.000045352273239, -0.000000001422860, 0;
        0.000042311261004, -0.000000001325440, 0;
        0.000039478282143, -0.000000001243581, 0;
        0.000036837871345, -0.000000001162167, 0;
        0.000034376558823, -0.000000001080772, 0;
        0.000032080874791, -0.000000001008074, 0;
        0.000029937183167, -0.000000000940918, 0;
        0.000027932679341, -0.000000000878062, 0;
        0.000026058882334, -0.000000000819485, 0;
        0.000024309306694, -0.000000000763684, 0;
        0.000022676968088, -0.000000000713002, 0;
        0.000021155547355, -0.000000000664539, 0;
        0.000019737062401, -0.000000000620388, 0;
        0.000018414196303, -0.000000000578462, 0;
        0.000017180796197, -0.000000000540220, 0;
        0.000016030942027, -0.000000000503692, 0;
        0.000014958613964, -0.000000000469849, 0;
        0.000013957991728, -0.000000000439113, 0;
        0.000013024219546, -0.000000000408923, 0;
        0.000012152674453, -0.000000000381982, 0;
        0.000011338750114, -0.000000000356439, 0;
        0.000010577806936, -0.000000000332270, 0;
        0.000009865172068, -0.000000000310056, 0;
        0.000009198001888, -0.000000000288732, 0;
        0.000008574367389, -0.000000000269510, 0;
        0.000007992356194, -0.000000000251542, 0;
        0.000007450072556, -0.000000000233719, 0;
        0.000006944988810, -0.000000000217953, 0;
        0.000006474410999, -0.000000000203681, 0;
        0.000006036027642, -0.000000000189703, 0;
        0.000005627593774, -0.000000000177040, 0;
        0.000005246781283, -0.000000000164740, 0;
        0.000004891511499, -0.000000000154196, 0;
        0.000004560154744, -0.000000000143558, 0;
        0.000004251280893, -0.000000000134020, 0;
        0.000003963426560, -0.000000000124297, 0;
        0.000003695144992, -0.000000000116085, 0;
        0.000003444939545, -0.000000000108294, 0;
        0.000003211563017, -0.000000000100976, 0;
        0.000002994017645, -0.000000000094124, 0;
        0.000002791289039, -0.000000000087706, 0;
        0.000002602346178, -0.000000000081763, 0;
        0.000002426124783, -0.000000000076229, 0;
        0.000002261776754, -0.000000000071133, 0;
        0.000002108587031, -0.000000000066256, 0;
        0.000001965823920, -0.000000000061765, 0;
        0.000001832755730, -0.000000000057600, 0;
        0.000001708650769, -0.000000000053734, 0;
        0.000001592885435, -0.000000000050088, 0;
        0.000001484974150, -0.000000000046707, 0;
        0.000001384408057, -0.000000000043496, 0;
        0.000001290691600, -0.000000000040584, 0;
        0.000001203294301, -0.000000000037783, 0;
        0.000001121788788, -0.000000000035217, 0;
        0.000001045814202, -0.000000000032868, 0;
        0.000000975011348, -0.000000000030623, 0;
        0.000000909022696, -0.000000000028553, 0;
        0.000000847472423, -0.000000000026708, 0;
        0.000000790062861, -0.000000000024874, 0;
        0.000000736544571, -0.000000000023252, 0;
        0.000000686668112, -0.000000000021539, 0;
        0.000000640185707, -0.000000000020097, 0;
        0.000000596836275, -0.000000000018643, 0;
        0.000000556406959, -0.000000000017386, 0;
        0.000000518719826, -0.000000000016334, 0;
        0.000000483596942, -0.000000000015312, 0;
        0.000000450863697, -0.000000000014147, 0];
end
