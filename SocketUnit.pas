unit SocketUnit2;

interface

uses Windows, Winsock;

type
  TClientSocket = class(TObject)
  private
    FAddress: pansichar;
    FData: pointer;
    FTag: integer;
    FConnected: boolean;
    function GetLocalAddress: ansistring;
    function GetLocalPort: integer;
    function GetRemoteAddress: ansistring;
    function GetRemotePort: integer;
  protected
    FSocket: TSocket;
  public
    function set_nonblocking(non_blocking: boolean): boolean;
    function enable_keepalive(): boolean;
    function set_timeout(timeout: integer): boolean;
    procedure Connect(Address: ansistring; Port: integer);
    property Connected: boolean read FConnected;
    property Data: pointer read FData write FData;
    destructor Destroy; override;
    procedure Disconnect;
    function Idle(Seconds: integer): boolean;
    property LocalAddress: ansistring read GetLocalAddress;
    property LocalPort: integer read GetLocalPort;
    function ReceiveBuffer(var Buffer; BufferSize: integer): integer;
    function ReceiveLength: integer;
    function ReceiveString: ansistring;
    property RemoteAddress: ansistring read GetRemoteAddress;
    property RemotePort: integer read GetRemotePort;
    function SendBuffer(var Buffer; BufferSize: integer): integer;
    function SendString(Buffer: ansistring): integer;
    property Socket: TSocket read FSocket;
    property Tag: integer read FTag write FTag;
  end;

  TServerSocket = class(TObject)
  private
    FListening: boolean;
    function GetLocalAddress: ansistring;
    function GetLocalPort: integer;
  protected
    FSocket: TSocket;
  public
    function Accept: TClientSocket;
    destructor Destroy; override;
    procedure Disconnect;
    procedure Idle;
    procedure Listen(Port: integer);
    property Listening: boolean read FListening;
    property LocalAddress: ansistring read GetLocalAddress;
    property LocalPort: integer read GetLocalPort;
  end;

var
  WSAData: TWSAData;

implementation

const
  SO_KEEPALIVE = 1;
  TCP_KEEPIDLE = 5;
  TCP_KEEPINTVL = 3;
  TCP_KEEPCNT = 3;

function TClientSocket.set_nonblocking(non_blocking: boolean): boolean;
var
  mode: integer;
begin
  if (non_blocking = true) then
  begin
    mode := 1;
  end
  else
  begin
    mode := 0;
  end;
  result := (ioctlsocket(FSocket, FIONBIO, mode) = 0);
end;

function TClientSocket.enable_keepalive(): boolean;
var
  yes: integer;
  Idle: integer;
  interval: integer;
  maxpkt: integer;
begin
  result := false;
  yes := 1;
  if setsockopt(FSocket, SOL_SOCKET, SO_KEEPALIVE, @yes, 4) = 0 then
  begin
    Idle := 15;
    if setsockopt(FSocket, IPPROTO_TCP, TCP_KEEPIDLE, @Idle, 4) = 0 then
    begin
      interval := 10;
      if setsockopt(FSocket, IPPROTO_TCP, TCP_KEEPINTVL, @interval, 4) = 0 then
      begin
        maxpkt := 10;
        if setsockopt(FSocket, IPPROTO_TCP, TCP_KEEPCNT, @maxpkt, 4) = 0 then
        begin
          result := true;
        end;
      end;
    end;
  end;
end;

function TClientSocket.set_timeout(timeout: integer): boolean;
var
  tv: timeval;
begin
  result := false;
  tv.tv_usec := timeout;
  tv.tv_sec := 0;
  if setsockopt(FSocket, SOL_SOCKET, SO_RCVTIMEO, @timeout, sizeof(timeout)) = 0
  then
  begin
    tv.tv_usec := timeout;
    tv.tv_sec := 0;
    if setsockopt(FSocket, SOL_SOCKET, SO_SNDTIMEO, @timeout, sizeof(timeout)) = 0
    then
      result := true;
  end;
end;

procedure TClientSocket.Connect(Address: ansistring; Port: integer);
var
  SockAddrIn: TSockAddrIn;
  HostEnt: PHostEnt;
  arg: integer;
  FDSetW: TFDSet;
  FDSetE: TFDSet;
  timeval: TTimeVal;
const
  FTimeOutConnect: Cardinal = 120000;
