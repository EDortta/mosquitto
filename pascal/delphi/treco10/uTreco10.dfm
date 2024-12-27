object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 443
  ClientWidth = 583
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = True
  OnCreate = FormCreate
  OnShow = FormShow
  DesignSize = (
    583
    443)
  PixelsPerInch = 96
  TextHeight = 15
  object Label1: TLabel
    Left = 8
    Top = 360
    Width = 28
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Texto'
  end
  object mLog: TMemo
    Left = 8
    Top = 8
    Width = 563
    Height = 346
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Verdana'
    Font.Style = []
    Lines.Strings = (
      'Registro de consultas')
    ParentFont = False
    TabOrder = 0
  end
  object eQuery: TEdit
    Left = 8
    Top = 381
    Width = 482
    Height = 23
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 1
    OnChange = eQueryChange
  end
  object bSend: TButton
    Left = 496
    Top = 380
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Enviar'
    Default = True
    Enabled = False
    TabOrder = 2
    OnClick = bSendClick
  end
  object bConfig: TButton
    Left = 8
    Top = 409
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Config'
    TabOrder = 3
    OnClick = bConfigClick
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 5000
    OnTimer = Timer1Timer
    Top = 48
  end
end
