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
program LogTest;

{$APPTYPE CONSOLE}

uses
  FastMM5,
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.SyncObjs,
  System.Diagnostics,
  System.IOUtils,
  System.DateUtils,
  System.Math,
  Winapi.Windows,
  System.Types,
  System.Generics.Collections,
  GLog in 'GLog.pas';

type
  THTTPRequest = record
    Method: string;
    URL: string;
    UserAgent: string;
    IP: string;
    ContentLength: Integer;
    ProcessingTimeMs: Integer;
    StatusCode: Integer;
    RequestId: string;
  end;

  TTestScenario = (
    tsBasicLogging,
    tsHighThroughput,
    tsMultiThreadStress,
    tsMemoryPressure,
    tsFileRotation,
    tsErrorHandling,
    tsLongRunning,
    tsIOPSimulation
  );

  TPerformanceMetrics = class
  private
    FLock: TCriticalSection;
    FTotalMessages: Int64;
    FErrorCount: Int64;
    FStartTime: TDateTime;
    FMinLatencyMs: Double;
    FMaxLatencyMs: Double;
    FSumLatencyMs: Double;
    FLatencyCount: Int64;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RecordMessage;
    procedure RecordError;
    procedure RecordLatency(LatencyMs: Double);

    function GetTotalMessages: Int64;
    function GetErrorRate: Double;
    function GetMessagesPerSecond: Double;
    function GetAverageLatency: Double;
    function GetMinLatency: Double;
    function GetMaxLatency: Double;

    procedure Reset;
    procedure PrintStats;
  end;

var
  Metrics: TPerformanceMetrics;
  TestRunning: Boolean = True;

{ TPerformanceMetrics }

constructor TPerformanceMetrics.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
  Reset;
end;

destructor TPerformanceMetrics.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

procedure TPerformanceMetrics.RecordMessage;
begin
  FLock.Enter;
  try
    Inc(FTotalMessages);
  finally
    FLock.Leave;
  end;
end;

procedure TPerformanceMetrics.RecordError;
begin
  FLock.Enter;
  try
    Inc(FErrorCount);
  finally
    FLock.Leave;
  end;
end;

procedure TPerformanceMetrics.RecordLatency(LatencyMs: Double);
begin
  FLock.Enter;
  try
    if FLatencyCount = 0 then
    begin
      FMinLatencyMs := LatencyMs;
      FMaxLatencyMs := LatencyMs;
    end
    else
    begin
      FMinLatencyMs := Min(FMinLatencyMs, LatencyMs);
      FMaxLatencyMs := Max(FMaxLatencyMs, LatencyMs);
    end;
    FSumLatencyMs := FSumLatencyMs + LatencyMs;
    Inc(FLatencyCount);
  finally
    FLock.Leave;
  end;
end;

function TPerformanceMetrics.GetTotalMessages: Int64;
begin
  FLock.Enter;
  try
    Result := FTotalMessages;
  finally
    FLock.Leave;
  end;
end;

function TPerformanceMetrics.GetErrorRate: Double;
begin
  FLock.Enter;
  try
    if FTotalMessages > 0 then
      Result := (FErrorCount / FTotalMessages) * 100
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

function TPerformanceMetrics.GetMessagesPerSecond: Double;
var
  ElapsedSeconds: Double;
begin
  FLock.Enter;
  try
    ElapsedSeconds := SecondsBetween(Now, FStartTime);
    if ElapsedSeconds > 0 then
      Result := FTotalMessages / ElapsedSeconds
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

function TPerformanceMetrics.GetAverageLatency: Double;
begin
  FLock.Enter;
  try
    if FLatencyCount > 0 then
      Result := FSumLatencyMs / FLatencyCount
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

function TPerformanceMetrics.GetMinLatency: Double;
begin
  FLock.Enter;
  try
    Result := FMinLatencyMs;
  finally
    FLock.Leave;
  end;
end;

