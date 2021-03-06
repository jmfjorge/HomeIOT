unit Unit8;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Layouts, FMX.Memo,
  FMX.Controls.Presentation, FMX.ScrollBox;

type
  TForm8 = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure OnPrint(Msg: String);
  end;

var
  Form8: TForm8;

implementation

{$R *.fmx}

uses
  VerySimple.Lua, VerySimple.Lua.Lib, System.IOUtils;




function LuaActionInfo(L: lua_State; iTemp : integer): String;
begin
  lua_getglobal(L, 'LuaActionInfo'); // name of the function
  lua_pushinteger(L, iTemp);  // parameter
  lua_call(L, 1, 3);  // call function with 1 parameters and 1 result
  Result := lua_tostring(L,-1); // get result
  lua_pop(L, 1);  // remove result from stack
  Result := Result + lua_tostring(L,-1); // get result
  lua_pop(L, 1);  // remove result from stack
  Result := Result + lua_tostring(L,-1); // get result
  lua_pop(L, 1);  // remove result from stack
end;


function LuaInitCommands(L: lua_State; iIndex : integer): Boolean;
var
  sName    : String;
  sAddress : String;
  sDevID   : String;
begin
  lua_getglobal(L, 'LuaInitCommands'); // name of the function
  lua_pushinteger(L, iIndex);  // parameter
  lua_call(L, 1, 3);  // call function with 1 parameters and 3 results
  sName := lua_tostring(L,-1); // get result 1
  lua_pop(L, 1);  // remove result from stack
  sAddress := lua_tostring(L,-1); // get result 2
  lua_pop(L, 1);  // remove result from stack
  sDevID :=  lua_tostring(L,-1); // get result 3
  lua_pop(L, 1);  // remove result from stack
  if sAddress<>'' then
  begin
    Showmessage(sName + ' ' + sAddress + ' ' + sDevID);
    Result:=True;
  end
  else
    Result:=False;
end;

procedure TForm8.Button1Click(Sender: TObject);
var
  Lua: TVerySimpleLua;
  iCommand : Integer;
begin
  Lua := TVerySimpleLua.Create;

  {$IF defined(WIN32)}
  Lua.LibraryPath :=  'C:\Desenvolvimento\VerySimpleLua\DLL\Win32\' + LUA_LIBRARY;
  Lua.FilePath := 'C:\Desenvolvimento\VerySimpleLua\Examples\Example 3 - Hello world (FMX)\';

  {$ELSEIF defined(WIN64)}
  Lua.LibraryPath :=  '..\..\..\..\DLL\WIN64\' + LUA_LIBRARY;
  Lua.FilePath := '..\..\';
  {$ENDIF}

  Lua.OnPrint := OnPrint; // Redirect console output to memo
  Lua.DoFile('example3.lua');
  Showmessage(LuaActionInfo(Lua.LuaState, 10));
  iCommand:=0;
  repeat
    Inc(iCommand);
  until (not LuaInitCommands(Lua.LuaState, iCommand));
  Lua.Free;
end;

procedure TForm8.OnPrint(Msg: String);
begin
  Memo1.Lines.Add(Msg);
  Memo1.GoToTextEnd;
  Application.ProcessMessages;
end;

end.
