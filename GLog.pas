{ ***************************************************************************
  GLogger - High-Performance Thread-Safe Logger for Delphi
  
  Copyright (c) 2025 GLogger Contributors
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
*************************************************************************** }
unit GLog;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  System.SyncObjs, System.IOUtils, System.Threading, Winapi.Windows,
  System.Messaging;

type
  TLogLevel = (llDebug, llInfo, llWarning, llError);
  TLogOutput = (loConsole, loFile, loBoth);

  TLogMessage = record
    TimeStamp: TDateTime;
    Level: TLogLevel;
    Message: string;
    ThreadId: Cardinal;
  end;

  TThreadSafeQueue<T> = class
  private
    FQueue: TQueue<T>;
    FLock: TCriticalSection;
    FEvent: TEvent;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(const Item: T);
    function Dequeue(out Item: T; TimeoutMs: Cardinal = INFINITE): Boolean;
    function Count: Integer;
  end;

  TGLogger = class
  private
    FQueue: TThreadSafeQueue<TLogMessage>;
    FTask: ITask;
    FStopSignal: TEvent;
    FLogFile: string;
    FLogDirectory: string;
    FLogOutput: TLogOutput;
    FMaxFileSize: Int64;
    FAutoRotate: Boolean;
    FColorEnabled: Boolean;
    FBatchSize: Integer;
    FStreamLock: TCriticalSection;

    procedure ProcessMessages;
    procedure ProcessBatch(const Messages: TArray<TLogMessage>);
    procedure WriteToConsole(const AMessage: string; ALevel: TLogLevel);
    procedure WriteToFile(const AMessage: string);
    procedure WriteBatchToFile(const Messages: TArray<string>);
    function FormatLogMessage(const Msg: TLogMessage): string;
    function GetLevelColor(ALevel: TLogLevel): Word;
    function GetLevelString(ALevel: TLogLevel): string;
    procedure RotateLogFile;
    procedure SetConsoleColor(Color: Word);
    procedure ResetConsoleColor;
    procedure AddLogMessage(ALevel: TLogLevel; const AMessage: string);
    function CreateLogFileName: string;
    procedure EnsureLogDirectory;

  public
    constructor Create(const ALogDirectory: string = 'LOGS';
                      AOutput: TLogOutput = loBoth;
                      AMaxFileSize: Int64 = 10 * 1024 * 1024;
                      ABatchSize: Integer = 50);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;

    procedure WriteDebugLogLn(const AFormat: string; const Args: array of const); overload;
    procedure WriteDebugLogLn(const AMessage: string); overload;
    procedure WriteInfoLogLn(const AFormat: string; const Args: array of const); overload;
    procedure WriteInfoLogLn(const AMessage: string); overload;
    procedure WriteWarningLogLn(const AFormat: string; const Args: array of const); overload;
    procedure WriteWarningLogLn(const AMessage: string); overload;
    procedure WriteErrorLogLn(const AFormat: string; const Args: array of const); overload;
    procedure WriteErrorLogLn(const AMessage: string); overload;

    property LogFile: string read FLogFile;
    property LogDirectory: string read FLogDirectory write FLogDirectory;
    property LogOutput: TLogOutput read FLogOutput write FLogOutput;
    property ColorEnabled: Boolean read FColorEnabled write FColorEnabled;
    property AutoRotate: Boolean read FAutoRotate write FAutoRotate;
    property MaxFileSize: Int64 read FMaxFileSize write FMaxFileSize;
    property BatchSize: Integer read FBatchSize write FBatchSize;
  end;

var
  GLogger: TGLogger;

implementation

{ TThreadSafeQueue<T> }
constructor TThreadSafeQueue<T>.Create;
begin
  inherited Create;
  FQueue := TQueue<T>.Create;
  FLock := TCriticalSection.Create;
  FEvent := TEvent.Create(nil, False, False, '');
end;

