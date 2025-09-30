<?php
/**
 * LAMP/DB health check
 *
 * Env vars (or edit defaults below):
 *   DB_HOST, DB_USER, DB_PASS, DB_PORT
 *
 * Query params:
 *   expected_php=7.4      // compare major.minor against PHP_VERSION
 *   mode=json|text        // default json
 */

// ---------- Config (env with sane defaults) ----------
$DB_HOST = getenv('DB_HOST') ?: '127.0.0.1';
$DB_USER = getenv('DB_USER') ?: 'root';
$DB_PASS = getenv('DB_PASS') ?: '';
$DB_PORT = intval(getenv('DB_PORT') ?: 3306);

$expectedPhp = isset($_GET['expected_php']) ? trim($_GET['expected_php']) : '7.4';
$mode = (isset($_GET['mode']) && strtolower($_GET['mode']) === 'text') ? 'text' : 'json';

// ---------- Helpers ----------
function status_text(bool $ok): string { return $ok ? 'OK' : 'FAIL'; }
function bool_to_str(bool $b): string { return $b ? 'true' : 'false'; }

// Compare “7.4” with current (allows 7.4.x)
function php_matches(string $expected, string $current): bool {
    $exp = preg_quote($expected, '/');
    return (bool)preg_match("/^{$exp}(\\.|$)/", $current);
}

// ---------- Checks ----------

// 1) PHP version
$phpVersion = PHP_VERSION;
$phpOk = php_matches($expectedPhp, $phpVersion);

// 2) MySQL connectivity + trivial query
mysqli_report(MYSQLI_REPORT_OFF);
$mysqlOk = false;
$mysqlInfo = null;
$mysqlError = null;
$mysqli = @mysqli_init();
if ($mysqli && @$mysqli->real_connect($DB_HOST, $DB_USER, $DB_PASS, /*db*/null, $DB_PORT)) {
    $mysqlInfo = @$mysqli->get_server_info();
    $res = @$mysqli->query("SELECT 1");
    if ($res) {
        $row = $res->fetch_row();
        $mysqlOk = ($row && intval($row[0]) === 1);
        $res->free();
    } else {
        $mysqlError = $mysqli->error;
    }
    $mysqli->close();
} else {
    $mysqlError = $mysqli ? $mysqli->connect_error : 'mysqli_init_failed';
}

// 3) “LAMP”/Apache indicator + required extensions
$serverSoftware = $_SERVER['SERVER_SOFTWARE'] ?? '';
$apacheVersion = function_exists('apache_get_version') ? @apache_get_version() : null;
$runningUnderApache = (stripos($serverSoftware, 'Apache') !== false) || ($apacheVersion !== null);
$mysqliLoaded = extension_loaded('mysqli');

$lampOk = $runningUnderApache && $mysqliLoaded;

// ---------- Aggregate ----------
$overallOk = $phpOk && $mysqlOk && $lampOk;

// ---------- Output ----------
$payload = [
    'overall' => [
        'ok' => $overallOk,
        'status' => status_text($overallOk)  // <-- keyword-friendly
    ],
    'php' => [
        'current' => $phpVersion,
        'expected' => $expectedPhp,
        'ok' => $phpOk,
        'status' => status_text($phpOk)
    ],
    'mysql' => [
        'host' => $DB_HOST,
        'port' => $DB_PORT,
        'connected' => $mysqlOk,
        'server_info' => $mysqlInfo,
        'error' => $mysqlOk ? null : $mysqlError,
        'ok' => $mysqlOk,
        'status' => status_text($mysqlOk)
    ],
    'lamp' => [
        'server_software' => $serverSoftware ?: null,
        'apache_version' => $apacheVersion,
        'running_under_apache' => $runningUnderApache,
        'mysqli_extension_loaded' => $mysqliLoaded,
        'ok' => $lampOk,
        'status' => status_text($lampOk)
    ],
    'timestamp' => gmdate('c')
];

if ($mode === 'text') {
    header('Content-Type: text/plain; charset=UTF-8');
    echo "OVERALL: " . $payload['overall']['status'] . "\n";
    echo "PHP: current={$payload['php']['current']} expected={$payload['php']['expected']} status={$payload['php']['status']}\n";
    echo "MySQL: host={$DB_HOST} port={$DB_PORT} status={$payload['mysql']['status']}";
    if (!$mysqlOk && $payload['mysql']['error']) echo " error=" . $payload['mysql']['error'];
    echo "\n";
    echo "LAMP: apache=" . bool_to_str($runningUnderApache) .
         " mysqli_ext=" . bool_to_str($mysqliLoaded) .
         " status={$payload['lamp']['status']}\n";
    echo "Timestamp: {$payload['timestamp']}\n";
} else {
    header('Content-Type: application/json; charset=UTF-8');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
}

