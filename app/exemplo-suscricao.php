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


$mqtt->subscribe('minha/empresa', function ($topic, $message) {
    printf("Mensagem recebida no tópico [%s]: %s\n", $topic, $message);
}, 0);

$mqtt->loop(true);
$mqtt->disconnect();
echo "Fim\n";