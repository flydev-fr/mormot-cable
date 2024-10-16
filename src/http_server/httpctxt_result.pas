unit httpctxt_result;

interface

uses
  sysutils, classes,
  mormot.core.base,
  mormot.core.rtti;

type
  THTTPCtxt = class;
  THTTPResult = class;
  // Mount the routing function pattern
  TEvenControllerProcedure = procedure(QHTTPCtxt: THTTPCtxt; QHTTPResult: THTTPResult);
  // Create the control layer to get an object
  THTTPResultMode = (ResultJSON, TEXT, URL, OUTFILE, HTML); // Create a control layer to get an object.
  // standResult string, number, time, boolean
  // objResult returns an object
  // objListResult returns a TObjectList.
  // listResult returns a TList.
  // genericsListResult returns a TList<T> or an object.
  // genericsObjListResult TObjectList<T>.
  // arrayResult returns an array or dynamic array.
  TPersonDemo = class
  private
    FaName: RawUtf8;
    FAag: integer;
    FParent: RawUtf8;
  public
    property name: RawUtf8 read FaName write FaName;
    property age: integer read FAag write FAag;
    property Parent: RawUtf8 read FParent write FParent;
  end;

  TPersonRecord = record
  public
    name: RawUtf8;
    age: integer;
  end;
  
  // Keep it the same as TActionResult.
  THTTPResult = class
  private
    FResultSuccess: boolean;
    FResultStatus: cardinal;
    FResultCode: RawUtf8;
    FResultMsg: RawByteString;
    FResultOutMode: THTTPResultMode;
    FResultOut: RawUtf8;
    FResultObj: TObject;
    FResultTValue: TRttiVarData;
    FResultCount: integer;
    { Server returns a URL redirection }
    FResultRedirect: RawUtf8;
    FResultParams: RawUtf8;
    // Capture exception
    FResultException: RawUtf8;
    //
    FMethodRtti: TRttiMethod;
  public
    procedure SetHTTPResultTrue();
    procedure SetMethodRtti(QOneMethodRtti: TRttiMethod);
    destructor Destroy; override;
    function ResultToJson(): RawUtf8;

  published
    property ResultSuccess: boolean read FResultSuccess write FResultSuccess;
    property ResultStatus: cardinal read FResultStatus write FResultStatus;
    property ResultCode: RawUtf8 read FResultCode write FResultCode;
    property ResultMsg: RawByteString read FResultMsg write FResultMsg;
    property ResultOutMode: THTTPResultMode read FResultOutMode write FResultOutMode;
    property ResultOut: RawUtf8 read FResultOut write FResultOut;
    property ResultObj: TObject read FResultObj write FResultObj;
    property ResultTValue: TRttiVarData read FResultTValue write FResultTValue;
    property ResultCount: integer read FResultCount write FResultCount;
    property ResultRedirect: RawUtf8 read FResultRedirect write FResultRedirect;
    property ResultParams: RawUtf8 read FResultParams write FResultParams;
    property ResultException: RawUtf8 read FResultException write FResultException;
  end;
  
  THTTPCtxt = class
  private
    FConnectionID: int64; // HTTP request method GET, POST, etc.
    // HTTP request methods GET, POST, etc.
    FMethod: RawUtf8; // Which method to execute for the controller.
    // Which controller method to execute
    FControllerMethodName: RawUtf8; // The IP address of the client.
    // Client IP
    FClientIP: RawUtf8; // Client MAC address.
    // Client MAC address
    FClientMAC: RawUtf8; // URL path
    // URL path with parameters instead of parameters ?xxxx=zzzz
    FUrl: RawUtf8; // url without parameter ?
    // url without parameters ? ?xxxx=zzzz
    FUrlPath: RawUtf8; // URL path with parameter substitution ?
    // Parameters for the URL request
    FUrlParams: TStringList; // The header parameters of the URL request.
    // header parameters
    FHeadParamList: TStringList; // Get the format and encoding of the request data initiation.
    // Get the format and encoding of the request data origination
    FRequestContentType: RawUtf8; // Get the format and encoding of the request data initiation.
    FRequestContentTypeCharset: RawUtf8; // Get the format and encoding of the request data initiation.
    // The requested data
    FRequestInContent: RawByteString; // The request header.
    // The headers of the request
    FRequestInHeaders: RawByteString; // The data of the request.
    // The content of the HTTP request
    FOutContent: RawByteString; // The content of the HTTP request.
    // Get the format and encoding of the request return acceptance
    FRequestAccept: RawUtf8; // Get the format and encoding of the request return acceptance.
    FRequestAcceptCharset: RawUtf8; // Get the request return acceptance format and encoding.
    { custom head parsing }
    FResponCustHeaderList: RawByteString; { custom header parsing }
    FTokenUserCode: RawUtf8;
  public
    destructor Destroy; override;
    procedure SetUrlParams();
    procedure SetHeadParams();
    procedure SetInContent(qInContent: RawByteString);
  public
    procedure AddCustomerHead(QHead: RawUtf8; QConnect: RawUtf8);
    property ConnectionID: int64 read FConnectionID write FConnectionID;
    property URL: RawUtf8 read FUrl write FUrl;
    property URLPath: RawUtf8 read FUrlPath write FUrlPath;
    property ClientIP: RawUtf8 read FClientIP write FClientIP;
    property ClientMAC: RawUtf8 read FClientMAC write FClientMAC;
    property UrlParams: TStringList read FUrlParams write FUrlParams;
    property HeadParamList: TStringList read FHeadParamList write FHeadParamList;
    property RequestContentType: RawUtf8 read FRequestContentType write FRequestContentType;
    property RequestContentTypeCharset: RawUtf8 read FRequestContentTypeCharset write FRequestContentTypeCharset;
    property RequestInContent: RawByteString read FRequestInContent write FRequestInContent;
    property RequestInHeaders: RawByteString read FRequestInHeaders write FRequestInHeaders;
    property OutContent: RawByteString read FOutContent write FOutContent;
    property RequestAccept: RawUtf8 read FRequestAccept write FRequestAccept;
    property ResponCustHeaderList: RawByteString read FResponCustHeaderList write FResponCustHeaderList;
    property TokenUserCode: RawUtf8 read FTokenUserCode write FTokenUserCode;
    property Method: RawUtf8 read FMethod write FMethod;
    property ControllerMethodName: RawUtf8 read FControllerMethodName write FControllerMethodName;
    property RequestAcceptCharset: RawUtf8 read FRequestAcceptCharset write FRequestAcceptCharset;
  end;
  