function TPerformanceMetrics.GetMaxLatency: Double;
begin
  FLock.Enter;
  try
    Result := FMaxLatencyMs;
  finally
    FLock.Leave;
  end;
end;

procedure TPerformanceMetrics.Reset;
begin
  FLock.Enter;
  try
    FTotalMessages := 0;
    FErrorCount := 0;
    FStartTime := Now;
    FMinLatencyMs := 0;
    FMaxLatencyMs := 0;
    FSumLatencyMs := 0;
    FLatencyCount := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TPerformanceMetrics.PrintStats;
begin
  FLock.Enter;
  try
    Writeln('=== PERFORMANCE METRICS ===');
    Writeln(Format('Total Messages: %d', [FTotalMessages]));
    Writeln(Format('Messages/sec: %.2f', [GetMessagesPerSecond]));
    Writeln(Format('Error Rate: %.2f%%', [GetErrorRate]));
    Writeln(Format('Avg Latency: %.3f ms', [GetAverageLatency]));
    Writeln(Format('Min Latency: %.3f ms', [FMinLatencyMs]));
    Writeln(Format('Max Latency: %.3f ms', [FMaxLatencyMs]));
    Writeln('============================');
  finally
    FLock.Leave;
  end;
end;

function GenerateRandomIP: string;
begin
  Result := Format('%d.%d.%d.%d', [
    Random(256), Random(256), Random(256), Random(256)
  ]);
end;

function GenerateRandomUserAgent: string;
const
  UserAgents: array[0..4] of string = (
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X)',
    'Mozilla/5.0 (Android 11; Mobile; rv:91.0) Gecko/91.0'
  );
begin
  Result := UserAgents[Random(Length(UserAgents))];
end;

function GenerateHTTPRequest: THTTPRequest;
const
  Methods: array[0..3] of string = ('GET', 'POST', 'PUT', 'DELETE');
  URLs: array[0..9] of string = (
    '/api/users', '/api/orders', '/api/products', '/health',
    '/api/auth/login', '/api/payments', '/api/reports',
    '/api/notifications', '/api/settings', '/metrics'
  );
  StatusCodes: array[0..6] of Integer = (200, 201, 400, 401, 403, 404, 500);
begin
  Result.Method := Methods[Random(Length(Methods))];
  Result.URL := URLs[Random(Length(URLs))];
  Result.UserAgent := GenerateRandomUserAgent;
  Result.IP := GenerateRandomIP;
  Result.ContentLength := Random(10000);
  Result.ProcessingTimeMs := Random(2000) + 1;
  Result.StatusCode := StatusCodes[Random(Length(StatusCodes))];
  Result.RequestId := Format('req_%d_%d', [GetTickCount, Random(999999)]);
end;

procedure TestBasicLogging;
const
  MESSAGE_COUNT = 1000;
var
  i: Integer;
  StartTime: TStopwatch;
begin
  Writeln('=== Test: Basic Logging ===');
  Metrics.Reset;
  StartTime := TStopwatch.StartNew;
  for i := 1 to MESSAGE_COUNT do
  begin
    GLogger.WriteInfoLogLn('Basic test message %d', [i]);
    Metrics.RecordMessage;
    if i mod 100 = 0 then
      Write('.');
  end;
  StartTime.Stop;
  Writeln('');
  Writeln(Format('Completed %d messages in %d ms',
    [MESSAGE_COUNT, StartTime.ElapsedMilliseconds]));
  Metrics.PrintStats;
  Writeln('');
end;

procedure TestHighThroughput;
const
  MESSAGE_COUNT = 10000;
  BATCH_SIZE = 100;
var
  i, j: Integer;
  StartTime: TStopwatch;
  Request: THTTPRequest;
