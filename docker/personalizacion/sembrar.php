<?php
/**
 * Datos de ejemplo para el Escenario 2 (Constructora Los Angeles - capacitacion sin registro).
 * Lo ejecuta aprovisionar.sh UNA vez, despues de instalar Chamilo. Usa la API interna de Chamilo 1.11.
 * Cada bloque es independiente: si uno falla, se anota y se sigue con el siguiente.
 */
chdir('/var/www/html/main/inc');
$_SERVER['HTTP_HOST']   = 'capacitacion.losangeles.internal';
$_SERVER['SERVER_NAME'] = 'capacitacion.losangeles.internal';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SCRIPT_NAME'] = '/main/inc/sembrar.php';
$_SERVER['REMOTE_ADDR'] = '127.0.0.1';
$_SERVER['HTTPS']       = 'on';
$_SERVER['REQUEST_METHOD'] = 'GET';

require_once '/var/www/html/main/inc/global.inc.php';
require_once api_get_path(SYS_CODE_PATH).'inc/lib/fileUpload.lib.php';

$errores = 0;
function paso($nombre, callable $fn) {
    global $errores;
    try { $r = $fn(); echo "[OK] $nombre\n"; return $r; }
    catch (Throwable $e) { $errores++; echo "[ERROR] $nombre: ".$e->getMessage()."\n"; return null; }
}

$clave = getenv('CHAMILO_DEMO_PASS') ?: 'Cambiar.123';

// ---------- 1) Tema activo ----------
paso('tema losangeles activo', function () {
    $db = new mysqli('bd', getenv('DB_USER'), getenv('DB_PASS'), getenv('DB_NAME'));
    $db->query("UPDATE settings_current SET selected_value='losangeles' WHERE variable='stylesheets'");
    $db->query("UPDATE settings_current SET selected_value='Constructora Los Angeles - Capacitacion' WHERE variable='siteName'");
    if ($db->error) { throw new Exception($db->error); }
});

// ---------- 2) Usuarios ----------
$usuarios = [
    ['Carlos', 'Ramirez', COURSEMANAGER, 'carlos.ramirez@losangeles.internal', 'Instructor1'],
    ['Ana',    'Mora',    STUDENT,       'ana.mora@losangeles.internal',        'estudiante1'],
    ['Luis',   'Soto',    STUDENT,       'luis.soto@losangeles.internal',       'Estudiante2'],
    ['Maria',  'Vargas',  STUDENT,       'maria.vargas@losangeles.internal',    'Estudiante3'],
];
$ids = [];
foreach ($usuarios as $u) {
    $ids[$u[4]] = paso("usuario {$u[4]}", function () use ($u, $clave) {
        $existente = api_get_user_info_from_username($u[4]);
        if (!empty($existente['user_id'])) { return $existente['user_id']; }
        $id = UserManager::create_user($u[0], $u[1], $u[2], $u[3], $u[4], $clave);
        if (!$id) { throw new Exception('create_user devolvio false'); }
        return $id;
    });
}

// ---------- 3) Curso ----------
$curso = paso('curso SEGOBRA', function () use ($ids) {
    $info = api_get_course_info('SEGOBRA');
    if (!empty($info['real_id'])) { return $info; }
    $params = [
        'title'           => 'Seguridad en obra',
        'wanted_code'     => 'SEGOBRA',
        'tutor_name'      => 'Carlos Ramirez',
        'course_language' => 'spanish',
        'visibility'      => COURSE_VISIBILITY_REGISTERED,
        'subscribe'       => 0,
        'unsubscribe'     => 0,
        'disk_quota'      => 100 * 1024 * 1024,
    ];
    $c = CourseManager::create_course($params, $ids['Instructor1'] ?: 1);
    if (empty($c['code'])) { throw new Exception('create_course fallo'); }
    return api_get_course_info($c['code']);
});
if (!$curso) { echo "Sin curso no se puede continuar\n"; exit(1); }
$code = $curso['code'];
$cid  = $curso['real_id'];

paso('inscribir instructor y estudiantes', function () use ($ids, $code) {
    CourseManager::subscribeUser($ids['Instructor1'], $code, COURSEMANAGER);
    foreach (['estudiante1', 'Estudiante2', 'Estudiante3'] as $login) {
        CourseManager::subscribeUser($ids[$login], $code, STUDENT);
    }
});

