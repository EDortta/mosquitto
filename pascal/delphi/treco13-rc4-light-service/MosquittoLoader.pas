unit MosquittoLoader;

interface
const
  MOSQUITTO_DLL = 'mosquitto.dll';
var
  MosquittoLibHandle: THandle = 0;
implementation
uses
  Windows;
initialization
  MosquittoLibHandle := LoadLibrary(MOSQUITTO_DLL);
  if MosquittoLibHandle = 0 then
  begin
    // Handle error if the library cannot be loaded
    writeln('Failed to load '+ MOSQUITTO_DLL);
    readln;
    halt(1);
  end;
finalization
  if MosquittoLibHandle <> 0 then
    FreeLibrary(MosquittoLibHandle);
end.