begin
  Writeln('=== Test: High Throughput ===');
  Metrics.Reset;
  StartTime := TStopwatch.StartNew;
  for i := 1 to MESSAGE_COUNT div BATCH_SIZE do
  begin
    for j := 1 to BATCH_SIZE do
    begin
      Request := GenerateHTTPRequest;
      GLogger.WriteInfoLogLn('%s %s - %s - %d - %dms - %d bytes', [
        Request.Method, Request.URL, Request.IP, Request.StatusCode,
        Request.ProcessingTimeMs, Request.ContentLength
      ]);
      Metrics.RecordMessage;
    end;
    if i mod 10 = 0 then
      Write('.');
  end;
  StartTime.Stop;
  Writeln('');
  Writeln(Format('Completed %d messages in %d ms',
    [MESSAGE_COUNT, StartTime.ElapsedMilliseconds]));
  Metrics.PrintStats;
  Writeln('');
end;

procedure TestMultiThreadStress;
const
  THREAD_COUNT = 8;
  MESSAGES_PER_THREAD = 1000;
var
  Tasks: array of ITask;
  i: Integer;
  StartTime: TStopwatch;
begin
  Writeln('=== Test: Multi-Thread Stress ===');
  Metrics.Reset;
  StartTime := TStopwatch.StartNew;
  SetLength(Tasks, THREAD_COUNT);
  for i := 0 to THREAD_COUNT - 1 do
  begin
    Tasks[i] := TTask.Run(
      procedure
      var
        j: Integer;
        ThreadId: Cardinal;
        Request: THTTPRequest;
        MsgStartTime: TStopwatch;
      begin
        ThreadId := GetCurrentThreadId;
        for j := 1 to MESSAGES_PER_THREAD do
        begin
          try
            MsgStartTime := TStopwatch.StartNew;
            Request := GenerateHTTPRequest;
            case Random(4) of
              0: GLogger.WriteDebugLogLn('[T:%d] Debug: Processing request %s',
                   [ThreadId, Request.RequestId]);
              1: GLogger.WriteInfoLogLn('[T:%d] %s %s from %s - Status: %d',
                   [ThreadId, Request.Method, Request.URL, Request.IP, Request.StatusCode]);
              2: GLogger.WriteWarningLogLn('[T:%d] Slow request %s took %dms',
                   [ThreadId, Request.RequestId, Request.ProcessingTimeMs]);
              3: GLogger.WriteErrorLogLn('[T:%d] Error processing %s - Code: %d',
                   [ThreadId, Request.RequestId, Request.StatusCode]);
            end;
            MsgStartTime.Stop;
            Metrics.RecordLatency(MsgStartTime.Elapsed.TotalMilliseconds);
            Metrics.RecordMessage;
          except
            on E: Exception do
            begin
              Metrics.RecordError;
              GLogger.WriteErrorLogLn('[T:%d] Exception: %s', [ThreadId, E.Message]);
            end;
          end;
          if Random(100) < 5 then
            Sleep(Random(10));
        end;
      end
    );
  end;
  TTask.WaitForAll(Tasks);
  StartTime.Stop;
  Writeln(Format('Completed %d threads x %d messages in %d ms',
    [THREAD_COUNT, MESSAGES_PER_THREAD, StartTime.ElapsedMilliseconds]));
  Metrics.PrintStats;
  Writeln('');
end;

procedure TestMemoryPressure;
const
  LARGE_MESSAGE_COUNT = 5000;
var
  i: Integer;
  LargeData: string;
  StartTime: TStopwatch;
begin
  Writeln('=== Test: Memory Pressure ===');
  Metrics.Reset;
  StartTime := TStopwatch.StartNew;
  SetLength(LargeData, 1024);
  for i := 1 to Length(LargeData) do
    LargeData[i] := Chr(Ord('A') + (i mod 26));
  for i := 1 to LARGE_MESSAGE_COUNT do
  begin
    GLogger.WriteInfoLogLn('Large message %d: %s', [i, LargeData]);
    Metrics.RecordMessage;
    if i mod 100 = 0 then
      Write('.');
  end;
  StartTime.Stop;
  Writeln('');
  Writeln(Format('Completed %d large messages in %d ms',
    [LARGE_MESSAGE_COUNT, StartTime.ElapsedMilliseconds]));
  Metrics.PrintStats;
  Writeln('');
