unit mqtt_reflektor_rc3;

interface

uses
  Classes,
  SysUtils,
  System.JSON,
  Mosquitto;

type
  TMessageID = ansistring;
  TOnMessageReceivedEvent = function(messageId: TMessageID;
    sender, target, subject, action: ansistring; payload: TJSONObject)
    : TJSONObject of object;
  TOnIdleEvent = procedure of object;

  TMqttClient = class
  private
    mq: Pmosquitto;
    major, minor, revision: integer;
    MQTT_HOST: PAnsiChar;
    MQTT_PORT: integer;
    MQTT_USERNAME: PAnsiChar;
    MQTT_PASSWORD: PAnsiChar;
    MQTT_TOPIC: PAnsiChar;
    MQTT_MYSELF: ansistring;
    FOnMessageReceived: TOnMessageReceivedEvent;
    FOnIdle: TOnIdleEvent;
    function EncodeMessage(sender, target, subject, action: string;
      payload: TJSONObject): TJSONObject;
    function DecodeMessage(msg: ansistring): TJSONObject;
    procedure log(const msg: pchar);
    procedure on_log(mosq: Pmosquitto; obj: pointer; level: integer;
      const str: pchar);
    procedure on_message(mosq: Pmosquitto; obj: pointer;
      const message: P_mosquitto_message);
  public
    constructor Create;
    function connect(host: PAnsiChar; port: integer;
      username, password, topic: PAnsiChar; clientId: ansistring): boolean;
    function postMessage(target, subject, action: string; payload: TJSONObject)
      : TMessageID;
    property OnMessageReceived: TOnMessageReceivedEvent read FOnMessageReceived
      write FOnMessageReceived;
    property OnIdle: TOnIdleEvent read FOnIdle write FOnIdle;
    destructor Destroy; override;
    procedure Run;
  end;

var
  mqttClient: TMqttClient;

implementation

var
  major, minor, revision: integer;
  mq: Pmosquitto;

function TMqttClient.EncodeMessage(sender, target, subject, action: string;
  payload: TJSONObject): TJSONObject;
var
  messageId: TGuid;
begin
  CreateGUID(messageId);
  Result := TJSONObject.Create;
  Result.AddPair('messageId', GUIDToString(messageId));
  Result.AddPair('sender', sender);
  Result.AddPair('target', target);
  Result.AddPair('subject', subject);
  Result.AddPair('action', action);
  Result.AddPair('payload', payload);
end;

function TMqttClient.DecodeMessage(msg: ansistring): TJSONObject;
var
  auxJSONObject: TJSONObject;
  target, sender: ansistring;
begin
  Result := nil;
  auxJSONObject := TJSONObject(TJSONObject.ParseJSONValue(msg));
  try
    sender := auxJSONObject.GetValue('sender', '');
    if (sender <> MQTT_MYSELF) then
    begin
      target := auxJSONObject.GetValue('target', '');
      if (target = '*') or (target = MQTT_MYSELF) then
      begin
        Result := auxJSONObject;
        auxJSONObject := nil;
      end;
    end;
  finally
    auxJSONObject.Free;
  end;
end;

procedure mqtt_on_log(mosq: Pmosquitto; obj: pointer; level: integer;
  const str: pchar); cdecl;
begin
  mqttClient.on_log(mosq, obj, level, str);
end;

procedure mqtt_on_message(mosq: Pmosquitto; obj: pointer;
  const message: P_mosquitto_message); cdecl;
begin
  mqttClient.on_message(mosq, obj, message);
end;

constructor TMqttClient.Create;
begin
  inherited Create();
  if mosquitto_lib_init <> MOSQ_ERR_SUCCESS then
  begin
    writeln('Failed.');
    halt(1);
  end;
end;

function TMqttClient.connect(host: PAnsiChar; port: integer;
  username, password, topic: PAnsiChar; clientId: ansistring): boolean;
