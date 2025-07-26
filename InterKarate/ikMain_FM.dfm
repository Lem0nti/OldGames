object MainFM: TMainFM
  Left = 0
  Top = 0
  Caption = 'MainFM'
  ClientHeight = 800
  ClientWidth = 1280
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  WindowState = wsMaximized
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 13
  object pnlScreen: TPanel
    Left = 0
    Top = 0
    Width = 1280
    Height = 800
    Align = alClient
    Caption = 'pnlScreen'
    Color = clBackground
    ParentBackground = False
    TabOrder = 0
  end
  object Timer: TTimer
    Interval = 30
    OnTimer = TimerTimer
    Left = 448
    Top = 392
  end
end
