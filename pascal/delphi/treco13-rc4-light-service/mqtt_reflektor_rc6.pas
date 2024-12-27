unit mqtt_reflektor_rc6;

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
  TOnLogEvent = procedure(msg: pchar) of object;

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
    running: boolean;
    runningFlag: string;

    FOnMessageReceived: TOnMessageReceivedEvent;
    FOnIdle: TOnIdleEvent;
    FOnLogEvent: TOnLogEvent;
    function EncodeMessage(sender, target, subject, action: string;
      payload: TJSONObject): TJSONObject;
    function DecodeMessage(msg: ansistring): TJSONObject;
    procedure log(const msg: pchar);
    procedure on_log(mosq: Pmosquitto; obj: pointer; level: integer;
      const str: pchar);
    procedure on_message(mosq: Pmosquitto; obj: pointer;
      const message: P_mosquitto_message);
    procedure Loop;
  public
    constructor Create;
    function connect(host: PAnsiChar; port: integer;
      username, password, topic: PAnsiChar; clientId: ansistring;
      asReceiver: boolean = false): boolean;
    function postMessage(target, subject, action: string; payload: TJSONObject)
      : TMessageID;
    function broadcastMessage(subject, action: string; payload: TJSONObject)
      : TMessageID;
    property OnMessageReceived: TOnMessageReceivedEvent read FOnMessageReceived
      write FOnMessageReceived;
    property OnIdle: TOnIdleEvent read FOnIdle write FOnIdle;
    property OnLogEvent: TOnLogEvent read FOnLogEvent write FOnLogEvent;
    destructor Destroy; override;
    function Run(iteractions: integer = 1000): boolean;
  end;

var
  mqttReceiver, mqttClient: TMqttClient;

implementation

var
  major, minor, revision: integer;

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

function PrintHexStr(str: pchar): string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to StrLen(str) - 1 do
  begin
    if (Ord(str[i]) < 32) or (Ord(str[i]) > 126) then
      Result := Result + (Format('%x ', [Ord(str[i])]))
    else
      Result := Result + (str[i]);
  end;
end;

procedure TouchFile(FileName: string);
var
  FileHandle: integer;
begin
  FileHandle := FileCreate(FileName);
  if FileHandle <> 0 then
  begin
    try
    finally
      FileClose(FileHandle);
    end;
  end
  else
    raise Exception.Create('Failed to create file.');
end;

procedure _log(tag: string; msg: pchar);
var
  LogFile: TextFile;
  LogFilePath: string;
begin
  LogFilePath := GetCurrentDir() + '\logs\' + tag + '.log';
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
    // writeln(PrintHexStr(msg));
    writeln(LogFile, Format('[%s] %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss',
      Now), PrintHexStr(msg)]));
  finally
    CloseFile(LogFile);
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
  _log('any', PWideChar('message on ' + message^.topic));
  mqttClient.on_message(mosq, obj, message);
end;

constructor TMqttClient.Create;
begin
  inherited Create();
  running := false;
  if mosquitto_lib_init <> MOSQ_ERR_SUCCESS then
  begin
    writeln('Failed.');
    halt(1);
  end;
end;

function TMqttClient.connect(host: PAnsiChar; port: integer;
  username, password, topic: PAnsiChar; clientId: ansistring;
  asReceiver: boolean = false): boolean;
var
  receiverTopic: ansistring;
begin
  MQTT_HOST := host;
  MQTT_PORT := port;
  MQTT_USERNAME := username;
  MQTT_PASSWORD := password;
  MQTT_TOPIC := topic;
  MQTT_MYSELF := clientId;

  mq := mosquitto_new(nil, 1, nil);
  if Assigned(mq) then
  begin
    log('----------------------------------------------');
    log(PWideChar('Connecting to ' + host + ' ' + MQTT_TOPIC));
    mosquitto_log_callback_set(mq, @mqtt_on_log);
    mosquitto_message_callback_set(mq, @mqtt_on_message);
    mosquitto_username_pw_set(mq, MQTT_USERNAME, MQTT_PASSWORD);
    mosquitto_connect(mq, MQTT_HOST, MQTT_PORT, 60);
    log(PWideChar('Subscribing to ' + MQTT_TOPIC));
    mosquitto_subscribe(mq, nil, MQTT_TOPIC, 1);

    if (not asReceiver) then
    begin
      if (nil = mqttReceiver) then
      begin
        runningFlag := GetCurrentDir + '\flags\' + clientId + '.flag';
        try
          log(PWideChar('Running Flag ' + runningFlag));
          ForceDirectories(ExtractFilePath(runningFlag));
        except
          log(PWideChar('Was not possible to create ' +
            ExtractFilePath(runningFlag)));
        end;

        TouchFile(runningFlag);

        receiverTopic := ansistring(topic) + '@' + clientId;
        mqttReceiver := TMqttClient.Create;
        mqttReceiver.connect(host, port, username, password,
          PAnsiChar(receiverTopic), clientId + '-listener', true);
      end;
    end;

    Result := true;

  end
  else
  begin
    writeln('ERROR: Cannot create a mosquitto instance.');
    Result := false;
  end;
