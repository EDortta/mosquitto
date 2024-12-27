unit uService;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs,
  MosquittoLoader, mqtt_reflektor_rc6, uQueueReflektor, Registry;

type
  TreflektorService = class(TService)
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServicePause(Sender: TService; var Paused: Boolean);
    procedure ServiceContinue(Sender: TService; var Continued: Boolean);
    procedure ServiceExecute(Sender: TService);
    procedure ServiceAfterUninstall(Sender: TService);
    procedure ServiceBeforeInstall(Sender: TService);
    procedure ServiceAfterInstall(Sender: TService);
    procedure ServiceBeforeUninstall(Sender: TService);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  reflektorService: TreflektorService;

implementation

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  reflektorService.Controller(CtrlCode);
end;

function TreflektorService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TreflektorService.ServiceAfterInstall(Sender: TService);
var
  Reg: TRegistry;
begin
  LogMessage('Service installed', EVENTLOG_INFORMATION_TYPE);
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('\SYSTEM\CurrentControlSet\Services\' + name, false) then
    begin
      Reg.WriteString('Description', 'Data reflector');
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TreflektorService.ServiceAfterUninstall(Sender: TService);
begin
  LogMessage('Service uninstalled', EVENTLOG_INFORMATION_TYPE);
end;

procedure TreflektorService.ServiceBeforeInstall(Sender: TService);
begin
  LogMessage('Installing the service', EVENTLOG_INFORMATION_TYPE);
end;

procedure TreflektorService.ServiceBeforeUninstall(Sender: TService);
begin
  LogMessage('Starting service uninstallation', EVENTLOG_INFORMATION_TYPE);
end;

procedure TreflektorService.ServiceContinue(Sender: TService;
  var Continued: Boolean);
begin
  LogMessage('Continuing service', EVENTLOG_INFORMATION_TYPE);
  if (queueReflektorClient <> nil) then
  begin
    queueReflektorClient.Continue;
  end;
  Continued := True;
end;

procedure TreflektorService.ServiceExecute(Sender: TService);
begin
  LogMessage('Executing service', EVENTLOG_INFORMATION_TYPE);
  while not terminated do
  begin
    TThread.Sleep(1000);
  end;
  LogMessage('Service execution ended', EVENTLOG_INFORMATION_TYPE);
end;

procedure TreflektorService.ServicePause(Sender: TService; var Paused: Boolean);
begin
  LogMessage('Pausing service', EVENTLOG_INFORMATION_TYPE);
  if (queueReflektorClient <> nil) then
  begin
    queueReflektorClient.Pause;
  end;
  Paused := True;
end;

procedure TreflektorService.ServiceStart(Sender: TService;
  var Started: Boolean);
begin
  LogMessage('Starting service', EVENTLOG_INFORMATION_TYPE);
  if (queueReflektorClient = nil) then
  begin
    queueReflektorClient := TQueueReflektor.Create(True);
  end;
  queueReflektorClient.Start;
  Started := True;
end;

procedure TreflektorService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  LogMessage('Stopping service', EVENTLOG_INFORMATION_TYPE);
  if (queueReflektorClient <> nil) then
  begin
    queueReflektorClient.Pause;
    queueReflektorClient.Terminate;
    queueReflektorClient.WaitFor;
    FreeAndNil(queueReflektorClient);
  end;
  Stopped := True;
end;

end.
