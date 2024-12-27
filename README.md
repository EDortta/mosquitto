# Introdução

JVMF, este é um exemplo bem simples de MQTT usando mosquitto e PHP 8.2.

Penso que deve ser útil para estabelecer o funcionamento mínimo de forma compreensível

Eliminei a segurança de usuário para facilitar. O correto em produção é ter usuário e senha e também usar TLS.

## Exemplos avulsos

A. Rodar um shell dentro da imagem do servidor MQTT Mosquitto na rede `mosquitto_pernilongo`

```bash
docker run -it -p 1883:1883 -p 9001:9001 --network=mosquitto_pernilongo -v $(pwd)/shared/config/mosquitto.conf:/mosquitto/config/mosquitto.conf -it eclipse-mosquitto sh
```
Esse shell pode servir para conferir o funcionamento no braço.


B. Rodar um servidor mosquitto na rede `mosquitto_pernilongo`

```bash
docker run -it -p 1883:1883 -p 9001:9001 --network=mosquitto_pernilongo -v $(pwd)/shared/config/mosquitto.conf:/mosquitto/config/mosquitto.conf eclipse-mosquitto
```

Esse servidor pode servir para testar manualmente o funcionamento com outros clientes, por exemplo

C. Rodar um shell dentro da imagem php na rede `mosquito_pernilongo`

```bash
docker run -v $(pwd)/app:/var/www/html --network=mosquitto_pernilongo  -it php:8.2-alpine3.16 sh
```

Isso pode ser util para fazer coisas como a seguinte:

Abra dois console e rode dois deles

Em um faça assim:
```bash
cd /var/www/html
php exemplo-suscricao.php
```

E no outro assim:
```bash
cd /var/www/html
php exemplo-envio.php
```

A cada cutucada em `exemplo-envio.php` uma nova linha vai aparecer no outro console. Isso pode ajudar a construir a ideia de suscrições com o que se pode construir um esquema de envio de mensagens em um sentido.

A comunicação em dois sentidos se pode fazer simplesmente tendo um outro canal para a resposta específica para o solicitante.

Uma coisa que pode ser interessante, é abrir mais de um `exemplo-suscricao.php`

## Finalmente

Repare que a mensagem é livre. Um `JSON` dá conta de tudo o que precisa. Você mesmo pode criar a estrutura que precisar.

*Não estou usando exceções* o correto é fazer esse tratamento.
