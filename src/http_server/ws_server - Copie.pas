unit ws_server;

interface

uses
  mormot.core.base,
  mormot.core.collections,
  mormot.net.ws.async,
  mormot.net.ws.core,
  ws_const,
  token;

{$define WITH_LOGS}

const
  SErrServerAlreadyStarted = 'WS server is already started.';
  SErrServerInvalidPort = 'WS server port not set, current binding port: 【%】';

type
  TCableWebSocketAsyncServer = class;

  TCableWebSocketProtocol = class(TWebSocketProtocolChat)
  private
    FOwnerWebSocketMgr: TCableWebSocketAsyncServer;
  protected
    procedure DoIncomingFrame(Sender: TWebSocketProcess; const Frame: TWebSocketFrame);
  public
    function GetWsTokenByConnectionID(QConnectionID: int64): TWsToken;
  end;

  TCableWebSocketAsyncServer = class
  private
    FWsTokenDict: IKeyValue<RawUtf8, TWsToken>;
    FWsConnectionDict: IKeyValue<int64, RawUtf8>;
    FErrMsg: RawUtf8;
    FStarted: boolean;
    FStopRequest: boolean;
    FPort: integer;
    FThreadPoolCount: integer;
    FHttpQueueLength: integer;
    FKeepAliveTimeOut: integer;
    FWebSocketServer: TWebSocketAsyncServer;
  private
    procedure WsTokenDictOp(QConnectionID: int64; QIsClose: boolean = false);
    function GetConnectionIDByWsUserID(QWsUserID: RawUtf8): int64;
  public
    constructor Create;
    destructor Destroy; override;
    function Start: boolean;
    function Stop: boolean;
    function ServerStopRequest(): boolean;
    function SendMsgAll(QMsg: RawByteString): boolean;
    function SendMsgToUser(QWsMsg: TWsMsg): boolean;
    function SendMsg(QConnectionID: int64; QMsg: RawUtf8): boolean;
    procedure SendWsUserID(QConnectionID: int64);
    function SendFrame(QConnectionID: int64; QFrame: TWebSocketFrame): boolean;
    function GetWsTokenList(): IList<TWsToken>;
    procedure Broadcast(const Channel, Message: RawUtf8);
  public
    property Server: TWebSocketAsyncServer read FWebSocketServer;
  end;

implementation

uses
  mormot.core.os,
  mormot.core.json,
  mormot.core.text,
  mormot.core.unicode,
  mormot.core.data,
  mormot.core.variants,
  mormot.core.datetime,
  mormot.core.threads,
  mormot.net.server,
  httpctxt_result;

{ TCableWebSocketProtocol }

procedure TCableWebSocketProtocol.DoIncomingFrame(Sender: TWebSocketProcess;
  const Frame: TWebSocketFrame);
var
  lWsMsg: TWsMsg;
begin
  case Frame.opcode of
    focContinuation:
      begin
        ConsoleWrite('focContinuation: %', [Sender.Protocol.ConnectionID], ccLightCyan);
        Self.FOwnerWebSocketMgr.WsTokenDictOp(Sender.Protocol.ConnectionID, false);
        TSynThread.CreateAnonymousThread(
          procedure()
          begin
            SleepHiRes(100);
            Self.FOwnerWebSocketMgr.SendWsUserID(Sender.Protocol.ConnectionID);
          end
        ).Start;
      end;
    focConnectionClose:
      begin
        ConsoleWrite('focConnectionClose: %', [Sender.Protocol.ConnectionID], ccLightRed);
        Self.FOwnerWebSocketMgr.WsTokenDictOp(Sender.Protocol.ConnectionID, true);
      end;
    focText, focBinary:
      begin
        if Frame.payload = '' then exit;

        lWsMsg := TWsMsg.Create;
        try
          lWsMsg.FromUserID := '';
          lWsMsg.FromUserName := '';
          lWsMsg.MsgData := Frame.payload;
          SendFrameJson(Sender, ObjectToJson(lWsMsg));
          ConsoleWrite('focText, focBinary: %', [ObjectToJson(lWsMsg)], ccLightMagenta);
        finally
          lWsMsg.Free;
        end;
      end;
  end;
end;

function TCableWebSocketProtocol.GetWsTokenByConnectionID(QConnectionID: int64): TWsToken;
var
  lWsUserID: RawUtf8;
