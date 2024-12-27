program reflektorServiceRC3;

uses
  Vcl.SvcMgr,
  mosquitto in 'mosquitto.pas',
  MosquittoLoader in 'MosquittoLoader.pas',
  mqtt_reflektor_rc6 in 'mqtt_reflektor_rc6.pas',
  uQueueReflektor in 'uQueueReflektor.pas',
  uService in 'uService.pas' {reflektorService: TService};

{$R *.RES}

begin
  // Windows 2003 Server requires StartServiceCtrlDispatcher to be
  // called before CoRegisterClassObject, which can be called indirectly
  // by Application.Initialize. TServiceApplication.DelayInitialize allows
  // Application.Initialize to be called from TService.Main (after
  // StartServiceCtrlDispatcher has been called).
  //
  // Delayed initialization of the Application object may affect
  // events which then occur prior to initialization, such as
  // TService.OnCreate. It is only recommended if the ServiceApplication
  // registers a class object with OLE and is intended for use with
  // Windows 2003 Server.
  //
  // Application.DelayInitialize := True;
  //
  if not Application.DelayInitialize or Application.Installing then
    Application.Initialize;
  Application.CreateForm(TreflektorService, reflektorService);
  Application.Run;
end.