end;

procedure TestFileRotation;
const
  MESSAGE_COUNT = 2000;
var
  i: Integer;
  CustomLogger: TGLogger;
  StartTime: TStopwatch;
begin
  Writeln('=== Test: File Rotation ===');
  Metrics.Reset;
  StartTime := TStopwatch.StartNew;
  CustomLogger := TGLogger.Create('test_rotation.log', loFile, 50 * 1024);
  try
    CustomLogger.Start;
    for i := 1 to MESSAGE_COUNT do
    begin
      CustomLogger.WriteInfoLogLn(
        'Rotation test message %d - This is a longer message to fill up the log file faster ' +
        'and trigger rotation. Current timestamp: %s',
        [i, FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now)]
      );
      Metrics.RecordMessage;
      if i mod 100 = 0 then
        Write('.');
    end;
    CustomLogger.Stop;
  finally
    CustomLogger.Free;
  end;
  StartTime.Stop;
  Writeln('');
  Writeln(Format('Completed file rotation test in %d ms', [StartTime.ElapsedMilliseconds]));
  Metrics.PrintStats;
  var LogFiles := TDirectory.GetFiles('.', 'test_rotation*.log');
  Writeln(Format('Created %d log files', [Length(LogFiles)]));
  Writeln('');
end;

procedure TestErrorHandling;
const
  MESSAGE_COUNT = 1000;
var
  i: Integer;
  StartTime: TStopwatch;
begin
  Writeln('=== Test: Error Handling ===');
  Metrics.Reset;
  StartTime := TStopwatch.StartNew;
  for i := 1 to MESSAGE_COUNT do
  begin
    try
      case Random(5) of
        0: GLogger.WriteInfoLogLn('Normal message %d', [i]);
        1: GLogger.WriteErrorLogLn('Invalid format %s %d %q', [i]);
        2: GLogger.WriteWarningLogLn('Missing param %s', []);
        3: GLogger.WriteDebugLogLn('Too many params %d', [i, i, i]);
        4: GLogger.WriteInfoLogLn('Division by zero: %f', [i / 0]);
      end;
      Metrics.RecordMessage;
    except
      on E: Exception do
      begin
        Metrics.RecordError;
        Writeln('Error in test: ', E.Message);
      end;
    end;
    if i mod 100 = 0 then
      Write('.');
  end;
  StartTime.Stop;
  Writeln('');
  Writeln(Format('Completed error handling test in %d ms', [StartTime.ElapsedMilliseconds]));
  Metrics.PrintStats;
  Writeln('');
end;

procedure ProcessHTTPRequest(const Request: THTTPRequest);
var
  ProcessingStart: TStopwatch;
  ProcessingTime: Integer;
begin
  ProcessingStart := TStopwatch.StartNew;
  try
    GLogger.WriteInfoLogLn('[%s] START %s %s - UA: %s - Size: %d bytes', [
      Request.RequestId, Request.Method, Request.URL,
      Copy(Request.UserAgent, 1, 50), Request.ContentLength
    ]);
    ProcessingTime := Request.ProcessingTimeMs + Random(100);
    Sleep(ProcessingTime);
    if Request.StatusCode >= 400 then
    begin
      GLogger.WriteErrorLogLn('[%s] ERROR %s %s - Status: %d - Time: %dms - IP: %s', [
        Request.RequestId, Request.Method, Request.URL,
        Request.StatusCode, ProcessingTime, Request.IP
      ]);
    end
    else if ProcessingTime > 1000 then
    begin
      GLogger.WriteWarningLogLn('[%s] SLOW %s %s - Status: %d - Time: %dms - IP: %s', [
        Request.RequestId, Request.Method, Request.URL,
        Request.StatusCode, ProcessingTime, Request.IP
      ]);
    end
    else
    begin
      GLogger.WriteInfoLogLn('[%s] OK %s %s - Status: %d - Time: %dms - IP: %s', [
        Request.RequestId, Request.Method, Request.URL,
        Request.StatusCode, ProcessingTime, Request.IP
      ]);
    end;
    ProcessingStart.Stop;
    Metrics.RecordLatency(ProcessingStart.Elapsed.TotalMilliseconds);
    Metrics.RecordMessage;
  except
    on E: Exception do
    begin
      GLogger.WriteErrorLogLn('[%s] EXCEPTION %s - %s', [
        Request.RequestId, E.ClassName, E.Message
      ]);
      Metrics.RecordError;
    end;
  end;
