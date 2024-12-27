{
  NT Service  model based completely on API calls. Version 0.1
  Inspired by NT service skeleton from Aphex
  Adapted by Runner
}

program ReflektorService;

{$APPTYPE CONSOLE}
{$IF CompilerVersion > 20}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$WEAKLINKRTTI ON}
{$IFEND}

uses
  Windows,
  System.SysUtils,
  WinSvc,
  mosquitto in 'mosquitto.pas',
  MosquittoLoader in 'MosquittoLoader.pas',
  mqtt_reflektor_rc6 in 'mqtt_reflektor_rc6.pas',
  uQueueReflektor in 'uQueueReflektor.pas',
  registry;

const
  ServiceName = 'ReflektorService';
  DisplayName = 'Data and messages Reflektor Service';
  NUM_OF_SERVICES = 2;

var
  ServiceStatus: TServiceStatus;
  StatusHandle: SERVICE_STATUS_HANDLE;
  ServiceTable: array [0 .. NUM_OF_SERVICES] of TServiceTableEntry;
  Stopped: Boolean;
  Paused: Boolean;

var
  ghSvcStopEvent: Cardinal;

procedure OnServiceCreate;
begin
  // do your stuff here;
  _log('basement', 'OnServiceCreate');
  queueReflektorClient := TQueueReflektor.Create(true);
end;

procedure AfterUninstall;
begin
  // do your stuff here;
  _log('basement', 'AfterUninstall');
end;

procedure ReportSvcStatus(dwCurrentState, dwWin32ExitCode, dwWaitHint: DWORD);
begin
  // fill in the SERVICE_STATUS structure.
  ServiceStatus.dwCurrentState := dwCurrentState;
  ServiceStatus.dwWin32ExitCode := dwWin32ExitCode;
  ServiceStatus.dwWaitHint := dwWaitHint;

  case dwCurrentState of
    SERVICE_START_PENDING:
      ServiceStatus.dwControlsAccepted := 0;
  else
    ServiceStatus.dwControlsAccepted := SERVICE_ACCEPT_STOP;
  end;

  case (dwCurrentState = SERVICE_RUNNING) or
    (dwCurrentState = SERVICE_STOPPED) of
    true:
      ServiceStatus.dwCheckPoint := 0;
    False:
      ServiceStatus.dwCheckPoint := 1;
  end;

  // Report the status of the service to the SCM.
  SetServiceStatus(StatusHandle, ServiceStatus);
end;

procedure MainProc;
begin
  // we have to do something or service will stop
  ghSvcStopEvent := CreateEvent(nil, true, False, nil);

  if ghSvcStopEvent = 0 then
  begin
    ReportSvcStatus(SERVICE_STOPPED, NO_ERROR, 0);
    Exit;
  end;

  // Report running status when initialization is complete.
  ReportSvcStatus(SERVICE_RUNNING, NO_ERROR, 0);

  // Perform work until service stops.
  while true do
  begin
    // Check whether to stop the service.
    WaitForSingleObject(ghSvcStopEvent, INFINITE);
    ReportSvcStatus(SERVICE_STOPPED, NO_ERROR, 0);
    Exit;
  end;
end;

procedure ServiceCtrlHandler(Control: DWORD); stdcall;
begin
  case Control of
    SERVICE_CONTROL_STOP:
      begin
        _log('basement', 'STOP service');
        Stopped := true;
        SetEvent(ghSvcStopEvent);
        ServiceStatus.dwCurrentState := SERVICE_STOP_PENDING;
        SetServiceStatus(StatusHandle, ServiceStatus);
      end;
    SERVICE_CONTROL_PAUSE:
      begin
        _log('basement', 'PAUSE service');
        Paused := true;
        ServiceStatus.dwCurrentState := SERVICE_PAUSED;
        SetServiceStatus(StatusHandle, ServiceStatus);
      end;
    SERVICE_CONTROL_CONTINUE:
      begin
        _log('basement', 'CONTINUE service');
        Paused := False;
        ServiceStatus.dwCurrentState := SERVICE_RUNNING;
        SetServiceStatus(StatusHandle, ServiceStatus);
      end;
    SERVICE_CONTROL_INTERROGATE:
      begin
        _log('basement', 'INTERROGATE service');
        SetServiceStatus(StatusHandle, ServiceStatus);
      end;
    SERVICE_CONTROL_SHUTDOWN:
      begin
        _log('basement', 'SHUTDOWN service');
        Stopped := true;
      end
  end;
end;

