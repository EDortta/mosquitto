program treco11;

uses
  Vcl.Forms,
  uTreco11 in 'uTreco11.pas' {Form1},
  uQueueReflektor in 'uQueueReflektor.pas',
  uConfig in 'uConfig.pas' {fConfig};

{$R *.res}

begin
  Application.Initialize;
//  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TfConfig, fConfig);
  Application.Run;
end.