destructor TThreadSafeQueue<T>.Destroy;
begin
  FreeAndNil(FEvent);
  FreeAndNil(FLock);
  FreeAndNil(FQueue);
  inherited;
end;

procedure TThreadSafeQueue<T>.Enqueue(const Item: T);
begin
  FLock.Enter;
  try
    FQueue.Enqueue(Item);
    FEvent.SetEvent;
  finally
    FLock.Leave;
  end;
end;

function TThreadSafeQueue<T>.Dequeue(out Item: T; TimeoutMs: Cardinal): Boolean;
begin
  Result := False;
  if FEvent.WaitFor(TimeoutMs) = wrSignaled then
  begin
    FLock.Enter;
    try
      if FQueue.Count > 0 then
      begin
        Item := FQueue.Dequeue;
        Result := True;
        if FQueue.Count > 0 then
          FEvent.SetEvent;
      end;
    finally
      FLock.Leave;
    end;
  end;
end;

function TThreadSafeQueue<T>.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FQueue.Count;
  finally
    FLock.Leave;
  end;
end;

{ TGLogger }
constructor TGLogger.Create(const ALogDirectory: string;
  AOutput: TLogOutput; AMaxFileSize: Int64; ABatchSize: Integer);
begin
  inherited Create;
  FQueue := TThreadSafeQueue<TLogMessage>.Create;
  FStopSignal := TEvent.Create(nil, True, False, '');
  FStreamLock := TCriticalSection.Create;
  FLogDirectory := ALogDirectory;
  if FLogDirectory = '' then
    FLogDirectory := 'LOGS';
  EnsureLogDirectory;
  FLogFile := CreateLogFileName;
  FLogOutput := AOutput;
  FMaxFileSize := AMaxFileSize;
  FAutoRotate := True;
  FColorEnabled := True;
  FBatchSize := ABatchSize;
end;

destructor TGLogger.Destroy;
begin
  Stop;
  FreeAndNil(FStreamLock);
  FreeAndNil(FQueue);
  FreeAndNil(FStopSignal);
  inherited;
end;

procedure TGLogger.Start;
begin
  if Assigned(FTask) and (FTask.Status in [TTaskStatus.Running, TTaskStatus.WaitingToRun]) then
    Exit;
  FStopSignal.ResetEvent;
  FTask := TTask.Run(
    procedure
    begin
      ProcessMessages;
    end
  );
end;

procedure TGLogger.Stop;
begin
  if Assigned(FTask) then
  begin
    FStopSignal.SetEvent;
    if TTask.WaitForAll([FTask], 5000) then
    begin
    end
    else
    begin
      if FTask.Status = TTaskStatus.Running then
        FTask.Cancel;
    end;
    FTask := nil;
  end;
end;

procedure TGLogger.ProcessMessages;
var
  Messages: TArray<TLogMessage>;
  Msg: TLogMessage;
  Count: Integer;
  StopCheck: Integer;
begin
  StopCheck := 0;
  while True do
  begin
    Inc(StopCheck);
    if (StopCheck mod 5 = 0) and (FStopSignal.WaitFor(0) = wrSignaled) then
      Break;
    SetLength(Messages, 0);
    Count := 0;
    if FQueue.Dequeue(Msg, 50) then
    begin
      SetLength(Messages, FBatchSize);
      Messages[0] := Msg;
      Count := 1;
      while (Count < FBatchSize) and FQueue.Dequeue(Msg, 0) do
      begin
        Messages[Count] := Msg;
        Inc(Count);
      end;
      SetLength(Messages, Count);
      ProcessBatch(Messages);
    end
    else
    begin
      if FStopSignal.WaitFor(0) = wrSignaled then
        Break;
    end;
  end;

  SetLength(Messages, FQueue.Count + 10);
  Count := 0;
  while FQueue.Dequeue(Msg, 0) do
  begin
    if Count >= Length(Messages) then
      SetLength(Messages, Length(Messages) * 2);
    Messages[Count] := Msg;
    Inc(Count);
  end;
  if Count > 0 then
  begin
    SetLength(Messages, Count);
    ProcessBatch(Messages);
  end;
