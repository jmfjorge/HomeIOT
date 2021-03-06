unit untPrincipal;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Generics.Collections, System.IOUtils, FMX.Types, FMX.Controls,
  FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Controls.Presentation, FMX.StdCtrls,
  FMX.Effects, REST.Types, REST.Client, Data.Bind.Components,
  Data.Bind.ObjectScope, FMX.WebBrowser, FMX.Media, System.Net.URLClient,
  System.Net.HttpClient, System.Net.HttpClientComponent, FMX.Objects,
  System.Threading, System.JSON, VerySimple.Lua, VerySimple.Lua.Lib;

type
  TDeviceIOTInfo = record
      sAddress     : String;
      sIOTDevID    : String;
      sAddressInfo : String;
  end;
  TfrmPrinicipal = class(TForm)
    pnControls: TPanel;
    RESTClient1: TRESTClient;
    RESTRequest1: TRESTRequest;
    RESTResponse1: TRESTResponse;
    NetHTTPClient1: TNetHTTPClient;
    ImageStream: TImage;
    lbTemperature: TLabel;
    NetHTTPClient2: TNetHTTPClient;
    TimerAutomation: TTimer;
    SwitchAutoMode: TSwitch;
    LabelSwitchAutoMode: TLabel;
    NetHTTPClient3: TNetHTTPClient;
    RESTClient2: TRESTClient;
    RESTRequest2: TRESTRequest;
    RESTResponse2: TRESTResponse;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TimerAutomationTimer(Sender: TObject);
    procedure RESTRequest2AfterExecute(Sender: TCustomRESTRequest);
  private
    { Private declarations }
    m_oDevIOTInfo : TDictionary<TControl, TDeviceIOTInfo>;
    m_bApplicationActive : Boolean;
    m_sESP32AddressCam : String;
    m_sESP32AddressTemp : String;
    m_iCurrentTemp : Integer;
    Lua: TVerySimpleLua;
    procedure CreateCommanderControl(sName, sDescription, sControlAddress, sDevID, sAddressInfo : String; bState : Boolean; iPosX, iPosY : Integer);
    procedure CreateCommanderControls;
    procedure OnSwitchEnter(Sender: TObject);
    procedure OnSwitchExit(Sender: TObject);
    procedure OnSwitchKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure TryFocusNextControl(oParent : TComponent; iCurrentY : Integer);
    procedure TrySetFocusControl(oControl: TComponent);
    procedure TryFocusPrevControl(oParent: TComponent; iCurrentY: Integer);
    procedure OnSwitchSwitch(Sender: TObject);
    procedure SendCommandIOTDev(bEnabled: Boolean; oDevInfo: TDeviceIOTInfo);
    procedure OnSwitchKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure PreparePreviewThread(sServerAddress : String);
    procedure PrepareTemperatureThread(sServerAddress : String);
    procedure SetESP32CamAddress(sAddress: String);
    procedure SetESP32TempAddress(sAddress: String);
    procedure ForceSelectSwitches(oList: TStringList);
    procedure InitLuaScript;
    function InitCommands(L: lua_State; iIndex, iDelta : integer): Boolean;
    function LuaActionInfo(L: lua_State; iTemp : integer): Boolean;
    procedure PopLuaResultStack(L: lua_State);
    function LuaInitSensors(L: lua_State; iIndex, iDelta: integer): Boolean;
    procedure OnLuaError(sMsg: String);
    function DownloadScriptFromGoogleDriveLink: String;
    function GetApplicationScriptStoragePath: String;
    procedure GetStateIOTDevs;
    procedure SetSwitchValueByID(sID: String; bIsChecked: Boolean);
  public
    { Public declarations }
  end;

var
  frmPrinicipal: TfrmPrinicipal;

implementation

{$R *.fmx}

procedure TfrmPrinicipal.ForceSelectSwitches(oList : TStringList);
var
  oItem : TControl;
  bOld  : Boolean;
