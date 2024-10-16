unit ws_handler;

interface

uses
  sysutils,
  mormot.core.base,
  mormot.net.http,
  mormot.net.server,
  mormot.net.ws.core,
  mormot.net.ws.server;

type
  TWebSocketHandler = class
  private
    FServer: TWebSocketServerRest;
  public
    constructor Create(const aPort: integer);
    procedure HandleRequest(Ctxt: THttpServerRequest); virtual;
    procedure DoConnect(Sender: TWebSocketServerSocket);
    procedure DoDisconnect(Sender: TWebSocketServerSocket);
    destructor Destroy; override;
  end;

implementation  

uses
  mormot.core.os,
  mormot.core.text;

constructor TWebSocketHandler.Create(const aPort: integer);
begin
  FServer := TWebSocketServerRest.Create(
    IntToStr(aPort), nil, nil, 'WebSocketHandler', 'cable', '', True);
  FServer.OnWebSocketConnect := DoConnect;
  FServer.OnWebSocketDisconnect := DoDisconnect;
end;

procedure TWebSocketHandler.HandleRequest(Ctxt: THttpServerRequest);
begin
  // Handle WebSocket requests here
  ConsoleWrite('%: %', ['handleRequest', ctxt.UserAgent], ccMagenta);
end;

procedure TWebSocketHandler.DoConnect(Sender: TWebSocketServerSocket);
begin
  // Handle new WebSocket connections
  ConsoleWrite('DoConnect', ccLightCyan);
end;

procedure TWebSocketHandler.DoDisconnect(Sender: TWebSocketServerSocket);
begin
  // Handle WebSocket disconnections
  ConsoleWrite('DoDisconnect', ccDarkGray);
end;

destructor TWebSocketHandler.Destroy;
begin
  FServer.Free;
  inherited Destroy;
end;

end.
