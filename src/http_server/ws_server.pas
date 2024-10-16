unit ws_server;

interface

uses
  mormot.core.base,
  mormot.core.collections,
  mormot.net.ws.async,
  mormot.net.ws.core,
  mormot.rest.mvc,
  ws_const,
  token,
  base,
  channel_base,
  MVCModel,
  MVCViewModel;

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
    FChannelDict: IKeyValue<RawUtf8, TChannelBase>;
    FErrMsg: RawUtf8;
    FStarted: boolean;
    FStopRequest: boolean;
    FPort: integer;
    FThreadPoolCount: integer;
    FHttpQueueLength: integer;
    FKeepAliveTimeOut: integer;
    FWebSocketServer: TWebSocketAsyncServer;
    FMvcApp: TBlogApplication;  // Add the MVC application reference
  private
    procedure WsTokenDictOp(QConnectionID: int64; QIsClose: boolean = false);
    procedure WsTokenDictUpdate(QConnectionID: int64; UserName: RawUtf8);
    function GetConnectionIDByWsUserID(QWsUserID: RawUtf8): int64;
    procedure InitializeChannels;
  public
    constructor Create(AMvcApp: TBlogApplication);  // Modify the constructor
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
    procedure PerformAction(const Action: string; const Data: IKeyValue<RawUtf8, Variant>);
  public
    property Server: TWebSocketAsyncServer read FWebSocketServer;
    property MVCApp: TBlogApplication read FMVCApp write FMVCApp;
  end;

implementation

uses
  contnrs,
  mormot.core.os,
  mormot.core.json,
  mormot.core.text,
  mormot.core.unicode,
  mormot.core.data,
  mormot.core.variants,
  mormot.core.datetime,
  mormot.core.threads,
  mormot.net.server,
  mormot.core.mustache,
  chat_channel;

{ TCableWebSocketProtocol }

procedure TCableWebSocketProtocol.DoIncomingFrame(Sender: TWebSocketProcess;
  const Frame: TWebSocketFrame);
var
  lWsMsg: TWsMsg;
  Channel: TChannelBase;
  Token: TWsToken;
  data: IKeyValue<RawUtf8, Variant>;
  buf: RawUtf8;
  cmd: TDocVariantData;