end;

function TMqttClient.broadcastMessage(subject, action: string;
  payload: TJSONObject): TMessageID;
var
  JSONData: TJSONValue;
  msg: ansistring;
begin
  log(PWideChar('Broadcasting "' + subject + ':' + action + '" on ' +
    MQTT_TOPIC));

  JSONData := EncodeMessage(MQTT_MYSELF, '*', subject, action, payload);
  msg := JSONData.ToJSON;
  log(PWideChar('payload: ' + JSONData.ToJSON));
  log(PWideChar('Length: ' + inttostr(length(msg))));
  Result := JSONData.GetValue<String>('messageId', '');
  log(PWideChar('publish_ret:' + inttostr(mosquitto_publish(mq, nil, MQTT_TOPIC,
    length(msg), pchar(msg), 1, 0))));
end;

function TMqttClient.postMessage(target, subject, action: string;
  payload: TJSONObject): TMessageID;
var
  JSONData: TJSONValue;
  targetTopic, msg: ansistring;
begin
  if (target = '*') then
    Result := broadcastMessage(subject, action, payload)
  else
  begin
    if (target <> MQTT_MYSELF) then
    begin
      targetTopic := ansistring(MQTT_TOPIC) + '@' + target;
      log(PWideChar('Posting ' + subject + ':' + action + ' to ' + target +
        ' on ' + targetTopic));

      JSONData := EncodeMessage(MQTT_MYSELF, target, subject, action, payload);
      msg := JSONData.ToJSON;
      log(PWideChar('payload: ' + JSONData.ToJSON));
      log(PWideChar('Length: ' + inttostr(length(msg))));
      Result := JSONData.GetValue<String>('messageId', '');

      mosquitto_publish(mq, nil, PAnsiChar(targetTopic), length(msg),
        pchar(msg), 1, 0);
    end
    else
    begin
      Result := '';
    end;
  end;
end;

procedure TMqttClient.log(const msg: pchar);
begin
  if (Assigned(FOnLogEvent)) then
    FOnLogEvent(msg);
  _log(MQTT_MYSELF, msg);
end;

procedure TMqttClient.on_log(mosq: Pmosquitto; obj: pointer; level: integer;
  const str: pchar);
begin
  // if (assigned(FOnLogEvent)) then
  // FOnLogEvent(str);
  _log('any', 'Activity');
  // log(str);
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

    log(PWideChar('Payloadlen ' + inttostr(payloadlen)));

    SetLength(msg, payloadlen);
    if (payloadlen > 0) then
      Move(payload^, msg[1], payloadlen);
    log(PWideChar('Topic: [' + topic + '] - Message: [' + msg + ']'));
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
              TJSONObject(JSONMessage.GetValue<TJSONObject>('payload')));

          if Assigned(JSONObj) then
          begin
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

procedure TMqttClient.Loop;
begin
  mosquitto_loop(mq, 100, 1)
end;

function TMqttClient.Run(iteractions: integer = 1000): boolean;
var
  ret: boolean;
begin
  ret := true;
  if (not running) then
  begin
    try
      running := true;
      while ((iteractions = -1) or (iteractions > 0)) and
        (mosquitto_loop(mq, 100, 1) = MOSQ_ERR_SUCCESS) do
      begin
        if (iteractions > 0) then
          iteractions := iteractions - 1;
        if (runningFlag <> '') then
        begin
          if (not FileExists(runningFlag)) then
          begin
            ret := false;
            break;
          end;

          if (Assigned(mqttReceiver)) then
            mqttReceiver.Loop;
        end;

        if (Assigned(FOnIdle)) then
          FOnIdle;
      end;
    finally
      running := false;
    end;
  end;

  Result := ret;
end;

var
  location: string;

begin
  location := ExtractFilePath(ExtractFilePath(ParamStr(0)));
  SetCurrentDir(location);

  mosquitto_lib_version(@major, @minor, @revision);
  _log('any', PWideChar('Running against libmosquitto ' + inttostr(major) + '.'
    + inttostr(minor) + '.' + inttostr(revision)));

  mqttClient := TMqttClient.Create;

end.