begin
  for oItem in m_oDevIOTInfo.Keys do
  begin
    bOld:=TSwitch(oItem).IsChecked;
    TSwitch(oItem).IsChecked:=oList.IndexOf(oItem.Name)>=0;
    if bOld=TSwitch(oItem).IsChecked then
      TSwitch(oItem).OnSwitch(TSwitch(oItem));
  end;
end;
procedure TfrmPrinicipal.PreparePreviewThread(sServerAddress : String);
var
  oStream : TMemoryStream;
begin
    TThread.CreateAnonymousThread(
    procedure
    begin
      while (m_bApplicationActive) do
      begin
        try
          oStream := TMemoryStream.Create;
          NetHTTPClient1.Get(sServerAddress,oStream);
          oStream.Seek( 0, TSeekOrigin(soFromBeginning));
          TThread.Synchronize(TThread.CurrentThread,
          procedure
          begin
            ImageStream.Bitmap.LoadFromStream(oStream);
          end);
        except
        end;
        if oStream<>nil then
          oStream.Free;
      end;
    end).Start;
end;

procedure TfrmPrinicipal.PrepareTemperatureThread(sServerAddress : String);
var
  oStream : TStringStream;
  sTemp : String;
  dLast : Double;
  dTemp : Double; 
begin
    TThread.CreateAnonymousThread(
    procedure
    begin    
      while (m_bApplicationActive) do
      begin
        try
          oStream := TStringStream.Create;
          NetHTTPClient2.Get(sServerAddress,oStream);
          sTemp:=oStream.DataString.Trim;
          TThread.Synchronize(TThread.CurrentThread,
          procedure
          begin
            if StrToIntDef(sTemp ,-999)<>-999 then
            begin
              dTemp:=(StrToIntDef(sTemp, 0)/100) + 4;
              if dLast<>0 then    
                dTemp:=(dTemp + dLast) / 2;
              dLast:=dTemp;
              m_iCurrentTemp:=Round(dTemp);
              lbTemperature.Text:='Temperatura: ' + m_iCurrentTemp.ToString + '?C';
            end;  
          end);
        except
        end;
        if oStream<>nil then
          oStream.Free;
        Sleep(500);          
      end;
    end).Start;
end;


procedure TfrmPrinicipal.RESTRequest2AfterExecute(Sender: TCustomRESTRequest);
var
  sTemp     : String;
  JSONObj   : TJSONObject;
  JSONVal   : TJSONObject;
  JSONArray : TJSONArray;
  JSONArrayElement: TJSonValue;
  bEnabled  : Boolean;
  sID       : String;
begin
  if Assigned(RESTResponse2.JSONValue) then
  begin
    try
      sTemp:=RESTResponse2.JSONValue.ToString;
      JSONObj := TJSONObject.ParseJSONValue( TEncoding.ASCII.GetBytes(sTemp), 0) as TJSONObject;
      JSONArray := TJSONArray(JSONObj.Get('data').JsonValue);
      JSONVal:= TJSONObject(JSONArray.Get(0));
      bEnabled:=False;
      for JSONArrayElement in JsonArray do
      begin
        if JSONArrayElement.ToString='"switch":"on"' then
          bEnabled:=True;
        if Copy(JSONArrayElement.ToString,1,11)='"deviceid":' then
          sID:=StringReplace(Copy(JSONArrayElement.ToString,13,100),'"','', [rfReplaceAll]);
      end;

      JSONObj.Free;

      TThread.Queue(nil,procedure
      begin
        SetSwitchValueByID(sID, bEnabled);
      end);
    except
    end;
  end;
end;

procedure TfrmPrinicipal.SetSwitchValueByID(sID : String; bIsChecked : Boolean);
var
  oItem : TControl;
  oDevInfo: TDeviceIOTInfo;
begin
  for oItem in m_oDevIOTInfo.Keys do
  begin
    m_oDevIOTInfo.TryGetValue(oItem, oDevInfo);
    if oDevInfo.sIOTDevID=sID then
    begin
      if TSwitch(oItem).IsChecked<>bIsChecked then
        TSwitch(oItem).IsChecked:=bIsChecked;
      Break;
    end;
  end;