begin
  Disconnect;
  FAddress := pansichar(Address);
  FSocket := Winsock.Socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
  SockAddrIn.sin_family := AF_INET;
  SockAddrIn.sin_port := htons(Port);
  SockAddrIn.sin_addr.s_addr := inet_addr(FAddress);
  if (DWORD(SockAddrIn.sin_addr.s_addr) = INADDR_NONE) then
  begin
    HostEnt := gethostbyname(FAddress);
    if HostEnt = nil then
    begin
      Exit;
    end;
    SockAddrIn.sin_addr.s_addr := Longint(PLongint(HostEnt^.h_addr_list^)^);
  end;

  arg := 1;
  if ioctlsocket(FSocket, FIONBIO, arg) = no_error then
  begin
    if Winsock.Connect(FSocket, SockAddrIn, sizeof(SockAddrIn)) <> 0 then
    begin
      arg := 0;
      if ioctlsocket(FSocket, FIONBIO, arg) = no_error then
      begin
        FD_ZERO(FDSetW);
        FD_ZERO(FDSetE);
        FD_SET(FSocket, FDSetW);
        FD_SET(FSocket, FDSetE);
        timeval.tv_sec := 0;
        timeval.tv_usec := FTimeOutConnect;
        select(0, nil, @FDSetW, @FDSetE, @timeval);
        if FD_ISSET(FSocket, FDSetW) then
        begin
          FConnected := true;
        end;
      end;
    end;

  end;
end;

procedure TClientSocket.Disconnect;
begin
  closesocket(FSocket);
  FConnected := false;
end;

function TClientSocket.GetLocalAddress: ansistring;
var
  SockAddrIn: TSockAddrIn;
  Size: integer;
begin
  Size := sizeof(SockAddrIn);
  getsockname(FSocket, SockAddrIn, Size);
  result := inet_ntoa(SockAddrIn.sin_addr);
end;

function TClientSocket.GetLocalPort: integer;
var
  SockAddrIn: TSockAddrIn;
  Size: integer;
begin
  Size := sizeof(SockAddrIn);
  getsockname(FSocket, SockAddrIn, Size);
  result := ntohs(SockAddrIn.sin_port);
end;

function TClientSocket.GetRemoteAddress: ansistring;
var
  SockAddrIn: TSockAddrIn;
  Size: integer;
begin
  Size := sizeof(SockAddrIn);
  getpeername(FSocket, SockAddrIn, Size);
  result := inet_ntoa(SockAddrIn.sin_addr);
end;

function TClientSocket.GetRemotePort: integer;
var
  SockAddrIn: TSockAddrIn;
  Size: integer;
begin
  Size := sizeof(SockAddrIn);
  getpeername(FSocket, SockAddrIn, Size);
  result := ntohs(SockAddrIn.sin_port);
end;

function TClientSocket.Idle(Seconds: integer): boolean;
var
  FDset: TFDSet;
  timeval: TTimeVal;
begin
  if Seconds = 0 then
  begin
    FD_ZERO(FDset);
    FD_SET(FSocket, FDset);
    result := (select(0, @FDset, nil, nil, nil) > 0);
  end
  else
  begin
    timeval.tv_sec := 0;
    timeval.tv_usec := Seconds * 1000;
    FD_ZERO(FDset);
    FD_SET(FSocket, FDset);
    result := (select(0, @FDset, nil, nil, @timeval) > 0);
  end;
end;

function TClientSocket.ReceiveLength: integer;
begin
  result := ReceiveBuffer(pointer(nil)^, -1);
end;

function TClientSocket.ReceiveBuffer(var Buffer; BufferSize: integer): integer;
begin
  if BufferSize = -1 then
  begin
    if ioctlsocket(FSocket, FIONREAD, result) = SOCKET_ERROR then
    begin
      result := SOCKET_ERROR;
      // Disconnect;
    end;
  end
  else
  begin
    result := recv(FSocket, Buffer, BufferSize, 0);
    if result = 0 then
    begin
      // Disconnect;
    end;
    if result = SOCKET_ERROR then
    begin
      result := WSAGetLastError;
      if result = WSAEWOULDBLOCK then
      begin
        result := 0;
      end
      else
      begin
        result := 0;
        // Disconnect;
      end;
    end;
  end;
end;

