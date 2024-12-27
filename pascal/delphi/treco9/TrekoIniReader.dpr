program TrekoIniReader;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.IniFiles,
  System.SysUtils,
  System.Classes;

var
  IniFile: TIniFile;
  StringList: TStringList;
  Key: string;

begin
  IniFile := TIniFile.Create(GetCurrentDir + '\treko.ini');
  StringList := TStringList.Create;
  try
    IniFile.ReadSection('QUEUE', StringList);

    for Key in StringList do
    begin
      writeln(Key, ': ', IniFile.ReadString('QUEUE', Key, ''));
    end;
  finally
    StringList.Free;
    IniFile.Free;
  end;
end.
