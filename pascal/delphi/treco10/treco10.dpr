program treco10;

uses
  Vcl.Forms,
  uTreco10 in 'uTreco10.pas' {Form1},
  uConfig in 'uConfig.pas' {fConfig};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TfConfig, fConfig);
  Application.Run;
end.