function IsMultipartForm(QContentType: RawUtf8): boolean;
function SplitUrlSchemePathAndQuery(const pmcUrl: RawUtf8; out pmoUrlPath, pmoUrlQuery: RawUtf8): Boolean;
  
implementation

uses
  contnrs,
  mormot.core.os,
  mormot.core.json,
  mormot.core.text,
  mormot.core.unicode,
  mormot.core.collections;
        
const
  sMultiPartFormData = 'multipart/form-data';

function IsMultipartForm(QContentType: RawUtf8): boolean;
begin
  result := IdemPChar(pointer(QContentType), sMultiPartFormData);
  //Result := StrLIComp(PChar(QContentType), PChar(sMultiPartFormData), Length(sMultiPartFormData)) = 0;
end;
  
{ THTTPCtxt }

function SplitUrlSchemePathAndQuery(const pmcUrl: RawUtf8; out pmoUrlPath, pmoUrlQuery: RawUtf8): Boolean;
var
  p: PUtf8Char;
  urlQuery: PUtf8Char;
  urlPathLen: Integer;
begin
  p := PUtf8Char(Pointer(pmcUrl));
  if (p <> Nil) and (p^ = '/') then
    Inc(p)
  else
    Exit(False); //=>

  urlQuery := PosChar(p, '?');
  if urlQuery <> Nil then
  begin
    Inc(urlQuery);
    urlPathLen := urlQuery - p - 1;
    FastSetString(pmoUrlQuery, urlQuery, Length(p) - (urlQuery - p));
  end
  else
    urlPathLen := Length(p);

  FastSetString(pmoUrlPath, p, urlPathLen);
  Result := True;
end;

procedure THTTPCtxt.SetUrlParams();
var
  iUrl, i: integer;
  vUrlParams: string;
  vArr: TArray<string>;
begin
  // URL parameters
  iUrl := 0;
  vUrlParams := '';
  iUrl := PosEx('?', self.FUrl);
  if iUrl > 0 then
  begin
    vUrlParams := Copy(self.FUrl, iUrl + 1, Length(self.FUrl));
    // vUrlParams := decode(vUrlParams);
    vArr := vUrlParams.Split(['amp;', '&'], TStringSplitOptions.ExcludeEmpty);
    // If there is an '&' in the argument string, cut it first and 
    // parse it to make sure it's correct.
    for i := Low(vArr) to High(vArr) do
    begin
      self.FUrlParams.Add(vArr[i]);
    end;
  end
end;

procedure THTTPCtxt.SetHeadParams();
var
  P, S: PAnsiChar;
  vTagchar: string;
  tempStr: RawByteString;
  vHeadA, vHeadB, vValue: string;