end;

procedure TestIOPSimulation;
const
  SIMULATION_DURATION_SEC = 30;
  MAX_CONCURRENT_REQUESTS = 50;
var
  StartTime: TDateTime;
  ActiveTasks: TList<ITask>;
  i: Integer;
begin
  Writeln('=== Test: IOP Server Simulation ===');
  Writeln(Format('Simulating %d seconds of HTTP server activity...', [SIMULATION_DURATION_SEC]));
  Metrics.Reset;
  StartTime := Now;
  ActiveTasks := TList<ITask>.Create;
  try
    GLogger.WriteInfoLogLn('IOP Server simulation started - Max concurrent: %d', [MAX_CONCURRENT_REQUESTS]);
    i := 0;
    while SecondsBetween(Now, StartTime) < SIMULATION_DURATION_SEC do
    begin
      for var j := ActiveTasks.Count - 1 downto 0 do
      begin
        if not (ActiveTasks[j].Status in [TTaskStatus.Running, TTaskStatus.WaitingToRun]) then
          ActiveTasks.Delete(j);
      end;
      if ActiveTasks.Count < MAX_CONCURRENT_REQUESTS then
      begin
        Inc(i);
        var Request := GenerateHTTPRequest;
        Request.RequestId := Format('req_%d', [i]);
        var Task := TTask.Run(
          procedure
          begin
            ProcessHTTPRequest(Request);
          end
        );
        ActiveTasks.Add(Task);
      end
      else
      begin
        Sleep(10);
      end;
      if i mod 100 = 0 then
      begin
        Write(Format('[%d requests, %d active] ', [i, ActiveTasks.Count]));
      end;
      var ElapsedSec := SecondsBetween(Now, StartTime);
      if ElapsedSec mod 10 < 3 then
        Sleep(Random(50))
      else
        Sleep(Random(200));
    end;
    Writeln('');
    Writeln('Waiting for active requests to complete...');
    while ActiveTasks.Count > 0 do
    begin
      for var j := ActiveTasks.Count - 1 downto 0 do
      begin
        if not (ActiveTasks[j].Status in [TTaskStatus.Running, TTaskStatus.WaitingToRun]) then
          ActiveTasks.Delete(j);
      end;
      Sleep(100);
      Write('.');
    end;
  finally
    ActiveTasks.Free;
  end;
  Writeln('');
  GLogger.WriteInfoLogLn('IOP Server simulation completed - Total requests: %d', [i]);
  Writeln(Format('IOP Simulation completed - %d requests processed', [i]));
  Metrics.PrintStats;
  Writeln('');
end;

procedure TestLongRunning;
const
  DURATION_MINUTES = 2;
var
  StartTime: TDateTime;
  MessageCount: Integer;
  LastReport: TDateTime;