// ---------- 4) Lecciones (3 documentos HTML + ruta de aprendizaje) ----------
$lecciones = [
 'Leccion 1 - Equipo de proteccion personal (EPP)' => '<h2>Equipo de protecci&oacute;n personal (EPP)</h2>
<p>El EPP es la &uacute;ltima barrera entre el trabajador y el peligro; no reemplaza las medidas de control en la fuente, pero es obligatorio en toda zona de obra.</p>
<ul><li><b>Casco:</b> protege contra ca&iacute;da de objetos y golpes. Debe reemplazarse si recibi&oacute; un impacto fuerte o tiene fisuras.</li>
<li><b>Gafas de seguridad:</b> obligatorias al cortar, esmerilar, picar o manipular concreto.</li>
<li><b>Guantes:</b> seg&uacute;n la tarea (cuero para carga, nitrilo para qu&iacute;micos, diel&eacute;ctricos para electricidad).</li>
<li><b>Botas con punta de acero:</b> evitan lesiones por aplastamiento y perforaci&oacute;n por clavos.</li>
<li><b>Protecci&oacute;n auditiva:</b> obligatoria sobre 85 dB (compactadoras, sierras, martillos neum&aacute;ticos).</li>
<li><b>Chaleco reflectivo:</b> imprescindible donde circulan veh&iacute;culos y maquinaria.</li></ul>
<p><b>Antes de empezar el turno:</b> revise que cada pieza est&eacute; completa, limpia y sin da&ntilde;os. Si algo falla, reporte y cambie la pieza antes de entrar a la obra.</p>',
 'Leccion 2 - Trabajo en alturas' => '<h2>Trabajo en alturas</h2>
<p>Se considera trabajo en alturas toda labor realizada a 1,80 m o m&aacute;s sobre el nivel inferior. Las ca&iacute;das son una de las principales causas de muerte en construcci&oacute;n.</p>
<ol><li><b>Permiso de trabajo:</b> ninguna tarea en alturas empieza sin permiso firmado por el supervisor y checklist de equipos.</li>
<li><b>Arn&eacute;s de cuerpo completo</b> con l&iacute;nea de vida y punto de anclaje certificado para 2 270 kg (5 000 lb).</li>
<li><b>Andamios:</b> base nivelada, barandas a 1 m, rodapi&eacute;s, plataformas completas y revisi&oacute;n diaria. Nunca se sobrecargan.</li>
<li><b>Escaleras:</b> &aacute;ngulo 75&deg; (1 m de apoyo por cada 4 m de altura), tres puntos de contacto, nunca sobre la &uacute;ltima huella.</li>
<li><b>Clima:</b> se suspende el trabajo con lluvia, rayos o viento fuerte.</li></ol>
<p>Solo puede trabajar en alturas quien tenga la capacitaci&oacute;n vigente. Esta lecci&oacute;n, con su evaluaci&oacute;n, deja constancia de qui&eacute;n la aprob&oacute;.</p>',
 'Leccion 3 - Prevencion de incendios y emergencias' => '<h2>Prevenci&oacute;n de incendios y emergencias</h2>
<p>En obra hay combustibles (di&eacute;sel, gasolina, solventes), soldadura y electricidad provisional: el riesgo de incendio es permanente.</p>
<ul><li><b>Extintores:</b> tipo ABC visibles, se&ntilde;alizados y revisados cada mes. Uso: <i>Halar el pasador, Apuntar a la base, Apretar la palanca, Barrer</i> (PASS/HAAB).</li>
<li><b>Orden y limpieza:</b> sin acumulaci&oacute;n de escombros, cart&oacute;n o madera cerca de zonas de soldadura.</li>
<li><b>Trabajos en caliente:</b> requieren permiso, extintor a la mano y vigilancia 30 min despu&eacute;s de terminar.</li>
<li><b>Combustibles:</b> en recipientes aprobados, lejos de fuentes de calor y con hoja de seguridad (SDS).</li></ul>
<p><b>Si hay una emergencia:</b> 1) d&eacute; la alarma, 2) llame al 911, 3) evacue por la ruta se&ntilde;alizada al punto de encuentro, 4) cuente al personal y 5) no regrese hasta que el encargado lo autorice.</p>',
];
$docIds = [];
foreach ($lecciones as $titulo => $html) {
    $docIds[$titulo] = paso("documento: $titulo", function () use ($curso, $titulo, $html) {
        $ruta = api_get_path(SYS_COURSE_PATH).$curso['directory'].'/document/';
        $archivo = preg_replace('/[^a-z0-9]+/', '_', strtolower(iconv('UTF-8', 'ASCII//TRANSLIT', $titulo))).'.html';
        $cuerpo = '<!DOCTYPE html><html><head><meta charset="utf-8"><title>'.$titulo.'</title></head><body>'.$html.'</body></html>';
        file_put_contents($ruta.$archivo, $cuerpo);
        $id = add_document($curso, '/'.$archivo, 'file', strlen($cuerpo), $titulo);
        if (!$id) { throw new Exception('add_document fallo'); }
        return $id;
    });
}

paso('ruta de aprendizaje (3 lecciones)', function () use ($code, $docIds, $ids) {
    $lpId = learnpath::add_lp($code, 'Seguridad en obra - Curso basico', 'Tres lecciones obligatorias antes de ingresar a obra.', 'guess', 'manual');
    $lp = new learnpath($code, $lpId, $ids['Instructor1']);
    $prev = 0;
    foreach ($docIds as $titulo => $docId) {
        if (!$docId) { continue; }
        $prev = $lp->add_item(0, $prev, 'document', $docId, $titulo, '');
    }
});