end;


procedure TfrmPrinicipal.CreateCommanderControl(sName, sDescription, sControlAddress, sDevID, sAddressInfo : String;
                                                bState : Boolean; iPosX, iPosY : Integer);
var
  oSwitch : TSwitch;
  oDevInfo : TDeviceIOTInfo;
begin
  try
    oSwitch:=TSwitch.Create(pnControls);
    with oSwitch do
    begin
      Parent:=pnControls;
      Position.X:=iPosX;
      Position.Y:=iPosY;
      Name:=sName;
      IsChecked:=bState;
      Opacity:=0.7;
      Visible:=True;
      OnEnter:=OnSwitchEnter;
      OnExit:=OnSwitchExit;
      OnKeyUp:=OnSwitchKeyUp;
      OnKeyDown:=OnSwitchKeyDown;
      OnSwitch:=OnSwitchSwitch;
    end;
    oDevInfo.sAddress:=sControlAddress;
    oDevInfo.sIOTDevID:=sDevID;
    oDevInfo.sAddressInfo:=sAddressInfo;
    //oDevInfo.sCompName:=TControl(oSwitch).Name;
    m_oDevIOTInfo.Add(TControl(oSwitch),oDevInfo);
    with TLabel.Create(pnControls) do
    begin
      Parent:=pnControls;
      Position.X:=iPosX + 90;
      Position.Y:=iPosY + 6;
      Name:='Label'+sName;
      Text:=sDescription;
      StyledSettings:=[];
    end;
  except
  end;
end;

procedure TfrmPrinicipal.OnSwitchEnter(Sender: TObject);
begin
  TSwitch(Sender).Opacity:=1;
  TLabel(pnControls.FindComponent('Label'+TSwitch(Sender).Name)).TextSettings.Font.Style:=[TFontStyle.fsBold];
end;

procedure TfrmPrinicipal.OnSwitchExit(Sender: TObject);
begin
  TLabel(pnControls.FindComponent('Label'+TSwitch(Sender).Name)).TextSettings.Font.Style:=[];
  TSwitch(Sender).Opacity:=0.7;
end;

procedure TfrmPrinicipal.OnSwitchSwitch(Sender: TObject);
var
  sServer : String;
  oDevInfo : TDeviceIOTInfo;
begin
  //if TSwitch(Sender).IsChecked then
  m_oDevIOTInfo.TryGetValue(TControl(Sender), oDevInfo);
  SendCommandIOTDev(TSwitch(Sender).IsChecked, oDevInfo);
end;


procedure TfrmPrinicipal.OnSwitchKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if Key=38 then
    TryFocusPrevControl(pnControls, Trunc(TSwitch(Sender).Position.Y));
  if Key=40 then
    TryFocusNextControl(pnControls, Trunc(TSwitch(Sender).Position.Y));
end;

procedure TfrmPrinicipal.OnSwitchKeyUp(Sender: TObject; var Key: Word;  var KeyChar: Char; Shift: TShiftState);
begin
  if Key=0 then
    TSwitch(Sender).IsChecked:=not TSwitch(Sender).IsChecked;
end;

procedure TfrmPrinicipal.SetESP32CamAddress(sAddress : String);
begin
  m_sESP32AddressCam:=sAddress;
end;

procedure TfrmPrinicipal.SetESP32TempAddress(sAddress : String);
begin
  m_sESP32AddressTemp:=sAddress;
end;

function TfrmPrinicipal.GetApplicationScriptStoragePath : String;
begin
  Result:=System.IOUtils.TPath.GetHomePath +
          System.IOUtils.TPath.DirectorySeparatorChar +
         'HomeIOT' + System.IOUtils.TPath.DirectorySeparatorChar;
end;

procedure TfrmPrinicipal.CreateCommanderControls;
var
  oList : TStringList;
  sPath : String;
