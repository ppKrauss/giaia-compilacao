<?php
/**
 * Scan e carga para banco SQL, dos XMLs dispostos em filesystem. Ver scripts "ini.sql".
 */

// // // //
// CONFIGURACOES:
$PG_USER = 'postgres';
$PG_PW   = 'pp@123456'; 
$pasta =  '/home/peter/Área de Trabalho/hackday/xml-scielo';


$n=0;
$dsn="pgsql:dbname=postgres;host=localhost";
$db = new pdo($dsn,$PG_USER,$PG_PW);

$XHEAD = ''; // $XHEAD = '<?xml version="1.0" encoding="UTF-8"  >'."\n";
$rgx_doctype = '/^\s*<!DOCTYPE\s([^>]+)>/s';

// INSERT de teste com as ~2mil amostras do SciELO-BR 
$stmt = $db->prepare(
  "INSERT INTO articles(repo,repos_pid,content_dtd,xcontent) VALUES (1,:pid,:doctype,:conteudo)"
);

foreach (scandir($pasta) as $file) if (strlen($file)>5) { //  && $n<10 
	$n++;
	print "\n -- $file";
	$pid = str_replace('.xml','',$file);
	$cont = file_get_contents("$pasta/$file");

	$stmt->bindParam(':pid',$pid,PDO::PARAM_STR);

	$doctype = preg_match($rgx_doctype,$cont,$m)? $m[1]: '';
	if ($doctype) 
		$cont = preg_replace($rgx_doctype, '', $cont);
	$stmt->bindParam(':doctype',$doctype,PDO::PARAM_STR);

	// $stmt->bindParam(':conteudo',$XHEAD.$cont,PDO::PARAM_STR);
	$stmt->bindParam(':conteudo',$cont,PDO::PARAM_STR);

	$re = $stmt->execute();
	if (!$re) print "\n-- ERROR at $file, not saved";
}

print "\n$n arquivos inseridos \n falra rodar SELECT articles_kx_refresh();\n";

/*
$stmt = $dbh->prepare("SELECT * FROM REGISTRY where name = ?");
if ($stmt->execute(array($_GET['name']))) {
  while ($row = $stmt->fetch()) {
    print_r($row);
  }
}

*/

?>

