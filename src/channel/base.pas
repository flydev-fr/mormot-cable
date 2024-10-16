unit base;

interface

uses
  SysUtils, Classes, 
  mormot.core.variants, 
  mormot.core.json,
  mormot.core.rtti, 
  mormot.core.base, 
  mormot.core.collections,
  Callbacks, Naming, Periodic_Timers, Streams;

type
  TActionCableConnection = class
  private
    FIdentifiers: TArray<string>;
  public
    procedure Transmit(const AIdentifier, AMessage: string);
    property Identifiers: TArray<string> read FIdentifiers;
  end;

  TActionCableChannelBase = class(TInterfacedObject)
  private
    FParams: IKeyValue<string, Variant>;
    FConnection: TActionCableConnection;
    FIdentifier: string;
    FDeferSubscriptionConfirmationCounter: Integer;
    FRejectSubscription: Boolean;
    FSubscriptionConfirmationSent: Boolean;
    FParameterFilter: TObject; // Placeholder for actual parameter filter implementation
    FRTTI: TRttiCustom;
  protected
    procedure DelegateConnectionIdentifiers;
    procedure EnsureConfirmationSent;
    procedure TransmitSubscriptionConfirmation;
    procedure TransmitSubscriptionRejection;
    procedure RejectSubscription;
    procedure RunCallbacks(CallbackType: string);
    function ProcessableAction(const Action: string): Boolean;
    procedure DispatchAction(const Action: string; const Data: Variant);
    function ActionSignature(const Action: string; const Data: Variant): string;
    function ExtractAction(const Data: Variant): string;    
  public
    constructor Create(AConnection: TActionCableConnection; const AIdentifier: string; AParams: IKeyValue<string, Variant>);
    procedure Subscribed; virtual;
    procedure Unsubscribed; virtual;
    procedure Transmit(const Data: Variant); overload;
    procedure Transmit(const Data: Variant; const Via: string); overload;
    procedure SubscribeToChannel;
    procedure UnsubscribeFromChannel;
    procedure PerformAction(const Data: Variant);
    property Params: IKeyValue<string, Variant> read FParams;
    property Connection: TActionCableConnection read FConnection;
    property Identifier: string read FIdentifier;
  end;

implementation

{ TActionCableConnection }

procedure TActionCableConnection.Transmit(const AIdentifier, AMessage: string);
begin
  // Implementation for transmitting messages to the client
end;

{ TActionCableChannelBase }

constructor TActionCableChannelBase.Create(AConnection: TActionCableConnection; const AIdentifier: string; AParams: IKeyValue<string, Variant>);
begin
  FConnection := AConnection;
  FIdentifier := AIdentifier;
  FParams := AParams;
  FDeferSubscriptionConfirmationCounter := 1;
  FRejectSubscription := False;
  FSubscriptionConfirmationSent := False;
  DelegateConnectionIdentifiers;
  FRTTI := Rtti.RegisterClass(Self.ClassType);
end;   

procedure TActionCableChannelBase.DelegateConnectionIdentifiers;
var
  Identifier: string;
  Prop: PRttiCustomProp;
  info: PRttiProps;
begin
  for Identifier in FConnection.Identifiers do
  begin
    Prop := FRTTI.Props.Find(Identifier);
    
  end;
end;

procedure TActionCableChannelBase.EnsureConfirmationSent;
begin
  if not FRejectSubscription then
  begin
    Dec(FDeferSubscriptionConfirmationCounter);
    if FDeferSubscriptionConfirmationCounter <= 0 then
      TransmitSubscriptionConfirmation;
  end;
end;

procedure TActionCableChannelBase.TransmitSubscriptionConfirmation;
begin
  if not FSubscriptionConfirmationSent then
  begin
    // Implement the logic to transmit the subscription confirmation
    FSubscriptionConfirmationSent := True;
  end;
end;

procedure TActionCableChannelBase.TransmitSubscriptionRejection;
begin
  // Implement the logic to transmit the subscription rejection
end;

procedure TActionCableChannelBase.RejectSubscription;
begin
  FRejectSubscription := True;
end;

procedure TActionCableChannelBase.RunCallbacks(CallbackType: string);
begin
  // Implement the logic to run the appropriate callbacks
end;

function TActionCableChannelBase.ProcessableAction(const Action: string): Boolean;
begin
  Result := not FRejectSubscription and (FRTTI.Props.Find(Action) <> nil);
end;
       
procedure TActionCableChannelBase.DispatchAction(const Action: string; const Data: Variant);
var
  Method: PRttiMethod;
  MethodParams: TRttiMethodArg;
  Args: TArray<TRttiVarData>;
  i: Integer;
begin
 
end;

function TActionCableChannelBase.ActionSignature(const Action: string; const Data: Variant): string;
begin
  Result := Format('%s#%s', [Self.ClassName, Action]);
  // more logic 
end;

function TActionCableChannelBase.ExtractAction(const Data: Variant): string;
var
  doc: IDocDict;
begin
  doc := DocDict(VariantToString(Data));
  Result := VariantToString(doc.Get('action'));
  if Result = '' then
    Result := 'receive';
end;

procedure TActionCableChannelBase.PerformAction(const Data: Variant);
var
  Action: string;
begin
  Action := ExtractAction(Data);
  if ProcessableAction(Action) then
  begin
    DispatchAction(Action, Data);
  end
  else
  begin
    // Log error 
  end;
end;

procedure TActionCableChannelBase.Subscribed;
begin
  // Override in subclasses
end;

procedure TActionCableChannelBase.Unsubscribed;
begin
  // Override in subclasses
end;

procedure TActionCableChannelBase.Transmit(const Data: Variant);
begin
  Transmit(Data, '');
end;

procedure TActionCableChannelBase.Transmit(const Data: Variant; const Via: string);
begin
  // Implement the logic to transmit the data
end;

procedure TActionCableChannelBase.SubscribeToChannel;
begin
  RunCallbacks('subscribe');
  Subscribed;
  if FRejectSubscription then
    RejectSubscription;
  EnsureConfirmationSent;
end;

procedure TActionCableChannelBase.UnsubscribeFromChannel;
begin
  RunCallbacks('unsubscribe');
  Unsubscribed;
end;

end.

