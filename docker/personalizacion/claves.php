<?php
/**
 * Despues de restaurar el respaldo de la base, las claves de las cuentas son las del servidor original
 * (no estan en el repositorio). Este script pone las claves definidas en el .env:
 *   admin                                 -> CHAMILO_ADMIN_PASS
 *   Instructor1, estudiante1/2/3          -> CHAMILO_DEMO_PASS
 * Chamilo 1.11 usa bcrypt ($2y$), que es lo que genera password_hash().
 */
$db = new mysqli('bd', getenv('DB_USER'), getenv('DB_PASS'), getenv('DB_NAME'));
if ($db->connect_error) { echo "[ERROR] ".$db->connect_error."\n"; exit(1); }

$cuentas = [
    [getenv('CHAMILO_ADMIN_USER') ?: 'admin', getenv('CHAMILO_ADMIN_PASS')],
    ['Instructor1',  getenv('CHAMILO_DEMO_PASS')],
    ['estudiante1',  getenv('CHAMILO_DEMO_PASS')],
    ['Estudiante2',  getenv('CHAMILO_DEMO_PASS')],
    ['Estudiante3',  getenv('CHAMILO_DEMO_PASS')],
];
$errores = 0;
$st = $db->prepare('UPDATE user SET password = ? WHERE username = ?');
foreach ($cuentas as [$usuario, $clave]) {
    if (!$clave) { echo "[ERROR] falta la clave de $usuario en el .env\n"; $errores++; continue; }
    $hash = password_hash($clave, PASSWORD_BCRYPT);
    $st->bind_param('ss', $hash, $usuario);
    $st->execute();
    echo $st->affected_rows > 0 ? "[OK] clave de $usuario\n" : "[AVISO] no existe el usuario $usuario\n";
}
exit($errores ? 1 : 0);

