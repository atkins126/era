unit Erm;
{
DESCRIPTION:  Native ERM support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  SysUtils, Math, Windows,
  Utils, Crypto, TextScan, AssocArrays, DataLib, CFiles, Files, Ini, TypeWrappers, ApiJack,
  Lists, StrLib,
  Core, Heroes, GameExt, RscLists, EventMan;

type
  (* Import *)
  TAssocArray = AssocArrays.TAssocArray;
  TStrList    = DataLib.TStrList;
  TDict       = DataLib.TDict;
  TString     = TypeWrappers.TString;
  TResource   = RscLists.TResource;

const
  ERM_SCRIPTS_SECTION      = 'Era.ErmScripts';
  FUNC_NAMES_SECTION       = 'Era.FuncNames';
  ERM_SCRIPTS_PATH         = 'Data\s';
  EXTRACTED_SCRIPTS_PATH   = GameExt.DEBUG_DIR + '\Scripts';
  ERM_TRACKING_REPORT_PATH = DEBUG_DIR + '\erm tracking.erm';

  (* Erm command conditions *)
  LEFT_COND  = 0;
  RIGHT_COND = 1;
  COND_AND   = 0;
  COND_OR    = 1;

  ERM_CMD_MAX_PARAMS_NUM = 16;
  MIN_ERM_SCRIPT_SIZE    = Length('ZVSE'#13#10);
  LINE_END_MARKER        = #10;

  (* Erm script state*)
  SCRIPT_NOT_USED = 0;
  SCRIPT_IS_USED  = 1;
  SCRIPT_IN_MAP   = 2;

  AltScriptsPath: pchar     = Ptr($2730F68);
  CurrErmEventID: pinteger  = Ptr($27C1950);

  (* Trigger if-else-then *)
  ZVS_TRIGGER_IF_TRUE     = 1;
  ZVS_TRIGGER_IF_FALSE    = 0;
  ZVS_TRIGGER_IF_INACTIVE = -1;

  (* Erm triggers *)
  TRIGGER_FU1       = 0;
  TRIGGER_FU30000   = 29999;
  TRIGGER_TM1       = 30000;
  TRIGGER_TM100     = 30099;
  TRIGGER_HE0       = 30100;
  TRIGGER_HE198     = 30298;
  TRIGGER_BA0       = 30300;
  TRIGGER_BA1       = 30301;
  TRIGGER_BR        = 30302;
  TRIGGER_BG0       = 30303;
  TRIGGER_BG1       = 30304;
  TRIGGER_MW0       = 30305;
  TRIGGER_MW1       = 30306;
  TRIGGER_MR0       = 30307;
  TRIGGER_MR1       = 30308;
  TRIGGER_MR2       = 30309;
  TRIGGER_CM0       = 30310;
  TRIGGER_CM1       = 30311;
  TRIGGER_CM2       = 30312;
  TRIGGER_CM3       = 30313;
  TRIGGER_CM4       = 30314;
  TRIGGER_AE0       = 30315;
  TRIGGER_AE1       = 30316;
  TRIGGER_MM0       = 30317;
  TRIGGER_MM1       = 30318;
  TRIGGER_CM5       = 30319;
  TRIGGER_MP        = 30320;
  TRIGGER_SN        = 30321;
  TRIGGER_MG0       = 30322;
  TRIGGER_MG1       = 30323;
  TRIGGER_TH0       = 30324;
  TRIGGER_TH1       = 30325;
  TRIGGER_IP0       = 30330;
  TRIGGER_IP1       = 30331;
  TRIGGER_IP2       = 30332;
  TRIGGER_IP3       = 30333;
  TRIGGER_CO0       = 30340;
  TRIGGER_CO1       = 30341;
  TRIGGER_CO2       = 30342;
  TRIGGER_CO3       = 30343;
  TRIGGER_BA50      = 30350;
  TRIGGER_BA51      = 30351;
  TRIGGER_BA52      = 30352;
  TRIGGER_BA53      = 30353;
  TRIGGER_GM0       = 30360;
  TRIGGER_GM1       = 30361;
  TRIGGER_PI        = 30370;
  TRIGGER_DL        = 30371;
  TRIGGER_HM        = 30400;
  TRIGGER_HM0       = 30401;
  TRIGGER_HM198     = 30599;
  TRIGGER_HL        = 30600;
  TRIGGER_HL0       = 30601;
  TRIGGER_HL198     = 30799;
  TRIGGER_BF        = 30800;
  TRIGGER_MF1       = 30801;
  TRIGGER_TL0       = 30900;
  TRIGGER_TL1       = 30901;
  TRIGGER_TL2       = 30902;
  TRIGGER_TL3       = 30903;
  TRIGGER_TL4       = 30904;
  TRIGGER_OB_POS    = integer($10000000);
  TRIGGER_LE_POS    = integer($20000000);
  TRIGGER_OB_LEAVE  = integer($08000000);
  TRIGGER_INVALID   = -1;
  
  (* Era Triggers *)
  FIRST_ERA_TRIGGER                 = 77001;
  TRIGGER_SAVEGAME_WRITE            = 77001;
  TRIGGER_SAVEGAME_READ             = 77002;
  TRIGGER_KEYPRESS                  = 77003;
  TRIGGER_OPEN_HEROSCREEN           = 77004;
  TRIGGER_CLOSE_HEROSCREEN          = 77005;
  TRIGGER_STACK_OBTAINS_TURN        = 77006;
  TRIGGER_REGENERATE_PHASE          = 77007;
  TRIGGER_AFTER_SAVE_GAME           = 77008;
  TRIGGER_BEFOREHEROINTERACT        = 77010;
  TRIGGER_AFTERHEROINTERACT         = 77011;
  TRIGGER_ONSTACKTOSTACKDAMAGE      = 77012;
  TRIGGER_ONAICALCSTACKATTACKEFFECT = 77013;
  TRIGGER_ONCHAT                    = 77014;
  TRIGGER_ONGAMEENTER               = 77015;
  TRIGGER_ONGAMELEAVE               = 77016;
  TRIGGER_ONREMOTEEVENT             = 77017;
  {!} LAST_ERA_TRIGGER              = TRIGGER_ONREMOTEEVENT;
  
  INITIAL_FUNC_AUTO_ID = 95000;

  (* Remote Event IDs *)
  REMOTE_EVENT_NONE         = 0;
  REMOTE_EVENT_PLACE_OBJECT = 1;

  ZvsProcessErm:        Utils.TProcedure = Ptr($74C816);
  ZvsErmError:          procedure ({n} FileName: pchar; Line: integer; ErrStr: pchar) cdecl = Ptr($712333);
  ZvsIsErmError:        pinteger  = Ptr($2772744);
  ZvsBreakTrigger:      PLONGBOOL = Ptr($27F9A40);
  ZvsErmErrorsDisabled: PLONGBOOL = Ptr($2772740);
  ZvsErmHeapPtr:        ppointer  = Ptr($27F9548);
  ZvsErmHeapSize:       pinteger  = Ptr($27F9958);

  (* ERM Flags *)
  ERM_FLAG_NETWORK_BATTLE               = 997;
  ERM_FLAG_REMOTE_BATTLE_VS_HUMAN       = 998;
  ERM_FLAG_THIS_PC_HUMAN_PLAYER         = 999;
  ERM_FLAG_HUMAN_VISITOR_OR_REAL_BATTLE = 1000;

  (* WoG Options *)
  NUM_WOG_OPTIONS           = 1000;
  CURRENT_WOG_OPTIONS       = 0;
  GLOBAL_WOG_OPTIONS        = 1;
  WOG_OPTION_ERROR          = 905;
  WOG_OPTION_DISABLE_ERRORS = 904;
  DONT_WOGIFY               = 0;
  WOGIFY_ALL                = 2;

  NUM_WOG_HEROES = 156;


type
  TErmValType   = (ValNum, ValF, ValQuick, ValV, ValW, ValX, ValY, ValZ);
  TErmCheckType =
  (
    NO_CHECK,
    CHECK_GET,
    CHECK_EQUAL,
    CHECK_NOTEQUAL,
    CHECK_MORE,
    CHECK_LESS,
    CHECK_MOREEUQAL,
    CHECK_LESSEQUAL
  );

  TErmCmdParam = packed record
    Value:    integer;
    {
    [4 bits]  Type:             TErmValType;  // ex: y5;  y5 - type
    [4 bits]  IndexedPartType:  TErmValType;  // ex: vy5; y5 - indexed part;
    [3 bits]  CheckType:        TErmCheckType;
    }
    ValType:  integer;
  end; // .record TErmCmdParam

  TErmString = packed record
    Value:  pchar;
    Len:    integer;
  end; // .record TErmString
  
  TGameString = packed record
    Value:  pchar;
    Len:    integer;
    Dummy:  integer;
  end; // .record TGameString

  PErmCmdConditions = ^TErmCmdConditions;
  TErmCmdConditions = array [COND_AND..COND_OR, 0..15, LEFT_COND..RIGHT_COND] of TErmCmdParam;

  PErmCmdParams = ^TErmCmdParams;
  TErmCmdParams = array [0..ERM_CMD_MAX_PARAMS_NUM - 1] of TErmCmdParam;

  TErmCmdId = packed record
    case boolean of
      true:  (Name: array [0..1] of char);
      false: (Id: word);
  end; // .record TErmCmdId
  
  PErmCmd = ^TErmCmd;
  TErmCmd = packed record
    CmdId:        TErmCmdId;
    Disabled:     boolean;
    PrevDisabled: boolean;
    Conditions:   TErmCmdConditions;
    Structure:    pointer;
    Params:       TErmCmdParams;
    NumParams:    integer;
    CmdHeader:    TErmString; // ##:...
    CmdBody:      TErmString; // #^...^/...
  end; // .record TErmCmd

  PErmSubCmd = ^TErmSubCmd;
  TErmSubCmd = packed record
    Pos:        integer;
    Code:       TGameString;
    Conditions: TErmCmdConditions;
    Params:     TErmCmdParams;
    (* ... *)
  end; // .record TErmSubCmd
  
  TScriptMan = class
     private
      {O} fScripts: RscLists.TResourceList;
     
     public
      constructor Create;
      destructor  Destroy; override;
     
      procedure ClearScripts;
      procedure SaveScripts;
      function  LoadScript (const ScriptPath: string; ScriptName: string = ''): boolean;
      procedure LoadScriptsFromSavedGame;
      procedure LoadScriptsFromDisk;
      procedure ReloadScriptsFromDisk;
      procedure ExtractScripts;
      function  AddrToScriptNameAndLine ({n} Addr: pchar; var {out} ScriptName: string; out LineN: integer; out LinePos: integer): boolean;

      property Scripts: RscLists.TResourceList read fScripts;
    end; // .class TScriptMan

  PZvsTriggerIfs = ^TZvsTriggerIfs;
  TZvsTriggerIfs = array [0..9] of shortint;
  
  PErmVVars = ^TErmVVars;
  TErmVVars = array [1..10000] of integer;
  PWVars    = ^TWVars;
  TWVars    = array [0..255, 1..200] of integer;
  TErmZVar  = array [0..511] of char;
  PErmZVars = ^TErmZVars;
  TErmZVars = array [1..1000] of TErmZVar;
  PErmNZVars = ^TErmNZVars;
  TErmNZVars = array [1..10] of TErmZVar;
  PErmYVars = ^TErmYVars;
  TErmYVars = array [1..100] of integer;
  PErmNYVars = ^TErmNYVars;
  TErmNYVars = array [1..100] of integer;
  PErmXVars = ^TErmXVars;
  TErmXVars = array [1..16] of integer;
  PErmFlags = ^TErmFlags;
  TErmFlags = array [1..1000] of boolean;
  PErmEVars = ^TErmEVars;
  TErmEVars = array [1..100] of single;
  PErmNEVars = ^TErmNEVars;
  TErmNEVars = array [1..100] of single;
  PErmQuickVars = ^TErmQuickVars;
  TErmQuickVars = array [0..14] of integer;

  TZvsLoadErmScript = function (ScriptId: integer): integer; cdecl;
  TZvsLoadErmTxt    = function (IsNewLoad: integer): integer; cdecl;
  TZvsLoadErtFile   = function (Dummy, FileName: pchar): integer; cdecl;
  TZvsShowMessage   = function (Mes: pchar; MesType: integer; DummyZero: integer): integer; cdecl;
  TZvsCheckFlags    = function (Flags: PErmCmdConditions): longbool; cdecl;
  TFireErmEvent     = function (EventId: integer): integer; cdecl;
  TZvsDumpErmVars   = procedure (Error, {n} ErmCmdPtr: pchar); cdecl;
  
  POnBeforeTriggerArgs  = ^TOnBeforeTriggerArgs;
  TOnBeforeTriggerArgs  = packed record
    TriggerId:          integer;
    BlockErmExecution:  longbool;
  end; // .record TOnBeforeTriggerArgs
  
  TYVars = class
    Value: Utils.TArrayOfInt;
  end; // .class TYVars

  TWoGOptions = array [CURRENT_WOG_OPTIONS..GLOBAL_WOG_OPTIONS, 0..NUM_WOG_OPTIONS - 1] of integer;

  THeroSpecRecord = packed record
    Setup:       array [0..6] of integer;

    case boolean of
      false: (
        ShortName:   pchar;
        FullName:    pchar;
        Description: pchar;
      );
    
      true: (Descr: array [0..2] of pchar;);
  end; // .record THeroSpecRecord

  PHeroSpecsTable = ^THeroSpecsTable;
  THeroSpecsTable = array [0..NUM_WOG_HEROES - 1] of THeroSpecRecord;

  THeroSpecSettings = packed record
    PicNum:    integer;
    ZVarDescr: array [0..2] of integer;
  end; // .record THeroSpecSettings

  PHeroSpecSettingsTable = ^THeroSpecSettingsTable;
  THeroSpecSettingsTable = array [0..NUM_WOG_HEROES - 1] of THeroSpecSettings;

  PSecSkillSettings = ^TSecSkillSettings;
  TSecSkillSettings = packed record
    case byte of
      0: (
        _0:       integer; // use Name instead
        Basic:    integer; // z-index, description
        Advanced: integer;
        Expert:   integer;
      );

      1: (
        Name:  integer;
        Descs: array [0..SKILL_LEVEL_EXPERT - 1] of integer;
      );

      2: (
        Texts: array [0..SKILL_LEVEL_EXPERT] of integer;
      );
  end; // .record TSecSkillSettings

  PSecSkillSettingsTable = ^TSecSkillSettingsTable;
  TSecSkillSettingsTable = array [0..Heroes.MAX_SECONDARY_SKILLS - 1] of TSecSkillSettings;

  TFireRemoteEventProc = procedure (EventId: integer; Data: pinteger; NumInts: integer); cdecl;
  TZvsPlaceMapObject   = function (x, y, Level, ObjType, ObjSubtype, ObjType2, ObjSubtype2, Terrain: integer): integer; cdecl;

const
  (* WoG vars *)
  QuickVars: PErmQuickVars = Ptr($27718D0);
  v:  PErmVVars = Ptr($887668);
  w:  PWVars    = Ptr($A4AB10);
  z:  PErmZVars = Ptr($9273E8);
  y:  PErmYVars = Ptr($A48D80);
  x:  PErmXVars = Ptr($91DA38);
  f:  PErmFlags = Ptr($91F2E0);
  e:  PErmEVars = Ptr($A48F18);
  nz: PErmNZVars = Ptr($A46D28);
  ny: PErmNYVars = Ptr($A46A30);
  ne: PErmNEVars = Ptr($27F93B8);

  ZvsIsGameLoading:   PBOOLEAN          = Ptr($A46BC0);
  ZvsTriggerIfs:      PZvsTriggerIfs    = Ptr($A46D18);
  ZvsTriggerIfsDepth: pbyte             = Ptr($A46D22);
  IsWoG:              plongbool         = Ptr($803288);
  WoGOptions:         ^TWoGOptions      = Ptr($2771920);
  ErmEnabled:         plongbool         = Ptr($27F995C);
  ErmErrCmdPtr:       ppchar            = Ptr($840E0C);
  ErmDlgCmd:          pinteger          = Ptr($887658);
  MrMonPtr:           PPOINTER          = Ptr($2846884); // MB_Mon
  HeroSpecsTable:     PHeroSpecsTable   = Ptr($7B4C40);
  HeroSpecsTableBack: PHeroSpecsTable   = Ptr($91DA78);
  HeroSpecSettingsTable: PHeroSpecSettingsTable = Ptr($A49BC0);
  SecSkillSettingsTable: PSecSkillSettingsTable = Ptr($899410);
  SecSkillNamesBack:     Heroes.PSecSkillNames  = Ptr($A89190);
  SecSkillDescsBack:     Heroes.PSecSkillDescs  = Ptr($A46BC4);
  SecSkillTextsBack:     Heroes.PSecSkillTexts  = Ptr($A490A8);

  (* WoG funcs *)
  ZvsFindErm:         Utils.TProcedure  = Ptr($749955);
  ZvsClearErtStrings: Utils.TProcedure  = Ptr($7764F2);
  ZvsClearErmScripts: Utils.TProcedure  = Ptr($750191);
  ZvsLoadErmScript:   TZvsLoadErmScript = Ptr($72C297);
  ZvsLoadErmTxt:      TZvsLoadErmTxt    = Ptr($72C8B1);
  ZvsLoadErtFile:     TZvsLoadErtFile   = Ptr($72C641);
  ZvsShowMessage:     TZvsShowMessage   = Ptr($70FB63);
  ZvsCheckFlags:      TZvsCheckFlags    = Ptr($740DF1);
  FireErmEvent:       TFireErmEvent     = Ptr($74CE30);
  ZvsDumpErmVars:     TZvsDumpErmVars   = Ptr($72B8C0);
  ZvsResetCommanders: Utils.TProcedure  = Ptr($770B25);

  FireRemoteEventProc: TFireRemoteEventProc = Ptr($76863A);
  ZvsPlaceMapObject:   TZvsPlaceMapObject   = Ptr($71299E);


var
{O} ScriptMan:       TScriptMan;
    ErmTriggerDepth: integer = 0;

    FreezedWogOptionWogify: integer = WOGIFY_ALL;
  
  (* ERM tracking options *)
  TrackingOpts: record
    Enabled:              boolean;
    MaxRecords:           integer;
    DumpCommands:         boolean;
    IgnoreEmptyTriggers:  boolean;
    IgnoreRealTimeTimers: boolean;
  end;


procedure SetZVar (Str: pchar; const Value: string);
procedure ZvsProcessCmd (Cmd: PErmCmd);

procedure ShowErmError (const Error: string);
function  GetErmFuncByName (const FuncName: string): integer;
function  GetErmFuncName (FuncId: integer; out Name: string): boolean;
function  AllocErmFunc (const FuncName: string; {i} out FuncId: integer): boolean;
function  GetTriggerReadableName (EventId: integer): string;
procedure ExecErmCmd (const CmdStr: string);
procedure ReloadErm; stdcall;
procedure ExtractErm; stdcall;
function  AddrToScriptNameAndLine (CharPos: pchar; var ScriptName: string; var LineN: integer; var LinePos: integer): boolean;
procedure FireErmEventEx (EventId: integer; Params: array of integer);
function  FindErmCmdBeginning ({n} CmdPtr: pchar): {n} pchar;

(*  Up to 16 arguments  *)
procedure FireRemoteErmEvent (EventId: integer; Args: array of integer);


(***) implementation (***)
uses PatchApi, Stores, AdvErm, ErmTracking;


const
  ERM_CMD_CACHE_LIMIT = 30000;


var
{O} FuncNames:       DataLib.TDict {OF FuncId: integer};
{O} FuncIdToNameMap: DataLib.TObjDict {O} {OF TString};
    FuncAutoId:      integer;
{O} ScriptNames:     Lists.TStringList;
{O} ErmScanner:      TextScan.TTextScanner;
{O} ErmCmdCache:     {O} TAssocArray {OF PErmCmd};
{O} SavedYVars:      {O} Lists.TList {OF TYVars};
{O} EventTracker:    ErmTracking.TEventTracker;
    ErmErrReported:  boolean = false;


procedure ShowErmError (const Error: string);
begin
  ZvsErmError(nil, 0, pchar(Error));
end;
   
function GetErmValType (c: char; out ValType: TErmValType): boolean;
begin
  result  :=  true;
  
  case c of
    '+', '-': ValType :=  ValNum;
    '0'..'9': ValType :=  ValNum;
    'f'..'t': ValType :=  ValQuick;
    'v':      ValType :=  ValV;
    'w':      ValType :=  ValW;
    'x':      ValType :=  ValX;
    'y':      ValType :=  ValY;
    'z':      ValType :=  ValZ;
  else
    result := false;
    ShowMessage('Invalid ERM value type: "' + c + '"');
  end; // .switch
end; // .function GetErmValType

function GetErmFuncByName (const FuncName: string): integer;
begin
  result := integer(FuncNames[FuncName]);
end;

function GetErmFuncName (FuncId: integer; out Name: string): boolean;
var
{U} SearchRes: TString;

begin
  SearchRes := TString(FuncIdToNameMap[Ptr(FuncId)]);
  result    := SearchRes <> nil;

  if result then begin
    Name := SearchRes.Value;
  end;
end;

procedure NameTrigger (const TriggerId: integer; const FuncName: string);
begin
  FuncNames[FuncName]                           := Ptr(TriggerId);
  FuncIdToNameMap[Ptr(TriggerId)]               := TString.Create(FuncName);
  AdvErm.GetOrCreateAssocVar(FuncName).IntValue := TriggerId;
end;

function AllocErmFunc (const FuncName: string; {i} out FuncId: integer): boolean;
begin
  FuncId := integer(FuncNames[FuncName]);
  result := FuncId = 0;

  if result then begin
    FuncId                       := FuncAutoId;
    FuncNames[FuncName]          := Ptr(FuncId);
    FuncIdToNameMap[Ptr(FuncId)] := TString.Create(FuncName);
    AdvErm.GetOrCreateAssocVar(FuncName).IntValue := FuncId;
    inc(FuncAutoId);
  end;
end; // .function AllocErmFunc

function GetTriggerReadableName (EventID: integer): string;
var
  BaseEventName: string;
  
  x:             integer;
  y:             integer;
  z:             integer;
  
  ObjType:       integer;
  ObjSubtype:    integer;

begin
  result := '';

  case EventID of
    {*} Erm.TRIGGER_FU1..Erm.TRIGGER_FU30000:
      result := 'OnErmFunction ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_FU1 + 1); 
    {*} Erm.TRIGGER_TM1..Erm.TRIGGER_TM100:
      result := 'OnErmTimer ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_TM1 + 1); 
    {*} Erm.TRIGGER_HE0..Erm.TRIGGER_HE198:
      result := 'OnHeroInteraction ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HE0);
    {*} Erm.TRIGGER_BA0:      result :=  'OnBeforeBattle';
    {*} Erm.TRIGGER_BA1:      result :=  'OnAfterBattle';
    {*} Erm.TRIGGER_BR:       result :=  'OnBattleRound';
    {*} Erm.TRIGGER_BG0:      result :=  'OnBeforeBattleAction';
    {*} Erm.TRIGGER_BG1:      result :=  'OnAfterBattleAction';
    {*} Erm.TRIGGER_MW0:      result :=  'OnWanderingMonsterReach';
    {*} Erm.TRIGGER_MW1:      result :=  'OnWanderingMonsterDeath';
    {*} Erm.TRIGGER_MR0:      result :=  'OnMagicBasicResistance';
    {*} Erm.TRIGGER_MR1:      result :=  'OnMagicCorrectedResistance';
    {*} Erm.TRIGGER_MR2:      result :=  'OnDwarfMagicResistance';
    {*} Erm.TRIGGER_CM0:      result :=  'OnAdventureMapRightMouseClick';
    {*} Erm.TRIGGER_CM1:      result :=  'OnTownMouseClick';
    {*} Erm.TRIGGER_CM2:      result :=  'OnHeroScreenMouseClick';
    {*} Erm.TRIGGER_CM3:      result :=  'OnHeroesMeetScreenMouseClick';
    {*} Erm.TRIGGER_CM4:      result :=  'OnBattleScreenMouseClick';
    {*} Erm.TRIGGER_CM5:      result :=  'OnAdventureMapLeftMouseClick';
    {*} Erm.TRIGGER_AE0:      result :=  'OnEquipArt';
    {*} Erm.TRIGGER_AE1:      result :=  'OnUnequipArt';
    {*} Erm.TRIGGER_MM0:      result :=  'OnBattleMouseHint';
    {*} Erm.TRIGGER_MM1:      result :=  'OnTownMouseHint';
    {*} Erm.TRIGGER_MP:       result :=  'OnMp3MusicChange';
    {*} Erm.TRIGGER_SN:       result :=  'OnSoundPlay';
    {*} Erm.TRIGGER_MG0:      result :=  'OnBeforeAdventureMagic';
    {*} Erm.TRIGGER_MG1:      result :=  'OnAfterAdventureMagic';
    {*} Erm.TRIGGER_TH0:      result :=  'OnEnterTown';
    {*} Erm.TRIGGER_TH1:      result :=  'OnLeaveTown';
    {*} Erm.TRIGGER_IP0:      result :=  'OnBeforeBattleBeforeDataSend';
    {*} Erm.TRIGGER_IP1:      result :=  'OnBeforeBattleAfterDataReceived';
    {*} Erm.TRIGGER_IP2:      result :=  'OnAfterBattleBeforeDataSend';
    {*} Erm.TRIGGER_IP3:      result :=  'OnAfterBattleAfterDataReceived';
    {*} Erm.TRIGGER_CO0:      result :=  'OnOpenCommanderWindow';
    {*} Erm.TRIGGER_CO1:      result :=  'OnCloseCommanderWindow';
    {*} Erm.TRIGGER_CO2:      result :=  'OnAfterCommanderBuy';
    {*} Erm.TRIGGER_CO3:      result :=  'OnAfterCommanderResurrect';
    {*} Erm.TRIGGER_BA50:     result :=  'OnBeforeBattleForThisPcDefender';
    {*} Erm.TRIGGER_BA51:     result :=  'OnAfterBattleForThisPcDefender';
    {*} Erm.TRIGGER_BA52:     result :=  'OnBeforeBattleUniversal';
    {*} Erm.TRIGGER_BA53:     result :=  'OnAfterBattleUniversal';
    {*} Erm.TRIGGER_GM0:      result :=  'OnAfterLoadGame';
    {*} Erm.TRIGGER_GM1:      result :=  'OnBeforeSaveGame';
    {*} Erm.TRIGGER_PI:       result :=  'OnAfterErmInstructions';
    {*} Erm.TRIGGER_DL:       result :=  'OnCustomDialogEvent';
    {*} Erm.TRIGGER_HM:       result :=  'OnHeroMove';
    {*} Erm.TRIGGER_HM0..Erm.TRIGGER_HM198:
      result := 'OnHeroMove ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HM0);
    {*} Erm.TRIGGER_HL:   result :=  'OnHeroGainLevel';
    {*} Erm.TRIGGER_HL0..Erm.TRIGGER_HL198:
      result := 'OnHeroGainLevel ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HL0);
    {*} Erm.TRIGGER_BF:       result :=  'OnSetupBattlefield';
    {*} Erm.TRIGGER_MF1:      result :=  'OnMonsterPhysicalDamage';
    {*} Erm.TRIGGER_TL0:      result :=  'OnEverySecond';
    {*} Erm.TRIGGER_TL1:      result :=  'OnEvery2Seconds';
    {*} Erm.TRIGGER_TL2:      result :=  'OnEvery5Seconds';
    {*} Erm.TRIGGER_TL3:      result :=  'OnEvery10Seconds';
    {*} Erm.TRIGGER_TL4:      result :=  'OnEveryMinute';
    (* Era Triggers *)
    {*} Erm.TRIGGER_SAVEGAME_WRITE:            result := 'OnSavegameWrite';
    {*} Erm.TRIGGER_SAVEGAME_READ:             result := 'OnSavegameRead';
    {*} Erm.TRIGGER_KEYPRESS:                  result := 'OnKeyPressed';
    {*} Erm.TRIGGER_OPEN_HEROSCREEN:           result := 'OnOpenHeroScreen';
    {*} Erm.TRIGGER_CLOSE_HEROSCREEN:          result := 'OnCloseHeroScreen';
    {*} Erm.TRIGGER_STACK_OBTAINS_TURN:        result := 'OnBattleStackObtainsTurn';
    {*} Erm.TRIGGER_REGENERATE_PHASE:          result := 'OnBattleRegeneratePhase';
    {*} Erm.TRIGGER_AFTER_SAVE_GAME:           result := 'OnAfterSaveGame';
    {*} Erm.TRIGGER_BEFOREHEROINTERACT:        result := 'OnBeforeHeroInteraction';
    {*} Erm.TRIGGER_AFTERHEROINTERACT:         result := 'OnAfterHeroInteraction';
    {*} Erm.TRIGGER_ONSTACKTOSTACKDAMAGE:      result := 'OnStackToStackDamage';
    {*} Erm.TRIGGER_ONAICALCSTACKATTACKEFFECT: result := 'OnAICalcStackAttackEffect';
    {*} Erm.TRIGGER_ONCHAT:                    result := 'OnChat';
    {*} Erm.TRIGGER_ONGAMEENTER:               result := 'OnGameEnter';
    {*} Erm.TRIGGER_ONGAMELEAVE:               result := 'OnGameLeave';
    (* END Era Triggers *)
  else
    if EventID >= Erm.TRIGGER_OB_POS then begin
      if ((EventID and Erm.TRIGGER_OB_POS) or (EventID and Erm.TRIGGER_LE_POS)) <> 0 then begin
        x := EventID and 1023;
        y := (EventID shr 16) and 1023;
        z := (EventID shr 26) and 1;
        
        if (EventID and Erm.TRIGGER_LE_POS) <> 0 then begin
          BaseEventName := 'OnLocalEvent ';
        end else begin
          if (EventID and Erm.TRIGGER_OB_LEAVE) <> 0 then begin
            BaseEventName := 'OnAfterVisitObject ';
          end else begin
            BaseEventName := 'OnBeforeVisitObject ';
          end;
        end;
        
        result :=
          BaseEventName + SysUtils.IntToStr(x) + '/' +
          SysUtils.IntToStr(y) + '/' + SysUtils.IntToStr(z);
      end else begin
        ObjType    := (EventID shr 12) and 255;
        ObjSubtype := (EventID and 255) - 1;
        
        if (EventID and Erm.TRIGGER_OB_LEAVE) <> 0 then begin
          BaseEventName := 'OnAfterVisitObject ';
        end else begin
          BaseEventName := 'OnBeforeVisitObject ';
        end;
        
        result :=
          BaseEventName + SysUtils.IntToStr(ObjType) + '/' + SysUtils.IntToStr(ObjSubtype);
      end; // .else
    end else begin
      if GetErmFuncName(EventID, result) then begin
        // Ok
      end else begin
        result := 'OnErmFunction ' + SysUtils.IntToStr(EventID);
      end;
    end; // .else
  end; // .switch
end; // .function GetTriggerReadableName

procedure SetZVar (Str: pchar; const Value: string);
var
  StrBufSize: integer;

begin
  if (cardinal(Str) >= cardinal(@z[1])) and (cardinal(Str) <= cardinal(@z[high(z^)])) then begin
    StrBufSize := integer(@z[high(z^)]) - integer(Str) + sizeof(z[1]);
  end else begin
    StrBufSize := sizeof(z[1]);
  end;

  Utils.SetPcharValue(Str, Value, StrBufSize);
end;

procedure ZvsProcessCmd (Cmd: PErmCmd); ASSEMBLER;
asm
  // Push parameters
  MOV EAX, Cmd
  PUSH 0
  PUSH 0
  PUSH EAX
  // Push return address
  LEA EAX, @@Ret
  PUSH EAX
  // Execute initial function code
  PUSH EBP
  MOV EBP, ESP
  SUB ESP, $544
  PUSH EBX
  PUSH ESI
  PUSH EDI
  MOV EAX, [EBP + $8]
  MOV CX, [EAX]
  MOV [EBP - $314], CX
  MOV EDX, [EBP + $8]
  MOV EAX, [EDX + $294]
  MOV [EBP - $2FC], EAX
  // Give control to code after logging area
  PUSH $741E3F
  RET
  @@Ret:
  ADD ESP, $0C
end; // .procedure ZvsProcessCmd

procedure ClearErmCmdCache;
begin
  with DataLib.IterateDict(ErmCmdCache) do begin
    while IterNext do begin
      FreeMem(PErmCmd(IterValue).CmdHeader.Value);
      Dispose(PErmCmd(IterValue));
    end;
  end; 

  ErmCmdCache.Clear;
end; // .procedure ClearErmCmdCache

procedure ExecSingleErmCmd (const CmdStr: string);
const
  LETTERS = ['A'..'Z'];
  DIGITS  = ['0'..'9'];
  SIGNS   = ['+', '-'];
  NUMBER  = DIGITS + SIGNS;
  DELIMS  = ['/', ':'];

var
{U} Cmd:      PErmCmd;
    CmdName:  string;
    NumArgs:  integer;
    Res:      boolean;
    c:        char;
    
  function ReadNum (out Num: integer): boolean;
  var
    StartPos: integer;
    Token:    string;
    c:        char;

  begin
    result := ErmScanner.GetCurrChar(c) and (c in NUMBER);

    if result then begin
      if c in SIGNS then begin
        StartPos := ErmScanner.Pos;
        ErmScanner.GotoNextChar;
        ErmScanner.SkipCharset(DIGITS);
        Token := ErmScanner.GetSubstrAtPos(StartPos, ErmScanner.Pos - StartPos);
      end else begin
        ErmScanner.ReadToken(DIGITS, Token);
      end;
      
      result := SysUtils.TryStrToInt(Token, Num) and ErmScanner.GetCurrChar(c) and (c in DELIMS);
    end; // .if
  end; // .function ReadNum

  function ReadArg (out Arg: TErmCmdParam): boolean;
  var
    ValType: TErmValType;
    IndType: TErmValType;
  
  begin
    result := ErmScanner.GetCurrChar(c) and GetErmValType(c, ValType);
    
    if result then begin
      IndType := ValNum;
      
      if ValType <> ValNum then begin
        result := ErmScanner.GotoNextChar and ErmScanner.GetCurrChar(c) and
                  GetErmValType(c, IndType);

        if result and (IndType <> ValNum) then begin
          ErmScanner.GotoNextChar;
        end;
      end;
      
      if result then begin
        result := ReadNum(Arg.Value);
        
        if result then begin
          Arg.ValType := ORD(IndType) shl 4 + ORD(ValType);
        end;
      end;
    end; // .if
  end; // .function ReadArg
  
begin
  Cmd := ErmCmdCache[CmdStr];
  // * * * * * //
  Res := true;
  
  if Cmd = nil then begin
    New(Cmd);
    FillChar(Cmd^, sizeof(Cmd^), 0);
    ErmScanner.Connect(CmdStr, LINE_END_MARKER);
    Res     := ErmScanner.ReadToken(LETTERS, CmdName) and (Length(CmdName) = 2);
    NumArgs := 0;
    
    while Res and ErmScanner.GetCurrChar(c) and (c <> ':') and (NumArgs < ERM_CMD_MAX_PARAMS_NUM) do begin
      Res := ReadArg(Cmd.Params[NumArgs]) and ErmScanner.GetCurrChar(c);

      if Res then begin
        Inc(NumArgs);

        if c = '/' then begin
          ErmScanner.GotoNextChar;
        end;
      end;
    end; // .while

    Res := Res and ErmScanner.GotoNextChar;

    if Res then begin
      // Allocate memory, because ERM engine changes command contents during execution
      GetMem(Cmd.CmdHeader.Value, Length(CmdStr) + 1);
      Utils.CopyMem(Length(CmdStr) + 1, pointer(CmdStr), Cmd.CmdHeader.Value);
      
      Cmd.CmdBody.Value := Utils.PtrOfs(Cmd.CmdHeader.Value, ErmScanner.Pos - 1);
      Cmd.CmdId.Name[0] := CmdName[1];
      Cmd.CmdId.Name[1] := CmdName[2];
      Cmd.NumParams     := NumArgs;
      Cmd.CmdHeader.Len := ErmScanner.Pos - 1;
      Cmd.CmdBody.Len   := Length(CmdStr) - ErmScanner.Pos + 1;
      
      if ErmCmdCache.ItemCount = ERM_CMD_CACHE_LIMIT then begin
        ClearErmCmdCache;
      end;
      
      ErmCmdCache[CmdStr] := Cmd;
    end; // .if
  end; // .if
  
  if not Res then begin
    ShowMessage('ExecErmCmd: Invalid command "' + CmdStr + '"');
  end else begin
    ZvsProcessCmd(Cmd);
  end;
end; // .procedure ExecSingleErmCmd

procedure ExecErmCmd (const CmdStr: string);
var
  Commands: Utils.TArrayOfStr;
  Command:  string;
  i:        integer;
   
begin
  Commands := StrLib.ExplodeEx(CmdStr, ';', StrLib.INCLUDE_DELIM, not StrLib.LIMIT_TOKENS, 0);

  for i := 0 to High(Commands) do begin
    Command := SysUtils.Trim(Commands[i]);

    if Command <> '' then begin
      if (i = High(Commands)) and (Command[Length(Command)] <> ';') then begin
        Command := Command + ';';
      end;

      ExecSingleErmCmd(Command);
    end;
  end; // .for
end; // .procedure ExecErmCmd

procedure OnEraSaveScripts (Event: GameExt.PEvent); stdcall;
begin
  (* Save function names and auto ID *)
  with Stores.NewRider(FUNC_NAMES_SECTION) do begin
    WriteInt(FuncAutoId);
    WriteStr(DataLib.SerializeDict(FuncNames));
  end;
  
  ScriptMan.SaveScripts;
end;

procedure OnEraLoadScripts (Event: GameExt.PEvent); stdcall;
begin
  (* Read function names and auto ID *)
  with Stores.NewRider(FUNC_NAMES_SECTION) do begin
    FuncAutoId := ReadInt;
    FuncNames  := DataLib.UnserializeDict(ReadStr, not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  end;
  
  FreeAndNil(FuncIdToNameMap);
  FuncIdToNameMap := DataLib.FlipDict(FuncNames);

  (* Load scripts *)
  ScriptMan.LoadScriptsFromSavedGame;
end;

function Hook_LoadErtFile (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  ARG_FILENAME = 2;

var
  FileName: pchar;
  
begin
  FileName := pchar(pinteger(Context.EBP + 12)^);
  Utils.CopyMem(SysUtils.StrLen(FileName) + 1, FileName, Ptr(Context.EBP - $410));
  
  Context.RetAddr := Ptr($72C760);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_LoadErtFile

procedure LoadErtFile (const ErmScriptName: string);
var
  ErtFilePath: string;
   
begin
  ErtFilePath := ERM_SCRIPTS_PATH + '\' + SysUtils.ChangeFileExt(ErmScriptName, '.ert');
    
  if SysUtils.FileExists(ErtFilePath) then begin
    ZvsLoadErtFile('', pchar('..\' + ErtFilePath));
  end;
end;

function AddrToLineAndPos (Document: pchar; DocSize: integer; CharPos: pchar; var LineN: integer; var LinePos: integer): boolean;
var
{Un} CharPtr: pchar;

begin
  CharPtr := nil;
  // * * * * * //
  result := (cardinal(CharPos) >= cardinal(Document)) and (cardinal(CharPos) < cardinal(Document) + cardinal(DocSize));
  
  if result then begin
    LineN   := 1;
    LinePos := 1;
    CharPtr := Document;

    while CharPtr <> CharPos do begin
      if CharPtr^ = #10 then begin
        inc(LineN);
        LinePos := 1;
      end else begin
        inc(LinePos);
      end;
      
      inc(CharPtr);
    end;
  end; // .if
end; // .function AddrToLineAndPos

function PreprocessErm (const ScriptName, Script: string): string;
const
  ANY_CHAR            = [#0..#255];
  FUNCNAME_CHARS      = ANY_CHAR - [')', #10, #13];
  LABEL_CHARS         = ANY_CHAR - [']', #10, #13];
  SPECIAL_CHARS       = ['[', '!'];
  INCMD_SPECIAL_CHARS = ['[', '(', '^', ';'];

  NO_LABEL = -1;

type
  TScope = (GLOBAL_SCOPE, CMD_SCOPE);

var
{
  For unresolved labels value for key is index of previous unresolved label in Buf.
  Zero indexes are ignored.
}
{O} Buf:                TStrList {of integer};
{O} Scanner:            TextScan.TTextScanner;
{O} Labels:             TDict {of CmdN + 1};
    UnresolvedLabelInd: integer; // index of last unresolved label or NO_LABEL
    CmdN:               integer; // index of next command
    MarkedPos:          integer;
    c:                  char;

  procedure ShowError (ErrPos: integer; const Error: string);
  var
    LineN:   integer;
    LinePos: integer;

  begin
    if not Scanner.PosToLine(ErrPos, LineN, LinePos) then begin
      LineN   := -1;
      LinePos := -1;
    end;
    
    ShowMessage(Format('{~gold}Error in "%s".'#10'Line: %d. Position: %d.{~}'#10 +
                       '%s.'#10#10'Context:'#10#10'%s',
                       [ScriptName, LineN, LinePos, Error,
                        Scanner.GetSubstrAtPos(ErrPos - 20, 20) + ' <<< ' +
                        Scanner.GetSubstrAtPos(ErrPos + 0,  100)]));
  end; // .procedure ShowError

  procedure MarkPos;
  begin
    MarkedPos := Scanner.Pos;
  end;

  procedure FlushMarked;
  begin
    if Scanner.Pos > MarkedPos then begin
      Buf.Add(Scanner.GetSubstrAtPos(MarkedPos, Scanner.Pos - MarkedPos));
      MarkedPos := Scanner.Pos;
    end;
  end;

  procedure ParseFuncName;
  var
    FuncId:   integer;
    FuncName: string;
    c:        char;

  begin
    FlushMarked;
    Scanner.GotoNextChar;

    if Scanner.ReadToken(FUNCNAME_CHARS, FuncName) and Scanner.GetCurrChar(c) then begin
      if c = ')' then begin
        Scanner.GotoNextChar;
        AllocErmFunc(FuncName, FuncId);
        Buf.Add(IntToStr(FuncId));
      end else begin
        ShowError(Scanner.Pos, 'Unexpected line end in function name');
        Buf.Add('999999');
      end;
    end else begin
      ShowError(Scanner.Pos, 'Missing closing ")"');
      Buf.Add('999999');
    end; // .else

    MarkPos;
  end; // .procedure ParseFuncName

  procedure DeclareLabel (const LabelName: string);
  begin
    if Labels[LabelName] = nil then begin
      Labels[LabelName] := Ptr(CmdN + 1);
    end else begin
      ShowError(Scanner.Pos, 'Duplicate label "' + LabelName + '"');
    end;
  end;

  procedure ParseLabel (Scope: TScope);
  var
    IsDeclaration: boolean;
    LabelName:     string;
    LabelValue:    integer;
    c:             char;

  begin
    FlushMarked;
    Scanner.GotoNextChar;

    IsDeclaration := Scanner.GetCurrChar(c) and (c = ':');

    if IsDeclaration then begin
      Scanner.GotoNextChar;
    end;
    
    if Scanner.ReadToken(LABEL_CHARS, LabelName) and Scanner.GetCurrChar(c) then begin
      if c = ']' then begin
        Scanner.GotoNextChar;

        if IsDeclaration then begin
          if Scope = GLOBAL_SCOPE then begin
            DeclareLabel(LabelName);
          end else begin
            ShowError(Scanner.Pos, 'Label declaration inside command is prohibited');
          end;
        end else begin
          if Scope = CMD_SCOPE then begin
            LabelValue := integer(Labels[LabelName]);

            if LabelValue = 0 then begin
              UnresolvedLabelInd := Buf.AddObj(LabelName, Ptr(UnresolvedLabelInd));
            end else begin
              Buf.Add(IntToStr(LabelValue - 1));
            end;
          end else begin
            FlushMarked;
          end; // .else
        end; // .else
      end else begin
        ShowError(Scanner.Pos, 'Unexpected line end in label name');

        if not IsDeclaration then begin
          Buf.Add('999999');
        end;
      end; // .else
    end else begin
      ShowError(Scanner.Pos, 'Missing closing "]"');

      if not IsDeclaration then begin
        Buf.Add('999999');
      end;
    end; // .else

    MarkPos;
  end; // .procedure ParseLabel

  procedure ResolveLabels;
  var
    LabelName:  string;
    LabelValue: integer;
    i:          integer;

  begin
    i := UnresolvedLabelInd;

    while i <> NO_LABEL do begin
      LabelName  := Buf[i];
      LabelValue := integer(Labels[LabelName]);

      if LabelValue = 0 then begin
        ShowError(Scanner.Pos, 'Unresolved label "' + LabelName + '"');
        Buf[i] := '999999';
      end else begin
        Buf[i] := IntToStr(LabelValue - 1);
      end;

      i := integer(Buf.Values[i]);
    end; // .while

    UnresolvedLabelInd := NO_LABEL;
  end; // .procedure ResolveLabels

  procedure ParseCmd;
  var
    c: char;

  begin
    Scanner.GotoNextChar;
    c := ' ';

    while Scanner.FindCharset(INCMD_SPECIAL_CHARS) and Scanner.GetCurrChar(c) and (c <> ';') do begin
      case c of
        '[': begin
          if Scanner.GetCharAtRelPos(+1, c) and (c <> ':') then begin
            ParseLabel(CMD_SCOPE);
          end else begin
            Scanner.GotoNextChar;
          end;
        end; // .case '['

        '(': begin
          ParseFuncName;
        end; // .case '('

        '^': begin
          Scanner.GotoNextChar;
          Scanner.FindChar('^');
          Scanner.GotoNextChar;
        end; // .case '^'
      end; // .switch c
    end; // .while

    if c = ';' then begin
      Scanner.GotoNextChar;
      Inc(CmdN);
    end;
  end; // .procedure ParseCmd

begin
  Buf        := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  Scanner    := TextScan.TTextScanner.Create;
  Labels     := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  // * * * * * //
  Scanner.Connect(Script, #10);
  MarkedPos          := 1;
  CmdN               := 999000; // CmdN must not be used in instructions
  UnresolvedLabelInd := NO_LABEL;
  
  while Scanner.FindCharset(SPECIAL_CHARS) do begin
    Scanner.GetCurrChar(c);

    case c of
      '!': begin
        Scanner.GotoNextChar;

        if Scanner.GetCurrChar(c) then begin
          case c of
            '!': begin
              if Scanner.GetCharAtRelPos(+1, c) and (c = '!') then begin
                FlushMarked;
                Scanner.SkipChars('!');
                MarkPos;
              end else begin
                ParseCmd;
              end;
            end; // .case '!'

            '?': begin
              ResolveLabels;
              Labels.Clear;
              CmdN := -1;
              ParseCmd;
            end; // .case '?'

            '#': begin
              ParseCmd;
            end; // .case '!'
          end; // .switch c
        end; // .if
      end; // .case '!'

      '[': begin
        if Scanner.GetCharAtRelPos(+1, c) and (c = ':') then begin
          ParseLabel(GLOBAL_SCOPE);
        end else begin
          Scanner.GotoNextChar;
        end;
      end; // .case '['
    end; // .switch c
  end; // .while

  if MarkedPos = 1 then begin
    result := Script;
  end else begin
    FlushMarked;
    ResolveLabels;
    result := Buf.ToText('');
  end;
  // * * * * * //
  SysUtils.FreeAndNil(Buf);
  SysUtils.FreeAndNil(Scanner);
  SysUtils.FreeAndNil(Labels);
end; // .function PreprocessErm

(* Returns list of files in specified locations, sorted by numeric priorities like '906 file name.erm'.
   The higher priority is, the ealier in the list item will appear. If same files exists ib several
   locations, files from the earlier locations take precedence *)
function GetOrderedPrioritizedFileList (const MaskedPaths: array of string): {O} Lists.TStringList;
const
  PRIORITY_SEPARATOR  = ' ';
  DEFAULT_PRIORITY    = 0;

  FILENAME_NUM_TOKENS = 2;
  PRIORITY_TOKEN      = 0;
  FILENAME_TOKEN      = 1;

var
  FileNameTokens: Utils.TArrayOfStr;
  Priority:       integer;
  TestPriority:   integer;
  ItemInd:        integer;
  i:              integer;
  j:              integer;

begin
  result        := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  result.Sorted := true;
  
  for i := 0 to High(MaskedPaths) do begin
    with Files.Locate(MaskedPaths[i], Files.ONLY_FILES) do begin
      while FindNext do begin
        FileNameTokens := StrLib.ExplodeEx(FoundName, PRIORITY_SEPARATOR, not StrLib.INCLUDE_DELIM, StrLib.LIMIT_TOKENS, FILENAME_NUM_TOKENS);
        Priority       := DEFAULT_PRIORITY;
        
        if (Length(FileNameTokens) = FILENAME_NUM_TOKENS) and (SysUtils.TryStrToInt(FileNameTokens[PRIORITY_TOKEN], TestPriority)) then begin
          Priority := TestPriority;
        end;

        if not result.Find(FoundName, ItemInd) then begin
          result.AddObj(FoundName, Ptr(Priority));
        end;
      end;
    end; // .with
  end; // .for

  result.Sorted := false;
  
  (* Sort via insertion by Priority *)
  for i := 1 to result.Count - 1 do begin
    Priority := integer(result.Values[i]);
    j        := i - 1;

    while (j >= 0) and (Priority > integer(result.Values[j])) do begin
      Dec(j);
    end;

    result.Move(i, j + 1);
  end;
end; // .function GetOrderedPrioritizedFileList

constructor TScriptMan.Create;
begin
  inherited;
  fScripts := RscLists.TResourceList.Create;
end;
  
destructor TScriptMan.Destroy;
begin
  SysUtils.FreeAndNil(fScripts);
  inherited;
end;

procedure TScriptMan.ClearScripts;
begin
  EventMan.GetInstance.Fire('OnBeforeClearErmScripts');
  fScripts.Clear;

  if TrackingOpts.Enabled then begin
    EventTracker.Reset;
  end;
end;

procedure TScriptMan.SaveScripts;
begin
  Self.fScripts.Save(ERM_SCRIPTS_SECTION);
end;

function TScriptMan.LoadScript (const ScriptPath: string; ScriptName: string = ''): boolean;
var
  ScriptContents:     string;
  PreprocessedScript: string;

begin
  if ScriptName = '' then begin
    ScriptName := SysUtils.ExtractFilePath(ScriptPath);
  end;
  
  result := not Self.fScripts.ItemExists(ScriptName) and Files.ReadFileContents(ScriptPath, ScriptContents);

  if result then begin
    PreprocessedScript := PreprocessErm(ScriptName, ScriptContents);
    fScripts.Add(TResource.Create(ScriptName, PreprocessedScript, Crypto.AnsiCrc32(ScriptContents)));
    LoadErtFile(ScriptName);
  end;
end;

procedure TScriptMan.LoadScriptsFromSavedGame;
var
{O} LoadedScripts: RscLists.TResourceList;
  
begin
  LoadedScripts := RscLists.TResourceList.Create;
  // * * * * * //
  LoadedScripts.LoadFromSavedGame(ERM_SCRIPTS_SECTION);

  if not LoadedScripts.FastCompare(Self.fScripts) then begin
    Utils.Exchange(int(LoadedScripts), int(Self.fScripts));
    ZvsFindErm;
  end;
  // * * * * * //
  SysUtils.FreeAndNil(LoadedScripts);
end;

procedure TScriptMan.LoadScriptsFromDisk;
const
  SCRIPTS_LIST_FILEPATH = ERM_SCRIPTS_PATH + '\load only these scripts.txt';
  
var
{O} ScriptList:    TStrList;
    ScriptsDir:    string;
    MapDirName:    string;
    ForcedScripts: Utils.TArrayOfStr;
    FileContents:  string;
    i:             integer;
   
begin
  ForcedScripts := nil;
  ScriptList    := nil;
  // * * * * * //
  Self.ClearScripts;
  ZvsClearErtStrings;

  if GameExt.LoadMapRscFile(SCRIPTS_LIST_FILEPATH, FileContents) then begin
    ForcedScripts := StrLib.Explode(SysUtils.Trim(FileContents), #13#10);

    for i := 0 to High(ForcedScripts) do begin
      Self.LoadScript(GameDir + '\' + ERM_SCRIPTS_PATH + '\' + ForcedScripts[i]);
    end;
  end else begin
    ScriptsDir := GameExt.GetMapResourcePath(ERM_SCRIPTS_PATH);
    ScriptList := GetOrderedPrioritizedFileList([ScriptsDir + '\*.erm']);
    MapDirName := GameExt.GetMapDirName;

    for i := 0 to ScriptList.Count - 1 do begin
      Self.LoadScript(ScriptsDir + '\' + ScriptList[i], MapDirName + '\' + ScriptList[i]);
    end;

    SysUtils.FreeAndNil(ScriptList);
    ScriptsDir := GameDir + '\' + ERM_SCRIPTS_PATH;
    ScriptList := GetOrderedPrioritizedFileList([ScriptsDir + '\*.erm']);

    for i := 0 to ScriptList.Count - 1 do begin
      Self.LoadScript(ScriptsDir + '\' + ScriptList[i], ScriptList[i]);
    end;
  end; // .else
  // * * * * * //
  SysUtils.FreeAndNil(ScriptList);
end; // .procedure TScriptMan.LoadScriptsFromDisk

procedure TScriptMan.ReloadScriptsFromDisk;
begin
  if ErmTriggerDepth = 0 then begin
    EventMan.GetInstance.Fire('OnBeforeScriptsReload');
    Self.LoadScriptsFromDisk;
    ZvsIsGameLoading^ := true;
    ZvsFindErm;
    EventMan.GetInstance.Fire('OnAfterScriptsReload');
    Heroes.PrintChatMsg('{~white}ERM and language data were reloaded{~}');
  end;
end;

procedure TScriptMan.ExtractScripts;
var
  Error: string;
  
begin
  Files.DeleteDir(GameExt.GameDir + '\' + EXTRACTED_SCRIPTS_PATH);
  Error := '';

  if not Files.ForcePath(GameExt.GameDir + '\' + EXTRACTED_SCRIPTS_PATH) then begin
    Error := 'Cannot recreate directory "' + EXTRACTED_SCRIPTS_PATH + '"';
  end;
  
  if Error = '' then begin
    Error := Self.fScripts.Export(GameExt.GameDir + '\' + EXTRACTED_SCRIPTS_PATH);
  end;
  
  if Error <> '' then begin
    Heroes.PrintChatMsg(Error);
  end;
end; // .procedure TScriptMan.ExtractScripts

function TScriptMan.AddrToScriptNameAndLine ({n} Addr: pchar; var {out} ScriptName: string; out LineN: integer; out LinePos: integer): boolean;
var
{Un} Script: TResource;
     i:      integer;


begin
  Script := nil;
  // * * * * * //
  result := (Addr <> nil) and (fScripts.Count > 0);
  
  if result then begin  
    result := false;
    
    for i := 0 to Self.fScripts.Count - 1 do begin
      Script := TResource(Self.fScripts[i]);

      if Script.OwnsAddr(Addr) then begin
        ScriptName := Script.Name;
        result     := AddrToLineAndPos(Script.GetPtr, Length(Script.Contents), Addr, LineN, LinePos);
        exit;
      end;
    end;
  end; // .if
end; // .function TScriptMan.AddrToScriptNameAndLine

procedure ReloadErm;
begin
  ScriptMan.ReloadScriptsFromDisk;
end;

procedure ExtractErm;
begin
  ScriptMan.ExtractScripts;
end;

function AddrToScriptNameAndLine (CharPos: pchar; var ScriptName: string; var LineN: integer; var LinePos: integer): boolean;
begin
  result := ScriptMan.AddrToScriptNameAndLine(CharPos, ScriptName, LineN, LinePos);
end;

function FindErmCmdBeginning ({n} CmdPtr: pchar): {n} pchar;
begin
  result := CmdPtr;
  
  if (result <> nil) and (result^ <> '!') then begin
    Dec(result);
    
    while result^ <> '!' do begin
      Dec(result);
    end;
    
    Inc(result);
    
    if result^ <> '!' then begin
      // [!]#
      Dec(result);
    end else begin
      // ![!]
      Dec(result, 2);
    end;
  end; // .if
end; // .function FindErmCmdBeginning

function GrabErmCmd ({n} CmdPtr: pchar): string;
var
  StartPos: pchar;
  EndPos:   pchar;

begin
  if CmdPtr <> nil then begin
    StartPos := FindErmCmdBeginning(CmdPtr);
    EndPos   := CmdPtr;
    
    repeat
      Inc(EndPos);
    until (EndPos^ = ';') or (EndPos^ = #0);
    
    if EndPos^ = ';' then begin
      Inc(EndPos);
    end;
    
    result := StrLib.ExtractFromPchar(StartPos, EndPos - StartPos);
  end; // .if
end; // .function GrabErmCmd

function GrabErmCmdContext ({n} CmdPtr: pchar): string;
const
  NEW_LINE_COST        = 40;
  MIN_CHARS_TO_ACCOUNT = 50;
  MAX_CONTEXT_COST     = NEW_LINE_COST * 5;

var
  StartPos: pchar;
  EndPos:   pchar;
  Cost:     integer;
  CurrCost: integer;


begin
  result := '';

  if CmdPtr <> nil then begin
    Cost     := 0;
    CurrCost := 0;
    StartPos := FindErmCmdBeginning(CmdPtr);
    EndPos   := CmdPtr;
    
    repeat
      Inc(EndPos);

      if EndPos^ = #10 then begin
        Inc(Cost, NEW_LINE_COST);
        CurrCost := 0;
      end else begin
        Inc(CurrCost);

        if CurrCost >= MIN_CHARS_TO_ACCOUNT then begin
          Inc(Cost, CurrCost);
          CurrCost := 0;
        end;
      end;
    until (EndPos^ = #0) or (Cost >= MAX_CONTEXT_COST);
    
    result := StrLib.ExtractFromPchar(StartPos, EndPos - StartPos);
  end; // .if
end; // .function GrabErmCmdContext

procedure ReportErmError (Error: string; {n} ErrCmd: pchar);
const
  CONTEXT_LEN = 00;

var
  PositionLocated: boolean;
  ScriptName:      string;
  Line:            integer;
  LinePos:         integer;
  Question:        string;
  
begin
  ErmErrReported  := true;
  PositionLocated := AddrToScriptNameAndLine(ErrCmd, ScriptName, Line, LinePos);
  
  if Error = '' then begin
    Error := 'Unknown error';
  end;

  Question := '{~FF3333}' + Error + '{~}';

  if PositionLocated then begin
    Question := Format('%s'#10'Location: %s:%d:%d', [Question, ScriptName, Line, LinePos]);
  end;
  
  Question := Question + #10#10'{~g}' + GrabErmCmdContext(ErrCmd) + '{~}' + #10#10'Continue without saving ERM memory dump?';
  
  if not Ask(Question) then begin
    ZvsDumpErmVars(pchar(Error), ErrCmd);
  end;
end; // .procedure ReportErmError

function Hook_MError (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  ReportErmError(ppchar(Context.EBP + 16)^, ErmErrCmdPtr^);
  Context.RetAddr := Ptr($712483);
  result          := not Core.EXEC_DEF_CODE;
end;

procedure Hook_ErmMess (OrigFunc: pointer; SubCmd: PErmSubCmd); stdcall;
var
  Code: pchar;
  i:    integer;

begin
  Code := SubCmd.Code.Value;
  // * * * * * //
  if not ErmErrReported then begin
    ReportErmError('', Code);
  end; // .if

  i := SubCmd.Pos;

  while not (Code[i] in [#0, ';']) do begin
    Inc(i);
  end;

  SubCmd.Pos     := i;
  ErmErrReported := false;
end; // .function Hook_ErmMess

function Hook_FindErm_SkipUntil2 (SubCmd: PErmSubCmd): integer; cdecl;
var
  CurrChar: pchar;

begin
  CurrChar := @SubCmd.Code.Value[SubCmd.Pos];

  while (CurrChar^ <> #0) and not ((CurrChar^ = '!') and (CurrChar[1] in ['!', '#', '?', '$', '@'])) do begin
    Inc(CurrChar);
  end;

  if CurrChar^ <> #0 then begin
    ErmErrCmdPtr^ := CurrChar;
    SubCmd.Pos    := integer(CurrChar) - integer(SubCmd.Code.Value) + 1;
    result        := 0;
  end else begin
    result := -1;
  end;
end; // .function Hook_FindErm_SkipUntil2

procedure RegisterErmEventNames;
begin
  NameTrigger(Erm.TRIGGER_BA0,  'OnBeforeBattle');
  NameTrigger(Erm.TRIGGER_BA1,  'OnAfterBattle');
  NameTrigger(Erm.TRIGGER_BR,   'OnBattleRound');
  NameTrigger(Erm.TRIGGER_BG0,  'OnBeforeBattleAction');
  NameTrigger(Erm.TRIGGER_BG1,  'OnAfterBattleAction');
  NameTrigger(Erm.TRIGGER_MW0,  'OnWanderingMonsterReach');
  NameTrigger(Erm.TRIGGER_MW1,  'OnWanderingMonsterDeath');
  NameTrigger(Erm.TRIGGER_MR0,  'OnMagicBasicResistance');
  NameTrigger(Erm.TRIGGER_MR1,  'OnMagicCorrectedResistance');
  NameTrigger(Erm.TRIGGER_MR2,  'OnDwarfMagicResistance');
  NameTrigger(Erm.TRIGGER_CM0,  'OnAdventureMapRightMouseClick');
  NameTrigger(Erm.TRIGGER_CM1,  'OnTownMouseClick');
  NameTrigger(Erm.TRIGGER_CM2,  'OnHeroScreenMouseClick');
  NameTrigger(Erm.TRIGGER_CM3,  'OnHeroesMeetScreenMouseClick');
  NameTrigger(Erm.TRIGGER_CM4,  'OnBattleScreenMouseClick');
  NameTrigger(Erm.TRIGGER_CM5,  'OnAdventureMapLeftMouseClick');
  NameTrigger(Erm.TRIGGER_AE0,  'OnEquipArt');
  NameTrigger(Erm.TRIGGER_AE1,  'OnUnequipArt');
  NameTrigger(Erm.TRIGGER_MM0,  'OnBattleMouseHint');
  NameTrigger(Erm.TRIGGER_MM1,  'OnTownMouseHint');
  NameTrigger(Erm.TRIGGER_MP,   'OnMp3MusicChange');
  NameTrigger(Erm.TRIGGER_SN,   'OnSoundPlay');
  NameTrigger(Erm.TRIGGER_MG0,  'OnBeforeAdventureMagic');
  NameTrigger(Erm.TRIGGER_MG1,  'OnAfterAdventureMagic');
  NameTrigger(Erm.TRIGGER_TH0,  'OnEnterTown');
  NameTrigger(Erm.TRIGGER_TH1,  'OnLeaveTown');
  NameTrigger(Erm.TRIGGER_IP0,  'OnBeforeBattleBeforeDataSend');
  NameTrigger(Erm.TRIGGER_IP1,  'OnBeforeBattleAfterDataReceived');
  NameTrigger(Erm.TRIGGER_IP2,  'OnAfterBattleBeforeDataSend');
  NameTrigger(Erm.TRIGGER_IP3,  'OnAfterBattleAfterDataReceived');
  NameTrigger(Erm.TRIGGER_CO0,  'OnOpenCommanderWindow');
  NameTrigger(Erm.TRIGGER_CO1,  'OnCloseCommanderWindow');
  NameTrigger(Erm.TRIGGER_CO2,  'OnAfterCommanderBuy');
  NameTrigger(Erm.TRIGGER_CO3,  'OnAfterCommanderResurrect');
  NameTrigger(Erm.TRIGGER_BA50, 'OnBeforeBattleForThisPcDefender');
  NameTrigger(Erm.TRIGGER_BA51, 'OnAfterBattleForThisPcDefender');
  NameTrigger(Erm.TRIGGER_BA52, 'OnBeforeBattleUniversal');
  NameTrigger(Erm.TRIGGER_BA53, 'OnAfterBattleUniversal');
  NameTrigger(Erm.TRIGGER_GM0,  'OnAfterLoadGame');
  NameTrigger(Erm.TRIGGER_GM1,  'OnBeforeSaveGame');
  NameTrigger(Erm.TRIGGER_PI,   'OnAfterErmInstructions');
  NameTrigger(Erm.TRIGGER_DL,   'OnCustomDialogEvent');
  NameTrigger(Erm.TRIGGER_HM,   'OnHeroMove');
  NameTrigger(Erm.TRIGGER_HL,   'OnHeroGainLevel');
  NameTrigger(Erm.TRIGGER_BF,   'OnSetupBattlefield');
  NameTrigger(Erm.TRIGGER_MF1,  'OnMonsterPhysicalDamage');
  NameTrigger(Erm.TRIGGER_TL0,  'OnEverySecond');
  NameTrigger(Erm.TRIGGER_TL1,  'OnEvery2Seconds');
  NameTrigger(Erm.TRIGGER_TL2,  'OnEvery5Seconds');
  NameTrigger(Erm.TRIGGER_TL3,  'OnEvery10Seconds');
  NameTrigger(Erm.TRIGGER_TL4,  'OnEveryMinute');
  NameTrigger(Erm.TRIGGER_SAVEGAME_WRITE,            'OnSavegameWrite');
  NameTrigger(Erm.TRIGGER_SAVEGAME_READ,             'OnSavegameRead');
  NameTrigger(Erm.TRIGGER_KEYPRESS,                  'OnKeyPressed');
  NameTrigger(Erm.TRIGGER_OPEN_HEROSCREEN,           'OnOpenHeroScreen');
  NameTrigger(Erm.TRIGGER_CLOSE_HEROSCREEN,          'OnCloseHeroScreen');
  NameTrigger(Erm.TRIGGER_STACK_OBTAINS_TURN,        'OnBattleStackObtainsTurn');
  NameTrigger(Erm.TRIGGER_REGENERATE_PHASE,          'OnBattleRegeneratePhase');
  NameTrigger(Erm.TRIGGER_AFTER_SAVE_GAME,           'OnAfterSaveGame');
  NameTrigger(Erm.TRIGGER_BEFOREHEROINTERACT,        'OnBeforeHeroInteraction');
  NameTrigger(Erm.TRIGGER_AFTERHEROINTERACT,         'OnAfterHeroInteraction');
  NameTrigger(Erm.TRIGGER_ONSTACKTOSTACKDAMAGE,      'OnStackToStackDamage');
  NameTrigger(Erm.TRIGGER_ONAICALCSTACKATTACKEFFECT, 'OnAICalcStackAttackEffect');
  NameTrigger(Erm.TRIGGER_ONCHAT,                    'OnChat');
  NameTrigger(Erm.TRIGGER_ONGAMEENTER,               'OnGameEnter');
  NameTrigger(Erm.TRIGGER_ONGAMELEAVE,               'OnGameLeave');
end; // .procedure RegisterErmEventNames

procedure FireErmEventEx (EventId: integer; Params: array of integer);
var
  i: integer;

begin
  {!} Assert(Length(Params) <= Length(GameExt.EraEventParams^), 'Cannot fire ERM event with so many arguments: ' + SysUtils.IntToStr(length(Params)));
  GameExt.EraSaveEventParams;
  
  for i := 0 to High(Params) do begin
    EraEventParams[i] := Params[i];
  end;
  
  Erm.FireErmEvent(EventId);
  GameExt.EraRestoreEventParams;
end; // .procedure FireErmEventEx

procedure FireRemoteErmEvent (EventId: integer; Args: array of integer);
begin
  {!} Assert(length(Args) <= 16, 'Cannot fire remote ERM event with more than 16 arguments');
  
  if length(Args) = 0 then begin
    FireRemoteEventProc(EventId, nil, 0);
  end else begin
    FireRemoteEventProc(EventId, @Args[0], length(Args));
  end;
end;

function ErmCurrHero: {n} pointer;
begin
  result := PPOINTER($27F9970)^;
end;

function ErmCurrHeroInd: integer; // or -1
begin
  if ErmCurrHero <> nil then begin
    result := pinteger(Utils.PtrOfs(ErmCurrHero, $1A))^;
  end else begin
    result := -1;
  end;
end; 

function Hook_ProcessErm (Context: Core.PHookContext): longbool; stdcall;
var
{O} YVars:     TYVars;
    EventArgs: TOnBeforeTriggerArgs;

begin
  if ErmEnabled^ then begin
    YVars := TYVars.Create;
    // * * * * * //
    if CurrErmEventID^ >= Erm.TRIGGER_FU30000 then begin
      SetLength(YVars.Value, Length(y^));
      Utils.CopyMem(sizeof(y^), @y[1], @YVars.Value[0]);
    end;
    
    SavedYVars.Add(YVars); YVars := nil;
    
    (* ProcessErm - initializing v996..v1000 variables *)
    asm
      CMP DWORD [$793C80], 0
      JL @L005
      MOV CL, byte [$793C80]
      MOV byte [$91F6C7], CL
      JMP @L013
    @L005:
      MOV EAX, $710FD3
      CALL EAX
      PUSH EAX
      MOV EAX, $711828
      CALL EAX
      ADD ESP, 4
      NEG EAX
      SBB AL, AL
      Inc AL
      MOV byte [$91F6C7], AL
    @L013:
      MOV EAX, $710FD3
      CALL EAX
      PUSH EAX
      MOV EAX, $7118A3
      CALL EAX
      ADD ESP,4
      MOV byte [$91F6C6], AL
      MOV EDX, DWORD [$27F9964]
      MOV DWORD [$8885FC], EDX
      MOV EAX, DWORD [$27F9968]
      MOV DWORD [$888600], EAX
      MOV ECX, DWORD [$27F996C]
      MOV DWORD [$888604], ECX
    end; // .asm
    
    if TrackingOpts.Enabled then begin
      EventTracker.TrackTrigger(ErmTracking.TRACKEDEVENT_START_TRIGGER, CurrErmEventID^);
    end;
    
    Inc(ErmTriggerDepth);

    EventArgs.TriggerId         := CurrErmEventID^;
    EventArgs.BlockErmExecution := false;
    EventMan.GetInstance.Fire('OnBeforeTrigger', @EventArgs, sizeof(EventArgs));
    
    if EventArgs.BlockErmExecution then begin
      CurrErmEventID^ := TRIGGER_INVALID;
    end;
    // * * * * * //
    SysUtils.FreeAndNil(YVars);
  end; // .if
  
  result := Core.EXEC_DEF_CODE;
end; // .function Hook_ProcessErm

function Hook_ProcessErm_End (Context: Core.PHookContext): longbool; stdcall;
var
{O} YVars:     TYVars;
    TriggerId: integer;

begin
  if ErmEnabled^ then begin
    YVars := SavedYVars.Pop;
    // * * * * * //
    TriggerId := pinteger(Context.EBP - $1A0)^;
    EventMan.GetInstance.Fire('OnAfterTrigger', @TriggerId, sizeof(TriggerId));
    
    if YVars.Value <> nil then begin
      Utils.CopyMem(sizeof(y^), @YVars.Value[0], @y[1]);
    end;
    
    Dec(ErmTriggerDepth);

    if TrackingOpts.Enabled then begin
      EventTracker.TrackTrigger(ErmTracking.TRACKEDEVENT_END_TRIGGER, TriggerId);
    end;
    // * * * * * //
    SysUtils.FreeAndNil(YVars);
  end; // .if

  result := Core.EXEC_DEF_CODE;
end; // .function Hook_ProcessErm_End

function Hook_ProcessCmd (Context: Core.PHookContext): longbool; stdcall;
begin
  if TrackingOpts.Enabled then begin
    EventTracker.TrackCmd(PErmCmd(ppointer(Context.EBP + 8)^).CmdHeader.Value);
  end;

  ErmErrReported := false;  
  result         := Core.EXEC_DEF_CODE;
end;

function Hook_FindErm_BeforeMainLoop (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  GLOBAL_EVENT_SIZE = 52;

begin
  // Skip internal map events: GEp_ = GEp1 - [sizeof(_GlbEvent_) = 52]
  pinteger(Context.EBP - $3F4)^ := pinteger(pinteger(Context.EBP - $24)^ + $88)^ - GLOBAL_EVENT_SIZE;
  ErmErrReported                := false;
  EventMan.GetInstance.Fire('OnBeforeErm');

  if not ZvsIsGameLoading^ then begin
    EventMan.GetInstance.Fire('OnBeforeErmInstructions');
  end;
  
  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_FindErm_BeforeMainLoop

function Hook_FindErm_AfterMapScripts (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  GLOBAL_EVENT_SIZE = 52;

var
  ScriptIndPtr: pinteger;
  
begin
  ScriptIndPtr := Ptr(Context.EBP - $18);
  // * * * * * //
  if not ZvsIsGameLoading^ and (ScriptIndPtr^ = 0) then begin
    EventMan.GetInstance.Fire('$OnEraMapStart');
    ZvsResetCommanders;
    AdvErm.ResetMemory;
    FuncNames.Clear;
    FuncAutoId := INITIAL_FUNC_AUTO_ID;
    RegisterErmEventNames;
    ScriptMan.LoadScriptsFromDisk;
  end;
  
  if ScriptIndPtr^ < ScriptMan.Scripts.Count then begin
    // M.m.i = 0
    pinteger(Context.EBP - $318)^ := 0;
    // M.m.s = ErmScript
    ppchar(Context.EBP - $314)^ := ScriptMan.Scripts[ScriptIndPtr^].GetPtr();
    // M.m.l = Length(ErmScript)
    pinteger(Context.EBP - $310)^ := Length(ScriptMan.Scripts[ScriptIndPtr^].Contents);
    // GEp_--; Process one more script
    Dec(pinteger(Context.EBP - $3F4)^, GLOBAL_EVENT_SIZE);
    Inc(ScriptIndPtr^);
    // Jump to ERM header processing
    Context.RetAddr := Ptr($74A00C);
  end else begin
    // Jimp right after loop end
    Context.RetAddr := Ptr($74C5A7);
  end; // .else
  
  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_FindErm_AfterMapScripts

function LoadWoGOptions (FilePath: pchar): boolean; ASSEMBLER;
asm
  PUSH $0FA0
  PUSH $2771920
  PUSH EAX // FilePath
  MOV EAX, $773867
  CALL EAX
  ADD ESP, $0C
  CMP EAX, 0
  JGE @OK // ==>
  xor EAX, EAX
  JMP @Done
@OK:
  xor EAX, EAX
  Inc EAX
@Done:
end; // .function LoadWoGOptions

function Hook_UN_J3_End (Context: Core.PHookContext): longbool; stdcall;
const
  RESET_OPTIONS_COMMAND = ':clear:';
  WOG_OPTION_MAP_RULES  = 101;
  USE_SELECTED_RULES    = 2;

var
  WoGOptionsFile: string;
  i:              integer;

begin
  WoGOptionsFile := pchar(Context.ECX);

  if WoGOptionsFile = RESET_OPTIONS_COMMAND then begin
    for i := 0 to High(WoGOptions[CURRENT_WOG_OPTIONS]) do begin
      WoGOptions[CURRENT_WOG_OPTIONS][i] := 0;
    end;
    
    WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_MAP_RULES] := USE_SELECTED_RULES;
  end else if not LoadWoGOptions(pchar(WoGOptionsFile)) then begin
    ShowMessage('Cannot load file with WoG options: ' + WoGOptionsFile);
  end;
  
  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_UN_J3_End

{$W-}
procedure Hook_ErmCastleBuilding; ASSEMBLER;
asm
  MOVZX EDX, byte [ECX + $150]
  MOVZX EAX, byte [ECX + $158]
  or EDX, EAX
  PUSH $70E8A9
  // RET
end;
{$W+}

function Hook_ErmHeroArt (Context: Core.PHookContext): longbool; stdcall;
begin
  result := ((pinteger(Context.EBP - $E8)^ shr 8) and 7) = 0;
  
  if not result then begin
    Context.RetAddr := Ptr($744B85);
  end;
end;

function Hook_ErmHeroArt_FindFreeSlot (Context: Core.PHookContext): longbool; stdcall;
begin
  f[1]   := false;
  result := Core.EXEC_DEF_CODE;
end;

function Hook_ErmHeroArt_FoundFreeSlot (Context: Core.PHookContext): longbool; stdcall;
begin
  f[1]   := true;
  result := Core.EXEC_DEF_CODE;
end;

function Hook_ErmHeroArt_DeleteFromBag (Context: Core.PHookContext): longbool; stdcall;
const
  NUM_BAG_ARTS_OFFSET = +$3D4;
  HERO_PTR_OFFSET     = -$380;
  
var
  Hero: pointer;

begin
  Hero := PPOINTER(Context.EBP + HERO_PTR_OFFSET)^;
  Dec(PBYTE(Utils.PtrOfs(Hero, NUM_BAG_ARTS_OFFSET))^);
  result := Core.EXEC_DEF_CODE;
end; // .function Hook_ErmHeroArt_DeleteFromBag

function Hook_DlgCallback (Context: Core.PHookContext): longbool; stdcall;
const
  NO_CMD = 0;

begin
  ErmDlgCmd^ := NO_CMD;
  result     := Core.EXEC_DEF_CODE;
end;

function Hook_CM3 (Context: Core.PHookContext): longbool; stdcall;
const
  MOUSE_STRUCT_ITEM_OFS = +$8;
  CM3_RES_ADDR          = $A6929C;

var
  SwapManager: integer;
  MouseStruct: integer;

begin
  SwapManager := Context.EBX;
  MouseStruct := Context.EDI;
  
  asm
    PUSHAD
    PUSH SwapManager
    POP [$27F954C]
    PUSH MouseStruct
    POP [$2773860]
    MOV EAX, $74FB3C
    CALL EAX
    POPAD
  end; // .asm
  
  pinteger(Context.EDI + MOUSE_STRUCT_ITEM_OFS)^ := pinteger(CM3_RES_ADDR)^;
  result := Core.EXEC_DEF_CODE;
end; // .function Hook_CM3

function Hook_MR_N (c: Core.PHookContext): longbool; stdcall;
begin
  c.eax     := Heroes.GetStackIdByPos(Heroes.GetVal(MrMonPtr^, STACK_POS).v);
  c.RetAddr := Ptr($75DC76);
  result    := not Core.EXEC_DEF_CODE;
end;

function Hook_CmdElse (Context: Core.PHookContext): longbool; stdcall;
var
  CmdFlags: PErmCmdConditions;
  
begin
  if ZvsTriggerIfs[ZvsTriggerIfsDepth^] = ZVS_TRIGGER_IF_TRUE then begin
    ZvsTriggerIfs[ZvsTriggerIfsDepth^] := ZVS_TRIGGER_IF_INACTIVE;
  end else if ZvsTriggerIfs[ZvsTriggerIfsDepth^] = ZVS_TRIGGER_IF_FALSE then begin
    CmdFlags := Ptr(pinteger(Context.EBP - $19C)^ * $29C + $212 + pinteger(Context.EBP - 4)^);
    ZvsTriggerIfs[ZvsTriggerIfsDepth^] := 1 - integer(ZvsCheckFlags(CmdFlags));
  end;
  
  Context.RetAddr := Ptr($74CA64);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_CmdElse

function Hook_FU_P_RetValue (C: Core.PHookContext): longbool; stdcall;
var
{U} OldXVars: PErmXVars;
    Transfer: integer;
    i:        integer;
  
begin
  OldXVars := Ptr(C.EBP - $15E0);
  
  for i := Low(x^) to High(x^) do begin
    Transfer    := x[i];
    x[i]        := OldXVars[i];
    OldXVars[i] := Transfer;
  end;

  C.RetAddr := Ptr($74CA64);
  result    := Core.EXEC_DEF_CODE;
end; // .function Hook_FU_P_RetValue

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
begin
  ExtractErm;

  if TrackingOpts.Enabled then begin
    EventTracker.GenerateReport(GameExt.GameDir + '\' + ERM_TRACKING_REPORT_PATH);
  end;
end;

procedure OnBeforeWoG (Event: GameExt.PEvent); stdcall;
const
  NEW_ERM_HEAP_SIZE = 128 * 1000 * 1000;

var
{On} NewErmHeap: pointer;

begin
  (* Remove WoG CM3 trigger *)
  Core.p.WriteDword(Ptr($78C210), $887668);

  (* Extend ERM memory limit to 128 MB *)
  NewErmHeap := Windows.VirtualAlloc(nil, NEW_ERM_HEAP_SIZE, Windows.MEM_RESERVE or Windows.MEM_COMMIT, Windows.PAGE_EXECUTE_READWRITE);
  {!} Assert(NewErmHeap <> nil, 'Failed to allocate 128 MB memory block for new ERM heap');
  Core.p.WriteDataPatch(Ptr($73E1DE), ['%d', integer(NewErmHeap)]);
  Core.p.WriteDataPatch(Ptr($73E1E8), ['%d', integer(NEW_ERM_HEAP_SIZE)]);
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  // Patch WoG FindErm to allow functions with arbitrary positive IDs
  Core.p.WriteDataPatch(Ptr($74A724), ['EB']);

  (* Disable internal map scripts interpretation *)
  Core.ApiHook(@Hook_FindErm_BeforeMainLoop, Core.HOOKTYPE_BRIDGE, Ptr($749BBA));

  (* Remove default mechanism of loading [mapname].erm *)
  Core.p.WriteDataPatch(Ptr($72CA8A), ['E90102000090909090']);

  (* Never load [mapname].cmd file *)
  Core.p.WriteDataPatch(Ptr($771CA8), ['E9C2070000']);

  (* Replace all points of wog option 5 (Wogify) access with FreezedWogOptionWogify *)
  Core.p.WriteDword(Ptr($705601 + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($72CA2F + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($749BFE + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($749CAF + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($749D91 + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($749E2D + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($749E9D + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($74C6F5 + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($753F07 + 2), integer(@FreezedWogOptionWogify));

  (* Force all maps to be treated as WoG format *)
  // Replace MOV WoG, 0 with MOV WoG, 1
  Core.p.WriteDataPatch(Ptr($704F48 + 6), ['01']);
  Core.p.WriteDataPatch(Ptr($74C6E1 + 6), ['01']);

  (* New way of iterating scripts in FindErm *)
  Core.ApiHook(@Hook_FindErm_AfterMapScripts, Core.HOOKTYPE_BRIDGE, Ptr($749BF5));

  (* Remove LoadERMTXT calls everywhere *)
  Core.p.WriteDataPatch(Ptr($749932 - 2), ['33C09090909090909090']);
  Core.p.WriteDataPatch(Ptr($749C24 - 2), ['33C09090909090909090']);
  Core.p.WriteDataPatch(Ptr($74C7DD - 2), ['33C09090909090909090']);
  Core.p.WriteDataPatch(Ptr($7518CC - 2), ['33C09090909090909090']);

  (* Remove call to FindErm from _B1.cpp::LoadManager *)
  Core.p.WriteDataPatch(Ptr($7051A2), ['9090909090']);
  
  (* Remove saving and loading old ERM scripts array *)
  Core.p.WriteDataPatch(Ptr($75139D), ['EB7D909090']);
  Core.p.WriteDataPatch(Ptr($751EED), ['E99C000000']);
  
  (* InitErm always sets IsWoG to true *)
  Core.p.WriteDataPatch(Ptr($74C6FC), ['9090']);

  (* ERM OnAnyTrigger *)
  Core.Hook(@Hook_ProcessErm, Core.HOOKTYPE_BRIDGE, 6, Ptr($74C819));
  Core.Hook(@Hook_ProcessErm_End, Core.HOOKTYPE_BRIDGE, 5, Ptr($74CE2A));

  (* Fix ERM CA:B3 bug *)
  Core.Hook(@Hook_ErmCastleBuilding, Core.HOOKTYPE_JUMP, 7, Ptr($70E8A2));
  
  (* Fix HE:A art get syntax bug *)
  Core.Hook(@Hook_ErmHeroArt, Core.HOOKTYPE_BRIDGE, 9, Ptr($744B13));
  
  (* Fix HE:A# - set flag 1 as success *)
  Core.Hook(@Hook_ErmHeroArt_FindFreeSlot, Core.HOOKTYPE_BRIDGE, 10, Ptr($7454B2));
  Core.Hook(@Hook_ErmHeroArt_FoundFreeSlot, Core.HOOKTYPE_BRIDGE, 6, Ptr($7454EC));
  
  (* Fix HE:A3 artifacts delete - update art number *)
  Core.ApiHook(@Hook_ErmHeroArt_DeleteFromBag, Core.HOOKTYPE_BRIDGE, Ptr($745051));
  Core.ApiHook(@Hook_ErmHeroArt_DeleteFromBag, Core.HOOKTYPE_BRIDGE, Ptr($7452F3));
  
  (* Fix DL:C close all dialogs bug *)
  Core.Hook(@Hook_DlgCallback, Core.HOOKTYPE_BRIDGE, 6, Ptr($729774));
  
  (* Fix LoadErtFile to handle any relative pathes *)
  Core.Hook(@Hook_LoadErtFile, Core.HOOKTYPE_BRIDGE, 5, Ptr($72C660));

  (* Disable connection between script number and option state in WoG options *)
  Core.p.WriteDataPatch(Ptr($777E48), ['E9180100009090909090']);
  
  (* Fix CM3 trigger allowing to handle all clicks *)
  Core.ApiHook(@Hook_CM3, Core.HOOKTYPE_BRIDGE, Ptr($5B0255));
  Core.p.WriteDataPatch(Ptr($5B02DD), ['8B47088D70FF']);

  (* !!el&[condition] support *)
  Core.ApiHook(@Hook_CmdElse, Core.HOOKTYPE_BRIDGE, Ptr($74CC0D));

  (* UN:J3 does not reset commanders or load scripts. New: it can be used to reset wog options *)
  // Turned off because of side effects of NPC reset and not displaying wogification message some authors could rely on.
  //Core.ApiHook(@Hook_UN_J3_End, Core.HOOKTYPE_BRIDGE, Ptr($733A85));

  (* Fix MR:N in !?MR1 !?MR2 *)
  Core.ApiHook(@Hook_MR_N, Core.HOOKTYPE_BRIDGE, Ptr($75DC67));

  (* Allow !!FU:P?x[n] syntax. *)
  Core.ApiHook(@Hook_FU_P_RetValue, Core.HOOKTYPE_BRIDGE, Ptr($72D04A));
  Core.p.WriteDataPatch(Ptr($72D0A0), ['8D849520EAFFFF']);
  Core.p.WriteDataPatch(Ptr($72D0B2), ['E9E70000009090909090']);

  (* Detailed ERM error reporting *)
  // Replace simple message with detailed message with location and context
  Core.ApiHook(@Hook_MError,  Core.HOOKTYPE_BRIDGE, Ptr($71236A));
  // Disallow repeated message, display detailed message with location otherwise
  ApiJack.StdSplice(Ptr($73DE8A), @Hook_ErmMess, ApiJack.CONV_CDECL, 1);
  // Disable double reporting of error location in ProcessCmd
  Core.p.WriteDataPatch(Ptr($749421), ['E9BF0200009090']);
  // Track ERM errors location during FindErm
  Core.ApiHook(@Hook_FindErm_SkipUntil2, Core.HOOKTYPE_CALL, Ptr($74A14A));

  (* Disable default tracing of last ERM command *)
  Core.p.WriteDataPatch(Ptr($741E34), ['9090909090909090909090']);

  (* Enable ERM tracking and pre-command initialization *)
  with TrackingOpts do begin
    if Enabled then begin
      EventTracker := ErmTracking.TEventTracker.Create(MaxRecords).SetDumpCommands(DumpCommands).SetIgnoreEmptyTriggers(IgnoreEmptyTriggers).SetIgnoreRealTimeTimers(IgnoreRealTimeTimers);
    end;

    Core.ApiHook(@Hook_ProcessCmd, Core.HOOKTYPE_BRIDGE, Ptr($741E3F));
  end;
end; // .procedure OnAfterWoG

begin
  ScriptMan       := TScriptMan.Create;
  FuncNames       := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  FuncIdToNameMap := DataLib.NewObjDict(Utils.OWNS_ITEMS);
  
  ErmScanner  := TextScan.TTextScanner.Create;
  ErmCmdCache := AssocArrays.NewSimpleAssocArr
  (
    Crypto.AnsiCRC32,
    AssocArrays.NO_KEY_PREPROCESS_FUNC
  );
  IsWoG^      :=  true;
  ScriptNames :=  Lists.NewSimpleStrList;
  SavedYVars  :=  Lists.NewStrictList(TYVars);
  
  EventMan.GetInstance.On('OnBeforeWoG',         OnBeforeWoG);
  EventMan.GetInstance.On('OnAfterWoG',          OnAfterWoG);
  EventMan.GetInstance.On('$OnEraSaveScripts',   OnEraSaveScripts);
  EventMan.GetInstance.On('$OnEraLoadScripts',   OnEraLoadScripts);
  EventMan.GetInstance.On('OnGenerateDebugInfo', OnGenerateDebugInfo);
end.
