unit MosquittoLoader;

interface

const
  MOSQUITTO_DLL = 'mosquitto.dll';

var
  MosquittoLibHandle: THandle = 0;

implementation

uses
  Windows,
  VCL.dialogs,
  System.SysUtils;

initialization
  MosquittoLibHandle := LoadLibrary(MOSQUITTO_DLL);
  if MosquittoLibHandle = 0 then
  begin
    // Handle error if the library cannot be loaded
    {$IFDEF WIN32}
      MessageDlg('Falied to load '+MOSQUITTO_DLL+' at '+GetCurrentDir+' ERR: '+IntToStr(GetLastError), mtError, [mbOK], 0);
    {$ELSE}
      writeln('Failed to load '+ MOSQUITTO_DLL);
      readln;
    {$ENDIF}
    halt(1);
  end;

finalization
  if MosquittoLibHandle <> 0 then
    FreeLibrary(MosquittoLibHandle);

end.

