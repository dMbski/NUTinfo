unit mainwindow;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ComCtrls, StdCtrls, ExtCtrls,
  Spin, Buttons, IniFiles, BlckSock, LCLType;

type

  { TFmainw }

  TFmainw = class(TForm)
    BBsave: TBitBtn;
    BBsend: TBitBtn;
    Ecmd: TComboBox;
    EInfo: TMemo;
    Eport: TEdit;
    Ehost: TEdit;
    Eups: TEdit;
    GBparameters: TGroupBox;
    GBdata: TGroupBox;
    Image1: TImage;
    ImageList1: TImageList;
    Lhost: TLabel;
    Lport: TLabel;
    Lupsname: TLabel;
    Linterval: TLabel;
    Memo1: TMemo;
    Memo2: TMemo;
    PC1: TPageControl;
    SBar: TStatusBar;
    Eupsinterval: TSpinEdit;
    Info: TTabSheet;
    Tterminal: TTabSheet;
    Tdata: TTabSheet;
    Timer1: TTimer;
    Tsettings: TTabSheet;
    procedure BBsaveClick(Sender: TObject);
    procedure BBsendClick(Sender: TObject);
    procedure EcmdKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure EhostChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure TCPSocketStatus(Sender: TObject; Reason: THookSocketReason;
      const Value: string);
  private
    tcpConnected: boolean;
    timerCycle: integer;
    timerInterval: integer;
    tcpSocket: TBlockSocket;
    tcpRecived: integer;
    tcpLastError: integer;
    listBuffer: string;
    listVar: TStringList;
    function ListProcess: string;
    function GetVarByName(varname: string): string;
    procedure refreshDataTab;
  public
    MainIni: TINIFile;
  end;

var
  Fmainw: TFmainw;

const
  upsDefaultPortStr = '3493';
  appName = 'NUTinfo';
  iniMainSecN = 'programconfig';
  iniDefIntervalTimerOLMs = 1000;
  iniDefIntervalTimerOBMs = 500;
  iniDefUpsVarIntervalSec = 30;

implementation

{$R *.lfm}

{ TFmainw }

procedure TFmainw.FormCreate(Sender: TObject);
begin
  DefaultFormatSettings.ShortDateFormat := 'yyyy-MM-dd';
  DefaultFormatSettings.DateSeparator := '-';
  DefaultFormatSettings.DecimalSeparator := ',';
  {create sockets}
  listVar := TStringList.Create;
  listVar.Clear;
  tcpSocket := TBlockSocket.Create;
  tcpSocket.OnStatus := @Self.TCPSocketStatus;
  Timer1.Enabled := False;
  PC1.ActivePageIndex := 0;

  tcpConnected := False;
  tcpRecived := 0;
  tcpLastError := 1;//connect

  MainIni := TINIFile.Create(ExtractFilePath(Application.ExeName) + 'configups.ini');
  {Read program config}
  timerInterval := iniDefIntervalTimerOBMs;
  Timer1.Interval := timerInterval;
  {Read UPSes configs}
  Ehost.Text := MainIni.ReadString('ups0', 'host', '');
  Eport.Text := MainIni.ReadString('ups0', 'port', upsDefaultPortStr);
  Eups.Text := MainIni.ReadString('ups0', 'upsname', 'ups');
  Eupsinterval.Value := MainIni.ReadInteger('ups0', 'varinterval',
    iniDefUpsVarIntervalSec);
  {clear controls}
  Fmainw.Caption := appName;
  Application.Title := appName;
  Memo1.Clear;
  Memo2.Lines.Text := 'Waiting for data...';
  GBdata.Caption := '';
  GBparameters.Caption := '';
  Tdata.Caption := MainIni.ReadString(iniMainSecN, 'tdata', 'UPS data');
  Tsettings.Caption := MainIni.ReadString(iniMainSecN, 'tsettings', 'Settings');
  Tterminal.Caption := MainIni.ReadString(iniMainSecN, 'tterminal', 'Communication');
  BBsave.Caption := MainIni.ReadString(iniMainSecN, 'bbsave', 'Save');
  BBsend.Caption := MainIni.ReadString(iniMainSecN, 'bbsend', 'Send');
  Lhost.Caption := MainIni.ReadString(iniMainSecN, 'lhost', 'NUT host IP:');
  Lport.Caption := MainIni.ReadString(iniMainSecN, 'lport', 'NUT port:');
  Lupsname.Caption := MainIni.ReadString(iniMainSecN, 'lupsname', 'NUT upsname:');
  Linterval.Caption := MainIni.ReadString(iniMainSecN, 'linterval',
    'Read interval (sec):');
  Ecmd.Text := '';
  Ecmd.Items.Add('LIST UPS');
  Ecmd.Items.Add('LIST VAR ' + Eups.Text);
  Ecmd.Items.Add('LIST RW ' + Eups.Text);
  Ecmd.Items.Add('LIST CMD ' + Eups.Text);
  Ecmd.Items.Add('LIST CLIENT ' + Eups.Text);

  {start allreadings}
  if not (Ehost.Text = '') then
  begin
    Timer1.Enabled := True;
  end;
