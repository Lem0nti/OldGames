object MainFM: TMainFM
  Left = 0
  Top = 0
  Caption = 'MainFM'
  ClientHeight = 299
  ClientWidth = 635
  Color = clBtnFace
  DoubleBuffered = True
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
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 635
    Height = 299
    Align = alClient
    BevelOuter = bvNone
    ShowCaption = False
    TabOrder = 0
  end
  object Timer: TTimer
    Interval = 30
    OnTimer = TimerTimer
    Left = 312
    Top = 152
  end
  object HidCtl: TJvHidDeviceController
    OnEnumerate = HidCtlEnumerate
    OnDeviceChange = HidCtlDeviceChange
    OnDeviceData = HidCtlDeviceData
    Left = 376
    Top = 64
  end
end
