unit uConfig;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes,
  Vcl.Graphics,
  Registry,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, mqtt_reflektor_rc5;

type
  TfConfig = class(TForm)
    Label1: TLabel;
    eHost: TEdit;
    Label2: TLabel;
    ePort: TEdit;
    Label3: TLabel;
    Label4: TLabel;
    eUsername: TEdit;
    Label5: TLabel;
    ePassword: TEdit;
    Label6: TLabel;
    eTopic: TEdit;
    Label7: TLabel;
    eMyself: TEdit;
    Button1: TButton;
    Button2: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    port: integer;
    host, username, password, topic, myself: ansistring;
    { Public declarations }
    procedure associate;
  end;

var
  fConfig: TfConfig;

implementation

{$R *.dfm}

procedure TfConfig.Button1Click(Sender: TObject);
begin
  port := StrToIntDef(ePort.Text, 1883);
  ePort.Text := IntToStr(port);

  host := trim(eHost.Text);
  username := trim(eUsername.Text);
  password := trim(ePassword.Text);
  topic := trim(eTopic.Text);
  myself := trim(eMyself.Text);

  if (host > '') then
  begin
    with TRegistry.Create do
    begin
      RootKey := HKEY_CURRENT_USER;
      OpenKey('Software\InovacaoSistemas\reflektor', TRUE);

      WriteInteger('Port', port);
      WriteString('Host', host);
      WriteString('Username', username);
      WriteString('Password', password);
      WriteString('Topic', topic);
      WriteString('Myself', myself);

      CloseKey;
    end;

    ModalResult := mrOk;
  end;
end;

procedure TfConfig.Button2Click(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TfConfig.associate;
begin end;

procedure TfConfig.FormCreate(Sender: TObject);
begin
  with TRegistry.Create do
  begin
    RootKey := HKEY_CURRENT_USER;
    OpenKey('Software\InovacaoSistemas\reflektor', FALSE);
    if (ValueExists('Port')) then
    begin
      port := ReadInteger('Port');
      host := ReadString('Host');
      username := ReadString('Username');
      password := ReadString('Password');
      topic := ReadString('Topic');
      myself := ReadString('Myself');

      ePort.Text := IntToStr(port);
      eHost.Text := host;
      eUsername.Text := username;
      ePassword.Text := password;
      eTopic.Text := topic;
      eMyself.Text := myself;

    end;

    CloseKey;
  end;

end;

end.