begin
  Writeln(Format('=== Test: Long Running (%d minutes) ===', [DURATION_MINUTES]));
  Metrics.Reset;
  StartTime := Now;
  LastReport := StartTime;
  MessageCount := 0;
  GLogger.WriteInfoLogLn('Long running test started - Duration: %d minutes', [DURATION_MINUTES]);
  while MinutesBetween(Now, StartTime) < DURATION_MINUTES do
  begin
    Inc(MessageCount);
    case MessageCount mod 10 of
      0: GLogger.WriteInfoLogLn('Heartbeat #%d - Memory: %d KB',
           [MessageCount div 10, GetHeapStatus.TotalAllocated div 1024]);
      1..7: GLogger.WriteDebugLogLn('Regular operation #%d', [MessageCount]);
      8: GLogger.WriteWarningLogLn('Periodic warning #%d', [MessageCount]);
      9: GLogger.WriteErrorLogLn('Simulated error #%d', [MessageCount]);
    end;
    Metrics.RecordMessage;
    if SecondsBetween(Now, LastReport) >= 60 then
    begin
      Writeln(Format('Minute %d completed - %d messages',
        [MinutesBetween(Now, StartTime), MessageCount]));
      LastReport := Now;
    end;
    Sleep(100);
  end;
  GLogger.WriteInfoLogLn('Long running test completed - Total messages: %d', [MessageCount]);
  Writeln(Format('Long running test completed - %d messages', [MessageCount]));
  Metrics.PrintStats;
  Writeln('');
end;

procedure RunAllTests;
begin
  Writeln('GLogger Comprehensive Test Suite');
  Writeln('================================');
  Writeln('Testing logger for IOP server environments...');
  Writeln('');
  try
    TestBasicLogging;
    Sleep(1000);
    TestHighThroughput;
    Sleep(1000);
    TestMultiThreadStress;
    Sleep(1000);
    TestMemoryPressure;
    Sleep(1000);
    TestFileRotation;
    Sleep(1000);
    TestErrorHandling;
    Sleep(1000);
    TestIOPSimulation;
    Sleep(1000);
    Write('Run long running test (2 minutes)? [y/N]: ');
    var Response: string;
    Readln(Response);
    if (Response = 'y') or (Response = 'Y') then
    begin
      TestLongRunning;
    end;
    Writeln('=== ALL TESTS COMPLETED ===');
    GLogger.WriteInfoLogLn('Test suite completed successfully');
  except
    on E: Exception do
    begin
      Writeln('TEST SUITE ERROR: ', E.Message);
      GLogger.WriteErrorLogLn('Test suite failed: %s', [E.Message]);
    end;
  end;
end;

procedure MonitoringTask;
begin
  TTask.Run(
    procedure
    begin
      while TestRunning do
      begin
        Sleep(10000);
        if Metrics.GetTotalMessages > 0 then
        begin
          GLogger.WriteDebugLogLn('MONITOR: %d msgs, %.1f msg/s, %.2f%% errors', [
            Metrics.GetTotalMessages,
            Metrics.GetMessagesPerSecond,
            Metrics.GetErrorRate
          ]);
        end;
      end;
    end
  );
end;

procedure ConfigureFastMM;
begin
  FastMM_EnterDebugMode;
  FastMM_MessageBoxEvents := [];
  FastMM_LogToFileEvents := FastMM_LogToFileEvents + [mmetUnexpectedMemoryLeakDetail,
                            mmetUnexpectedMemoryLeakSummary,
                            mmetDebugBlockDoubleFree,
                            mmetDebugBlockReallocOfFreedBlock];
end;

begin
  ConfigureFastMM;
  try
    Randomize;
    Metrics := TPerformanceMetrics.Create;
    GLogger.BatchSize := 100;
    GLogger.LogOutput := loBoth;
    try
      Writeln('Logger configuration:');
      Writeln('- Log file: ', GLogger.LogFile);
      Writeln('- Batch size: ', GLogger.BatchSize);
      Writeln('- Output: Console + File');
      Writeln('');
      MonitoringTask;
      RunAllTests;
    finally
      TestRunning := False;
      Writeln('');
      Writeln('Final statistics:');
      Metrics.PrintStats;
      Writeln('Waiting for logger to flush...');
      Sleep(2000);
      FreeAndNil(Metrics);
    end;
  except
    on E: Exception do
    begin
      Writeln('CRITICAL ERROR: ', E.Message);
      ExitCode := 1;
    end;
  end;
  Writeln('');
  Writeln('Press Enter to exit...');
  Readln;
end.
