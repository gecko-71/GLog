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
program LogTest2;


{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Threading,
  System.DateUtils,
  Winapi.Windows,
  GLog in 'GLog.pas';

procedure DemoBasicLogging;
begin
  Writeln('=== Basic Logging Demo ===');
  GLogger.WriteInfoLogLn('Application started successfully');
  GLogger.WriteDebugLogLn('Debug info: Current time is %s', [TimeToStr(Now)]);
  GLogger.WriteWarningLogLn('This is a warning message');
  GLogger.WriteErrorLogLn('Simulated error for demonstration');
  Writeln('Basic logging completed. Check LOGS folder for log file.');
  Writeln('');
end;

procedure DemoMultiThreadLogging;
const
  THREAD_COUNT = 3;
  MESSAGES_PER_THREAD = 5;
var
  Tasks: array of ITask;
  i: Integer;
begin
  Writeln('=== Multi-Thread Logging Demo ===');
  SetLength(Tasks, THREAD_COUNT);
  for i := 0 to THREAD_COUNT - 1 do
  begin
    Tasks[i] := TTask.Run(
      procedure
      var
        ThreadId: Cardinal;
        j: Integer;
      begin
        ThreadId := GetCurrentThreadId;
        for j := 1 to MESSAGES_PER_THREAD do
        begin
          case Random(4) of
            0: GLogger.WriteDebugLogLn('[Thread %d] Processing item %d', [ThreadId, j]);
            1: GLogger.WriteInfoLogLn('[Thread %d] Task %d completed successfully', [ThreadId, j]);
            2: GLogger.WriteWarningLogLn('[Thread %d] Warning in task %d', [ThreadId, j]);
            3: GLogger.WriteErrorLogLn('[Thread %d] Error in task %d', [ThreadId, j]);
          end;
          Sleep(Random(100));
        end;
        GLogger.WriteInfoLogLn('[Thread %d] All tasks completed', [ThreadId]);
      end
    );
  end;
  TTask.WaitForAll(Tasks);
  Writeln('Multi-thread logging completed.');
  Writeln('');
end;

procedure DemoBusinessLogic;
begin
  Writeln('=== Business Logic Demo ===');
  GLogger.WriteInfoLogLn('Starting user registration process');
  GLogger.WriteDebugLogLn('Validating user email: user@example.com');
  Sleep(50);
  GLogger.WriteDebugLogLn('Checking password strength');
  Sleep(30);
  GLogger.WriteWarningLogLn('Password strength is weak - recommending stronger password');
  GLogger.WriteInfoLogLn('Saving user to database');
  Sleep(100);
  if Random(10) > 7 then
  begin
    GLogger.WriteErrorLogLn('Database connection failed - retrying...');
    Sleep(200);
    GLogger.WriteInfoLogLn('Database connection restored');
  end;
  GLogger.WriteInfoLogLn('User registration completed successfully');
  GLogger.WriteInfoLogLn('Sending welcome email to user@example.com');
  Writeln('Business logic demo completed.');
  Writeln('');
end;

procedure DemoErrorHandling;
begin
  Writeln('=== Error Handling Demo ===');
  try
    GLogger.WriteInfoLogLn('Testing error handling with invalid format: %s %d %q', [123]);
  except
    on E: Exception do
      Writeln('Expected format error handled by logger');
  end;
  try
    GLogger.WriteWarningLogLn('Missing parameters: %s %d', []);
  except
    on E: Exception do
      Writeln('Expected parameter error handled by logger');
  end;
  GLogger.WriteInfoLogLn('Error handling test completed');
  Writeln('Error handling demo completed.');
  Writeln('');
end;

procedure DemoPerformanceTest;
const
  MESSAGE_COUNT = 1000;
var
  i: Integer;
  StartTime: TDateTime;
  ElapsedMs: Int64;
begin
  Writeln('=== Performance Test Demo ===');
  Writeln(Format('Logging %d messages...', [MESSAGE_COUNT]));
  StartTime := Now;
  for i := 1 to MESSAGE_COUNT do
  begin
    case i mod 4 of
      0: GLogger.WriteDebugLogLn('Performance test message #%d', [i]);
      1: GLogger.WriteInfoLogLn('Info message #%d - timestamp: %s', [i, TimeToStr(Now)]);
      2: GLogger.WriteWarningLogLn('Warning #%d - check this later', [i]);
      3: GLogger.WriteErrorLogLn('Error simulation #%d', [i]);
    end;
    if i mod 100 = 0 then
      Write('.');
  end;
  ElapsedMs := MilliSecondsBetween(Now, StartTime);
  Writeln('');
  Writeln(Format('Performance test completed: %d messages in %d ms', [MESSAGE_COUNT, ElapsedMs]));
  Writeln(Format('Average: %.2f messages/second', [MESSAGE_COUNT / (ElapsedMs / 1000)]));
  Writeln('');
end;

procedure ShowLoggerInfo;
begin
  Writeln('=== Logger Configuration ===');
  Writeln('Log Directory: ', GLogger.LogDirectory);
  Writeln('Log File: ', ExtractFileName(GLogger.LogFile));
  Writeln('Batch Size: ', GLogger.BatchSize);
  Writeln('Max File Size: ', GLogger.MaxFileSize div 1024, ' KB');
  Writeln('Auto Rotate: ', BoolToStr(GLogger.AutoRotate, True));
  Writeln('Color Enabled: ', BoolToStr(GLogger.ColorEnabled, True));
  case GLogger.LogOutput of
    loConsole: Writeln('Output: Console only');
    loFile: Writeln('Output: File only');
    loBoth: Writeln('Output: Console + File');
  end;
  Writeln('================================');
  Writeln('');
end;

procedure RunDemo;
begin
  Writeln('Simple Logger Demo Application');
  Writeln('==============================');
  Writeln('');

  ShowLoggerInfo;

  while True do
  begin
    Writeln('Choose demo:');
    Writeln('1. Basic Logging');
    Writeln('2. Multi-Thread Logging');
    Writeln('3. Business Logic Simulation');
    Writeln('4. Error Handling');
    Writeln('5. Performance Test');
    Writeln('6. All Demos');
    Writeln('7. Show Logger Info');
    Writeln('0. Exit');
    Writeln('');
    Write('Your choice: ');
    var Cho:Char;
    Readln(Cho);
    Writeln('');

    case Cho of
      '1': DemoBasicLogging;
      '2': DemoMultiThreadLogging;
      '3': DemoBusinessLogic;
      '4': DemoErrorHandling;
      '5': DemoPerformanceTest;
      '6': begin
             DemoBasicLogging;
             DemoMultiThreadLogging;
             DemoBusinessLogic;
             DemoErrorHandling;
             DemoPerformanceTest;
           end;
      '7': ShowLoggerInfo;
      '0': Break;
    else
      Writeln('Invalid choice. Please try again.');
      Writeln('');
    end;
    Write('Enter: ');
  end;
end;

begin
  try
    Randomize;
    GLogger.LogOutput := loBoth;
    GLogger.ColorEnabled := True;
    GLogger.BatchSize := 50;
    GLogger.WriteInfoLogLn('=== Demo Application Started ===');
    RunDemo;
    GLogger.WriteInfoLogLn('=== Demo Application Finished ===');
    Writeln('Waiting for logger to finish writing...');
    Sleep(1000);
  except
    on E: Exception do
    begin
      Writeln('ERROR: ', E.Message);
      GLogger.WriteErrorLogLn('Critical error: %s', [E.Message]);
      ExitCode := 1;
    end;
  end;
  Writeln('');
  Writeln('Press Enter to exit...');
  Readln;
end.
