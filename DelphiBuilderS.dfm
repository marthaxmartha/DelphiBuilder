object MainForm: TMainForm
  Left = 0
  Top = 0
  AlphaBlendValue = 128
  BorderStyle = bsSingle
  Caption = 'DelphiBuilder'
  ClientHeight = 572
  ClientWidth = 794
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #12513#12452#12522#12458
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 18
  object Label2: TLabel
    Left = 8
    Top = 13
    Width = 72
    Height = 18
    Caption = #12499#12523#12489#27083#25104#65306
  end
  object GrdList: TStringGrid
    Left = 8
    Top = 91
    Width = 778
    Height = 421
    ColCount = 8
    DefaultRowHeight = 18
    FixedCols = 0
    RowCount = 2
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = #12513#12452#12522#12458
    Font.Style = []
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect]
    ParentFont = False
    ParentShowHint = False
    ShowHint = True
    TabOrder = 5
    OnDrawCell = GrdListDrawCell
    OnKeyUp = GrdListKeyUp
  end
  object CmbBuild: TComboBox
    Left = 86
    Top = 8
    Width = 75
    Height = 26
    Style = csDropDownList
    TabOrder = 0
  end
  object BtnBuild: TButton
    Left = 690
    Top = 522
    Width = 96
    Height = 25
    Caption = #12499#12523#12489'(&B)'
    TabOrder = 9
    OnClick = BtnBuildClick
  end
  object BtnSelect: TButton
    Left = 8
    Top = 522
    Width = 96
    Height = 25
    Caption = #20840#36984#25246'(&A)'
    TabOrder = 6
    OnClick = BtnSelectClick
  end
  object BtnCancel: TButton
    Left = 110
    Top = 522
    Width = 96
    Height = 25
    Caption = #20840#35299#38500'(&R)'
    TabOrder = 7
    OnClick = BtnCancelClick
  end
  object BtnClear: TButton
    Left = 226
    Top = 522
    Width = 96
    Height = 25
    Caption = #12463#12522#12450'(&C)'
    TabOrder = 8
    OnClick = BtnClearClick
  end
  object SbrStatus: TStatusBar
    Left = 0
    Top = 553
    Width = 794
    Height = 19
    Panels = <>
  end
  object BtnStop: TButton
    Left = 588
    Top = 522
    Width = 96
    Height = 25
    Caption = #20013#27490'(&S)'
    TabOrder = 10
    OnClick = BtnStopClick
  end
  object ChkCopy: TCheckBox
    Left = 8
    Top = 37
    Width = 288
    Height = 22
    Caption = #12499#12523#12489#12364#25104#21151#12375#12383#12425#25351#23450#12501#12457#12523#12480#12540#12395#12467#12500#12540#12377#12427
    Color = clBtnFace
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = #12513#12452#12522#12458
    Font.Style = []
    ParentColor = False
    ParentFont = False
    TabOrder = 1
    OnClick = ChkCopyClick
  end
  object EdtCopyFolder: TEdit
    Left = 302
    Top = 36
    Width = 449
    Height = 26
    ReadOnly = True
    TabOrder = 2
    Text = 'EdtCopyFolder'
  end
  object BtnSelectFolder: TButton
    Left = 757
    Top = 37
    Width = 29
    Height = 25
    Caption = '...'
    TabOrder = 3
    OnClick = BtnSelectFolderClick
  end
  object ScrFake: TScrollBar
    Left = 767
    Top = 92
    Width = 18
    Height = 419
    Enabled = False
    Kind = sbVertical
    PageSize = 0
    TabOrder = 12
    TabStop = False
  end
  object ChkOverwrite: TCheckBox
    Left = 8
    Top = 63
    Width = 241
    Height = 22
    Caption = #12377#12391#12395#12501#12449#12452#12523#12364#12354#12427#12392#12365#12399#19978#26360#12365#12377#12427
    Color = clBtnFace
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = #12513#12452#12522#12458
    Font.Style = []
    ParentColor = False
    ParentFont = False
    TabOrder = 4
  end
end