function TClientSocket.ReceiveString: ansistring;
var
  t: ansistring;
  answer: Integer;
  sizebuffer: dword;
begin
  result := '';
  sizebuffer := 0;

  ReceiveBuffer(sizebuffer, sizeof(sizebuffer));
  if sizebuffer > 0 then begin

    SetLength(t, 8192);
    if Length(t) = 8192 then begin
      while true do begin
        answer := ReceiveBuffer(pointer(t)^, Length(t));
        if (answer = 0) or (answer = -1) then begin
          Break;
        end;
        if answer > 0 then begin
          result := result + copy(t, 1, answer);
        end;

        if Length(result) >= sizebuffer then
          Break;

      end;

    end;
  end;
end;

function TClientSocket.SendBuffer(var Buffer; BufferSize: integer): integer;
var
  ErrorCode: integer;
begin
  result := send(FSocket, Buffer, BufferSize, 0);
  if result = SOCKET_ERROR then
  begin
    ErrorCode := WSAGetLastError;
    if (ErrorCode = WSAEWOULDBLOCK) then
    begin
      result := -1;
    end
    else
    begin
      result := -1;
      // Disconnect;
    end;
  end;
end;

function TClientSocket.SendString(Buffer: ansistring): integer;
var
  answer, totalansw: Integer;
  l: DWORD;
begin
  result := 0;
  totalansw := 0;

  l := Length(Buffer);

  Buffer := PansiChar(@l)^ +
  PansiChar(Pointer(dword(@l) + 1))^ +
  PansiChar(Pointer(dword(@l) + 2))^ +
  PansiChar(Pointer(dword(@l) + 3))^ + Buffer;
  while true do begin
    if Length(Buffer) > 0 then begin
      answer := SendBuffer(pointer(Buffer)^, Length(Buffer));
      if (answer = 0) or (answer = -1) then begin
        Break;
      end;

      if answer > 0 then begin
        totalansw := totalansw + answer;
        Delete(Buffer, 1, answer);
      end;
    end else break;
  end;
  result := totalansw;
end;

destructor TClientSocket.Destroy;
begin
  Disconnect;
  inherited Destroy;
end;

procedure TServerSocket.Listen(Port: integer);
var
  SockAddrIn: TSockAddrIn;
begin
  FSocket := Socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
  SockAddrIn.sin_family := AF_INET;
  SockAddrIn.sin_addr.s_addr := htonl(INADDR_ANY);
  SockAddrIn.sin_port := htons(Port);
  if bind(FSocket, SockAddrIn, sizeof(SockAddrIn)) = 0 then
  begin
    if Winsock.Listen(FSocket, SOMAXCONN) = 0 then
      FListening := true;
  end;
end;

function TServerSocket.GetLocalAddress: ansistring;
var
  SockAddrIn: TSockAddrIn;
  Size: integer;
begin
  Size := sizeof(SockAddrIn);
  getsockname(FSocket, SockAddrIn, Size);
  result := inet_ntoa(SockAddrIn.sin_addr);
end;

function TServerSocket.GetLocalPort: integer;
var
  SockAddrIn: TSockAddrIn;
  Size: integer;
begin
  Size := sizeof(SockAddrIn);
  getsockname(FSocket, SockAddrIn, Size);
  result := ntohs(SockAddrIn.sin_port);
end;

procedure TServerSocket.Idle;
var
  FDset: TFDSet;
begin
  FD_ZERO(FDset);
  FD_SET(FSocket, FDset);
  select(0, @FDset, nil, nil, nil);
end;

function TServerSocket.Accept: TClientSocket;
var
  Size: integer;
  SockAddr: TSockAddr;
begin
  result := TClientSocket.Create;
  Size := sizeof(TSockAddr);
  result.FSocket := Winsock.Accept(FSocket, @SockAddr, @Size);
  if result.FSocket = INVALID_SOCKET then
  begin
    Disconnect;
    result.FConnected := false;
  end
  else
  begin
    result.FConnected := true;
  end;
end;

procedure TServerSocket.Disconnect;
begin
  FListening := false;
  closesocket(FSocket);
end;

destructor TServerSocket.Destroy;
begin
  Disconnect;
  inherited Destroy;
end;

initialization

WSAStartUp(257, WSAData);

finalization

WSACleanup;

end.