begin
  MQTT_HOST := host;
  MQTT_PORT := port;
  MQTT_USERNAME := username;
  MQTT_PASSWORD := password;
  MQTT_TOPIC := topic;
  MQTT_MYSELF := clientId;

  mosquitto_lib_version(@major, @minor, @revision);
  writeln('Running against libmosquitto ', major, '.', minor, '.', revision);
  mq := mosquitto_new(nil, 1, nil);
  if Assigned(mq) then
  begin
    mosquitto_log_callback_set(mq, @mqtt_on_log);
    mosquitto_message_callback_set(mq, @mqtt_on_message);
    mosquitto_username_pw_set(mq, MQTT_USERNAME, MQTT_PASSWORD);
    mosquitto_connect(mq, MQTT_HOST, MQTT_PORT, 60);
    mosquitto_subscribe(mq, nil, MQTT_TOPIC, 1);
    Result := true;
  end
  else
  begin
    writeln('ERROR: Cannot create a mosquitto instance.');
    Result := false;
  end;
end;

function TMqttClient.postMessage(target, subject, action: string;
  payload: TJSONObject): TMessageID;
var
  JSONData: TJSONValue;
  msg: ansistring;
begin
  JSONData := EncodeMessage(MQTT_MYSELF, target, subject, action, payload);
  msg := JSONData.Value;
  Result := JSONData.GetValue<String>('messageId', '');
  // Result := JSONData.GetValue<String>('messageId', '');
  mosquitto_publish(mq, nil, MQTT_TOPIC, Length(msg), pchar(msg), 1, 0);
end;

procedure TMqttClient.log(const msg: pchar);
var
  LogFile: TextFile;
  LogFilePath: string;
begin
  LogFilePath := GetCurrentDir()+'\logs\log.txt';
  try
    ForceDirectories(ExtractFilePath(LogFilePath));
  except
    writeln('Was not possible to create ' + ExtractFilePath(LogFilePath));
    halt(1);
  end;
  AssignFile(LogFile, LogFilePath);
  try
    Append(LogFile);
  except
    Rewrite(LogFile);
  end;
  try
    writeln(LogFile, msg);
  finally
    CloseFile(LogFile);
  end;
end;

procedure TMqttClient.on_log(mosq: Pmosquitto; obj: pointer; level: integer;
  const str: pchar);
begin
  log(str);
end;

procedure TMqttClient.on_message(mosq: Pmosquitto; obj: pointer;
  const message: P_mosquitto_message);
var
  JSONMessage: TJSONObject;
  JSONObj: TJSONObject;
  msg: ansistring;
begin
  msg := '';
  with message^ do
  begin

    writeln('Payloadlen ' + IntToStr(payloadlen));

    SetLength(msg, payloadlen);
    if (payloadlen>0) then
      Move(payload^, msg[1], payloadlen);
    writeln('Topic: [', topic, '] - Message: [', msg, ']');
    JSONMessage := DecodeMessage(msg);
    if (JSONMessage <> nil) then
    begin
      try
        if JSONMessage is TJSONObject then
        begin
          if (Assigned(FOnMessageReceived)) then
            JSONObj := FOnMessageReceived
              (JSONMessage.GetValue<String>('messageId', ''),
              JSONMessage.GetValue<String>('sender', ''),
              JSONMessage.GetValue<String>('target', ''),
              JSONMessage.GetValue<String>('subject', ''),
              JSONMessage.GetValue<String>('action', ''),
              TJSONObject(JSONMessage.GetValue<String>('payload')));

          writeln('  Message: ', JSONObj.GetValue<String>('msg', ''));
          writeln('  Date: ', JSONObj.GetValue<String>('date', ''));
          // JSONObj := EncodeMessage(
          // MQTT_MYSELF,
          // JSONData.GetValue<String>('sender', ''),
          // JSONData.GetValue<String>('action', 'answer'),
          // TJSONObject.Create(
          // ['Inteiro', Random(1000), 'String', 'Conjunto de letras', 'Float', Random(1000) / 100]
          // )
          // );
          // msg := JSONObj.AsJSON;
          // mosquitto_publish(mosq, nil, MQTT_TOPIC, Length(msg), PChar(msg), 1, False);
        end;
      finally
        JSONMessage.Free;
      end;
    end;
  end;
end;

destructor TMqttClient.Destroy;
begin
  if Assigned(mq) then
  begin
    mosquitto_disconnect(mq);
    mosquitto_destroy(mq);
  end;
  mosquitto_lib_cleanup;
  inherited;
end;

procedure TMqttClient.Run;
begin
  while mosquitto_loop(mq, 100, 1) = MOSQ_ERR_SUCCESS do
  begin
    if (Assigned(FOnIdle)) then
      FOnIdle;
  end;
end;

begin
  mqttClient := TMqttClient.Create;
end.