begin
  P := pointer(self.RequestInHeaders);
  S := P;
  while not(S^ in [#0]) do
  begin
    if S^ in [':', '=', ';', #13, #10] then
    begin
      SetString(tempStr, P, S - P);
      vValue := tempStr;
      if S^ = ':' then
      begin
        vHeadA := Trim(tempStr);
      end
      else if S^ = '=' then
      begin
        vHeadB := Trim(tempStr);
      end
      else
      begin
        if (vHeadA = 'Content-Type') and (vHeadB = 'charset') then
        begin
          FRequestContentTypeCharset := vValue.ToUpper;
        end
        else if (vHeadA = 'Accept') and (vHeadB = 'charset') then
        begin
          FRequestAcceptCharset := vValue.ToUpper;
        end
        else if vHeadA <> '' then
        begin
          self.FHeadParamList.Add(vHeadA + '=' + Trim(vValue));
        end;
        if S^ = ';' then
        begin
          vHeadB := '';
        end
        else
        begin
          vHeadB := '';
          vHeadA := '';
        end;
      end;
      P := S;
      Inc(P);
    end;
    Inc(S);
  end;
end;

procedure THTTPCtxt.SetInContent(qInContent: RawByteString);
var
  vBytes: TBytes;
begin
  // Determine if it is a mulpart file
  if IsMultipartForm(self.FRequestContentType) then
  begin
    // No processing to self unit processing
    FRequestInContent := qInContent;
  end
  else if FRequestContentTypeCharset = 'UTF-8' then
  begin
    FRequestInContent := UTF8Decode(qInContent);
  end
  else if FRequestContentTypeCharset = 'UNICODE' then
  begin
    FRequestInContent := String(qInContent);
  end
  else if FRequestContentTypeCharset = 'GB2312' then
  begin
    vBytes := TEncoding.UTF8.GetBytes(qInContent);
    FRequestInContent := TEncoding.getencoding(936).GetString(vBytes);
  end
  else
    FRequestInContent := UTF8Decode(qInContent);
end;

procedure THTTPCtxt.AddCustomerHead(QHead: RawUtf8; QConnect: RawUtf8);
begin
  FResponCustHeaderList := FResponCustHeaderList + #13#10 + QHead + ':' + UTF8Encode(QConnect);
end;

destructor THTTPCtxt.Destroy;
begin
  inherited Destroy;
  FUrlParams.Clear;
  FHeadParamList.Clear;
  FUrlParams.Free;
  FHeadParamList.Free;
end;

{ THTTPResult }

destructor THTTPResult.Destroy;
// Object release
var
  i: integer;
  lListT: IList<TObject>;
  lObjListT: IList<TObject>;
  lList: TList;
  lObjList: TObjectList;
  prop: TRttiInfo;
begin
  (*if FResultObj <> nil then
  begin
    // Pan-List release
    if FMethodRtti.Name <> '' then
    begin
      prop.Kind = rkLString
      if FMethodRtti.ResultType = emOneMethodResultType.genericsListResult then
      begin
        if FMethodRtti.ResultCollectionsValueType = emOneMethodResultType.objResult then
        begin
          lListT := TList<TObject>(FResultObj);
          for i := 0 to lListT.Count - 1 do
          begin
            if lListT[i] <> nil then
              lListT[i].Free;
          end;
          lListT.Clear;
        end
        else
        begin
          FResultObj.Free;
        end;
      end
      else if FMethodRtti.ResultType = emOneMethodResultType.genericsObjListResult then
      begin
        if FMethodRtti.ResultCollectionsValueType = emOneMethodResultType.objResult then
        begin
          lObjListT := TObjectList<TObject>(FResultObj);
          if not lObjListT.OwnsObjects then
          begin
            // 自已释放
            for i := 0 to lObjListT.Count - 1 do
            begin
              if lObjListT[i] <> nil then
                lObjListT[i].Free;
            end;
          end;
          lObjListT.Clear;
        end
        else
        begin
          FResultObj.Free;
        end;
      end
      else if FMethodRtti.ResultType = emOneMethodResultType.listResult then
      begin
        lList := TList(FResultObj);
        // We have to traverse to determine if it's an object or not, but 
        // we don't deal with it here.
        // Mainly for string, int and other common types.
        // Free your own
        for i := 0 to lList.Count - 1 do
        begin
          if TObject(lList[i]) <> nil then
            TObject(lList[i]).Free;
        end;
        lList.Clear;
        FResultObj.Free;
      end
      else if FMethodRtti.ResultType = emOneMethodResultType.objListResult then
      begin
        if FMethodRtti.ResultCollectionsValueType = emOneMethodResultType.objResult then
        begin
          lObjList := TObjectList(FResultObj);
          if not lObjList.OwnsObjects then
          begin
            // 自已释放
            for i := 0 to lObjList.Count - 1 do
            begin
              if lObjList[i] <> nil then
                lObjList[i].Free;
            end;
          end;
          lObjListT.Clear;
          FResultObj.Free;
        end
        else
        begin
          FResultObj.Free;
        end;
      end
      else if FMethodRtti.ResultType = emOneMethodResultType.mapResult then
      begin
        // map如何释放，通过RTTI释放未处理
        if FMethodRtti.ResultCollectionsKeyType = emOneMethodResultType.objResult then
        begin
          FMethodRtti.ResultRtti.GetProperty('Keys').GetValue(self.FResultObj);
        end;
        if FMethodRtti.ResultCollectionsValueType = emOneMethodResultType.objResult then
        begin
          FMethodRtti.ResultRtti.GetProperty('Values').GetValue(self.FResultObj);
        end;
        FResultObj.Free;
      end
      else
      begin
        FResultObj.Free;
      end;
    end
    else
      FResultObj.Free;
    FResultObj := nil;
  end;
  *)
  inherited;
end;

function THTTPResult.ResultToJson: RawUtf8;
begin

end;

procedure THTTPResult.SetHTTPResultTrue;
begin

end;

procedure THTTPResult.SetMethodRtti(QOneMethodRtti: TRttiMethod);
begin

end;

end.