begin
  case Frame.opcode of
    focContinuation:
      begin
        ConsoleWrite('focContinuation: %', [Sender.Protocol.ConnectionID], ccLightCyan);
        
        Self.FOwnerWebSocketMgr.WsTokenDictOp(Sender.Protocol.ConnectionID);
        
        TSynThread.CreateAnonymousThread(
          procedure()
          begin
            SleepHiRes(50);
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
        if Frame.payload = '' then 
          exit; //=>

        // Parse the incoming message
        cmd.InitJsonInPlace(pointer(Frame.payload), JSON_OPTIONS[true]);

        // Handle the command
        if cmd.GetAsRawUtf8('command', buf) then
        begin
          if buf = 'subscribe' then
          begin
            // Handle subscription logic
            if cmd.GetAsRawUtf8('channel', buf) then
            begin
              Channel := FOwnerWebSocketMgr.FChannelDict[buf];
              if Assigned(Channel) then
              begin
                // Perform the action related to subscription
                Data := Collections.NewKeyValue<RawUtf8, Variant>;
                try
                  Data.Add('channel', buf);
                  Data.Add('action', 'subscribe');
                  // set pseudo
                  if cmd.GetAsRawUtf8('user', buf) then
                  begin
                    Data.Add('user', buf);
                    self.FOwnerWebSocketMgr.WsTokenDictUpdate(Sender.Protocol.ConnectionID, buf);
                  end;
                  // perform action
                  Channel.PerformAction('subscribe', Data);                     
                                                              
                  // Send acknowledgment or relevant data back to the client
                  lWsMsg := TWsMsg.Create;
                  try
                    lWsMsg.MsgData := 'Subscription successful';
                    SendFrameJson(Sender, ObjectToJson(lWsMsg));
                  finally
                    lWsMsg.Free;
                  end;
                finally
                  Data.Clear;
                end;
              end;
            end;
          end
          else if buf = 'message' then
          begin
            // Handle subscription logic
            if cmd.GetAsRawUtf8('channel', buf) then
            begin
              Channel := FOwnerWebSocketMgr.FChannelDict[buf];
              if Assigned(Channel) then
              begin
                // Perform the action related to subscription
                Data := Collections.NewKeyValue<RawUtf8, Variant>;
                try
                  Data.Add('channel', buf);
                  Data.Add('action', 'send_message');
                  if cmd.GetAsRawUtf8('message', buf) then
                    Data.Add('message', buf);
                  Channel.PerformAction('send_message', Data);

                  Token := GetWsTokenByConnectionID(Sender.Protocol.ConnectionID);
                  if token <> nil then
                  begin
                    // Send acknowledgment or relevant data back to the clients
                    lWsMsg := TWsMsg.Create;
                    try
                      lWsMsg.FromUserID := Token.WsUserID;
                      lWsMsg.FromUserName := Token.UserName;
                      lWsMsg.MsgData := Data.GetValueOrDefault('message', 'no signal :(');
                    
                      Self.FOwnerWebSocketMgr.SendMsgAll(ObjectToJson(lWsMsg));
                    finally
                      lWsMsg.Free;
                    end;
                  end;
                finally
                  Data.Clear;
                end;
              end;
            end;
          end
          else if buf = 'render' then
          begin
            // handle render logic, for example rendering an article view
            if cmd.GetAsRawUtf8('channel', buf) and (buf = 'ChatChannel') then
            begin
              // Example for rendering an article view
              var ID: TID := 1; // Example ID, should be parsed from the command
              var WithComments: boolean := true;
              var Scope, Author: variant;
              var Article: TOrmArticle := TOrmArticle.Create;
              var Comments: TObjectList;
              var mustache: TSynMustache;

              FOwnerWebSocketMgr.FMvcApp.ArticleView(ID, WithComments, 0, Scope, Article, Author, Comments);

              // render the HTML
              mustache := TSynMustache.Create;
              var HtmlContent: RawUtf8 := '';              
              HtmlContent := Self.FOwnerWebSocketMgr.MVCApp.RenderArticleView(ID, WithComments, 0, 
                Scope, Article, Author, Comments);

              // send the rendered HTML back to the client
              lWsMsg := TWsMsg.Create;
              try
                lWsMsg.FromUserID := '';
                lWsMsg.FromUserName := '';
                lWsMsg.MsgData := VariantToUtf8(_ObjFast(['type', 'render', 'target', 'content', 'html', HtmlContent]));
                SendFrameJson(Sender, ObjectToJson(lWsMsg));
              finally
                lWsMsg.Free;
              end;
            end;
          end;
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

constructor TCableWebSocketAsyncServer.Create(AMvcApp: TBlogApplication);
begin
  Self.FStarted := false;
  Self.FStopRequest := false;
  Self.FPort := 8082;
  Self.FThreadPoolCount := 32;
  Self.FHttpQueueLength := 1000;
  Self.FKeepAliveTimeOut := 30000;
  Self.FWebSocketServer := nil;
  FMvcApp := AMvcApp;  // Set the MVC application
  FWsTokenDict := Collections.NewKeyValue<RawUtf8, TWsToken>;
  FWsConnectionDict := Collections.NewKeyValue<int64, RawUtf8>;
  FChannelDict := Collections.NewKeyValue<RawUtf8, TChannelBase>;
  InitializeChannels;
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
  FChannelDict.Clear;

  if FWebSocketServer <> nil then
  begin
    FWebSocketServer.Free;
  end;

  inherited Destroy;
end;

procedure TCableWebSocketAsyncServer.InitializeChannels;
begin
  // Here, initialize your channels and add them to the FChannelDict
  // Example:
  FChannelDict.Add('ChatChannel', TChatChannel.Create);
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
        if Self.FWsTokenDict.Remove(lWsUserID) then
          Self.FWsConnectionDict.Remove(QConnectionID);
      end;
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

procedure TCableWebSocketAsyncServer.WsTokenDictUpdate(QConnectionID: int64; UserName: RawUtf8);
var
  lWSToken: TWsToken;
  lWsUserID: RawUtf8;
begin
  TMonitor.Enter(Self);
  try
    if UserName <> '' then
    begin
      if Self.FWsConnectionDict.TryGetValue(QConnectionID, lWsUserID) then
      begin
        if Self.FWsTokenDict.Remove(lWsUserID) then
        begin
          Self.FWsConnectionDict.Remove(QConnectionID);
          lWSToken := TWsToken.Create;
          lWSToken.WsUserID := ToUtf8(QConnectionID);
          lWSToken.ConnectionID := QConnectionID;
          lWSToken.UserName := UserName;
          Self.FWsTokenDict.Add(lWSToken.WsUserID, lWSToken);
          Self.FWsConnectionDict.Add(QConnectionID, lWSToken.WsUserID);
        end;
      end;
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
  if not Self.FWsConnectionDict.TryGetValue(QConnectionID, lWsUserID) then 
    exit; //=>
  if lWsUserID = '' then 
    exit; //=>
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

procedure TCableWebSocketAsyncServer.PerformAction(const Action: string; const Data: IKeyValue<RawUtf8, Variant>);
var
  Channel: TChannelBase;
begin
  // Example logic to call the correct method in a channel
  if FChannelDict.TryGetValue(Data['channel'], Channel) then
  begin
    Channel.PerformAction(Action, Data);
  end
  else
  begin
    raise ESynException.CreateUtf8('Channel %s not found', [Data['channel']]);
  end;
end;

end.