end;

procedure TGLogger.ProcessBatch(const Messages: TArray<TLogMessage>);
var
  i: Integer;
  FormattedMessages: TArray<string>;
begin
  if Length(Messages) = 0 then
    Exit;
  SetLength(FormattedMessages, Length(Messages));
  try
    for i := 0 to High(Messages) do
      FormattedMessages[i] := FormatLogMessage(Messages[i]);
    case FLogOutput of
      loConsole:
      begin
        for i := 0 to High(Messages) do
          WriteToConsole(FormattedMessages[i], Messages[i].Level);
      end;
      loFile:
        WriteBatchToFile(FormattedMessages);
      loBoth:
      begin
        for i := 0 to High(Messages) do
          WriteToConsole(FormattedMessages[i], Messages[i].Level);
        WriteBatchToFile(FormattedMessages);
      end;
    end;
  except
    on E: Exception do
      Writeln('Logger batch error: ' + E.Message);
  end;
end;

procedure TGLogger.WriteToConsole(const AMessage: string; ALevel: TLogLevel);
begin
  if FColorEnabled then
  begin
    SetConsoleColor(GetLevelColor(ALevel));
    Writeln(AMessage);
    ResetConsoleColor;
  end
  else
    Writeln(AMessage);
end;

procedure TGLogger.WriteToFile(const AMessage: string);
begin
  WriteBatchToFile([AMessage]);
end;

procedure TGLogger.WriteBatchToFile(const Messages: TArray<string>);
var
  i: Integer;
  AllData: TStringBuilder;
  Data: TBytes;
  FileStream: TFileStream;
begin
  if (FLogFile = '') or (Length(Messages) = 0) then
    Exit;
  FStreamLock.Enter;
  try
    try
      if FAutoRotate and FileExists(FLogFile) and
         (TFile.GetSize(FLogFile) > FMaxFileSize) then
        RotateLogFile;
      AllData := TStringBuilder.Create;
      try
        for i := 0 to High(Messages) do
          AllData.AppendLine(Messages[i]);
        Data := TEncoding.UTF8.GetBytes(AllData.ToString);
        if FileExists(FLogFile) then
          FileStream := TFileStream.Create(FLogFile, fmOpenWrite or fmShareDenyWrite)
        else
          FileStream := TFileStream.Create(FLogFile, fmCreate or fmShareDenyWrite);
        try
          FileStream.Seek(0, soEnd);
          FileStream.WriteBuffer(Data, Length(Data));
        finally
          FileStream.Free;
        end;
      finally
        AllData.Free;
      end;
    except
      on E: Exception do
      begin
        Writeln('Batch file logging error: ' + E.Message);
      end;
    end;
  finally
    FStreamLock.Leave;
  end;
end;

function TGLogger.FormatLogMessage(const Msg: TLogMessage): string;
begin
  Result := Format('[%s] [%s] [TID:%d] %s', [
    FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Msg.TimeStamp),
    GetLevelString(Msg.Level),
    Msg.ThreadId,
    Msg.Message
  ]);
end;

function TGLogger.GetLevelColor(ALevel: TLogLevel): Word;
begin
  case ALevel of
    llDebug:   Result := FOREGROUND_INTENSITY;
    llInfo:    Result := FOREGROUND_GREEN or FOREGROUND_INTENSITY;
    llWarning: Result := FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_INTENSITY;
    llError:   Result := FOREGROUND_RED or FOREGROUND_INTENSITY;
  else
    Result := FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE;
  end;
end;

function TGLogger.GetLevelString(ALevel: TLogLevel): string;
begin
  case ALevel of
    llDebug:   Result := 'DEBUG';
    llInfo:    Result := 'INFO ';
    llWarning: Result := 'WARN ';
    llError:   Result := 'ERROR';
  else
    Result := 'UNKN ';
  end;
end;

