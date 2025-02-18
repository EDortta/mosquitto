unit uTreco11;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  System.JSON,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  System.inifiles,
  MosquittoLoader,
  uQueueReflektor, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TForm1 = class(TForm)
    mLog: TMemo;
    Label1: TLabel;
    eQuery: TEdit;
    bSend: TButton;
    bConfig: TButton;
    cbRunning: TCheckBox;
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
  cbRunning.Checked := false;
  sleep(2000);

  cbRunning.Checked := queueReflektorClient.connect(PAnsiChar(fConfig.host), fConfig.port,
    PAnsiChar(fConfig.username), PAnsiChar(fConfig.password),
    PAnsiChar(fConfig.topic), PAnsiChar(fConfig.myself));

  if queueReflektorClient.connected then begin

    payload := TJSONObject.Create;
    payload.AddPair('Mensagem', 'Oi mundo!');
    payload.AddPair('Inteiro', IntToStr(Random(1000)));
    payload.AddPair('String', 'Conjunto de letras');
    payload.AddPair('Flotante', FloatToStr(Random(1000) / 100));

    queueReflektorClient.postMessage('*', 'replication', 'hello', payload);

    queueReflektorClient.Resume;
  end;
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
  eQuery.Text:='';

  queueReflektorClient.postMessage('*', 'replication', 'message', payload);
end;

procedure TForm1.eQueryChange(Sender: TObject);
begin
  bSend.Enabled:=length(trim(eQuery.Text))>0;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  queueReflektorClient.OnMessageReceived := OnMessageReceived;
  queueReflektorClient.OnLogEvent := OnLog;
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
//  cbRunning.Checked := queueReflektorClient.Run(5);
end;

end.
