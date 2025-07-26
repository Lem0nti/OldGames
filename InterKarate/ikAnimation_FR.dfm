object AnimationFR: TAnimationFR
  Left = 0
  Top = 0
  Width = 451
  Height = 108
  Align = alTop
  TabOrder = 0
  DesignSize = (
    451
    108)
  object Image: TImage
    Left = 4
    Top = 4
    Width = 128
    Height = 97
    Align = alCustom
    Anchors = [akLeft, akTop, akBottom]
    Transparent = True
  end
  object bOk: TButton
    Left = 146
    Top = 4
    Width = 33
    Height = 97
    Anchors = [akLeft, akTop, akBottom]
    Caption = #9658
    TabOrder = 0
    OnClick = bOkClick
  end
  object Timer: TTimer
    Enabled = False
    Interval = 100
    OnTimer = TimerTimer
    Left = 212
    Top = 36
  end
end