end;

procedure TFmainw.BBsendClick(Sender: TObject);
begin
  tcpSocket.SendString(Ecmd.Text + LineEnding);
  timerCycle := -9;
end;

procedure TFmainw.EcmdKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
    BBsendClick(Sender);
end;

procedure TFmainw.EhostChange(Sender: TObject);
begin
  tcpLastError := 1;
end;

procedure TFmainw.BBsaveClick(Sender: TObject);
begin
  MainIni.WriteString(iniMainSecN, 'tdata', Tdata.Caption);
  MainIni.WriteString(iniMainSecN, 'tsettings', Tsettings.Caption);
  MainIni.WriteString(iniMainSecN, 'tterminal', Tterminal.Caption);
  MainIni.WriteString(iniMainSecN, 'bbsave', BBsave.Caption);
  MainIni.WriteString(iniMainSecN, 'bbsend', BBsend.Caption);
  MainIni.WriteString(iniMainSecN, 'lhost', Lhost.Caption);
  MainIni.WriteString(iniMainSecN, 'lport', Lport.Caption);
  MainIni.WriteString(iniMainSecN, 'lupsname', Lupsname.Caption);
  MainIni.WriteString(iniMainSecN, 'linterval', Linterval.Caption);

  MainIni.WriteString('ups0', 'host', Ehost.Text);
  MainIni.WriteString('ups0', 'port', Eport.Text);
  MainIni.WriteString('ups0', 'upsname', Eups.Text);
  MainIni.WriteInteger('ups0', 'varinterval', Eupsinterval.Value);

end;

procedure TFmainw.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  //closing
  listVar.Clear;
  listVar.Free;
  tcpSocket.Free;
end;

procedure TFmainw.Timer1Timer(Sender: TObject);
var
  upscmd: integer;
  datacount: integer;
begin
  upscmd := Eupsinterval.Value;
  if upscmd < 10 then
    upscmd := 10;
  if tcpSocket.LastError > 0 then
  begin
    SBar.SimpleText := tcpSocket.LastErrorDesc;
  end;
  if tcpLastError > 0 then
  begin
    tcpLastError := 0;
    tcpSocket.AbortSocket;
    if not (Ehost.Text = '') then
    begin
      tcpSocket.Connect(Ehost.Text, Eport.Text);
    end;
    Exit;
  end;
  if ((timerCycle mod upscmd) = 0) then
  begin
    SBar.SimpleText := 'Send to ' + tcpSocket.GetRemoteSinIP + ':' +
      IntToStr(tcpSocket.GetRemoteSinPort) + ' ' + Eups.Text;
    tcpSocket.SendString('LIST VAR ' + Eups.Text + LineEnding);
  end
  else if (timerCycle mod 4) = 0 then
    if tcpSocket.LastError > 0 then
      SBar.SimpleText := 'Last error #' + IntToStr(tcpSocket.LastError)
    else
      SBar.SimpleText := '_'
  else if (timerCycle mod 3) = 0 then
    SBar.SimpleText := '-';

  datacount := tcpSocket.WaitingDataEx;

  if (tcpRecived >= datacount) and (datacount > 0) then
  begin
    listBuffer := tcpSocket.RecvBufferStr(datacount, 500);
    Memo1.Append(ListProcess);
  end;
  if listVar.Text.Length > 0 then
  begin
    refreshDataTab;
    listVar.Clear;
  end;

  tcpRecived := datacount;
  timerCycle := timerCycle + 1;
  tcpLastError := tcpSocket.LastError;
end;

procedure TFmainw.TCPSocketStatus(Sender: TObject; Reason: THookSocketReason;
  const Value: string);
begin
  //SBar.SimpleText := 'Socket status '+ Value;
  if Reason = HR_ReadCount then
  begin
    SBar.SimpleText := 'Socket read ' + Value;
  end;

end;

function TFmainw.ListProcess: string;
var
  p: integer;
  c: string;
  bstr: string;
  listtype: integer;
