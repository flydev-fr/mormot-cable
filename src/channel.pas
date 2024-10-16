unit channel;

interface

uses
  sysutils,
  mormot.core.base,
  mormot.net.ws.server;

type
  TBaseChannel = class
  private
    FConnection: TWebSocketServerSocket;
    FIdentifier: RawUtf8;
    FParams: variant;
  public
    constructor Create(Connection: TWebSocketServerSocket; const Identifier: RawUtf8; Params: variant);
    procedure PerformAction(const Action: string; Data: variant); virtual;
    procedure Subscribed; virtual;
    procedure Unsubscribed; virtual;
  end;

implementation
  
constructor TBaseChannel.Create(Connection: TWebSocketServerSocket; const Identifier: RawUtf8; Params: variant);
begin
  FConnection := Connection;
  FIdentifier := Identifier;
  FParams := Params;
end;

procedure TBaseChannel.PerformAction(const Action: string; Data: variant);
begin
  // Override in subclasses to handle specific actions
end;

procedure TBaseChannel.Subscribed;
begin
  // Override in subclasses to handle subscription
end;

procedure TBaseChannel.Unsubscribed;
begin
  // Override in subclasses to handle unsubscription
end;

type
  TChatChannel = class(TBaseChannel)
  private
    FRoom: TObject; // Placeholder for actual room object
  public
    procedure Subscribed; override;
    procedure Speak(Data: variant);
  end;

procedure TChatChannel.Subscribed;
begin
  inherited Subscribed;
  // Initialize the room object based on FParams
  // FRoom := GetRoomFromParams(FParams);
end;

procedure TChatChannel.Speak(Data: variant);
begin
  // Handle the speak action
  // FRoom.Speak(Data, User);
end;

end.