procedure RegisterService(dwArgc: DWORD; var lpszArgv: PChar); stdcall;
begin
  _log('basement', 'RegisterService');
  ServiceStatus.dwServiceType := SERVICE_WIN32_OWN_PROCESS;
  ServiceStatus.dwCurrentState := SERVICE_START_PENDING;
  ServiceStatus.dwControlsAccepted := SERVICE_ACCEPT_STOP or
    SERVICE_ACCEPT_PAUSE_CONTINUE;
  ServiceStatus.dwServiceSpecificExitCode := 0;
  ServiceStatus.dwWin32ExitCode := 0;
  ServiceStatus.dwCheckPoint := 0;
  ServiceStatus.dwWaitHint := 0;

  StatusHandle := RegisterServiceCtrlHandler(ServiceName, @ServiceCtrlHandler);

  if StatusHandle <> 0 then
  begin
    ReportSvcStatus(SERVICE_RUNNING, NO_ERROR, 0);
    try
      Stopped := False;
      Paused := False;
      MainProc;
    finally
      ReportSvcStatus(SERVICE_STOPPED, NO_ERROR, 0);
    end;
  end;
end;

procedure UninstallService(const ServiceName: PChar; const Silent: Boolean);
const
  cRemoveMsg = 'Your service was removed sucesfuly!';
var
  SCManager: SC_HANDLE;
  Service: SC_HANDLE;
begin
  _log('basement', 'UninstallService');
  SCManager := OpenSCManager(nil, nil, SC_MANAGER_ALL_ACCESS);
  if SCManager = 0 then
    Exit;
  try
    Service := OpenService(SCManager, ServiceName, SERVICE_ALL_ACCESS);
    ControlService(Service, SERVICE_CONTROL_STOP, ServiceStatus);
    DeleteService(Service);
    CloseServiceHandle(Service);
    if not Silent then
      MessageBox(0, cRemoveMsg, ServiceName, MB_ICONINFORMATION or MB_OK or
        MB_TASKMODAL or MB_TOPMOST);
  finally
    CloseServiceHandle(SCManager);
    AfterUninstall;
  end;
end;

procedure InstallService(const ServiceName, DisplayName, LoadOrder: PChar;
  const FileName: string; const Silent: Boolean);
const
  cInstallMsg = 'Your service was Installed sucesfuly!';
  cSCMError = 'Error trying to open SC Manager';
var
  SCMHandle: SC_HANDLE;
  SvHandle: SC_HANDLE;
  Reg: TRegistry;
begin
  _log('basement', PWideChar('InstallService ' + ServiceName + ' "' +
    DisplayName + '"'));
  SCMHandle := OpenSCManager(nil, nil, SC_MANAGER_ALL_ACCESS);

  if SCMHandle = 0 then
  begin
    MessageBox(0, cSCMError, ServiceName, MB_ICONERROR or MB_OK or
      MB_TASKMODAL or MB_TOPMOST);
    Exit;
  end;

  try
    SvHandle := CreateService(SCMHandle, ServiceName, DisplayName,
      SERVICE_ALL_ACCESS, SERVICE_WIN32_OWN_PROCESS, SERVICE_AUTO_START or
      SERVICE_DEMAND_START, SERVICE_ERROR_IGNORE, PChar(FileName), LoadOrder,
      nil, nil, nil, nil);
    CloseServiceHandle(SvHandle);

    try
      Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if Reg.OpenKey('\SYSTEM\CurrentControlSet\Services\' + ServiceName, False)
      then
      begin
        Reg.WriteString('Description', DisplayName);
        Reg.CloseKey;
      end;
    finally
      Reg.Free;
    end;

    if not Silent then
      MessageBox(0, cInstallMsg, ServiceName, MB_ICONINFORMATION or MB_OK or
        MB_TASKMODAL or MB_TOPMOST);
  finally
    CloseServiceHandle(SCMHandle);
  end;
end;

procedure WriteHelpContent;
var
  myName: string;
begin
  myName := ExtractFileName(Paramstr(0));
  WriteLn('To install your service please type ' + myName + ' /install');
  WriteLn('To uninstall your service please type ' + myName + ' /remove');
  WriteLn('For help please type ' + myName + ' /? or /h');
end;

begin

  if (Paramstr(1) = '/h') or (Paramstr(1) = '/?') then
    WriteHelpContent
  else if Paramstr(1) = '/install' then
    InstallService(ServiceName, DisplayName, 'System Reserved', Paramstr(0),
      Paramstr(2) = '/s')
  else if Paramstr(1) = '/remove' then
    UninstallService(ServiceName, Paramstr(2) = '/s')
  else if ParamCount = 0 then
  begin
    _log('basement', 'ReflektorService wakeup');
    OnServiceCreate;

    ServiceTable[0].lpServiceName := ServiceName;
    ServiceTable[0].lpServiceProc := @RegisterService;
    ServiceTable[1].lpServiceName := nil;
    ServiceTable[1].lpServiceProc := nil;

    StartServiceCtrlDispatcher(ServiceTable[0]);
  end
  else
  begin
    _log('basement', 'ReflektorService - Wrong argument!');
    WriteLn('Wrong argument!');
  end;

end.