begin
  if Pos('BEGIN LIST VAR', listBuffer) > 0 then
  begin
    //LIST VAR
    bstr := 'VAR ' + Eups.Text + ' ';
    listtype := 1;
  end
  else if Pos('BEGIN LIST UPS', listBuffer) > 0 then
  begin
    //LIST UPS
    bstr := 'UPS ';
    listtype := 2;
  end
  else if Pos('BEGIN LIST CMD', listBuffer) > 0 then
  begin
    //LIST CMD
    bstr := 'CMD ' + Eups.Text + ' ';
    listtype := 3;
  end
  else if Pos('BEGIN LIST RW', listBuffer) > 0 then
  begin
    //LIST RW
    bstr := 'RW ' + Eups.Text + ' ';
    listtype := 4;
  end
  else if Pos('BEGIN LIST CLIENT', listBuffer) > 0 then
  begin
    //LIST Client
    bstr := 'CLIENT ' + Eups.Text + ' ';
    listtype := 5;
  end
  else
  begin
    listtype := 0;
    Result := LineEnding + '----unsuported' + LineEnding + listBuffer;
    Exit;
  end;
  Result := '';
  p := Pos(bstr, listBuffer);
  c := listBuffer.Substring(-1 + p + bstr.Length);
  p := 1;
  while (p > 0) do
  begin
    p := Pos(bstr, c);
    if p = 0 then
      p := Pos('END LIST ', c);
    if c.Substring(0, p - 1).Length > 0 then
      Result := Result + LineEnding + c.Substring(0, p - 1);
    c := c.Substring(-1 + p + bstr.Length);
  end;

  if listtype = 1 then
    listVar.Text := Result;
end;

function TFmainw.GetVarByName(varname: string): string;
var
  p: integer;
  i: integer;
  ss: string;
begin
  Result := '';
  if varname.Length < 3 then
    Exit;

  if (listVar.Text.Length < varname.Length) then
    Exit;

  for i := 0 to listVar.Count - 1 do
  begin
    p := Pos(AnsiUpperCase(varname), AnsiUpperCase(listVar.Strings[i]));
    if p > 0 then
    begin
      p := Pos('"', listVar.Strings[i]);
      if p > 0 then
      begin
        ss := listVar.Strings[i].Substring(p);
        if ss.Length < 2 then
          Exit;
        p := Pos('"', ss);
        if p > 1 then
          Result := ss.Substring(0, p - 1);
      end;
      Exit;
    end;
  end;
end;

procedure TFmainw.refreshDataTab;
var
  s: string;
begin
  if listVar.Text.Length < 5 then
    Exit;
  s := GetVarByName('ups.status');
  if s.Length > 1 then
  begin
    Fmainw.Caption := appName + ' - ' + s;
    Application.Title := appName + ' - ' + s;
    if Pos('OL', s) > 0 then      //status OL
    begin
      if Pos('CHRG', s) > 0 then
        Memo2.Color := $00EAFFFF
      else
        Memo2.Color := $00EFFFEA;
      ImageList1.GetBitmap(0, Image1.Picture.Bitmap);
      timerInterval := iniDefIntervalTimerOLMs;
    end
    else
    begin
      ImageList1.GetBitmap(1, Image1.Picture.Bitmap);//status OB, on battery
      Memo2.Color := $00EAEAFF;
      timerInterval := iniDefIntervalTimerOBMs;
    end;
  end;
  Memo2.Clear;
  //error  $00EAEAFF, warning $00EAFFFF, ok $00EFFFEA
  //OB DISCHRG, OL CHRG
  if Timer1.Interval <> timerInterval then
    Timer1.Interval := timerInterval;

  Memo2.Append('Input Voltage: ' + GetVarByName('input.voltage') +
    'V (Nominal ' + GetVarByName('input.voltage.nominal') + 'V)');
  Memo2.Append('Battery Voltage: ' + GetVarByName('battery.voltage') +
    'V (Nominal ' + GetVarByName('battery.voltage.nominal') + 'V)');
  Memo2.Append('Battery Charge: ' + GetVarByName('battery.charge') +
    '% (Warning ' + GetVarByName('battery.charge.warning') + '%, Low ' +
    GetVarByName('battery.charge.low') + '%)');
  Memo2.Append('UPS load: ' + GetVarByName('ups.load') + '%, runtime: ' +
    GetVarByName('battery.runtime') + ' sec');
  Memo2.Append('Device mfr: ' + GetVarByName('device.mfr') + ', model: ' +
    GetVarByName('device.model') + ' (SN: ' + GetVarByName('device.serial') + ')');
end;

end.
