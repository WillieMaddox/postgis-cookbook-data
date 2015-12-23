$conn = array(
	'dbname' => 'DATABASENAME',
	'host' => 'DATABASEHOST',
	'user' => 'USERNAME',
	'password' => 'PASSWORD'
);

// assemble connection string
$conn_str = array();
foreach ($conn as $k => $v) {
	if (!strlen(trim($v))) continue;
	$conn_str[] = $k . '=' . trim($v);
}
$conn_str = implode(' ', $conn_str);

$dbconn = pg_connect($conn_str);
if ($dbconn === false) {
	echo "error";
	return;
}

$dbr = pg_query(<<< END
-- PUT YOUR SQL BELOW THIS LINE AND ABOVE THEN "END"
END
);
if ($dbr === false) {
	echo "error";
	return false;
}

$row = pg_fetch_row($dbr);
pg_free_result($dbr);
if ($row === false) {
	echo "error";
	return false;
}

$fh = fopen('./surface.tif', 'wb');
if ($fh == false) {
	echo "error";
	return false;
}

fwrite($fh, pg_unescape_bytea($row[0]));
fclose($fh);

echo "done";