begin
  Result := nil;
  if Self.FOwnerWebSocketMgr.FWsConnectionDict.TryGetValue(QConnectionID, lWsUserID) then
  begin
    Self.FOwnerWebSocketMgr.FWsTokenDict.TryGetValue(lWsUserID, Result);
  end;
end;

{ TCableWebSocketAsyncServer }

constructor TCableWebSocketAsyncServer.Create;
begin
  Self.FStarted := false;
  Self.FStopRequest := false;
  Self.FPort := 8082;
  Self.FThreadPoolCount := 32;
  Self.FHttpQueueLength := 1000;
  Self.FKeepAliveTimeOut := 30000;
  Self.FWebSocketServer := nil;
  FWsTokenDict := Collections.NewKeyValue<RawUtf8, TWsToken>;
  FWsConnectionDict := Collections.NewKeyValue<int64, RawUtf8>;
end;

destructor TCableWebSocketAsyncServer.Destroy;
var
  i: PtrInt;
begin
  for i := 0 to FWsTokenDict.Count - 1 do
  begin
    FWsTokenDict.Value[i].Free;
  end;
  FWsTokenDict.Clear;
  FWsConnectionDict.Clear;

  if FWebSocketServer <> nil then
  begin
    FWebSocketServer.Free;
  end;

  inherited Destroy;
end;

function TCableWebSocketAsyncServer.GetConnectionIDByWsUserID(QWsUserID: RawUtf8): int64;
var
  lWSToken: TWsToken;
begin
  Result := -1;
  TMonitor.Enter(Self);
  try
    if Self.FWsTokenDict.TryGetValue(QWsUserID, lWSToken) then
    begin
      Result := lWSToken.ConnectionID;
    end;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TCableWebSocketAsyncServer.GetWsTokenList: IList<TWsToken>;
var
  e: TPair<RawUtf8, TWsToken>;
begin
  TMonitor.Enter(Self);
  try
    Result := Collections.NewList<TWsToken>;
    for e in FWsTokenDict do
    begin
      Result.Add(e.Value.Copy);
    end;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TCableWebSocketAsyncServer.WsTokenDictOp(QConnectionID: int64; QIsClose: boolean);
var
  lWSToken: TWsToken;
  lWsUserID: RawUtf8;
begin
  TMonitor.Enter(Self);
  try
    if QIsClose then
    begin
      if Self.FWsConnectionDict.TryGetValue(QConnectionID, lWsUserID) then
      begin
        if Self.FWsTokenDict.TryGetValue(lWsUserID, lWSToken) then
        begin
          lWSToken.Free;
        end;
        Self.FWsTokenDict.Remove(lWsUserID);
      end;
      Self.FWsConnectionDict.Remove(QConnectionID);
    end
    else
    begin
      lWSToken := TWsToken.Create;
      lWSToken.WsUserID := ToUtf8(QConnectionID);
      lWSToken.ConnectionID := QConnectionID;
      lWSToken.UserName := USERNAME_GUEST;
      Self.FWsTokenDict.Add(lWSToken.WsUserID, lWSToken);
      Self.FWsConnectionDict.Add(QConnectionID, lWSToken.WsUserID);
    end;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TCableWebSocketAsyncServer.SendFrame(QConnectionID: int64; QFrame: TWebSocketFrame): boolean;
begin
  Result := false;
  FWebSocketServer.WebSocketBroadcast(QFrame, [QConnectionID]);
  Result := true;
end;

function TCableWebSocketAsyncServer.SendMsg(QConnectionID: int64; QMsg: RawUtf8): boolean;
var
  lFrame: TWebSocketFrame;
begin
  Result := false;
  lFrame.opcode := focText;
  lFrame.payload := QMsg;
  FWebSocketServer.WebSocketBroadcast(lFrame, [QConnectionID]);
  Result := true;
end;

function TCableWebSocketAsyncServer.SendMsgAll(QMsg: RawByteString): boolean;
var
  lFrame: TWebSocketFrame;
begin
  Result := false;
  lFrame.opcode := focText;
  lFrame.payload := QMsg;
  FWebSocketServer.WebSocketBroadcast(lFrame, nil);
  Result := true;
end;

