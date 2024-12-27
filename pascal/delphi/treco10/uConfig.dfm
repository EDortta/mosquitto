object fConfig: TfConfig
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'fConfig'
  ClientHeight = 223
  ClientWidth = 446
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesktopCenter
  OnCreate = FormCreate
  TextHeight = 15
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 43
    Height = 15
    Caption = 'Servidor'
  end
  object Label2: TLabel
    Left = 219
    Top = 27
    Width = 9
    Height = 15
    Caption = ':'
  end
  object Label3: TLabel
    Left = 232
    Top = 8
    Width = 29
    Height = 15
    Caption = 'Porto'
  end
  object Label4: TLabel
    Left = 8
    Top = 64
    Width = 40
    Height = 15
    Caption = 'Usu'#225'rio'
  end
  object Label5: TLabel
    Left = 232
    Top = 64
    Width = 32
    Height = 15
    Caption = 'Senha'
  end
  object Label6: TLabel
    Left = 8
    Top = 120
    Width = 30
    Height = 15
    Caption = 'Canal'
  end
  object Label7: TLabel
    Left = 232
    Top = 120
    Width = 67
    Height = 15
    Caption = 'Identificador'
  end
  object eHost: TEdit
    Left = 8
    Top = 24
    Width = 201
    Height = 23
    TabOrder = 0
  end
  object ePort: TEdit
    Left = 232
    Top = 24
    Width = 65
    Height = 23
    TabOrder = 1
  end
  object eUsername: TEdit
    Left = 8
    Top = 80
    Width = 201
    Height = 23
    TabOrder = 2
  end
  object ePassword: TEdit
    Left = 232
    Top = 80
    Width = 121
    Height = 23
    PasswordChar = '*'
    TabOrder = 3
  end
  object eTopic: TEdit
    Left = 8
    Top = 136
    Width = 201
    Height = 23
    TabOrder = 4
  end
  object eMyself: TEdit
    Left = 232
    Top = 136
    Width = 201
    Height = 23
    TabOrder = 5
  end
  object Button1: TButton
    Left = 358
    Top = 176
    Width = 75
    Height = 25
    Caption = 'Ok'
    TabOrder = 6
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 232
    Top = 176
    Width = 75
    Height = 25
    Caption = 'Cancelar'
    TabOrder = 7
    OnClick = Button2Click
  end
end