procedure TGLogger.RotateLogFile;
var
  BackupFile: string;
  Counter: Integer;
  BaseName: string;
  Extension: string;
begin
  Counter := 1;
  BaseName := ChangeFileExt(FLogFile, '');
  Extension := ExtractFileExt(FLogFile);
  repeat
    BackupFile := Format('%s_%d%s', [BaseName, Counter, Extension]);
    Inc(Counter);
  until not FileExists(BackupFile);
  try
    TFile.Move(FLogFile, BackupFile);
  except
    TFile.Delete(FLogFile);
  end;
end;

procedure TGLogger.SetConsoleColor(Color: Word);
var
  ConsoleHandle: THandle;
begin
  ConsoleHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if ConsoleHandle <> INVALID_HANDLE_VALUE then
    SetConsoleTextAttribute(ConsoleHandle, Color);
end;

procedure TGLogger.ResetConsoleColor;
begin
  SetConsoleColor(FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE);
end;

procedure TGLogger.AddLogMessage(ALevel: TLogLevel; const AMessage: string);
var
  Msg: TLogMessage;
begin
  Msg.TimeStamp := Now;
  Msg.Level := ALevel;
  Msg.Message := AMessage;
  Msg.ThreadId := GetCurrentThreadId;
  FQueue.Enqueue(Msg);
end;

procedure TGLogger.WriteDebugLogLn(const AFormat: string; const Args: array of const);
begin
  try
    AddLogMessage(llDebug, Format(AFormat, Args));
  except
    on E: Exception do
      AddLogMessage(llDebug, AFormat + ' [Format Error: ' + E.Message + ']');
  end;
end;

procedure TGLogger.WriteDebugLogLn(const AMessage: string);
begin
  AddLogMessage(llDebug, AMessage);
end;

procedure TGLogger.WriteInfoLogLn(const AFormat: string; const Args: array of const);
begin
  try
    AddLogMessage(llInfo, Format(AFormat, Args));
  except
    on E: Exception do
      AddLogMessage(llInfo, AFormat + ' [Format Error: ' + E.Message + ']');
  end;
end;

procedure TGLogger.WriteInfoLogLn(const AMessage: string);
begin
  AddLogMessage(llInfo, AMessage);
end;

procedure TGLogger.WriteWarningLogLn(const AFormat: string; const Args: array of const);
begin
  try
    AddLogMessage(llWarning, Format(AFormat, Args));
  except
    on E: Exception do
      AddLogMessage(llWarning, AFormat + ' [Format Error: ' + E.Message + ']');
  end;
end;

procedure TGLogger.WriteWarningLogLn(const AMessage: string);
begin
  AddLogMessage(llWarning, AMessage);
end;

procedure TGLogger.WriteErrorLogLn(const AFormat: string; const Args: array of const);
begin
  try
    AddLogMessage(llError, Format(AFormat, Args));
  except
    on E: Exception do
      AddLogMessage(llError, AFormat + ' [Format Error: ' + E.Message + ']');
  end;
end;

procedure TGLogger.WriteErrorLogLn(const AMessage: string);
begin
  AddLogMessage(llError, AMessage);
end;

function TGLogger.CreateLogFileName: string;
var
  AppName: string;
  DateTime: string;
begin
  AppName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  DateTime := FormatDateTime('yyyy-mm-dd_hh-nn-ss', Now);
  Result := TPath.Combine(FLogDirectory, Format('%s_%s.log', [AppName, DateTime]));
end;

procedure TGLogger.EnsureLogDirectory;
begin
  if not TPath.IsPathRooted(FLogDirectory) then
    FLogDirectory := TPath.Combine(ExtractFilePath(ParamStr(0)), FLogDirectory);
  if not TDirectory.Exists(FLogDirectory) then
    TDirectory.CreateDirectory(FLogDirectory);
end;

initialization
  GLogger := TGLogger.Create;
  GLogger.Start;

finalization
  FreeAndNil(GLogger);

end.