// ---------- 5) PDF descargable ----------
paso('recurso PDF descargable', function () use ($curso) {
    $lineas = [
        'Constructora Los Angeles - Hoja de verificacion de seguridad',
        '',
        '1. Casco, gafas, guantes, botas y chaleco completos y sin danos.',
        '2. Permiso de trabajo en alturas firmado y arnes con linea de vida.',
        '3. Andamios revisados, con barandas y rodapies.',
        '4. Extintor ABC visible y vigente en la zona de trabajo.',
        '5. Ruta de evacuacion y punto de encuentro conocidos por todos.',
    ];
    $stream = "BT /F1 12 Tf 50 780 Td 16 TL\n";
    foreach ($lineas as $l) { $stream .= '('.str_replace(['\\', '(', ')'], ['\\\\', '\\(', '\\)'], $l).") Tj T*\n"; }
    $stream .= "ET";
    $o = [];
    $o[1] = "<< /Type /Catalog /Pages 2 0 R >>";
    $o[2] = "<< /Type /Pages /Kids [3 0 R] /Count 1 >>";
    $o[3] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>";
    $o[4] = "<< /Length ".strlen($stream)." >>\nstream\n$stream\nendstream";
    $o[5] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>";
    $pdf = "%PDF-1.4\n"; $pos = [];
    foreach ($o as $n => $c) { $pos[$n] = strlen($pdf); $pdf .= "$n 0 obj\n$c\nendobj\n"; }
    $xref = strlen($pdf);
    $pdf .= "xref\n0 6\n0000000000 65535 f \n";
    foreach ($pos as $p) { $pdf .= sprintf("%010d 00000 n \n", $p); }
    $pdf .= "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n";
    $ruta = api_get_path(SYS_COURSE_PATH).$curso['directory'].'/document/Documento-Ejemplo.pdf';
    file_put_contents($ruta, $pdf);
    if (!add_document($curso, '/Documento-Ejemplo.pdf', 'file', strlen($pdf), 'Documento-Ejemplo.pdf')) {
        throw new Exception('add_document fallo');
    }
});

// ---------- 6) Evaluacion de 5 preguntas ----------
paso('evaluacion de 5 preguntas', function () use ($curso, $cid) {
    $preguntas = [
        ['Cual es la altura minima a partir de la cual se considera trabajo en alturas?',
            ['1,80 m', 'Mas de 5 m', 'Mas de 10 m', 'Solo en techos'], 0],
        ['Que debe hacerse antes de iniciar cualquier tarea en alturas?',
            ['Tener permiso de trabajo firmado y revisar el arnes', 'Empezar rapido para ahorrar tiempo', 'Pedir prestado el arnes de otro', 'Nada, si la tarea es corta'], 0],
        ['A partir de que nivel de ruido es obligatoria la proteccion auditiva?',
            ['60 dB', '85 dB', '120 dB', 'Nunca es obligatoria'], 1],
        ['Que significa la secuencia del extintor Halar, Apuntar, Apretar, Barrer?',
            ['Halar el pasador, apuntar a la base, apretar la palanca, barrer de lado a lado', 'Halar la manguera y correr', 'Apuntar al humo y esperar', 'Es la forma de recargarlo'], 0],
        ['Ante una emergencia en obra, que se hace primero?',
            ['Seguir trabajando', 'Dar la alarma y evacuar por la ruta senalizada al punto de encuentro', 'Grabar un video', 'Volver a buscar herramientas'], 1],
    ];
    $ex = new Exercise($cid);
    $ex->updateTitle('Evaluacion: Seguridad en obra');
    $ex->updateDescription('Cinco preguntas sobre EPP, trabajo en alturas e incendios. Cada pregunta vale 1 punto, el maximo es 5.');
    $ex->updateAttempts(0);
    $ex->updateFeedbackType(0);
    $ex->updateType(ALL_ON_ONE_PAGE);
    $ex->save();
    $exId = $ex->iid;
    if (!$exId) { throw new Exception('no se creo el ejercicio'); }

    foreach ($preguntas as $i => $p) {
        $q = new UniqueAnswer();
        $q->updateTitle($p[0]);
        $q->updateType(UNIQUE_ANSWER);
        $q->updateWeighting(1);
        $q->save($ex);
        $qid = $q->iid;
        $a = new Answer($qid, $cid, $ex, false);
        foreach ($p[1] as $k => $texto) {
            $a->createAnswer($texto, $k === $p[2] ? 1 : 0, '', $k === $p[2] ? 1 : 0, $k + 1);
        }
        $a->save();
        $ex->addToList($qid);
    }
    $ex->save();
});

echo $errores ? "Terminado con $errores error(es)\n" : "Terminado sin errores\n";
exit($errores ? 1 : 0);

