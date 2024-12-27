program treco9;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.JSON,
  System.inifiles,
  MosquittoLoader,
  mqtt_reflektor_rc4;

var
  port: integer;
  host, username, password, topic, myself: ansistring;

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

procedure ReadConfig(filename: string);
var
  IniFile: TIniFile;
begin
  if FileExists(filename) then
  begin
    IniFile := TIniFile.Create(GetCurrentDir + '\' + filename);
    try
      host := ansistring(IniFile.ReadString('QUEUE', 'host', ''));
      port := IniFile.ReadInteger('QUEUE', 'port', 0);
      if ('' = host) or (port = 0) then
      begin
        writeln('QUEUE/host and/or QUEUE/port are empty in ' + filename);
        halt(1);
      end;

      username := IniFile.ReadString('QUEUE', 'username', '');
      password := IniFile.ReadString('QUEUE', 'password', '');
      topic := IniFile.ReadString('QUEUE', 'topic', '');
      myself := IniFile.ReadString('QUEUE', 'myself', '');
    finally
      IniFile.Free;
    end;
  end
  else
  begin
    writeln('File not found');
    halt(1);
  end;
end;

begin
  if ParamCount = 1 then
  begin
    // ParamStr(1) should be the path to the config file
    ReadConfig(ParamStr(1));
    try
      payload := TJSONObject.Create;
      payload.AddPair('Mensagem', 'Oi mundo!');
      payload.AddPair('Inteiro', Random(1000));
      payload.AddPair('String', 'Conjunto de letras');
      payload.AddPair('Flotante', Random(1000) / 100);

      myClient := TMyClient.Create;
      mqttClient.OnMessageReceived := myClient.OnMessageReceived;
      mqttClient.connect(PAnsiChar(host), port, PAnsiChar(username),
        PAnsiChar(password), PAnsiChar(topic), PAnsiChar(myself));
      mqttClient.postMessage('*', 'replication', 'hello', payload);
      mqttClient.Run;
    except
      on E: Exception do
        writeln(E.ClassName, ': ', E.Message);
    end;

  end
  else
  begin
    writeln('Please, indicate the config file to be used');
  end;

end.
