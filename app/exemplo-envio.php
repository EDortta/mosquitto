<?php
require('vendor/autoload.php');
use \PhpMqtt\Client\MqttClient;
use \PhpMqtt\Client\ConnectionSettings;

$server   = 'mos2';
$port     = 1883;
$clientId = rand(5, 15);
// $username = 'USUARIO';
// $password = 'SENHA';
$clean_session = false;
$mqtt_version = MqttClient::MQTT_3_1_1;

$connectionSettings = (new ConnectionSettings)
//   ->setUsername($username)
//   ->setPassword($password)
  ->setKeepAliveInterval(60)
  ->setLastWillTopic('minha/empresa/test')
  ->setLastWillMessage('client disconnect')
  ->setLastWillQualityOfService(1);


$mqtt = new MqttClient($server, $port, $clientId, $mqtt_version);

$mqtt->connect($connectionSettings, $clean_session);
printf("Conectado!\n");


/**
 * Esta lista a peguei de https://www.vortexmag.net/as-100-palavras-mais-estranhas-da-lingua-portuguesa-e-o-seu-significado/
 */
$palavras = explode("\n", file_get_contents('palavras.txt'));
$palavra_random = $palavras[array_rand($palavras)];
$palavra = substr($palavra_random,0,strpos($palavra_random,' '));
$definicao = substr($palavra_random,strpos($palavra_random,' '));
echo "Enviando $palavra\n";

$qos=0;
$retain=true;

$payload = [
    'data' => date("Y-m-d H:i:s"),
    'mensagem' => 'teste',
    'palavra' => $palavra,
    'definicao' => $definicao
];

$mqtt->publish(
    'minha/empresa',
    json_encode($payload),
    $qos,
    $retain
  );

$mqtt->disconnect();

echo "Fim\n";