begin
  try
    oList:=TStringList.Create;
    oList.Text:=DownloadScriptFromGoogleDriveLink;
    if oList.Text<>'' then
    begin
      sPath:=GetApplicationScriptStoragePath;
      ForceDirectories(sPath);
      oList.SaveToFile(sPath+'HomeIOT.lua');
    end;
  finally
    oList.Free;
  end;
  InitLuaScript;
end;

procedure TfrmPrinicipal.FormCreate(Sender: TObject);
begin
  m_sESP32AddressCam:='';
  m_sESP32AddressTemp:='';
  m_iCurrentTemp:=-99;
  NetHTTPClient1.ConnectionTimeout := 500;
  NetHTTPClient2.ConnectionTimeout := 500;
  SwitchAutoMode.OnKeyUp:=OnSwitchKeyUp;
  SwitchAutoMode.OnKeyDown:=OnSwitchKeyDown;
  SwitchAutoMode.OnEnter:=OnSwitchEnter;
  SwitchAutoMode.OnExit:=OnSwitchExit;
  pnControls.InsertComponent(SwitchAutoMode);
  pnControls.InsertComponent(LabelSwitchAutoMode);
  m_oDevIOTInfo:=TDictionary<TControl, TDeviceIOTInfo>.Create;
  CreateCommanderControls;  
  m_bApplicationActive:=True;
end;

procedure TfrmPrinicipal.FormDestroy(Sender: TObject);
begin
  m_oDevIOTInfo.Free;
  m_bApplicationActive:=False;
  if Assigned(Lua) then
    Lua.Free;
end;

procedure TfrmPrinicipal.FormShow(Sender: TObject);
begin
  //GetStateIOTDevs;  
  TSwitch(pnControls.FindComponent('Switch1')).SetFocus;
  if m_sESP32AddressCam<>'' then
    PreparePreviewThread(m_sESP32AddressCam);
  if m_sESP32AddressTemp<>'' then
  begin
    PrepareTemperatureThread(m_sESP32AddressTemp);
    TimerAutomation.Enabled:=True;
  end;
  GetStateIOTDevs;
end;

procedure TfrmPrinicipal.TimerAutomationTimer(Sender: TObject);
begin
  //Verify the logic according the LUA Script
  if (m_iCurrentTemp<>-99) and (Assigned(Lua) and (TSwitch(pnControls.FindComponent('SwitchAutoMode')).IsChecked)) then
    LuaActionInfo(Lua.LuaState, m_iCurrentTemp)
end;

procedure TfrmPrinicipal.TryFocusNextControl(oParent : TComponent; iCurrentY : Integer);
var
  iComponent, iDistance : Integer;
  sName : String;
  iDelta : Integer;
  sTopName : String;
  iMinY    : Integer;
begin
  iDistance:=99999;
  iMinY:=99999;
  sName:='';
  sTopName:='';
  for iComponent := 0 to oParent.ComponentCount-1 do
  begin
    if oParent.Components[iComponent] is TSwitch then
    begin
      if TControl(oParent.Components[iComponent]).Position.Y>iCurrentY then
      begin
        iDelta:=Trunc(TControl(oParent.Components[iComponent]).Position.Y)-iCurrentY;
        if ((iDelta>0) and (iDistance>iDelta)) then
        begin
          sName:=TControl(oParent.Components[iComponent]).Name;
          iDistance:=iDelta;
        end;
      end;
      if TControl(oParent.Components[iComponent]).Position.Y<iMinY then
      begin
        sTopName:=TControl(oParent.Components[iComponent]).Name;
        iMinY:=Trunc(TControl(oParent.Components[iComponent]).Position.Y);
      end;

    end;
  end;

  if sName<>'' then
    TrySetFocusControl(oParent.FindComponent(sName))
  else
  if sTopName<>'' then
    TrySetFocusControl(oParent.FindComponent(sTopName));
end;

procedure TfrmPrinicipal.TryFocusPrevControl(oParent : TComponent; iCurrentY : Integer);
var
  iComponent, iDistance : Integer;
  sName : String;
  iDelta : Integer;
  sBottomName : String;
  iMaxY  : Integer;
