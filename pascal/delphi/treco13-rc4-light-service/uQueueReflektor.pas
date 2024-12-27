unit uQueueReflektor;

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

  TQueueReflektor = class(TThread)
  private
    mq: Pmosquitto;
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
    FPaused, FConnected: boolean;

  public
    function connect(host: PAnsiChar; port: integer;
      username, password, topic: PAnsiChar; clientId: ansistring;
      asReceiver: boolean = false): boolean;
    function postMessage(target, subject, action: string; payload: TJSONObject)
      : TMessageID;
    function broadcastMessage(subject, action: string; payload: TJSONObject)
      : TMessageID;

    procedure pause;
    procedure continue;

    property connected: boolean read FConnected;

    property OnMessageReceived: TOnMessageReceivedEvent read FOnMessageReceived
      write FOnMessageReceived;
    property OnIdle: TOnIdleEvent read FOnIdle write FOnIdle;
    property OnLogEvent: TOnLogEvent read FOnLogEvent write FOnLogEvent;

  protected
    constructor Create(CreateSuspended: boolean);

    function EncodeMessage(sender, target, subject, action: string;
      payload: TJSONObject): TJSONObject;
    function DecodeMessage(msg: ansistring): TJSONObject;

    procedure log(const msg: pchar);
    procedure on_log(mosq: Pmosquitto; obj: pointer; level: integer;
      const str: pchar);
    procedure on_message(mosq: Pmosquitto; obj: pointer;
      const message: P_mosquitto_message);

    procedure Execute; override;
  end;

procedure _log(tag: string; msg: pchar);

var
  major, minor, revision: integer;
  queueReflektorReceiver, queueReflektorClient: TQueueReflektor;

implementation

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
  queueReflektorClient.on_log(mosq, obj, level, str);
end;

procedure mqtt_on_message(mosq: Pmosquitto; obj: pointer;
  const message: P_mosquitto_message); cdecl;
begin
  // _log('any', PWideChar('message on ' + message^.topic));
  queueReflektorClient.on_message(mosq, obj, message);
end;

{ TQueueReflektor }

function TQueueReflektor.broadcastMessage(subject, action: string;
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

procedure TQueueReflektor.pause;
begin
  _log('basement', 'Pausing TQueueReflektor');
  FPaused := true;
end;

function TQueueReflektor.postMessage(target, subject, action: string;
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

function TQueueReflektor.EncodeMessage(sender, target, subject, action: string;
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

function TQueueReflektor.DecodeMessage(msg: ansistring): TJSONObject;
var
  auxJSONObject: TJSONObject;
  target, sender: ansistring;
begin
  Result := nil;
  // msg := StringReplace(msg, '''''', '"', [rfReplaceAll]);
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

function TQueueReflektor.connect(host: PAnsiChar; port: integer;
  username, password, topic: PAnsiChar; clientId: ansistring;
  asReceiver: boolean): boolean;
var
  receiverTopic: ansistring;
begin
  FConnected := false;
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
    FConnected := (0 = mosquitto_connect(mq, MQTT_HOST, MQTT_PORT, 60));
    if connected then
    begin

      log(PWideChar('Subscribing to ' + MQTT_TOPIC));
      mosquitto_subscribe(mq, nil, MQTT_TOPIC, 1);

      if (not asReceiver) then
      begin
        if (nil = queueReflektorReceiver) then
        begin
          runningFlag := GetCurrentDir + '\flags\' + clientId + '.flag';
          try
            log(PWideChar('Running Flag ' + runningFlag));
            ForceDirectories(ExtractFilePath(runningFlag));
            running := true;
          except
            log(PWideChar('Was not possible to create ' +
              ExtractFilePath(runningFlag)));
          end;

          TouchFile(runningFlag);

          receiverTopic := ansistring(topic) + '@' + clientId;
          queueReflektorReceiver := TQueueReflektor.Create(true);
          queueReflektorReceiver.connect(host, port, username, password,
            PAnsiChar(receiverTopic), clientId + '-listener', true);
        end;
      end;

      Result := true;
    end
    else
    begin
      _log('basement', 'ERROR: Cannot connect to mosquitto queue');
      Result := false;
    end;

  end
  else
  begin
    _log('basement', 'ERROR: Cannot create a mosquitto instance.');
    Result := false;
  end;
end;

procedure TQueueReflektor.continue;
begin
  _log('basement', 'Continuing TQueueReflektor');
  FPaused := false;
end;

constructor TQueueReflektor.Create(CreateSuspended: boolean);
begin
  _log('basement', 'Creating TQueueReflektor');
  inherited Create(CreateSuspended);
  Priority := tpNormal;
  FreeOnTerminate := true;

  running := false;
  if mosquitto_lib_init <> MOSQ_ERR_SUCCESS then
  begin
    _log('basement', 'mosquito.dll cannot be initialized');
  end;
end;

procedure TQueueReflektor.Execute;
var
  ok: boolean;
begin
  FPaused := false;
  NameThreadForDebugging('QueueReflektor');
  _log('basement', 'Thread being executed');
  ok := true;
  while (not Terminated) and (running) and (ok) do
  begin
    if (not FPaused) then
    begin
      mosquitto_loop(mq, 100, 1);
    end;
  end;
  _log('basement', 'Thread terminated');

end;

procedure TQueueReflektor.log(const msg: pchar);
begin
  _log('any', msg);
end;

procedure TQueueReflektor.on_log(mosq: Pmosquitto; obj: pointer; level: integer;
  const str: pchar);
begin

end;

procedure TQueueReflektor.on_message(mosq: Pmosquitto; obj: pointer;
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
          begin
            synchronize(
              procedure()
              begin
                JSONObj := FOnMessageReceived(JSONMessage.GetValue<String>
                  ('messageId', ''), JSONMessage.GetValue<String>('sender', ''),
                  JSONMessage.GetValue<String>('target', ''),
                  JSONMessage.GetValue<String>('subject', ''),
                  JSONMessage.GetValue<String>('action', ''),
                  TJSONObject(JSONMessage.GetValue<TJSONObject>('payload')));
              end);

            if Assigned(JSONObj) then
            begin
              _log('basement',
                PWideChar('  Message: ' + JSONObj.GetValue<String>('msg', '')));
              _log('basement',
                PWideChar('  Date: ' + JSONObj.GetValue<String>('date', '')));
            end;
          end;
        end;
      finally
        JSONMessage.Free;
      end;
    end;
  end;
end;

var
  location: string;

begin
  location := ExtractFilePath(ExtractFilePath(ParamStr(0)));
  SetCurrentDir(location);
  mosquitto_lib_version(@major, @minor, @revision);
  _log('basement', PWideChar('Running against libmosquitto ' + inttostr(major) +
    '.' + inttostr(minor) + '.' + inttostr(revision)));

end.