function TCableWebSocketAsyncServer.SendMsgToUser(QWsMsg: TWsMsg): boolean;
var
  lJsonObj: IDocDict;
  lToUserConnecitonID: int64;
begin
  Result := false;
  if QWsMsg.ToUserID = '' then
  begin
    exit; //=>
  end;
  lToUserConnecitonID := Self.GetConnectionIDByWsUserID(QWsMsg.ToUserID);
  if lToUserConnecitonID <= 0 then exit; //=>
  lJsonObj := DocDict(ObjectToJson(QWsMsg));
  try
    Result := Self.SendMsg(lToUserConnecitonID, lJsonObj.ToString);
  finally
    lJsonObj.Clear;
  end;
end;

procedure TCableWebSocketAsyncServer.SendWsUserID(QConnectionID: int64);
var
  lWsUserID: RawUtf8;
  lWsMsg: TWsMsg;
  lJsonObj: IDocDict;
begin
  if not Self.FWsConnectionDict.TryGetValue(QConnectionID, lWsUserID) then exit; //=>
  if lWsUserID = '' then exit; //=>
  lWsMsg := TWsMsg.Create;
  try
    lWsMsg.MsgID := '';
    lWsMsg.ControllerRoot := '';
    lWsMsg.FromUserID := '';
    lWsMsg.FromUserName := '';
    lWsMsg.ToUserID := lWsUserID;
    lWsMsg.MsgCode := '';
    lWsMsg.MsgCmd := WsMsg_cmd_WsUserIDGet;
    lWsMsg.MsgData := '';
    lWsMsg.MsgTime := DateTimeMSToString(NowUtc);

    lJsonObj := DocDict(ObjectToJson(lWsMsg));
    Self.SendMsg(QConnectionID, lJsonObj.ToString);
  finally
    lJsonObj.Clear;
    lWsMsg.Free;
  end;
end;

function TCableWebSocketAsyncServer.ServerStopRequest: boolean;
begin
  Result := false;
  FStopRequest := true;
  Result := true;
end;

function TCableWebSocketAsyncServer.Start: boolean;
var
  lWSProtocol: TCableWebSocketProtocol;
begin
  Result := false;

  if FStarted then
  begin
    FErrMsg := SErrServerAlreadyStarted;
    exit;
  end;
  if (FPort <= 0) then
  begin
    FErrMsg := FormatUtf8(SErrServerInvalidPort, [ToUtf8(FPort)]);
    exit;
  end;
  if Self.FThreadPoolCount > 1000 then
    Self.FThreadPoolCount := 1000;

  FWebSocketServer := TWebSocketAsyncServer.Create(
    ToUtf8(FPort), nil, nil, 'ActionCable',
    SystemInfo.dwNumberOfProcessors + 1,
    FKeepAliveTimeOut,
    [hsoNoXPoweredHeader,
     hsoNoStats,
     hsoHeadersInterning,
     hsoThreadSmooting
     {$ifdef WITH_LOGS}
     ,hsoLogVerbose, hsoEnableLogging
     {$endif}
    ]);
  {$ifdef WITH_LOGS}
  FWebSocketServer.Settings^.SetFullLog;
  {$endif}
  lWSProtocol := TCableWebSocketProtocol.Create('', 'cable');
  lWSProtocol.OnIncomingFrame := lWSProtocol.DoIncomingFrame;
  FWebSocketServer.WebSocketProtocols.Add(lWSProtocol);
  lWSProtocol.FOwnerWebSocketMgr := Self;
  FWebSocketServer.HttpQueueLength := FHttpQueueLength;
  FWebSocketServer.WaitStarted;
  FStopRequest := false;
  FStarted := true;
end;

function TCableWebSocketAsyncServer.Stop: boolean;
begin
  Result := false;
  if Self.FWebSocketServer <> nil then
  begin
    Self.FWebSocketServer.Free;
    Self.FWebSocketServer := nil;
  end;
  Self.FStarted := false;
  Result := true;
end;

procedure TCableWebSocketAsyncServer.Broadcast(const Channel, Message: RawUtf8);
var
  Frame: TWebSocketFrame;
begin
  Frame.opcode := focText;
  Frame.payload := FormatUtf8('%:%', [Channel, Message]);
  FWebSocketServer.WebSocketBroadcast(Frame, nil);
end;

end.