begin
  iDistance:=99999;
  iMaxY:=-9999;
  sName:='';
  sBottomName:='';
  for iComponent := 0 to oParent.ComponentCount-1 do
  begin
    if oParent.Components[iComponent] is TSwitch then
    begin
      if TControl(oParent.Components[iComponent]).Position.Y<iCurrentY then
      begin
        iDelta:=iCurrentY-Trunc(TControl(oParent.Components[iComponent]).Position.Y);
        if ((iDelta>0) and (iDistance>iDelta)) then
        begin
          sName:=TControl(oParent.Components[iComponent]).Name;
          iDistance:=iDelta;
        end;
      end;
      if TControl(oParent.Components[iComponent]).Position.Y > iMaxY then
      begin
        sBottomName:=TControl(oParent.Components[iComponent]).Name;
        iMaxY:=Trunc(TControl(oParent.Components[iComponent]).Position.Y);
      end;

    end;
  end;

  if sName<>'' then
    TrySetFocusControl(oParent.FindComponent(sName))
  else
  if sBottomName<>'' then
    TrySetFocusControl(oParent.FindComponent(sBottomName));
end;


procedure TfrmPrinicipal.TrySetFocusControl(oControl : TComponent);
begin
  try
    if TControl(oControl).CanFocus then
      TControl(oControl).SetFocus;
  except
  end;
end;

procedure TfrmPrinicipal.SendCommandIOTDev(bEnabled : Boolean; oDevInfo : TDeviceIOTInfo);
var
  sOnOff : String;
  ATask  : ITask;
begin
  ATask := TTask.Create(
   procedure()
    begin
      try
        if oDevInfo.sAddress='' then
          Exit;
        sOnOff:='off';
        if bEnabled then
          sOnOff:='on';
        RESTClient1.BaseURL:=oDevInfo.sAddress;
        RESTRequest1.Params.ParameterByName('body').Value:='{"deviceid": "'+oDevInfo.sIOTDevID+'", "data": {"switch": "'+sOnOff+'"}}';
        RESTRequest1.Execute;
      except
      end;
   end);
  ATask.Start;
end;

procedure TfrmPrinicipal.GetStateIOTDevs;
var
  ATask  : ITask;
begin
  ATask := TTask.Create(
   procedure()
    var
      oItem : TControl;
      oDevInfo : TDeviceIOTInfo;
    begin
      try
        for oItem in m_oDevIOTInfo.Keys do
        begin
          m_oDevIOTInfo.TryGetValue(oItem, oDevInfo);
          RESTClient2.BaseURL:=oDevInfo.sAddressInfo;
          if oDevInfo.sAddressInfo<>'' then      
          begin
            RESTRequest2.Params.ParameterByName('body').Value:='{"deviceid": "'+oDevInfo.sIOTDevID+'", "data": {}}';
            RESTRequest2.Execute;
          end;
        end;
      except
      end;
   end);
  ATask.Start;
end;



function TfrmPrinicipal.DownloadScriptFromGoogleDriveLink : String;
var
  oStream : TStringStream;
  sLinkGDrive : String;
begin
  try
    //Link do Google Drive gerado em: https://sites.google.com/site/gdocs2direct/home
    //sLinkGDrive:='https://drive.google.com/uc?export=download&id=1FeUmcikjdlTSmTgR_48Db9Bf0qqSgbjJ';
    sLinkGDrive:='https://drive.google.com/uc?export=download&id=1FeUmcikjdlTSmTgR_48Db9Bf0qqSgbjJ';
    try
      oStream := TStringStream.Create;
      NetHTTPClient1.Get(sLinkGDrive,oStream);
      Result:=oStream.DataString;
      if Pos('>NOT FOUND<',Result.ToUpper)>0 then
        Result:='';
    finally
      oStream.Free;
    end;
  except
    Result:='';
  end;
end;

