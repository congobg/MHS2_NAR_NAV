<?php

define('DS', DIRECTORY_SEPARATOR);

function copy_r2($from, $to, $skip=false,$inc=false) {
    global $skip;
    $dir = opendir($from);
    if (!file_exists($to)) {mkdir ($to, 0775, true);}
	if(!$dir) return 1;
    while (false !== ($file = readdir($dir))) {
        if ($file == '.' OR $file == '..' OR in_array($file, $skip)) {continue;}

        if (is_dir($from . DIRECTORY_SEPARATOR . $file)) {
            copy_r2($from . DIRECTORY_SEPARATOR . $file, $to . DIRECTORY_SEPARATOR . $file, $skip, $inc);
        }
        else {
			if (isset($inc[0]) && !preg_match('/\.('.implode('|', $inc).')$/', $file, $matches))  {continue;}				
			if(isset($inc[10]) && !preg_match('/^'.$inc[10].'/', $file)) {continue;}
            copy($from . DIRECTORY_SEPARATOR . $file, $to . DIRECTORY_SEPARATOR . $file);
        }
    }
    closedir($dir);
}

$srcdir="z:/AUTO/_SOFTWARE/MAP/MIB2_EU/P192_N60S5MIBH3_EU_NT_2021_2022";
$dstdir="d:/tmp/DELPHI_HARMAN_MAP2";

$metaf = "$srcdir/Mib1/metainfo2.txt";
$fp = fopen($metaf, "r");
$tr = false;
$Eggnog_meta = 'FileName = "EggnogDB.ser"'."\r\n";
while ($line = stream_get_line($fp, 1024 * 1024, "\n")) {
	$line = str_replace(array("\n","\r"), '',$line);
	if ($line == '[Eggnog\eu\0\default\File]') {
		$tr = true;
	}
	if ($tr and preg_match('/^CheckSum/', $line)) {
		$Eggnog_meta .= $line."\r\n";
	}
	if ($tr and preg_match('/^FileSize/', $line)) {
		$Eggnog_meta .= $line."\r\n";
		$Eggnog_meta .= 'CheckSumSize = "524288"'."\r\n";
	}
	if ($line == "") {$tr = false;}
}
$Eggnog_meta .= "\r\n";
fclose($fp);

echo "copying mapStyles data ... \n";
copy_r2($srcdir."/Mib2/NavDB/mapStyles_eu/0/default",$dstdir."/database/eu/mapStyles",$skip=array());
echo "copying RegionList_eu data ... \n";
copy_r2($srcdir."/Mib2/NavDB/RegionList_eu/0/default",$dstdir."/database/eu/",$skip=array());
//fix region list
$json = "$dstdir/database/eu/regionList.json";
$json = file_get_contents($json);
$data = json_decode($json);
foreach($data->regions as $key => $val){
	$path = str_replace("/net/mmx/mnt/navdb/", "", $val->directory);
	$val->directory = $path;
}

$data = json_encode($data,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES);
$f = fopen("$dstdir/database/eu/regionList.json",'w+');
fwrite($f,$data);
fclose($f);

echo "copying Eggnog data ... \n";
copy_r2($srcdir."/Mib1/Eggnog/eu/0/default",$dstdir."/database/eu/eggnog/eggnog_light/",$skip=array());
echo "Create hashes.txt from metainfo2.txt manually\n";

copy_r2($srcdir."/Mib1/Eggnog/DBInfo/0/default",$dstdir."/eggnog",$skip=array());
copy_r2($srcdir."/Mib1/Eggnog/InfoFile/0/default",$dstdir."/eggnog",$skip=array());

$f = fopen("$dstdir/database/eu/eggnog/eggnog_light/hashes.txt",'w+');
fwrite($f,$Eggnog_meta);
fclose($f);

echo "copying NavDB common data ... \n";
copy_r2($srcdir."/Mib2/NavDB/common_eu/0/default",$dstdir."/database/eu/map/common/",$skip=array());
copy_r2($srcdir."/Mib2/NavDB/DBInfo/0/default",$dstdir."/database",$skip=array());
copy_r2($srcdir."/Mib2/NavDB/DBInfo/0/default",$dstdir,$skip=array());
copy_r2($srcdir."/Mib2/NavDB/InfoFile/0/default",$dstdir."/database",$skip=array());

$json = "$dstdir/database/eu/regionList.json";
$json = file_get_contents($json);
$data = json_decode($json);

foreach($data->regions as $key => $val){
	$reg=basename($val->directory);

	echo "copying NavDB ".$reg." data ... \n";
	copy_r2($srcdir."/Mib2/NavDB/".$reg."_eu/0/default",$dstdir."/database/eu/map/regions/".$reg."/",$skip=array(),$inc=array());
	switch ($reg) {
		case "BelgiumLuxembourg":
			$reg2='BeNeLux';
		break;

		case "Netherlands":
			$reg2='BeNeLux';
		break;

		case "FranceCenter":
		case "FranceNorthEast":
		case "FranceNorthWest":
		case "FranceSouthEast":
		case "FranceSouthWest":
			$reg2='France';
		break;

		case "GermanyEast":
		case "GermanyNorth":
		case "GermanySouth":
		case "GermanyWest":
			$reg2='Germany';
		break;

		case "ItalyCenter":
		case "ItalyNorth":
		case "ItalySouth":
			$reg2='Italy';
		break;

		case "Russia2":
		case "Russia3":
		case "Russia4":
		case "Russia5":
		case "Russia6":
		case "Kaliningrad":
		case "RussiaEast":
			$reg2='Russia';
		break;

		case "GreatBritainSouth":
		case "IrelandGreatBritainNorth":
			$reg2='UKIreland';
		break;

		case "SpainNorth":
		case "SpainSouth":
			$reg2='Spain';
		break;

		default:
			$reg2=$reg;
		break;
	}
	copy_r2($srcdir."/Mib1/NavDB/".$reg2."_eu/0/default/",$dstdir."/database/eu/map/regions/".$reg."/",$skip=array($reg."_Map3D_TIN.psf",$reg."_Map3D.psf"),$inc=array(0=>'psf',1=>'cff',10=>$reg));
}

echo "copying Truffles data ... \n";

$fields = scandir($srcdir."/Mib2/Truffles");
$fields = array_flip($fields);
unset($fields['.']);
unset($fields['..']);
unset($fields['InfoFile']);

$fields = array_flip($fields);
copy_r2($srcdir."/Mib2/Truffles/InfoFile/0/default",$dstdir."/truffles",$skip=array());
foreach($fields as $dir) {
	echo "copying Truffles ".$dir." data ... \n";
	copy_r2($srcdir."/Mib2/Truffles/$dir/0/default",$dstdir."/truffles/db/$dir",$skip=array());
}

$srcdir="d:/tmp/DELPHI_HARMAN_MAP";

echo "copying SpeechResVDE data ... \n";
copy_r2($srcdir."/speech",$dstdir."/speech",$skip=array());
#copy_r2($srcdir."/Mib2/SpeechResVDE",$dstdir."/speech/sr/vde/EU",$skip=array());


?>