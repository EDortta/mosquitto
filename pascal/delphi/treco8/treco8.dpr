program treco8;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.JSON,
  MosquittoLoader,
  mqtt_reflektor_rc3;

const
  host = 'w2.inovacaosistemas.com.br';
  port = 1883;
  username = 'syspan';
  password = '3h9j1E34';
  topic = 'repl/karazawa';
  myself = 'TREKO';

type
  TMyClient = class
  public
    function OnMessageReceived(messageId: TMessageID;
      sender, target, subject, action: ansistring; payload: TJSONObject)
      : TJSONObject;
  end;

function TMyClient.OnMessageReceived(messageId: TMessageID;
  sender, target, subject, action: ansistring; payload: TJSONObject)
  : TJSONObject;

begin
  Result := nil;
  writeln('MessageId: ', messageId);
  writeln('  Sender: ', sender);
  writeln('  Target: ', target);
  writeln('  Subject: ', subject);
  writeln('  Action: ', action);
end;

var
  myClient: TMyClient;
  payload: TJSONObject;

begin
  try
    payload := TJSONObject.Create;
    payload.AddPair('Mensagem', 'Oi mundo!');
    payload.AddPair('Inteiro', Random(1000));
    payload.AddPair('String', 'Conjunto de letras');
    payload.AddPair('Flotante', Random(1000) / 100);

    myClient := TMyClient.Create;
    mqttClient.OnMessageReceived := myClient.OnMessageReceived;
    mqttClient.connect(host, port, username, password, topic, myself);
    mqttClient.postMessage('*', 'replication', 'hello', payload);
    mqttClient.Run;
  except
    on E: Exception do
      writeln(E.ClassName, ': ', E.Message);
  end;

end.
