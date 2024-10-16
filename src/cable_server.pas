unit cable_server;

interface

uses
  sysutils,
  classes,
  mormot.core.base,
  mormot.core.os,
  mormot.core.rtti,
  mormot.core.log,
  mormot.core.text,
  mormot.core.json,
  mormot.core.collections,
  mormot.core.variants,
  mormot.core.unicode,
  mormot.db.raw.sqlite3,
  mormot.db.raw.sqlite3.static,
  mormot.orm.core,
  mormot.rest.http.server,
  mormot.rest.sqlite3,
  mormot.rest.server, 
  mormot.net.ws.core,
  mormot.net.ws.server,
  MVCModel,
  MVCViewModel,
  ws_server,
  token;

type  
  TActionCableServer = class
  private
    FHttpServer: TCableWebSocketAsyncServer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure InitMVCApp(var aApplication: TBlogApplication);
    procedure Start;
    procedure Stop;
    procedure HandleIncomingMessage(Context: TWebSocketServerSocket; const Msg: RawUtf8);    
  public
    property HttpServer: TCableWebSocketAsyncServer 
      read FHttpServer write FHttpServer;      
  end;

implementation  

{ TActionCableServer }
  
constructor TActionCableServer.Create;
var
  aApplication: TBlogApplication;
begin
  InitMVCApp(aApplication);

  fHttpServer := TCableWebSocketAsyncServer.Create(aApplication);  
end;

destructor TActionCableServer.Destroy;
begin
  fHttpServer.Free;
  inherited Destroy;
end;

procedure TActionCableServer.HandleIncomingMessage(Context: TWebSocketServerSocket; const Msg: RawUtf8);
var
  JsonMsg: variant;
  Channel, Data: RawUtf8;
begin
  JsonMsg := _JsonFast(Msg);
  Channel := JsonMsg.channel;
  Data := JsonMsg.data;
  // Process the incoming message and perform the desired action
  // For example, updating some shared state or broadcasting to other clients
  FHttpServer.Broadcast(Channel, Data);
end;

procedure TActionCableServer.InitMVCApp(var aApplication: TBlogApplication);
var
  aModel: TOrmModel;
  aServer: TRestServerDB;
  aHTTPServer: TRestHttpServer;
  LogFamily: TSynLogFamily;
begin
  aModel := CreateModel;
  try
    aServer := TRestServerDB.Create(
      aModel, ChangeFileExt(Executable.ProgramFileName, '.db'));
    try
      aServer.DB.Synchronous := smNormal;
      aServer.DB.LockingMode := lmExclusive;
      aServer.Server.CreateMissingTables;
      aApplication := TBlogApplication.Create;
      try
        aApplication.Start(aServer);
        aHTTPServer := TRestHttpServer.Create('8092', aServer, '+',
          HTTP_DEFAULT_MODE, nil, 16, secNone, '', '', HTTPSERVER_DEBUG_OPTIONS);
        try
          aHTTPServer.RootRedirectToURI('blog/default'); // redirect / to blog/default
          aServer.RootRedirectGet := 'blog/default';     // redirect blog to blog/default
          writeln('"MVC Blog Server" launched on port 8092 using ',
            aHttpServer.HttpServer.ClassName);
          writeln(#10'You can check http://localhost:8092/blog/mvc-info for information');
          writeln('or point to http://localhost:8092 to access the web app.');
          writeln(#10'Press [Enter] or ^C to close the server.'#10);
          //ConsoleWaitForEnterKey;
          //writeln('HTTP server shutdown...');
        finally
          //aHTTPServer.Free;
        end;
      finally
        //aApplication.Free;
      end;
    finally
      //aServer.Free;
    end;
  finally
    //aModel.Free;
  end;
end;

procedure TActionCableServer.Start;
var
  result: boolean;
begin
  result := FHttpServer.Start;
end;

procedure TActionCableServer.Stop;
var
  result: boolean;
begin
  result := FHttpServer.Stop;
end;

end.
