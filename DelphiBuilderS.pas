{***************************************************************************}
{                                                                           }
{ DelphiBuilder                                                             }
{                                                                           }
{ Copyright (c) 2018 Masahiko TOKUNAGA                                      }
{                                                                           }
{ [project or product site url]                                             }
{                                                                           }
{---------------------------------------------------------------------------}
{                                                                           }
{ 2018/04/14                                                                }
{                                                                           }
{***************************************************************************}
{                                                                           }
{ Licensed under the Apache License, Version 2.0 (the "License");           }
{ you may not use this file except in compliance with the License.          }
{ You may obtain a copy of the License at                                   }
{                                                                           }
{     http://www.apache.org/licenses/LICENSE-2.0                            }
{                                                                           }
{ Unless required by applicable law or agreed to in writing, software       }
{ distributed under the License is distributed on an "AS IS" BASIS,         }
{ WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  }
{ See the License for the specific language governing permissions and       }
{ limitations under the License.                                            }
{                                                                           }
{***************************************************************************}
unit DelphiBuilderS;

interface

uses
  Winapi.Windows, Winapi.Messages, System.Types, System.Classes, XML.XMLIntf,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Controls, Vcl.Forms, Vcl.Grids;

type
  TStringGrid = class(Vcl.Grids.TStringGrid)
  protected
    procedure DrawCell(ACol, ARow: Integer; Rect: TRect; State: TGridDrawState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  private
    procedure CMHintShow(var AMsg: TCMHintShow); message CM_HINTSHOW;
  end;

  TMainForm = class(TForm)
    GrdList: TStringGrid;
    CmbBuild: TComboBox;
    BtnBuild: TButton;
    BtnSelect: TButton;
    Label2: TLabel;
    BtnCancel: TButton;
    BtnClear: TButton;
    SbrStatus: TStatusBar;
    BtnStop: TButton;
    ChkCopy: TCheckBox;
    EdtCopyFolder: TEdit;
    BtnSelectFolder: TButton;
    ScrFake: TScrollBar;
    ChkOverwrite: TCheckBox;

    procedure FormCreate(Sender: TObject);
    procedure ChkCopyClick(Sender: TObject);
    procedure BtnSelectFolderClick(Sender: TObject);
    procedure GrdListDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure GrdListKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure BtnSelectClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
    procedure BtnClearClick(Sender: TObject);
    procedure BtnStopClick(Sender: TObject);
    procedure BtnBuildClick(Sender: TObject);

  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;

  private
    FHotKeySelect: ATOM;
    FHotKeyCancel: ATOM;
    FHotKeyClear: ATOM;
    FHotKeyStop: ATOM;
    FHotKeyBuild: ATOM;

    procedure WMHotKey(var Msg: TWMHotKey); message WM_HOTKEY;
    procedure WMSysCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
    procedure DropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;

    function GetSpecialFolder(ACSIDL: Integer): string;
    procedure ChangeControlStatus(ACtrl: TWinControl; AStatus: Boolean);
    procedure PollingMessage;
    function GetDprojInfo(APath, AFilename: string): Boolean;
    function SearchFolders(APath: string): string;
    function GetXmlNodeValue(ADoc: IXMLDocument; ANodeName: string): string;
    function BuildFileExists(ARow: Integer): string;
  end;

var
  MainForm: TMainForm;

implementation

uses
  Winapi.ShlObj, Winapi.ShellAPI, System.SysUtils, System.StrUtils,
  System.Variants, System.UITypes, System.IOUtils, System.Math, XML.XMLDoc,
  Vcl.Graphics, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.GraphUtil, Vcl.Themes,
  {$WARN UNIT_PLATFORM OFF}
  Vcl.Filectrl,
  {$WARN UNIT_PLATFORM ON}

  // http://mrxray.on.coocan.jp/Delphi/plSamples/000_CommandLineCompile.htm
  // http://mrxray.on.coocan.jp/Delphi/plSamples/552_PipeRedirect.htm
  plCommandRedirect;

const
  COL_SELECTIVE    = 0;
  COL_STATUS       = 1;
  COL_PROJID       = 2;
  COL_PROJPATH     = 3;
  COL_EXENAME      = 4;
  COL_PROJFULLPATH = 5;
  COL_CONFIG       = 6;
  COL_PLATFORM     = 7;
  COL_EXEOUTPUT    = 8;
  COL_BUILDINFO    = 9;

  BUILD_SUCCESS = '○';
  BUILD_FAIL    = '×';

  PATTERN_CONFIG   = '$(Config)';
  PATTERN_PLATFORM = '$(Platform)';

var
  ProjList: TStringList;
  IsStart: Boolean;
  IsStop: Boolean;

{$R *.dfm}

// ----------------------------------------------------------------------------
// TStringGridコンポーネントのカスタマイズ
// ----------------------------------------------------------------------------
procedure TStringGrid.CMHintShow(var AMsg: TCMHintShow);
var
  Col, Row: Integer;
  Rect: TRect;

begin
  inherited;

  // ドラッグ&ドロップまたはビルド中ならなにもしない
  if IsStart then
    Exit;

  with AMsg.HintInfo^.CursorPos do
    MouseToCell(X, Y, Col, Row);

  // ヘッダー行もしくは行列取得が失敗のとき
  if (Col <= 0) or (Row <= 0) then
    Exit;
  // 空行ならなにもしない
  if Cells[COL_PROJID, Row] = '' then
    Exit;

  case Col of
  COL_STATUS:
    // ビルド前またはビルド成功ならなにもしない
    if Cells[COL_STATUS, Row] <> BUILD_FAIL then
      Exit;

  COL_PROJPATH:
    // プロジェクトフォルダーが省略されてなければなにもしない
    if Cells[COL_PROJPATH, Row] = Cells[COL_PROJFULLPATH, Row] then
      Exit;
  else
    Exit;
  end;

  Rect := CellRect(Col, Row);
  with AMsg.HintInfo^ do
  begin
    CursorRect := Rect;
    HintPos := ClientToScreen(Rect.TopLeft);

    case Col of
    COL_STATUS:   HintStr := Cells[COL_BUILDINFO, Row];
    COL_PROJPATH: HintStr := Cells[COL_PROJFULLPATH, Row];
    end;

    HideTimeout := -1;
    AMsg.Result := 0;
  end;
end;

procedure TStringGrid.DrawCell(ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
const
  CHeightMargin = 2;

  COddRowColor      = clWebLightYellow;
  CSuccessColor     = clWebHoneydew;
  CFailColor        = clWebLavenderBlush;
  CClassicHighlight = clHighlight;
  CThemeHighlight   = clSkyBlue;

  function _IsThemeStyled: Boolean;
  begin
    Result := False;

    if StyleServices.Enabled then
      Result := True;
  end;

  procedure _DrawHighlightRow;
  begin
    if gdSelected in State then
      Canvas.Brush.Color := IfThen(_IsThemeStyled, CThemeHighlight, CClassicHighlight)
    else
      Canvas.Brush.Color := IfThen((ARow mod 2) = 1, clWhite, COddRowColor);

    Canvas.FillRect(Rect);
  end;

var
  Details: TThemedElementDetails;
  BoxRect: TRect;
  Height: Integer;
  Width: Integer;
  Status: Cardinal;

begin
  inherited;

  if ARow <> 0 then
  begin
    case ACol of
    // 先頭カラムにだけチェックボックスを描画
    COL_SELECTIVE:
      begin
        _DrawHighlightRow;

        Height := Self.DefaultRowHeight - (CHeightMargin * 2);
        Width := Height;

        BoxRect.Left   := Rect.Left + (ColWidths[ACol] - Width) div 2;
        BoxRect.Top    := Rect.Top + (RowHeights[ARow] - Height) div 2;
        BoxRect.Bottom := Rect.Bottom - CHeightMargin;
        BoxRect.Right  := BoxRect.Left + Width;
        Rect.Right := Rect.Bottom - Rect.Top;

        if _IsThemeStyled then
        begin
          if Bool(Objects[ACol, ARow]) then
            Details := StyleServices.GetElementDetails(tbCheckBoxCheckedNormal)
          else
            Details := StyleServices.GetElementDetails(tbCheckBoxUncheckedNormal);

          StyleServices.DrawElement(Canvas.Handle, Details, BoxRect, nil);
        end
        else
        begin
          if Bool(Objects[ACol, ARow]) then
            Status := DFCS_BUTTONCHECK or DFCS_CHECKED
          else
            Status := DFCS_BUTTONCHECK;

          DrawFrameControl(Canvas.Handle, BoxRect, DFC_BUTTON, Status);
        end;
      end;

    COL_STATUS:
      begin
        if gdSelected in State then
          Canvas.Brush.Color := IfThen(_IsThemeStyled, CThemeHighlight, CClassicHighlight)
        else if Cells[ACol, ARow] = BUILD_SUCCESS then
          Canvas.Brush.Color := CSuccessColor
        else if Cells[ACol, ARow] = BUILD_FAIL then
          Canvas.Brush.Color := CFailColor
        else
          Canvas.Brush.Color := IfThen((ARow mod 2) = 1, clWhite, COddRowColor);

        Canvas.FillRect(Rect);
        DrawText(Canvas.Handle, PWideChar(Cells[ACol, ARow]), -1, Rect, DT_VCENTER or DT_CENTER or DT_SINGLELINE);
      end;

    else
      begin
        _DrawHighlightRow;
        DrawText(Canvas.Handle, PWideChar(' ' + Cells[ACol, ARow]), -1, Rect, DT_VCENTER or DT_LEFT or DT_SINGLELINE);
      end;
    end;
  end
  else
  begin
    if Self.DrawingStyle = gdsClassic then
      Canvas.FillRect(Rect)
    else
      GradientFillCanvas(Canvas, GradientStartColor, GradientEndColor, Rect, gdVertical);

    DrawText(Canvas.Handle, PWideChar(Cells[ACol, ARow]), -1, Rect, DT_VCENTER or DT_CENTER or DT_SINGLELINE);
  end;
end;

procedure TStringGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Col: Integer;
  Row: Integer;
  IsChecked: Boolean;

begin
  inherited;

  if Button = mbLeft then
  begin
    MouseToCell(X, Y, Col, Row);
    if (Row > (FixedRows - 1)) and (Col = COL_SELECTIVE) then
    begin
      // 空行ならなにもしない
      if Cells[COL_PROJID, Row] = '' then
        Exit;

      IsChecked := Bool(Objects[Col, Row]);
      Objects[Col, Row] := TObject(not IsChecked);
    end;
  end;
end;

procedure TStringGrid.KeyDown(var Key: Word; Shift: TShiftState);
var
  ColLeft, RowTop, RowBottom, I: Integer;
  IsChecked: Boolean;

begin
  inherited;

  if Key = VK_SPACE then
  begin
    ColLeft := Selection.Left;
    RowTop := Selection.Top;
    RowBottom := Selection.Bottom;

    if ColLeft = 0 then
      for I := RowTop to RowBottom do
      begin
        // 空行ならなにもしない
        if Cells[COL_PROJID, I] = '' then
          Exit;

        IsChecked := Bool(Objects[ColLeft, I]);
        Objects[ColLeft, I] := TObject(not IsChecked);
      end;
  end;
end;

// ----------------------------------------------------------------------------
procedure TMainForm.CreateWnd();
begin
  inherited CreateWnd;

  FHotKeySelect := GlobalAddAtom('DBtn_Select');
  RegisterHotKey(Handle, FHotKeySelect, MOD_ALT, Ord('A'));

  FHotKeyCancel := GlobalAddAtom('DBtn_Cancel');
  RegisterHotKey(Handle, FHotKeyCancel, MOD_ALT, Ord('R'));

  FHotKeyClear := GlobalAddAtom('DBtn_Clear');
  RegisterHotKey(Handle, FHotKeyClear, MOD_ALT, Ord('C'));

  FHotKeyStop := GlobalAddAtom('DBtn_Stop');
  RegisterHotKey(Handle, FHotKeyStop, MOD_ALT, Ord('S'));

  FHotKeyBuild := GlobalAddAtom('DBtn_Build');
  RegisterHotKey(Handle, FHotKeyBuild, MOD_ALT, Ord('B'));
end;

procedure TMainForm.DestroyWnd();
begin
  UnregisterHotKey(Handle, FHotKeySelect);
  DeleteAtom(FHotKeySelect);

  UnregisterHotKey(Handle, FHotKeyCancel);
  DeleteAtom(FHotKeyCancel);

  UnregisterHotKey(Handle, FHotKeyClear);
  DeleteAtom(FHotKeyClear);

  UnregisterHotKey(Handle, FHotKeyStop);
  DeleteAtom(FHotKeyStop);

  UnregisterHotKey(Handle, FHotKeyBuild);
  DeleteAtom(FHotKeyBuild);

  inherited DestroyWnd;
end;

procedure TMainForm.WMHotKey(var Msg: TWMHotKey);
begin
  if Msg.HotKey = FHotKeySelect then
  begin
    if not BtnSelect.Enabled then
      Exit;
    BtnSelect.SetFocus;
    BtnSelectClick(BtnSelect);
  end;

  if Msg.HotKey = FHotKeyCancel then
  begin
    if not BtnCancel.Enabled then
      Exit;
    BtnCancel.SetFocus;
    BtnCancelClick(BtnCancel);
  end;

  if Msg.HotKey = FHotKeyClear then
  begin
    if not BtnClear.Enabled then
      Exit;
    BtnClear.SetFocus;
    BtnClearClick(BtnClear);
  end;

  if Msg.HotKey = FHotKeyStop then
  begin
    if not BtnStop.Enabled then
      Exit;
    BtnStop.SetFocus;
    BtnStopClick(BtnStop);
  end;

  if Msg.HotKey = FHotKeyBuild then
  begin
    if not BtnBuild.Enabled then
      Exit;
    BtnBuild.SetFocus;
    BtnBuildClick(BtnBuild);
  end;
end;

procedure TMainForm.WMSysCommand(var Msg: TWMSysCommand);
var
  IsIgnore: Boolean;

begin
  IsIgnore := False;

  case Msg.CmdType of
  SC_CLOSE:
    if IsStart then
    begin
      IsIgnore := True;
      MessageDlg('「中止」ボタンを押下して処理を中止してください', mtWarning, [mbOK], 0);
    end;
  SC_MAXIMIZE:
    IsIgnore := True; // 最大化を無視
  end;

  if IsIgnore then
    Msg.Result := 0
  else
    inherited;
end;

procedure TMainForm.DropFiles(var Msg: TWMDropFiles);
var
  I, Row, DropCount: Integer;
  Path: array[0..MAX_PATH + 1] of WideChar;
  Field: TStringList;

begin
  IsStart := True;

  ChangeControlStatus(Self, False);
  PollingMessage();

  DropCount := DragQueryFile(Msg.Drop, Cardinal(-1), nil, 0);

  ProjList := nil;
  Field := nil;
  try
    ProjList := TStringList.Create;
    Field := TStringList.Create;

    for I := 0 to DropCount - 1 do
    begin
      DragQueryFile(Msg.Drop, I, Path, SizeOf(Path) - 1);

      SearchFolders(Path);
      PollingMessage();

      if IsStop then
        Break;
    end;

    DragFinish(Msg.Drop);

    // リストアップされていなければヘッダー行を除く
    Row := 0;
    if ProjList.Count <> 0 then
    begin
      Row := IfThen(GrdList.Cells[COL_PROJID, 1] = '', GrdList.RowCount - 1, GrdList.RowCount);

      GrdList.RowCount := Row + ProjList.Count;
    end;

    ProjList.Sort;
    Field.Delimiter := ',';
    Field.StrictDelimiter := True;

    for I := 0 to ProjList.Count - 1 do
    begin
      Field.DelimitedText := ProjList[I];

      // プロジェクト情報は2カラム目以降
      GrdList.Cells[COL_STATUS, Row + I]       := '';
      GrdList.Cells[COL_PROJID, Row + I]       := Field[0];
      GrdList.Cells[COL_PROJPATH, Row + I]     := MinimizeName(Field[1], Canvas, GrdList.ColWidths[COL_PROJPATH]);
      GrdList.Cells[COL_EXENAME, Row + I]      := Field[2];
      GrdList.Cells[COL_PROJFULLPATH, Row + I] := Field[1];
      GrdList.Cells[COL_CONFIG, Row + I]       := Field[3];
      GrdList.Cells[COL_PLATFORM, Row + I]     := Field[4];
      GrdList.Cells[COL_EXEOUTPUT, Row + I]    := Field[5];
      GrdList.Cells[COL_BUILDINFO, Row + I]    := '*';

      PollingMessage();
    end;

    if IsStop then
    begin
      SbrStatus.SimpleText := '中止しました';
      IsStop := False;
    end
    else
    begin
      SbrStatus.SimpleText := Format('%s件のプロジェクトを追加しました', [FormatFloat('###,##0', ProjList.Count)]);
    end;
  finally
    ProjList.Free;
    Field.Free;
  end;

  ChangeControlStatus(Self, True);
  PollingMessage();

  IsStart := False;
end;

// ----------------------------------------------------------------------------
procedure TMainForm.FormCreate(Sender: TObject);
begin
  DragAcceptFiles(Self.Handle, True);

  IsStart := False;
  IsStop := False;

  ChkCopy.Checked := False;
  EdtCopyFolder.Enabled := False;
  EdtCopyFolder.Text := GetSpecialFolder(CSIDL_PERSONAL);
  BtnSelectFolder.Enabled := False;
  ChkOverwrite.Enabled := False;
  ChkOverwrite.Font.Color := clGrayText;

  CmbBuild.Clear;
  CmbBuild.Items.AddObject('Debug', TObject(1));
  CmbBuild.Items.AddObject('Release', TObject(2));
  CmbBuild.ItemIndex := 0;

  BtnClearClick(Sender);

  BtnStop.Enabled := False;
end;

procedure TMainForm.ChkCopyClick(Sender: TObject);
begin
  if ChkCopy.Checked then
  begin
    EdtCopyFolder.Enabled := True;
    BtnSelectFolder.Enabled := True;

    ChkOverwrite.Enabled := True;
    ChkOverwrite.Font.Color := clWindowText;
  end
  else
  begin
    EdtCopyFolder.Enabled := False;
    BtnSelectFolder.Enabled := False;

    ChkOverwrite.Enabled := False;
    ChkOverwrite.Font.Color := clGrayText;
  end;
end;

procedure TMainForm.BtnSelectFolderClick(Sender: TObject);
var
  FolderName: string;

begin
  FolderName := Trim(EdtCopyFolder.Text);

  if SelectDirectory('コピー先フォルダーを指定ください', '', FolderName) then
    EdtCopyFolder.Text := FolderName;
end;

procedure TMainForm.GrdListDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
begin
  // グリッド表示領域よりグリッド全行が超えたらフェイク用の
  // スクロールバーを非表示にする
  if (GrdList.RowCount - 1) > GrdList.VisibleRowCount then
    ScrFake.Visible := False
  else
    ScrFake.Visible := True;
end;

procedure TMainForm.GrdListKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  I: Integer;

begin
  case Key of
  VK_DELETE:
    begin
      // 先頭行が空行ならなにもしない
      if GrdList.Cells[COL_PROJID, 1] = '' then
        Exit;

      if GrdList.Row >= GrdList.RowCount - 1 then
      begin
        // 最終行ならクリア
        GrdList.Rows[GrdList.Row].Clear;

        if GrdList.RowCount - 1 <> 1 then
          GrdList.RowCount := GrdList.RowCount - 1;
      end
      else
      begin
        // 最終行以外なら行詰め
        for I := GrdList.Row + 1 to GrdList.RowCount - 1 do
          GrdList.Rows[I - 1].Assign(GrdList.Rows[I]);

        GrdList.Rows[GrdList.RowCount - 1].Clear;
        GrdList.RowCount := GrdList.RowCount - 1;
      end;
    end;
  end;
end;

procedure TMainForm.BtnSelectClick(Sender: TObject);
var
  I: Integer;

begin
  // 先頭行が空行ならなにもしない
  if GrdList.Cells[COL_PROJID, 1] = '' then
    Exit;

  for I := 1 to GrdList.RowCount - 1 do
    GrdList.Objects[COL_SELECTIVE, I] := TObject(True);
end;

procedure TMainForm.BtnCancelClick(Sender: TObject);
var
  I: Integer;

begin
  // 先頭行が空行ならなにもしない
  if GrdList.Cells[COL_PROJID, 1] = '' then
    Exit;

  for I := 1 to GrdList.RowCount - 1 do
    GrdList.Objects[COL_SELECTIVE, I] := TObject(False);
end;

procedure TMainForm.BtnClearClick(Sender: TObject);
begin
  GrdList.RowCount := 2;
  GrdList.ColCount := 10;
  GrdList.Rows[1].Clear;

  GrdList.Cells[COL_SELECTIVE, 0]    := '選択';
  GrdList.Cells[COL_STATUS, 0]       := 'ビルド';
  GrdList.Cells[COL_PROJID, 0]       := 'プロジェクトID';
  GrdList.Cells[COL_PROJPATH, 0]     := 'プロジェクトフォルダー';
  GrdList.Cells[COL_EXENAME, 0]      := 'EXEファイル';
  GrdList.Cells[COL_PROJFULLPATH, 0] := 'プロジェクトフルパス';
  GrdList.Cells[COL_CONFIG, 0]       := '$(Config)';
  GrdList.Cells[COL_PLATFORM, 0]     := '$(Platform)';
  GrdList.Cells[COL_EXEOUTPUT, 0]    := 'DCC_ExeOutput';
  GrdList.Cells[COL_BUILDINFO, 0]    := 'ビルド情報';

  GrdList.ColWidths[COL_SELECTIVE]    := 40;
  GrdList.ColWidths[COL_STATUS]       := 40;
  GrdList.ColWidths[COL_PROJID]       := 120;
  GrdList.ColWidths[COL_PROJPATH]     := 443;
  GrdList.ColWidths[COL_EXENAME]      := 110;
  GrdList.ColWidths[COL_PROJFULLPATH] := 0; // 400;
  GrdList.ColWidths[COL_CONFIG]       := 0; // 80;
  GrdList.ColWidths[COL_PLATFORM]     := 0; // 80;
  GrdList.ColWidths[COL_EXEOUTPUT]    := 0; // 180;
  GrdList.ColWidths[COL_BUILDINFO]    := 0; // 240;

  SbrStatus.SimplePanel := True;
  SbrStatus.SimpleText := '';
end;

procedure TMainForm.BtnStopClick(Sender: TObject);
begin
  IsStop := True;
end;

procedure TMainForm.BtnBuildClick(Sender: TObject);
const
  CMSBuildOption = '/nologo /verbosity:minimal';

var
  CmdLine: TplCommandRedirect;
  I, Selected, Count: Integer;
  Build, DProj, Path, ExeName: string;
  Counter, SrcFile, DestFile: string;

begin
  IsStart := True;

  ChangeControlStatus(Self, False);
  PollingMessage();

  Count := 0;
  for I := 1 to GrdList.RowCount - 1 do
  begin
    GrdList.Cells[COL_STATUS, I] := '';

    if GrdList.Objects[COL_SELECTIVE, I] = TObject(True) then
      Inc(Count);
  end;

  Build := CmbBuild.Items[CmbBuild.ItemIndex];
  PollingMessage();

  Selected := 0;

  CmdLine := nil;
  try
    CmdLine := TplCommandRedirect.Create;

    for I := 1 to GrdList.RowCount - 1 do
    begin
      if GrdList.Objects[COL_SELECTIVE, I] = TObject(True) then
      begin
        Inc(Selected);

        DProj := GrdList.Cells[COL_PROJID, I];
        Path := GrdList.Cells[COL_PROJFULLPATH, I];
        ExeName := GrdList.Cells[COL_EXENAME, I];
        Counter := Format('%s/%s', [FormatFloat('###,##0', Selected), FormatFloat('###,##0', Count)]);

        GrdList.Row := I;
        SbrStatus.SimpleText := Format('(%s) %sを%sビルドしています...', [Counter, DProj, Build]);
        PollingMessage();

        CmdLine.GrabStdOutText(Format('cmd.exe /K rsvars.bat & msbuild %s %s /target:Clean', [Path + '\' + DProj, CMSBuildOption]));
        PollingMessage();
        if IsStop then
          Break;

        GrdList.Cells[COL_BUILDINFO, I] := CmdLine.GrabStdOutText(Format('cmd.exe /K rsvars.bat & msbuild %s %s /target:Build /p:config=%s', [Path + '\' + DProj, CMSBuildOption, Build]));

        GrdList.Objects[COL_SELECTIVE, I] := TObject(False);
        SrcFile := BuildFileExists(I);
        if SrcFile <> '' then
        begin
          GrdList.Cells[COL_STATUS, I] := '○';
          GrdList.Cells[COL_BUILDINFO, I] := '';
        end
        else
        begin
          GrdList.Cells[COL_STATUS, I] := '×';
        end;

        PollingMessage();
        if IsStop then
          Break;

        if (SrcFile <> '') and (ChkCopy.Checked) and (EdtCopyFolder.Text <> '') then
        begin
          SbrStatus.SimpleText := Format('(%s) %sを指定フォルダーにコピーしています...', [Counter, ExeName]);

          try
            DestFile := EdtCopyFolder.Text + '\' + ExeName;
            TFile.Copy(SrcFile, DestFile, ChkOverwrite.Checked);
          except on E: EInOutError do
              SbrStatus.SimpleText := Format('(%s) %sのコピーに失敗しました', [Counter, ExeName]);
          end;
        end;

        PollingMessage();
        if IsStop then
          Break;
      end;
    end;
  finally
    CmdLine.Free;
  end;

  if IsStop then
  begin
    SbrStatus.SimpleText := '中止しました';
    IsStop := False;
  end
  else
  begin
    SbrStatus.SimpleText := 'ビルドが終了しました';
  end;

  ChangeControlStatus(Self, True);
  PollingMessage();

  IsStart := False;
end;

// ----------------------------------------------------------------------------
function TMainForm.GetSpecialFolder(ACSIDL: Integer): String;
var
  Path: array[0..MAX_PATH + 1] of WideChar;
  IdList: PItemIDList;

begin
  SHGetSpecialFolderLocation(Application.Handle, ACSIDL, IdList);
  SHGetPathFromIDList(IdList, Path);

  Result := Path;
end;

procedure TMainForm.ChangeControlStatus(ACtrl: TWinControl; AStatus: Boolean);
var
  I: Integer;

begin
  for I := 0 to ACtrl.ControlCount - 1 do
  begin
    if not(ACtrl.Controls[I] is TControl) then
      Continue;

    // 中止ボタンは反転させる
    if (ACtrl.Controls[I] is TButton) and ((ACtrl.Controls[I] as TButton).Name = 'BtnStop') then
    begin
      (ACtrl.Controls[I] as TButton).Enabled := not AStatus;
      Continue;
    end;

    if ACtrl.Controls[I] is TLabel then
      (ACtrl.Controls[I] as TLabel).Enabled := AStatus;
    if ACtrl.Controls[I] is TEdit then
      (ACtrl.Controls[I] as TEdit).Enabled := AStatus;
    if ACtrl.Controls[I] is TCheckBox then
    begin
      if (ACtrl.Controls[I] as TCheckBox).Name = 'ChkCopy' then
        if AStatus then
        begin
          (ACtrl.Controls[I] as TCheckBox).Enabled := True;
          (ACtrl.Controls[I] as TCheckBox).Font.Color := clWindowText;
        end
        else
        begin
          (ACtrl.Controls[I] as TCheckBox).Enabled := False;
          (ACtrl.Controls[I] as TCheckBox).Font.Color := clGrayText;
        end;

      if (ACtrl.Controls[I] as TCheckBox).Name = 'ChkOverwrite' then
        if AStatus then
          if ChkCopy.Checked then
          begin
            (ACtrl.Controls[I] as TCheckBox).Enabled := True;
            (ACtrl.Controls[I] as TCheckBox).Font.Color := clWindowText;
          end
          else
          begin
            (ACtrl.Controls[I] as TCheckBox).Enabled := False;
            (ACtrl.Controls[I] as TCheckBox).Font.Color := clGrayText;
          end;
    end;

    if ACtrl.Controls[I] is TButton then
      (ACtrl.Controls[I] as TButton).Enabled := AStatus;
    if ACtrl.Controls[I] is TRadioButton then
      (ACtrl.Controls[I] as TRadioButton).Enabled := AStatus;
    if ACtrl.Controls[I] is TComboBox then
      (ACtrl.Controls[I] as TComboBox).Enabled := AStatus;
    if ACtrl.Controls[I] is TStringGrid then
      (ACtrl.Controls[I] as TStringGrid).Enabled := AStatus;

    PollingMessage();
  end;
end;

procedure TMainForm.PollingMessage();
var
  Msg: TMsg;

begin
  Application.ProcessMessages;
  if PeekMessage(Msg, 0, WM_ACTIVATE, WM_ACTIVATE, PM_REMOVE) then
  begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;
end;

function TMainForm.GetDprojInfo(APath, AFilename: string): Boolean;
var
  Doc: IXMLDocument;
  Src, Config, Platforms, DprFile, ProjID, ExeOutput, S: string;
  F: TextFile;

begin
  Result := False;

  Doc := LoadXMLDocument(APath + '\' + AFilename);

  // dprファイル名の取得
  Src := GetXmlNodeValue(Doc, 'MainSource');
  if Src = '' then
    Exit;

  // dprファイルは同じフォルダに必ずあるはず
  DprFile := APath + '\' + Src;
  if not FileExists(DprFile) then
    Exit;

  // ビルド構成の取得 (dprojファイルを自動生成していれば必ずあるはず)
  Config := GetXmlNodeValue(Doc, 'Config');

  // ターゲットプラットフォームの取得 (dprojファイルを自動生成していれば必ずあるはず)
  Platforms := GetXmlNodeValue(Doc, 'Platform');

  // 出力ディレクトリの取得
  ExeOutput := GetXmlNodeValue(Doc, 'DCC_ExeOutput');

  S := '';
  AssignFile(F, DprFile);
  Reset(F);
  while not Eof(F) do
  begin
    Readln(F, S);
    // 'program'に記述されているのがプログラムIDのはず
    if Pos('program ', S) <> 0 then
      ProjID := Trim(Copy(S, Length('program '), Length(S) - Length('program '))); // 最後のセミコロンは除く
  end;
  CloseFile(F);

  if ProjID = '' then
    Exit;

  SbrStatus.SimpleText := Format('%sを処理中...', [ProjID]);
  // dprojファイル名、プロジェクトフォルダー、EXEファイル名, ビルド構成, ターゲットプラットフォーム, 出力ディレクトリ
  ProjList.Add(Format('%s,%s,%s.exe,%s,%s,%s', [AFilename, APath, ProjID, Config, Platforms, ExeOutput]));

  Result := True;
end;

function TMainForm.SearchFolders(APath: string): string;
  function _RPos(_SubStr: string; _S: string): Integer;
  var
    I: Integer;

  begin
    _SubStr := ReverseString(_SubStr);
    _S := ReverseString(_S);
    I := Pos(_SubStr, _S);

    if I <> 0 then
      I := (Length(_S) + 1) - (I + Length(_SubStr) - 1);

    Result := I;
  end;

var
  Rec: TSearchRec;

begin
  if not System.SysUtils.DirectoryExists(APath) then
    APath := ExtractFileDir(APath);

  if FindFirst(APath + '\*.*', faAnyFile, Rec) = 0 then
  begin
    try
      repeat
        if Rec.Attr and faDirectory <> 0 then
        begin
          if (Rec.Name = '.') or (Rec.Name = '..') then
            Continue;

          Result := SearchFolders(APath + '\' + Rec.Name);
        end
        else if (not(_RPos('.dproj.', Rec.Name) <> 0)) and (_RPos('.dproj', Rec.Name) <> 0) then
        begin
          GetDprojInfo(APath, Rec.Name);
        end;

        PollingMessage();

        if IsStop then
          Break;
      until (FindNext(Rec) <> 0) or (Result <> '');
    finally
      FindClose(Rec);
    end;
  end;
end;

function TMainForm.GetXmlNodeValue(ADoc: IXMLDocument; ANodeName: string): string;
  function _GetXmlChildNodeValue(_Node: IXMLNode; _NodeName: string): string;
  var
    I: Integer;
    Child: IXMLNode;

  begin
    // 子ノードの数だけループ
    for I := 0 to _Node.ChildNodes.Count - 1 do
    begin
      Child := _Node.ChildNodes[I];

      // 子ノードがあるなら
      if Child.ChildNodes.Count <> 0 then
      begin
        // 子ノードを検索
        Result := _GetXmlChildNodeValue(Child, _NodeName);
        if Result <> '' then
          Exit;
      end;

      // ノード名が同じならノード値を返す
      if Child.NodeName = _NodeName then
      begin
        Result := Child.NodeValue;
        Exit;
      end;
    end;

    Result := '';
  end;

var
  Node: IXMLNode;
  I: Integer;

begin
  // 子ノードの数だけループ
  for I := 0 to ADoc.ChildNodes.Count - 1 do
  begin
    Node := ADoc.ChildNodes[I];

    // 子ノードがあるなら
    if Node.ChildNodes.Count <> 0 then
    begin
      // 子ノードを検索
      Result := _GetXmlChildNodeValue(Node, ANodeName);
      if Result <> '' then
        Exit;
    end;

    // ノード名が同じならノード値を返す
    if Node.NodeName = ANodeName then
    begin
      Result := Node.NodeValue;
      Exit;
    end;
  end;

  Result := '';
end;

function TMainForm.BuildFileExists(ARow: Integer): string;
var
  Path, ExeName, Config, Platforms, ExeOutput: string;
  Build, PathName: string;

begin
  Result := '';

  Path := GrdList.Cells[COL_PROJFULLPATH, ARow];
  ExeName := GrdList.Cells[COL_EXENAME, ARow];
  Config := GrdList.Cells[COL_CONFIG, ARow];
  Platforms := GrdList.Cells[COL_PLATFORM, ARow];
  ExeOutput := GrdList.Cells[COL_EXEOUTPUT, ARow];

  Build := CmbBuild.Items[CmbBuild.ItemIndex];
  PathName := Format('%s\%s\%s', [Path, ExeOutput, ExeName]);

  if Build = Config then
    PathName := StringReplace(PathName, PATTERN_CONFIG, Config, [rfIgnoreCase, rfReplaceAll])
  else
    PathName := StringReplace(PathName, PATTERN_CONFIG, Build, [rfIgnoreCase, rfReplaceAll]);

  PathName := StringReplace(PathName, PATTERN_PLATFORM, Platforms, [rfIgnoreCase, rfReplaceAll]);

  if not FileExists(PathName) then
    Exit;

  Result := PathName;
end;

end.
