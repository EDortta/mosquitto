unit uTreco10;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  System.JSON,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  System.inifiles,
  MosquittoLoader,
  mqtt_reflektor_rc5, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TForm1 = class(TForm)
    mLog: TMemo;
    Label1: TLabel;
    eQuery: TEdit;
    bSend: TButton;
    bConfig: TButton;
    Timer1: TTimer;
    procedure bConfigClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure bSendClick(Sender: TObject);
    procedure eQueryChange(Sender: TObject);
  private
    { Private declarations }
  public
    function OnMessageReceived(messageId: TMessageID;
      Sender, target, subject, action: ansistring; payload: TJSONObject)
      : TJSONObject;
    procedure OnLog(msg: pchar);
    procedure associate;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses uConfig;

procedure TForm1.associate;
var
  payload: TJSONObject;
begin
  Timer1.Enabled := false;
  sleep(2000);

  Timer1.Enabled := mqttClient.connect(PAnsiChar(fConfig.host), fConfig.port,
    PAnsiChar(fConfig.username), PAnsiChar(fConfig.password),
    PAnsiChar(fConfig.topic), PAnsiChar(fConfig.myself));

  payload := TJSONObject.Create;
  payload.AddPair('Mensagem', 'Oi mundo!');
  payload.AddPair('Inteiro', inttostr(Random(1000)));
  payload.AddPair('String', 'Conjunto de letras');
  payload.AddPair('Flotante', floattostr(Random(1000) / 100));

  mqttClient.postMessage('*', 'replication', 'hello', payload);
end;

procedure TForm1.bConfigClick(Sender: TObject);
begin
  if (fConfig.ShowModal = mrOk) then
    associate;
end;

procedure TForm1.bSendClick(Sender: TObject);
var
  payload: TJSONObject;
begin
  payload := TJSONObject.Create;
  payload.AddPair('text', eQuery.Text);
  eQuery.Text := '';

  mqttClient.postMessage('*', 'replication', 'message', payload);
end;

procedure TForm1.eQueryChange(Sender: TObject);
begin
  bSend.Enabled := length(trim(eQuery.Text)) > 0;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  mqttClient.OnMessageReceived := OnMessageReceived;
  mqttClient.OnLogEvent := OnLog;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  if (length(fConfig.host) = 0) then
    fConfig.ShowModal
  else
    associate;
end;

procedure TForm1.OnLog(msg: pchar);
begin
  mLog.Lines.Add(msg)
end;

function TForm1.OnMessageReceived(messageId: TMessageID;
  Sender, target, subject, action: ansistring; payload: TJSONObject)
  : TJSONObject;
begin
  Result := nil;
  mLog.Lines.Add('MessageId: ' + messageId);
  mLog.Lines.Add('   Sender: ' + Sender);
  mLog.Lines.Add('   Target: ' + target);
  mLog.Lines.Add('  Subject: ' + subject);
  mLog.Lines.Add('   Action: ' + action);

end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := mqttClient.Run(5);
end;

end.