procedure TfrmPrinicipal.InitLuaScript;
var
  iLine : Integer;
begin
  Lua := TVerySimpleLua.Create;
  Lua.OnError:= OnLuaError;
  Lua.FilePath := GetApplicationScriptStoragePath;
  Lua.LibraryPath :=  ExtractFilePath(ParamStr(0)) + LUA_LIBRARY;
  Lua.DoFile('HomeIOT.lua');
  //Get the switches
  iLine:=0;
  repeat
    Inc(iLine);
  until (not InitCommands(Lua.LuaState, iLine, (30 *  (iLine-1))));
  //Get the switches
  iLine:=0;
  repeat
    Inc(iLine);
  until (not LuaInitSensors(Lua.LuaState, iLine, (30 *  (iLine-1))));
end;

function TfrmPrinicipal.InitCommands(L: lua_State; iIndex, iDelta : integer): Boolean;
var
  sName        : String;
  sAddress     : String;
  sDesc        : String;
  sDevID       : String;
  sAddressInfo : String;
begin
  lua_getglobal(L, 'InitCommands'); // name of the function
  lua_pushinteger(L, iIndex);  // parameter
  lua_call(L, 1, 5);  // call function with 1 parameters and 3 results
  sName := lua_tostring(L,-1); // get result 1
  PopLuaResultStack(L);
  sDesc := lua_tostring(L,-1); // get result 2
  PopLuaResultStack(L);
  sAddress := lua_tostring(L,-1); // get result 3
  PopLuaResultStack(L);
  sDevID :=  lua_tostring(L,-1); // get result 4
  PopLuaResultStack(L);
  sAddressInfo :=  lua_tostring(L,-1); // get result 5
  PopLuaResultStack(L);
  
  if sName<>'' then
  begin
    CreateCommanderControl(sName, sDesc, sAddress, sDevID, sAddressInfo, False, 20, 20 + iDelta);
    Result:=True;
  end
  else
    Result:=False;    
end;
function TfrmPrinicipal.LuaActionInfo(L: lua_State; iTemp : integer): Boolean;
var
  oList : TStringList;
  sRes  : String;
  iIndex : Integer;
begin
  try
    Result:=False;
    oList := TStringList.Create;
    lua_getglobal(L, 'ActionInfo'); // name of the function
    lua_pushinteger(L, iTemp);  // parameter
    lua_call(L, 1, 3);  // call function with 1 parameters and 1 result
    for iIndex := 1 to 3 do
    begin
      sRes:=lua_tostring(L,-1);
      if sRes<>'' then
        oList.Add(sRes); // get result
      lua_pop(L, 1);  // remove result from stack
    end;
    if oList.Count>0 then
      ForceSelectSwitches(oList);
    Result:=True;
  finally
    oList.Free;
  end;
end;
function TfrmPrinicipal.LuaInitSensors(L: lua_State; iIndex, iDelta : integer): Boolean;
var
  sName    : String;
  sAddress : String;
  sType   : String;
begin
  lua_getglobal(L, 'InitSensors'); // name of the function
  lua_pushinteger(L, iIndex);  // parameter
  lua_call(L, 1, 3);  // call function with 1 parameters and 3 results
  sName := lua_tostring(L,-1); // get result 1
  PopLuaResultStack(L);
  sAddress := lua_tostring(L,-1); // get result 2
  PopLuaResultStack(L);
  sType := lua_tostring(L,-1); // get result 3
  PopLuaResultStack(L);
  if sName<>'' then
  begin
    if sType='Cam' then
      SetESP32CamAddress(sAddress);
    if sType='Temp' then
      SetESP32TempAddress(sAddress);
    Result:=True;
  end
  else
    Result:=False;
end;
procedure TfrmPrinicipal.PopLuaResultStack(L: lua_State);
begin
  lua_pop(L, 1);  // remove result from stack
end;

procedure TfrmPrinicipal.OnLuaError(sMsg: String);
begin
  Showmessage('Lua Script Error: ' + sMsg);
end;

end.
