classdef ExhaustAnalyzer < matlab.apps.AppBase
    % ExhaustAnalyzer  Acoustic measurement and spectral analysis tool
    %
    % Launch:  app = ExhaustAnalyzer;

    properties (Access = public)
        UIFigure                matlab.ui.Figure
        TabGroup                matlab.ui.container.TabGroup

        MonitorTab              matlab.ui.container.Tab
        SetupPanel              matlab.ui.container.Panel
        DeviceDropdown          matlab.ui.control.DropDown
        DeviceLabel             matlab.ui.control.Label
        SampleRateDropdown      matlab.ui.control.DropDown
        SampleRateLabel         matlab.ui.control.Label
        BitDepthDropdown        matlab.ui.control.DropDown
        BitDepthLabel           matlab.ui.control.Label
        DurationSpinner         matlab.ui.control.Spinner
        DurationLabel           matlab.ui.control.Label
        RefreshDevicesButton    matlab.ui.control.Button

        RecordButton            matlab.ui.control.Button
        StopButton              matlab.ui.control.Button
        MonitorOnlyButton       matlab.ui.control.Button
        RecordStatusLamp        matlab.ui.control.Lamp
        RecordStatusLabel       matlab.ui.control.Label
        ProgressLabel           matlab.ui.control.Label

        CalPanel                matlab.ui.container.Panel
        LoadCalButton           matlab.ui.control.Button
        ClearCalButton          matlab.ui.control.Button
        CalFileLabel            matlab.ui.control.Label
        ApplyCalGlobalCheckbox  matlab.ui.control.CheckBox

        SPLCalPanel             matlab.ui.container.Panel
        SPLRefSpinner           matlab.ui.control.Spinner
        SPLRefLabel             matlab.ui.control.Label
        SPLCalibrateButton      matlab.ui.control.Button
        SPLStatusLabel          matlab.ui.control.Label

        ManualOffsetLabel       matlab.ui.control.Label
        ManualOffsetSpinner     matlab.ui.control.Spinner

        WaveformAxes            matlab.ui.control.UIAxes
        LiveFFTAxes             matlab.ui.control.UIAxes

        LiveFFTPanel            matlab.ui.container.Panel
        LiveFFTSizeDropdown     matlab.ui.control.DropDown
        LiveFFTSizeLabel        matlab.ui.control.Label
        LiveWindowDropdown      matlab.ui.control.DropDown
        LiveWindowLabel         matlab.ui.control.Label
        LivePeakHoldCheckbox    matlab.ui.control.CheckBox
        LiveDecayDropdown       matlab.ui.control.DropDown
        LiveDecayLabel          matlab.ui.control.Label
        LiveYMinSpinner         matlab.ui.control.Spinner
        LiveYMinLabel           matlab.ui.control.Label
        LiveYMaxSpinner         matlab.ui.control.Spinner
        LiveYMaxLabel           matlab.ui.control.Label
        LiveAutoYCheckbox       matlab.ui.control.CheckBox
        ClearPeaksButton        matlab.ui.control.Button

        % Sound level meter panel and display elements
        SPLMeterPanel           matlab.ui.container.Panel
        SPLCurrentLabel         matlab.ui.control.Label
        SPLValueLabel           matlab.ui.control.Label
        SPLPeakLabel            matlab.ui.control.Label
        SPLPeakValueLabel       matlab.ui.control.Label
        SPLMinLabel             matlab.ui.control.Label
        SPLMinValueLabel        matlab.ui.control.Label
        SPLWeightingDropdown    matlab.ui.control.DropDown
        SPLWeightingLabel       matlab.ui.control.Label
        SPLResetPeakButton      matlab.ui.control.Button

        SamplePanel             matlab.ui.container.Panel
        SampleListBox           matlab.ui.control.ListBox
        RenameSampleButton      matlab.ui.control.Button
        DeleteSampleButton      matlab.ui.control.Button
        ImportWavButton         matlab.ui.control.Button
        SaveSessionButton       matlab.ui.control.Button
        LoadSessionButton       matlab.ui.control.Button

        AnalysisTab             matlab.ui.container.Tab
        AnalysisPanel           matlab.ui.container.Panel
        FFTSizeDropdown         matlab.ui.control.DropDown
        FFTSizeLabel            matlab.ui.control.Label
        WindowDropdown          matlab.ui.control.DropDown
        WindowLabel             matlab.ui.control.Label
        AveragingDropdown       matlab.ui.control.DropDown
        AveragingLabel          matlab.ui.control.Label
        OverlayCheckbox         matlab.ui.control.CheckBox
        AnalyzeButton           matlab.ui.control.Button
        ExportAnalysisButton    matlab.ui.control.Button
        FreqScaleSwitch         matlab.ui.control.Switch
        FreqScaleLabel          matlab.ui.control.Label
        AnalysisAxes            matlab.ui.control.UIAxes

        % Analysis entries panel: build a list of sample+trim combos to plot
        EntriesPanel            matlab.ui.container.Panel
        EntrySampleDropdown     matlab.ui.control.DropDown
        EntrySampleLabel        matlab.ui.control.Label
        EntryStartSpinner       matlab.ui.control.Spinner
        EntryStartLabel         matlab.ui.control.Label
        EntryEndSpinner         matlab.ui.control.Spinner
        EntryEndLabel           matlab.ui.control.Label
        AddEntryButton          matlab.ui.control.Button
        RemoveEntryButton       matlab.ui.control.Button
        ClearEntriesButton      matlab.ui.control.Button
        AddAllButton            matlab.ui.control.Button
        EntriesListBox          matlab.ui.control.ListBox

        WaterfallTab            matlab.ui.container.Tab
        WFPanel                 matlab.ui.container.Panel
        WFSampleDropdown        matlab.ui.control.DropDown
        WFSampleLabel           matlab.ui.control.Label
        WFStyleDropdown         matlab.ui.control.DropDown
        WFStyleLabel            matlab.ui.control.Label
        WFFFTSizeDropdown       matlab.ui.control.DropDown
        WFFFTSizeLabel          matlab.ui.control.Label
        WFOverlapSpinner        matlab.ui.control.Spinner
        WFOverlapLabel          matlab.ui.control.Label
        WFMaxFreqSpinner        matlab.ui.control.Spinner
        WFMaxFreqLabel          matlab.ui.control.Label
        WFDbRangeSpinner        matlab.ui.control.Spinner
        WFDbRangeLabel          matlab.ui.control.Label
        WFApplyCalCheckbox      matlab.ui.control.CheckBox
        WFTrimStartSpinner      matlab.ui.control.Spinner
        WFTrimStartLabel        matlab.ui.control.Label
        WFTrimEndSpinner        matlab.ui.control.Spinner
        WFTrimEndLabel          matlab.ui.control.Label
        WFPlotButton            matlab.ui.control.Button
        WFExportButton          matlab.ui.control.Button
        WFAxes                  matlab.ui.control.UIAxes
    end

    properties (Access = private)
        Samples                 struct
        SampleCount             double = 0
        SessionFile             string = ""    % full path of last saved/loaded session

        CalFreq                 double
        CalDB                   double
        CalPhase                double         % phase response (degrees) from calibration file
        CalLoaded               logical = false
        CalFileName             string = ""
        SPLOffset               double = 0
        SPLCalibrated           logical = false

        Recorder
        IsRecording             logical = false
        IsMonitoring            logical = false
        LiveTimer
        RecordStartTime
        RecordDuration          double

        PeakHoldData            double
        SmoothedFFT             double

        % Persistent plot handles, updated in-place to avoid cla and replot
        hWaveform                       % line handle for waveform
        hCursor                         % line handle for record cursor
        hFFTArea                        % area handle for live FFT
        hPeakLine                       % line handle for peak hold
        LastNFFT                double = 0  % tracks FFT size changes to reset smoothing

        % Sound level meter state
        SPLPeakValue            double = -Inf   % highest observed dB reading
        SPLMinValue             double = Inf    % lowest observed dB reading

        % Per-sample trim and level storage for the analysis queue.
        % Each element is a struct with fields: name, tStart, tEnd, dB
        AnalysisEntries         struct
    end

    methods (Access = private)

        function createComponents(app)

            app.UIFigure = uifigure('Name', 'Exhaust Analyzer', ...
                'Position', [50 50 1340 850], ...
                'Color', [0.15 0.15 0.17], ...
                'CloseRequestFcn', @(~,~) appCloseRequest(app));

            app.TabGroup = uitabgroup(app.UIFigure, 'Position', [10 10 1320 830]);

            % Record and Monitor tab
            app.MonitorTab = uitab(app.TabGroup, 'Title', '  Record & Monitor  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            panelW = 320;

            % Audio device and recording setup panel
            app.SetupPanel = uipanel(app.MonitorTab, 'Title', 'Setup', ...
                'Position', [12 555 panelW 200], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            yy = 150;
            app.DeviceLabel = uilabel(app.SetupPanel, 'Text', 'Input:', ...
                'Position', [10 yy 40 22], 'FontColor', [0.85 0.85 0.85]);
            app.DeviceDropdown = uidropdown(app.SetupPanel, ...
                'Items', {'Default'}, 'Value', 'Default', ...
                'Position', [55 yy 195 22]);
            app.RefreshDevicesButton = uibutton(app.SetupPanel, 'push', ...
                'Text', 'Ref', 'Position', [255 yy 46 22], 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) populateDevices(app));
            app.populateDevices();

            yy = yy - 30;
            app.SampleRateLabel = uilabel(app.SetupPanel, 'Text', 'Rate:', ...
                'Position', [10 yy 35 22], 'FontColor', [0.85 0.85 0.85]);
            app.SampleRateDropdown = uidropdown(app.SetupPanel, ...
                'Items', {'44100','48000','96000'}, 'Value', '48000', ...
                'Position', [50 yy 85 22]);
            app.BitDepthLabel = uilabel(app.SetupPanel, 'Text', 'Bits:', ...
                'Position', [145 yy 30 22], 'FontColor', [0.85 0.85 0.85]);
            app.BitDepthDropdown = uidropdown(app.SetupPanel, ...
                'Items', {'16','24'}, 'Value', '24', ...
                'Position', [178 yy 60 22]);

            yy = yy - 30;
            app.DurationLabel = uilabel(app.SetupPanel, 'Text', 'Duration (s):', ...
                'Position', [10 yy 80 22], 'FontColor', [0.85 0.85 0.85]);
            app.DurationSpinner = uispinner(app.SetupPanel, ...
                'Value', 40, 'Limits', [1 600], 'Step', 5, ...
                'Position', [95 yy 80 22]);

            yy = yy - 38;
            app.RecordButton = uibutton(app.SetupPanel, 'push', ...
                'Text', 'Record + Analyze', 'Position', [10 yy 130 32], ...
                'BackgroundColor', [0.75 0.15 0.15], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'FontSize', 12, ...
                'ButtonPushedFcn', @(~,~) startRecording(app));
            app.StopButton = uibutton(app.SetupPanel, 'push', ...
                'Text', 'Stop', 'Position', [148 yy 60 32], ...
                'BackgroundColor', [0.4 0.4 0.4], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) stopAll(app));
            app.MonitorOnlyButton = uibutton(app.SetupPanel, 'push', ...
                'Text', 'Monitor Only', 'Position', [216 yy 90 32], ...
                'BackgroundColor', [0.2 0.42 0.2], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'FontSize', 11, ...
                'ButtonPushedFcn', @(~,~) startMonitorOnly(app));

            % Recording status indicators
            app.RecordStatusLamp = uilamp(app.MonitorTab, ...
                'Position', [15 530 14 14], 'Color', [0.4 0.4 0.4]);
            app.RecordStatusLabel = uilabel(app.MonitorTab, 'Text', 'Idle', ...
                'Position', [34 528 60 20], 'FontColor', [0.7 0.7 0.7], 'FontSize', 12);
            app.ProgressLabel = uilabel(app.MonitorTab, 'Text', '', ...
                'Position', [100 528 235 20], 'FontColor', [1 1 1], ...
                'FontWeight', 'bold', 'FontSize', 12);

            % Microphone frequency response calibration panel
            app.CalPanel = uipanel(app.MonitorTab, 'Title', 'Mic Calibration', ...
                'Position', [12 420 panelW 105], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.LoadCalButton = uibutton(app.CalPanel, 'push', ...
                'Text', 'Load Cal File', 'Position', [10 55 120 24], ...
                'BackgroundColor', [0.3 0.3 0.5], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) loadCalFile(app));
            app.ClearCalButton = uibutton(app.CalPanel, 'push', ...
                'Text', 'Clear', 'Position', [138 55 55 24], ...
                'ButtonPushedFcn', @(~,~) clearCal(app));
            app.CalFileLabel = uilabel(app.CalPanel, 'Text', 'No file loaded', ...
                'Position', [10 32 295 20], 'FontColor', [0.62 0.62 0.62], 'FontSize', 11);
            app.ApplyCalGlobalCheckbox = uicheckbox(app.CalPanel, ...
                'Text', 'Apply to all displays', 'Value', true, ...
                'Position', [10 8 180 22], 'FontColor', [0.85 0.85 0.85]);

            % SPL reference calibration panel
            app.SPLCalPanel = uipanel(app.MonitorTab, 'Title', 'SPL Calibration', ...
                'Position', [12 325 panelW 90], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            % Top Row: Auto Calibration
            app.SPLRefLabel = uilabel(app.SPLCalPanel, 'Text', 'Ref dB:', ...
                'Position', [10 42 45 22], 'FontColor', [0.85 0.85 0.85]);
            app.SPLRefSpinner = uispinner(app.SPLCalPanel, ...
                'Value', 94, 'Limits', [60 130], 'Step', 0.1, ...
                'Position', [58 42 70 22]);
            app.SPLCalibrateButton = uibutton(app.SPLCalPanel, 'push', ...
                'Text', 'Auto Calibrate', 'Position', [138 40 115 26], ...
                'BackgroundColor', [0.5 0.35 0.15], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) runSPLCalibration(app));

            % Bottom Row: Manual Offset & Status
            app.ManualOffsetLabel = uilabel(app.SPLCalPanel, 'Text', 'Manual Offset:', ...
                'Position', [10 12 85 22], 'FontColor', [0.85 0.85 0.85]);
            app.ManualOffsetSpinner = uispinner(app.SPLCalPanel, ...
                'Value', 0, 'Limits', [-200 200], 'Step', 0.5, ...
                'Position', [95 12 70 22], ...
                'ValueChangedFcn', @(~,~) applyManualOffset(app));
            
            app.SPLStatusLabel = uilabel(app.SPLCalPanel, 'Text', 'Not calibrated', ...
                'Position', [175 12 135 20], 'FontColor', [0.62 0.62 0.62], 'FontSize', 11);
            % Live FFT display controls
            app.LiveFFTPanel = uipanel(app.MonitorTab, 'Title', 'Live FFT Controls', ...
                'Position', [12 205 panelW 115], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            yy = 65;
            app.LiveFFTSizeLabel = uilabel(app.LiveFFTPanel, 'Text', 'FFT:', ...
                'Position', [10 yy 28 22], 'FontColor', [0.85 0.85 0.85]);
            app.LiveFFTSizeDropdown = uidropdown(app.LiveFFTPanel, ...
                'Items', {'2048','4096','8192','16384'}, 'Value', '8192', ...
                'Position', [42 yy 78 22]);
            app.LiveWindowLabel = uilabel(app.LiveFFTPanel, 'Text', 'Win:', ...
                'Position', [130 yy 28 22], 'FontColor', [0.85 0.85 0.85]);
            app.LiveWindowDropdown = uidropdown(app.LiveFFTPanel, ...
                'Items', {'Hanning','Hamming','Blackman-Harris','Flat Top','Rectangular'}, ...
                'Value', 'Hanning', 'Position', [162 yy 135 22]);

            yy = yy - 28;
            app.LiveDecayLabel = uilabel(app.LiveFFTPanel, 'Text', 'Decay:', ...
                'Position', [10 yy 40 22], 'FontColor', [0.85 0.85 0.85]);
            app.LiveDecayDropdown = uidropdown(app.LiveFFTPanel, ...
                'Items', {'Fast','Medium','Slow','None'}, 'Value', 'Medium', ...
                'Position', [55 yy 85 22]);
            app.LivePeakHoldCheckbox = uicheckbox(app.LiveFFTPanel, ...
                'Text', 'Peak Hold', 'Value', true, ...
                'Position', [150 yy 90 22], 'FontColor', [0.85 0.85 0.85]);
            app.ClearPeaksButton = uibutton(app.LiveFFTPanel, 'push', ...
                'Text', 'Clear', 'Position', [248 yy 50 22], 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) clearPeaks(app));

            yy = yy - 30;
            app.LiveAutoYCheckbox = uicheckbox(app.LiveFFTPanel, ...
                'Text', 'Auto Y', 'Value', true, ...
                'Position', [10 yy 70 22], 'FontColor', [0.85 0.85 0.85]);
            app.LiveYMinLabel = uilabel(app.LiveFFTPanel, 'Text', 'Y:', ...
                'Position', [85 yy 15 22], 'FontColor', [0.85 0.85 0.85]);
            app.LiveYMinSpinner = uispinner(app.LiveFFTPanel, ...
                'Value', -100, 'Limits', [-160 0], 'Step', 10, ...
                'Position', [102 yy 65 22]);
            uilabel(app.LiveFFTPanel, 'Text', 'to', ...
                'Position', [170 yy 15 22], 'FontColor', [0.7 0.7 0.7]);
            app.LiveYMaxSpinner = uispinner(app.LiveFFTPanel, ...
                'Value', 0, 'Limits', [-60 60], 'Step', 10, ...
                'Position', [188 yy 65 22]);
            uilabel(app.LiveFFTPanel, 'Text', 'dB', ...
                'Position', [256 yy 20 22], 'FontColor', [0.7 0.7 0.7]);

            % Real-time sound level meter panel
            app.SPLMeterPanel = uipanel(app.MonitorTab, 'Title', 'Sound Level (dB)', ...
                'Position', [345 755 960 40+20], ...
                'BackgroundColor', [0.20 0.20 0.22], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            % Large current dB readout
            app.SPLCurrentLabel = uilabel(app.SPLMeterPanel, 'Text', 'Level:', ...
                'Position', [10 12 40 22], 'FontColor', [0.7 0.7 0.7], 'FontSize', 12);
            app.SPLValueLabel = uilabel(app.SPLMeterPanel, 'Text', '--- dB', ...
                'Position', [50 6 120 32], ...
                'FontColor', [0.3 1.0 0.4], 'FontSize', 22, 'FontWeight', 'bold');

            % Peak and minimum readouts
            app.SPLPeakLabel = uilabel(app.SPLMeterPanel, 'Text', 'Peak:', ...
                'Position', [175 12 35 22], 'FontColor', [0.7 0.7 0.7], 'FontSize', 11);
            app.SPLPeakValueLabel = uilabel(app.SPLMeterPanel, 'Text', '--- dB', ...
                'Position', [212 12 80 22], ...
                'FontColor', [1.0 0.45 0.3], 'FontSize', 13, 'FontWeight', 'bold');

            app.SPLMinLabel = uilabel(app.SPLMeterPanel, 'Text', 'Min:', ...
                'Position', [300 12 30 22], 'FontColor', [0.7 0.7 0.7], 'FontSize', 11);
            app.SPLMinValueLabel = uilabel(app.SPLMeterPanel, 'Text', '--- dB', ...
                'Position', [332 12 80 22], ...
                'FontColor', [0.5 0.7 1.0], 'FontSize', 13, 'FontWeight', 'bold');

            % Frequency weighting selector for the level meter
            app.SPLWeightingLabel = uilabel(app.SPLMeterPanel, 'Text', 'Weighting:', ...
                'Position', [425 12 62 22], 'FontColor', [0.7 0.7 0.7], 'FontSize', 11);
            app.SPLWeightingDropdown = uidropdown(app.SPLMeterPanel, ...
                'Items', {'Z (Flat)','A','C'}, 'Value', 'A', ...
                'Position', [490 12 80 22]);

            % Reset button to clear peak and min values
            app.SPLResetPeakButton = uibutton(app.SPLMeterPanel, 'push', ...
                'Text', 'Reset', 'Position', [580 12 50 22], 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) resetSPLPeakMin(app));

            % Sample manager panel
            app.SamplePanel = uipanel(app.MonitorTab, 'Title', 'Samples', ...
                'Position', [12 5 panelW 195], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.SampleListBox = uilistbox(app.SamplePanel, ...
                'Items', {}, 'Position', [10 36 295 130], 'Multiselect', 'on');

            bw = 56; bx = 10;
            app.RenameSampleButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Rename', 'Position', [bx 5 bw 24], 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) renameSample(app));
            app.DeleteSampleButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Delete', 'Position', [bx+bw+3 5 bw 24], 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) deleteSample(app));
            app.ImportWavButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Import', 'Position', [bx+2*(bw+3) 5 bw 24], 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) importWav(app));
            app.SaveSessionButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Save', 'Position', [bx+3*(bw+3) 5 bw 24], 'FontSize', 10, ...
                'BackgroundColor', [0.2 0.42 0.28], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) saveSession(app));
            app.LoadSessionButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Load', 'Position', [bx+4*(bw+3) 5 bw 24], 'FontSize', 10, ...
                'BackgroundColor', [0.28 0.28 0.48], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) loadSession(app));

            % Live waveform and spectrum axes (positioned below the dB meter)
            axL = 345; axW = 960;

            app.WaveformAxes = uiaxes(app.MonitorTab, ...
                'Position', [axL 420 axW 320]);
            title(app.WaveformAxes, 'Waveform');
            xlabel(app.WaveformAxes, 'Time (s)'); ylabel(app.WaveformAxes, 'Amplitude');
            app.styleAxesDark(app.WaveformAxes);

            app.LiveFFTAxes = uiaxes(app.MonitorTab, ...
                'Position', [axL 15 axW 385]);
            title(app.LiveFFTAxes, 'Live Spectrum');
            xlabel(app.LiveFFTAxes, 'Frequency (Hz)'); ylabel(app.LiveFFTAxes, 'dBFS');
            app.LiveFFTAxes.XScale = 'log';
            app.styleAxesDark(app.LiveFFTAxes);

            % FFT Analysis tab
            app.AnalysisTab = uitab(app.TabGroup, 'Title', '  FFT Analysis  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            % --- Settings panel (FFT parameters only) ---
            app.AnalysisPanel = uipanel(app.AnalysisTab, 'Title', 'FFT Settings', ...
                'Position', [12 570 275 190], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            yy = 140;
            app.FFTSizeLabel = uilabel(app.AnalysisPanel, 'Text', 'FFT:', ...
                'Position', [10 yy 30 22], 'FontColor', [0.85 0.85 0.85]);
            app.FFTSizeDropdown = uidropdown(app.AnalysisPanel, ...
                'Items', {'1024','2048','4096','8192','16384','32768','65536'}, ...
                'Value', '8192', 'Position', [45 yy 90 22]);

            yy = yy - 26;
            app.WindowLabel = uilabel(app.AnalysisPanel, 'Text', 'Win:', ...
                'Position', [10 yy 30 22], 'FontColor', [0.85 0.85 0.85]);
            app.WindowDropdown = uidropdown(app.AnalysisPanel, ...
                'Items', {'Hanning','Hamming','Blackman-Harris','Flat Top','Rectangular'}, ...
                'Value', 'Hanning', 'Position', [45 yy 155 22]);

            yy = yy - 26;
            app.AveragingLabel = uilabel(app.AnalysisPanel, 'Text', 'Method:', ...
                'Position', [10 yy 45 22], 'FontColor', [0.85 0.85 0.85]);
            app.AveragingDropdown = uidropdown(app.AnalysisPanel, ...
                'Items', {'Welch (Averaged)','Raw FFT'}, ...
                'Value', 'Welch (Averaged)', 'Position', [60 yy 145 22]);

            yy = yy - 26;
            app.OverlayCheckbox = uicheckbox(app.AnalysisPanel, ...
                'Text', 'Overlay all', 'Value', true, ...
                'Position', [10 yy 90 22], 'FontColor', [0.85 0.85 0.85]);
            app.FreqScaleLabel = uilabel(app.AnalysisPanel, 'Text', 'Scale:', ...
                'Position', [110 yy 38 22], 'FontColor', [0.85 0.85 0.85]);
            app.FreqScaleSwitch = uiswitch(app.AnalysisPanel, 'slider', ...
                'Items', {'Linear','Log'}, 'Value', 'Log', ...
                'Position', [184 yy 45 20]);

            yy = yy - 32;
            app.AnalyzeButton = uibutton(app.AnalysisPanel, 'push', ...
                'Text', 'Analyze', 'Position', [10 yy 125 28], ...
                'BackgroundColor', [0.2 0.45 0.7], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'FontSize', 13, ...
                'ButtonPushedFcn', @(~,~) analyzeButtonPushed(app));
            app.ExportAnalysisButton = uibutton(app.AnalysisPanel, 'push', ...
                'Text', 'Export', 'Position', [145 yy 110 28], ...
                'ButtonPushedFcn', @(~,~) exportPlot(app, app.AnalysisAxes));

            % --- Analysis entries panel (build comparison list) ---
            app.EntriesPanel = uipanel(app.AnalysisTab, 'Title', 'Analysis Entries', ...
                'Position', [12 10 275 555], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            yy = 509;
            app.EntrySampleLabel = uilabel(app.EntriesPanel, 'Text', 'Sample:', ...
                'Position', [10 yy 50 22], 'FontColor', [0.85 0.85 0.85]);
            app.EntrySampleDropdown = uidropdown(app.EntriesPanel, ...
                'Items', {}, 'Position', [65 yy 192 22], ...
                'ValueChangedFcn', @(~,~) onEntrySampleChanged(app));

            yy = yy - 28;
            app.EntryStartLabel = uilabel(app.EntriesPanel, 'Text', 'Start (s):', ...
                'Position', [10 yy 55 22], 'FontColor', [0.85 0.85 0.85]);
            app.EntryStartSpinner = uispinner(app.EntriesPanel, ...
                'Value', 0, 'Limits', [0 9999], 'Step', 0.1, ...
                'Position', [68 yy 65 22], ...
                'ValueDisplayFormat', '%.1f');
            app.EntryEndLabel = uilabel(app.EntriesPanel, 'Text', 'End (s):', ...
                'Position', [141 yy 48 22], 'FontColor', [0.85 0.85 0.85]);
            app.EntryEndSpinner = uispinner(app.EntriesPanel, ...
                'Value', 0, 'Limits', [0 9999], 'Step', 0.1, ...
                'Position', [192 yy 65 22], ...
                'ValueDisplayFormat', '%.1f');

            yy = yy - 30;
            app.AddEntryButton = uibutton(app.EntriesPanel, 'push', ...
                'Text', '+ Add', 'Position', [10 yy 122 26], ...
                'BackgroundColor', [0.3 0.52 0.3], 'FontColor', 'w', ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) addEntry(app));
            app.AddAllButton = uibutton(app.EntriesPanel, 'push', ...
                'Text', '+ Add All', 'Position', [136 yy 121 26], ...
                'BackgroundColor', [0.28 0.42 0.28], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) addAllEntries(app));

            yy = yy - 28;
            app.RemoveEntryButton = uibutton(app.EntriesPanel, 'push', ...
                'Text', 'Remove Selected', 'Position', [10 yy 122 24], ...
                'FontSize', 11, ...
                'ButtonPushedFcn', @(~,~) removeEntry(app));
            app.ClearEntriesButton = uibutton(app.EntriesPanel, 'push', ...
                'Text', 'Clear All', 'Position', [136 yy 121 24], ...
                'FontSize', 11, ...
                'ButtonPushedFcn', @(~,~) clearEntries(app));

            yy = yy - 22;
            uilabel(app.EntriesPanel, 'Text', 'Queued for analysis (select to remove):', ...
                'Position', [10 yy 250 18], 'FontColor', [0.58 0.58 0.58], 'FontSize', 10);

            app.EntriesListBox = uilistbox(app.EntriesPanel, ...
                'Items', {'(empty - add entries above)'}, ...
                'Position', [10 10 250 yy-8], ...
                'FontName', 'Consolas', 'FontSize', 11);

            app.AnalysisAxes = uiaxes(app.AnalysisTab, ...
                'Position', [300 20 1000 760]);
            title(app.AnalysisAxes, 'Frequency Spectrum');
            xlabel(app.AnalysisAxes, 'Frequency (Hz)'); ylabel(app.AnalysisAxes, 'Magnitude (dB)');
            app.AnalysisAxes.XScale = 'log';
            app.styleAxesDark(app.AnalysisAxes);

            % Waterfall and Spectrogram tab
            app.WaterfallTab = uitab(app.TabGroup, 'Title', '  Waterfall / Spectrogram  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            app.WFPanel = uipanel(app.WaterfallTab, 'Title', 'Settings', ...
                'Position', [12 370 260 395], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            yy = 340;
            app.WFSampleLabel = uilabel(app.WFPanel, 'Text', 'Sample:', ...
                'Position', [10 yy 50 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFSampleDropdown = uidropdown(app.WFPanel, ...
                'Items', {}, 'Position', [65 yy 175 22]);

            yy = yy - 30;
            app.WFStyleLabel = uilabel(app.WFPanel, 'Text', 'View:', ...
                'Position', [10 yy 35 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFStyleDropdown = uidropdown(app.WFPanel, ...
                'Items', {'Spectrogram (2D)','Waterfall (3D)','Surface (3D)'}, ...
                'Value', 'Spectrogram (2D)', 'Position', [50 yy 190 22]);

            yy = yy - 30;
            app.WFFFTSizeLabel = uilabel(app.WFPanel, 'Text', 'FFT:', ...
                'Position', [10 yy 30 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFFFTSizeDropdown = uidropdown(app.WFPanel, ...
                'Items', {'1024','2048','4096','8192','16384'}, ...
                'Value', '8192', 'Position', [65 yy 100 22]);

            yy = yy - 30;
            app.WFOverlapLabel = uilabel(app.WFPanel, 'Text', 'Overlap %:', ...
                'Position', [10 yy 65 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFOverlapSpinner = uispinner(app.WFPanel, ...
                'Value', 75, 'Limits', [0 95], 'Step', 5, ...
                'Position', [80 yy 80 22]);

            yy = yy - 30;
            app.WFMaxFreqLabel = uilabel(app.WFPanel, 'Text', 'Max Hz:', ...
                'Position', [10 yy 50 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFMaxFreqSpinner = uispinner(app.WFPanel, ...
                'Value', 2000, 'Limits', [100 20000], 'Step', 500, ...
                'Position', [65 yy 95 22]);

            yy = yy - 30;
            app.WFDbRangeLabel = uilabel(app.WFPanel, 'Text', 'dB Range:', ...
                'Position', [10 yy 58 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFDbRangeSpinner = uispinner(app.WFPanel, ...
                'Value', 80, 'Limits', [20 120], 'Step', 10, ...
                'Position', [72 yy 80 22]);

            yy = yy - 28;
            app.WFApplyCalCheckbox = uicheckbox(app.WFPanel, ...
                'Text', 'Apply Calibration', 'Value', true, ...
                'Position', [10 yy 150 22], 'FontColor', [0.85 0.85 0.85]);

            yy = yy - 28;
            app.WFTrimStartLabel = uilabel(app.WFPanel, 'Text', 'Start (s):', ...
                'Position', [10 yy 55 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFTrimStartSpinner = uispinner(app.WFPanel, ...
                'Value', 0, 'Limits', [0 9999], 'Step', 0.5, ...
                'Position', [70 yy 60 22]);
            app.WFTrimEndLabel = uilabel(app.WFPanel, 'Text', 'End (s):', ...
                'Position', [138 yy 45 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFTrimEndSpinner = uispinner(app.WFPanel, ...
                'Value', 0, 'Limits', [0 9999], 'Step', 0.5, ...
                'Position', [186 yy 60 22]);

            yy = yy - 35;
            app.WFPlotButton = uibutton(app.WFPanel, 'push', ...
                'Text', 'Plot', 'Position', [10 yy 110 30], ...
                'BackgroundColor', [0.2 0.45 0.7], 'FontColor', 'w', 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) waterfallPlot(app));
            app.WFExportButton = uibutton(app.WFPanel, 'push', ...
                'Text', 'Export', 'Position', [130 yy 110 30], ...
                'ButtonPushedFcn', @(~,~) exportPlot(app, app.WFAxes));

            app.WFAxes = uiaxes(app.WaterfallTab, 'Position', [285 20 1020 760]);
            title(app.WFAxes, 'Spectrogram / Waterfall');
            app.styleAxesDark(app.WFAxes);
        end

        % Apply dark color scheme to any axes handle
        function styleAxesDark(~, ax)
            ax.Color = [0.12 0.12 0.14];
            ax.XColor = [0.7 0.7 0.7];
            ax.YColor = [0.7 0.7 0.7];
            ax.ZColor = [0.7 0.7 0.7];
            ax.Title.Color = [0.85 0.85 0.85];
            ax.GridColor = [0.3 0.3 0.3];
            grid(ax, 'on');
        end

        % Enumerate available audio input devices and populate the dropdown
        function populateDevices(app)
            try
                info = audiodevinfo();
                nIn = info.input;
                names = cell(1, numel(nIn)+1);
                names{1} = 'Default';
                for i = 1:numel(nIn)
                    names{i+1} = sprintf('[%d] %s', nIn(i).ID, nIn(i).Name);
                end
                app.DeviceDropdown.Items = names;
                app.DeviceDropdown.Value = 'Default';
            catch
                app.DeviceDropdown.Items = {'Default'};
            end
        end

        % Parse the selected device dropdown string and return the numeric device ID
        function id = getDeviceID(app)
            sel = app.DeviceDropdown.Value;
            if strcmp(sel, 'Default')
                id = -1;
            else
                tok = regexp(sel, '^\[(\d+)\]', 'tokens');
                if ~isempty(tok), id = str2double(tok{1}{1}); else, id = -1; end
            end
        end

        % Create an audiorecorder object with the given sample rate and bit depth
        function rec = makeRecorder(app, fs, bits)
            devID = app.getDeviceID();
            if devID == -1
                rec = audiorecorder(fs, bits, 1);
            else
                rec = audiorecorder(fs, bits, 1, devID);
            end
        end

        % Initialise persistent plot handles for waveform and FFT so they can be
        % updated in-place each timer tick instead of clearing and replotting
        function initLivePlots(app)
            cla(app.WaveformAxes);
            hold(app.WaveformAxes, 'on');
            app.hWaveform = plot(app.WaveformAxes, 0, 0, ...
                'Color', [0.3 0.7 1.0], 'LineWidth', 0.5);
            app.hCursor = plot(app.WaveformAxes, [0 0], [-1 1], '-', ...
                'Color', 'r', 'LineWidth', 1.5, 'Visible', 'off');
            hold(app.WaveformAxes, 'off');
            xlabel(app.WaveformAxes, 'Time (s)');
            ylabel(app.WaveformAxes, 'Amplitude');
            title(app.WaveformAxes, 'Waveform');

            cla(app.LiveFFTAxes);
            hold(app.LiveFFTAxes, 'on');
            app.hFFTArea = area(app.LiveFFTAxes, [20 20000], [0 0], ...
                'FaceColor', [0.12 0.38 0.65], 'FaceAlpha', 0.55, ...
                'EdgeColor', [0.25 0.6 0.95], 'LineWidth', 0.8);
            app.hPeakLine = plot(app.LiveFFTAxes, [20 20000], [0 0], ...
                'Color', [1.0 0.25 0.15], 'LineWidth', 1.3, 'Visible', 'off');
            hold(app.LiveFFTAxes, 'off');
            app.LiveFFTAxes.XScale = 'log';
            xlabel(app.LiveFFTAxes, 'Frequency (Hz)');
            title(app.LiveFFTAxes, 'Live Spectrum');

            app.LastNFFT = 0;

            % Reset the sound level meter display
            app.SPLPeakValue = -Inf;
            app.SPLMinValue  = Inf;
            app.SPLValueLabel.Text = '--- dB';
            app.SPLPeakValueLabel.Text = '--- dB';
            app.SPLMinValueLabel.Text = '--- dB';
        end

        % Begin a timed recording session, capturing audio for the configured duration
        function startRecording(app)
            if app.IsRecording || app.IsMonitoring, return; end
            fs = str2double(app.SampleRateDropdown.Value);
            bits = str2double(app.BitDepthDropdown.Value);
            dur = app.DurationSpinner.Value;
            try
                app.Recorder = app.makeRecorder(fs, bits);
            catch ME
                uialert(app.UIFigure, ME.message, 'Device Error'); return;
            end
            app.IsRecording = true;
            app.RecordDuration = dur;
            app.RecordStartTime = tic;
            app.PeakHoldData = [];
            app.SmoothedFFT = [];
            app.setUIState('recording');
            app.initLivePlots();
            record(app.Recorder);
            app.startLiveTimer();
        end

        % Begin continuous monitoring without saving; useful for live level checking
        function startMonitorOnly(app)
            if app.IsRecording || app.IsMonitoring, return; end
            try
                app.Recorder = app.makeRecorder(48000, 16);
            catch ME
                uialert(app.UIFigure, ME.message, 'Device Error'); return;
            end
            app.IsMonitoring = true;
            app.PeakHoldData = [];
            app.SmoothedFFT = [];
            app.setUIState('monitoring');
            app.initLivePlots();
            record(app.Recorder);
            app.startLiveTimer();
        end

        % Halt any active recording or monitoring and save the sample if recording
        function stopAll(app)
            wasRecording = app.IsRecording;
            app.IsRecording = false;
            app.IsMonitoring = false;
            app.stopLiveTimer();
            if ~isempty(app.Recorder)
                try stop(app.Recorder); catch, end
                if wasRecording
                    app.saveSampleFromRecorder();
                end
            end
            app.setUIState('idle');
        end

        % Update button enable states and status lamp colour for current mode
        function setUIState(app, state)
            switch state
                case 'recording'
                    app.RecordStatusLamp.Color = [0.9 0.1 0.1];
                    app.RecordStatusLabel.Text = 'REC';
                    app.ProgressLabel.Text = 'Starting...';
                    app.RecordButton.Enable = 'off';
                    app.MonitorOnlyButton.Enable = 'off';
                    app.StopButton.Enable = 'on';
                case 'monitoring'
                    app.RecordStatusLamp.Color = [0.1 0.7 0.2];
                    app.RecordStatusLabel.Text = 'MON';
                    app.ProgressLabel.Text = 'Monitoring';
                    app.RecordButton.Enable = 'off';
                    app.MonitorOnlyButton.Enable = 'off';
                    app.StopButton.Enable = 'on';
                case 'idle'
                    app.RecordStatusLamp.Color = [0.4 0.4 0.4];
                    app.RecordStatusLabel.Text = 'Idle';
                    app.RecordButton.Enable = 'on';
                    app.MonitorOnlyButton.Enable = 'on';
                    app.StopButton.Enable = 'off';
            end
        end

        % Create and start a periodic timer that drives the live display updates
        function startLiveTimer(app)
            app.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.10, ...
                'BusyMode', 'drop', ...
                'TimerFcn', @(~,~) liveUpdate(app));
            start(app.LiveTimer);
        end

        % Stop and destroy the live update timer
        function stopLiveTimer(app)
            if ~isempty(app.LiveTimer) && isvalid(app.LiveTimer)
                stop(app.LiveTimer); delete(app.LiveTimer);
            end
            app.LiveTimer = [];
        end

        % Timer callback: refresh waveform, FFT, and sound level meter each tick
        function liveUpdate(app)
            if ~app.IsRecording && ~app.IsMonitoring, return; end

            try
                data = getaudiodata(app.Recorder);
            catch
                return;
            end
            if isempty(data) || length(data) < 1024, return; end

            fs = app.Recorder.SampleRate;

            % Auto-stop when the target recording duration has elapsed
            if app.IsRecording
                elapsed = toc(app.RecordStartTime);
                remaining = max(0, app.RecordDuration - elapsed);
                pct = min(100, elapsed/app.RecordDuration * 100);
                app.ProgressLabel.Text = sprintf('%.1f / %.0f s   %.0f%%   (%.0f s left)', ...
                    elapsed, app.RecordDuration, pct, remaining);
                if elapsed >= app.RecordDuration
                    app.stopAll();
                    return;
                end
            end

            % Refresh the waveform plot by updating existing line handle data
            try
                t = (0:length(data)-1)' / fs;
                set(app.hWaveform, 'XData', t, 'YData', data);

                if app.IsRecording
                    xlim(app.WaveformAxes, [0 app.RecordDuration]);
                    el = toc(app.RecordStartTime);
                    yl = ylim(app.WaveformAxes);
                    set(app.hCursor, 'XData', [el el], 'YData', yl, 'Visible', 'on');
                else
                    maxT = min(5, t(end));
                    xlim(app.WaveformAxes, [max(0,t(end)-maxT) t(end)]);
                    app.hCursor.Visible = 'off';
                end
            catch
            end

            % Compute and display the real-time sound level in dB
            try
                % Use the most recent 0.125s of audio (fast time weighting)
                blockLen = round(fs * 0.125);
                if length(data) >= blockLen
                    block = data(end-blockLen+1:end);
                else
                    block = data;
                end

                % Apply frequency weighting if selected
                weightedBlock = app.applyWeighting(block, fs);

                % Compute RMS level in dBFS, or dB SPL if calibrated
                rmsVal = rms(weightedBlock);
                levelDB = 20*log10(rmsVal + eps);
                if app.SPLCalibrated
                    levelDB = levelDB + app.SPLOffset;
                end

                % Update the numeric readout
                app.SPLValueLabel.Text = sprintf('%.1f dB', levelDB);

                % Colour the readout based on level intensity
                if app.SPLCalibrated
                    if levelDB > 85
                        app.SPLValueLabel.FontColor = [1.0 0.2 0.2];
                    elseif levelDB > 70
                        app.SPLValueLabel.FontColor = [1.0 0.8 0.2];
                    else
                        app.SPLValueLabel.FontColor = [0.3 1.0 0.4];
                    end
                else
                    if levelDB > -6
                        app.SPLValueLabel.FontColor = [1.0 0.2 0.2];
                    elseif levelDB > -20
                        app.SPLValueLabel.FontColor = [1.0 0.8 0.2];
                    else
                        app.SPLValueLabel.FontColor = [0.3 1.0 0.4];
                    end
                end

                % Track peak and minimum levels across the session
                if levelDB > app.SPLPeakValue
                    app.SPLPeakValue = levelDB;
                    app.SPLPeakValueLabel.Text = sprintf('%.1f dB', levelDB);
                end
                if levelDB < app.SPLMinValue && rmsVal > 1e-10
                    app.SPLMinValue = levelDB;
                    app.SPLMinValueLabel.Text = sprintf('%.1f dB', levelDB);
                end

            catch
            end

            % Compute and display the live FFT spectrum
            try
                nfft = str2double(app.LiveFFTSizeDropdown.Value);
                if length(data) < nfft, return; end

                w = app.getWindow(nfft, app.LiveWindowDropdown.Value);
                seg = data(end-nfft+1:end) .* w;
                Y = fft(seg, nfft);
                f = (0:nfft/2)' * fs / nfft;
                mag = 20*log10(abs(Y(1:nfft/2+1))/(nfft/2) + eps);

                if app.SPLCalibrated, mag = mag + app.SPLOffset; end
                if app.ApplyCalGlobalCheckbox.Value && app.CalLoaded
                    mag = mag + app.getCalCorrection(f);
                end

                % Remove the DC bin for display
                f = f(2:end); mag = mag(2:end);

                % Reset smoothing and peak data when the FFT size changes
                if nfft ~= app.LastNFFT
                    app.SmoothedFFT = mag;
                    app.PeakHoldData = mag;
                    app.LastNFFT = nfft;
                end

                % Exponentially weighted moving average for visual smoothing
                alpha = app.getDecayAlpha();
                if isempty(app.SmoothedFFT) || length(app.SmoothedFFT) ~= length(mag)
                    app.SmoothedFFT = mag;
                else
                    app.SmoothedFFT = alpha * mag + (1-alpha) * app.SmoothedFFT;
                end

                % Maintain peak hold envelope across FFT frames
                if app.LivePeakHoldCheckbox.Value
                    if isempty(app.PeakHoldData) || length(app.PeakHoldData) ~= length(mag)
                        app.PeakHoldData = app.SmoothedFFT;
                    else
                        app.PeakHoldData = max(app.PeakHoldData, app.SmoothedFFT);
                    end
                end

                % Refresh the existing FFT plot handles with new data
                set(app.hFFTArea, 'XData', f, 'YData', app.SmoothedFFT);

                if app.LivePeakHoldCheckbox.Value && ~isempty(app.PeakHoldData)
                    set(app.hPeakLine, 'XData', f, 'YData', app.PeakHoldData, 'Visible', 'on');
                else
                    app.hPeakLine.Visible = 'off';
                end

                xlim(app.LiveFFTAxes, [20 fs/2]);

                if ~app.LiveAutoYCheckbox.Value
                    ylim(app.LiveFFTAxes, ...
                        [app.LiveYMinSpinner.Value app.LiveYMaxSpinner.Value]);
                else
                    ylim(app.LiveFFTAxes, 'auto');
                end

                if app.SPLCalibrated
                    ylabel(app.LiveFFTAxes, 'dB SPL');
                else
                    ylabel(app.LiveFFTAxes, 'dBFS');
                end
            catch
            end
        end

        % Return the exponential smoothing coefficient for the selected decay speed
        function alpha = getDecayAlpha(app)
            switch app.LiveDecayDropdown.Value
                case 'Fast',   alpha = 0.55;
                case 'Medium', alpha = 0.28;
                case 'Slow',   alpha = 0.12;
                otherwise,     alpha = 1.0;
            end
        end

        % Reset the FFT peak hold envelope so it begins accumulating fresh data
        function clearPeaks(app)
            app.PeakHoldData = [];
        end

        % Reset the sound level meter peak and minimum tracked values
        function resetSPLPeakMin(app)
            app.SPLPeakValue = -Inf;
            app.SPLMinValue  = Inf;
            app.SPLPeakValueLabel.Text = '--- dB';
            app.SPLMinValueLabel.Text  = '--- dB';
        end

        % Apply A-weighting or C-weighting filter to an audio block.
        % Returns the block unmodified when Z (flat) weighting is selected.
        function out = applyWeighting(app, block, fs)
            weightChoice = app.SPLWeightingDropdown.Value;
            if contains(weightChoice, 'Z')
                out = block;
                return;
            end
        
            f1 = 20.598997; f2 = 107.65265; f3 = 737.86223; f4 = 12194.217;
            w1 = 2*pi*f1; w2 = 2*pi*f2; w3 = 2*pi*f3; w4 = 2*pi*f4;
        
            if contains(weightChoice, 'A')
                z = [0; 0; 0; 0];
                p = [-w1; -w1; -w4; -w4; -w2; -w3];
                k = w4^2 * 10^(2/20);
            else
                z = [0; 0];
                p = [-w1; -w1; -w4; -w4];
                k = w4^2 * 10^(0.062/20);
            end
        
            % Bilinear transform in zpk form avoids ill-conditioned polynomial math
            [zd, pd, kd] = bilinear(z, p, k, fs);
            [sos, g] = zp2sos(zd, pd, kd);
            out = g * sosfilt(sos, block);
        end

        % Store the current recorder audio as a named sample in the session
        function saveSampleFromRecorder(app)
            try
                data = getaudiodata(app.Recorder);
            catch
                return;
            end
            fs = app.Recorder.SampleRate;
            if isempty(data), return; end
            app.SampleCount = app.SampleCount + 1;
            s.name = sprintf('Run_%d', app.SampleCount);
            s.data = data; s.fs = fs; s.timestamp = datetime('now');
            if isempty(app.Samples) || (numel(app.Samples)==1 && isempty(app.Samples(1).name))
                app.Samples = s;
            else
                app.Samples(end+1) = s;
            end
            app.updateSampleLists();
            app.ProgressLabel.Text = sprintf('Saved: %s (%.1f s)', s.name, length(data)/fs);
        end

        

        % Perform SPL calibration by measuring a known reference tone and
        % computing the offset between measured dBFS and the reference dB SPL
        function runSPLCalibration(app)
            if app.IsRecording || app.IsMonitoring
                uialert(app.UIFigure, 'Stop recording/monitoring first.', 'Busy');
                return;
            end
            refSPL = app.SPLRefSpinner.Value;
            app.SPLStatusLabel.Text = 'Measuring (3 s)';
            drawnow;
            try
                rec = app.makeRecorder(48000, 24);
                recordblocking(rec, 3);
                data = getaudiodata(rec);
                rmsVal = rms(data);
                measuredDBFS = 20*log10(rmsVal + eps);
                app.SPLOffset = refSPL - measuredDBFS;
                app.SPLCalibrated = true;
                app.SPLStatusLabel.Text = sprintf('Done: offset %+.1f dB  (ref %.1f dB SPL)', ...
                    app.SPLOffset, refSPL);
            catch ME
                uialert(app.UIFigure, ME.message, 'SPL Cal Error');
                app.SPLStatusLabel.Text = 'Failed';
            end
        end

        % Load a microphone frequency response calibration file.
        % Supports multiple formats:
        %   .ods / .xlsx / .csv  - Spreadsheet with Hz, dB, Phase columns
        %   .cal / .txt          - Two-column text (frequency, dB correction)
        function loadCalFile(app)
            [file, path] = uigetfile({ ...
                '*.ods;*.xlsx;*.csv;*.cal;*.txt', 'All Calibration Files (*.ods,*.xlsx,*.csv,*.cal,*.txt)'; ...
                '*.ods',  'OpenDocument Spreadsheet (*.ods)'; ...
                '*.xlsx', 'Excel Spreadsheet (*.xlsx)'; ...
                '*.csv',  'CSV File (*.csv)'; ...
                '*.cal;*.txt', 'Text Cal Files (*.cal, *.txt)'; ...
                '*.*', 'All Files (*.*)'}, ...
                'Load Calibration');
            if isequal(file, 0), return; end

            fullpath = fullfile(path, file);
            [~, ~, ext] = fileparts(file);
            ext = lower(ext);

            try
                switch ext
                    case {'.ods', '.xlsx', '.xls', '.csv'}
                        % Read spreadsheet formats using readtable for
                        % robust header and data type detection
                        T = readtable(fullpath);

                        % Identify columns by header name or fall back to
                        % positional order (Hz, dB, Phase)
                        colNames = lower(T.Properties.VariableNames);

                        % Find frequency column
                        freqCol = find(contains(colNames, 'hz') | ...
                                       contains(colNames, 'freq'), 1);
                        if isempty(freqCol), freqCol = 1; end

                        % Find dB column
                        dbCol = find(contains(colNames, 'db') | ...
                                     contains(colNames, 'mag') | ...
                                     contains(colNames, 'level') | ...
                                     contains(colNames, 'sens'), 1);
                        if isempty(dbCol), dbCol = 2; end

                        % Find phase column (optional)
                        phaseCol = find(contains(colNames, 'phase') | ...
                                        contains(colNames, 'deg'), 1);
                        if isempty(phaseCol) && width(T) >= 3
                            phaseCol = 3;
                        end

                        freqs = T{:, freqCol};
                        dbs   = T{:, dbCol};

                        % Convert to numeric if the table read them as
                        % strings or cell arrays (common with ODS files)
                        if iscell(freqs), freqs = cellfun(@str2double, freqs); end
                        if iscell(dbs),   dbs   = cellfun(@str2double, dbs);   end

                        % Remove any rows that failed to parse
                        valid = ~isnan(freqs) & ~isnan(dbs);
                        freqs = freqs(valid);
                        dbs   = dbs(valid);

                        % Read phase data if available
                        if ~isempty(phaseCol)
                            phases = T{:, phaseCol};
                            if iscell(phases), phases = cellfun(@str2double, phases); end
                            phases = phases(valid);
                            app.CalPhase = phases(:);
                        else
                            app.CalPhase = [];
                        end

                        app.CalFreq = freqs(:);
                        app.CalDB   = dbs(:);
                        app.CalLoaded = true;
                        app.CalFileName = file;
                        nPts = numel(freqs);

                        if ~isempty(app.CalPhase)
                            app.CalFileLabel.Text = sprintf('Loaded: %s (%d pts, +phase)', file, nPts);
                        else
                            app.CalFileLabel.Text = sprintf('Loaded: %s (%d pts)', file, nPts);
                        end

                    otherwise
                        % Legacy text/cal file parser (two-column: freq dB)
                        raw = fileread(fullpath);
                        lines = strsplit(raw, {'\n','\r'});
                        freqs = []; dbs = [];
                        for i = 1:numel(lines)
                            s = strtrim(lines{i});
                            if isempty(s) || any(s(1) == '*;#"'), continue; end
                            nums = sscanf(s, '%f %f');
                            if numel(nums) >= 2
                                freqs(end+1) = nums(1); dbs(end+1) = nums(2); %#ok<AGROW>
                            end
                        end
                        app.CalFreq = freqs(:); app.CalDB = dbs(:);
                        app.CalPhase = [];
                        app.CalLoaded = true; app.CalFileName = file;
                        app.CalFileLabel.Text = sprintf('Loaded: %s (%d pts)', file, numel(freqs));
                end

            catch ME
                uialert(app.UIFigure, ...
                    sprintf('Failed to read "%s":\n%s', file, ME.message), ...
                    'Cal File Error');
            end
        end

        % Remove the loaded calibration data and reset the display label
        function clearCal(app)
            app.CalFreq = []; app.CalDB = []; app.CalPhase = [];
            app.CalLoaded = false; app.CalFileName = "";
            app.CalFileLabel.Text = 'No file loaded';
        end

        % Interpolate the calibration curve at the requested frequencies,
        % returning zero correction when no calibration is loaded
        function c = getCalCorrection(app, f)
            if app.CalLoaded
                c = interp1(app.CalFreq, app.CalDB, f, 'linear', 0);
            else
                c = zeros(size(f));
            end
        end

        % Interpolate the calibration phase curve at the requested frequencies,
        % returning zero when no phase data is available
        function p = getCalPhaseCorrection(app, f)
            if app.CalLoaded && ~isempty(app.CalPhase)
                p = interp1(app.CalFreq, app.CalPhase, f, 'linear', 0);
            else
                p = zeros(size(f));
            end
        end

        % Synchronise all sample list controls across tabs with current session data
        function updateSampleLists(app)
            if isempty(app.Samples) || (numel(app.Samples)==1 && isempty(app.Samples(1).name))
                names = {}; raw = {};
            else
                names = arrayfun(@(s) sprintf('%s  [%.1fs, %dHz]', ...
                    s.name, length(s.data)/s.fs, s.fs), app.Samples, 'UniformOutput', false);
                raw = {app.Samples.name};
            end
            app.SampleListBox.Items = names;
            app.SampleListBox.ItemsData = raw;
            app.WFSampleDropdown.Items = names;
            app.WFSampleDropdown.ItemsData = raw;

            % Sync the analysis entry sample dropdown
            app.EntrySampleDropdown.Items = names;
            app.EntrySampleDropdown.ItemsData = raw;
        end

        % Prompt the user for a new name and rename the selected sample
        function renameSample(app)
            sel = app.SampleListBox.Value;
            if isempty(sel), return; end
            if iscell(sel), sel = sel{1}; end
            idx = find(strcmp({app.Samples.name}, sel), 1);
            if isempty(idx), return; end
            newName = inputdlg('New name:', 'Rename', [1 40], {sel});
            if ~isempty(newName) && ~isempty(newName{1})
                % Update any analysis entries referencing the old name
                for k = 1:numel(app.AnalysisEntries)
                    if strcmp(app.AnalysisEntries(k).name, sel)
                        app.AnalysisEntries(k).name = newName{1};
                    end
                end
                app.Samples(idx).name = newName{1};
                app.updateSampleLists();
                app.refreshEntriesListBox();
            end
        end

        % Remove the selected samples from the session
        function deleteSample(app)
            sel = app.SampleListBox.Value;
            if isempty(sel), return; end
            if ~iscell(sel), sel = {sel}; end
            for i = 1:numel(sel)
                idx = find(strcmp({app.Samples.name}, sel{i}), 1);
                if ~isempty(idx)
                    app.Samples(idx) = [];
                end
                % Remove any analysis entries referencing this sample
                if ~isempty(app.AnalysisEntries)
                    keep = ~strcmp({app.AnalysisEntries.name}, sel{i});
                    app.AnalysisEntries = app.AnalysisEntries(keep);
                end
            end
            app.updateSampleLists();
            app.refreshEntriesListBox();
        end

        % Import one or more WAV files from disk as new session samples
        function importWav(app)
            [file, path] = uigetfile({'*.wav','WAV'}, 'Import', 'MultiSelect', 'on');
            if isequal(file, 0), return; end
            if ~iscell(file), file = {file}; end
            for i = 1:numel(file)
                [data, fs] = audioread(fullfile(path, file{i}));
                if size(data,2)>1, data = mean(data,2); end
                app.SampleCount = app.SampleCount + 1;
                [~, fn] = fileparts(file{i});
                s.name = fn; s.data = data; s.fs = fs; s.timestamp = datetime('now');
                if isempty(app.Samples) || (numel(app.Samples)==1 && isempty(app.Samples(1).name))
                    app.Samples = s;
                else
                    app.Samples(end+1) = s;
                end
            end
            app.updateSampleLists();
        end

        % Generate a window function vector of length N for the given window name
        function w = getWindow(~, N, name)
            switch name
                case 'Hanning',          w = hann(N);
                case 'Hamming',          w = hamming(N);
                case 'Blackman-Harris',  w = blackmanharris(N);
                case 'Flat Top',         w = flattopwin(N);
                case 'Rectangular',      w = ones(N,1);
                otherwise,               w = hann(N);
            end
        end

        % When the entry sample dropdown changes, auto-fill End spinner
        % with the sample's full duration so the user can see the range
        function onEntrySampleChanged(app)
            selName = app.EntrySampleDropdown.Value;
            if isempty(selName), return; end
            idx = find(strcmp({app.Samples.name}, selName), 1);
            if ~isempty(idx)
                dur = length(app.Samples(idx).data) / app.Samples(idx).fs;
                app.EntryEndSpinner.Value = round(dur, 1);
                app.EntryStartSpinner.Value = 0;
            end
        end

        % Add the current sample + time window as a new entry in the queue
        function addEntry(app)
            selName = app.EntrySampleDropdown.Value;
            if isempty(selName), return; end
            e.name   = selName;
            e.tStart = app.EntryStartSpinner.Value;
            e.tEnd   = app.EntryEndSpinner.Value;
            e.dB     = NaN;
            if isempty(app.AnalysisEntries) || ...
               (numel(app.AnalysisEntries)==1 && isempty(app.AnalysisEntries(1).name))
                app.AnalysisEntries = e;
            else
                app.AnalysisEntries(end+1) = e;
            end
            app.refreshEntriesListBox();
        end

        % Add all session samples as full-duration entries in one click
        function addAllEntries(app)
            if isempty(app.Samples), return; end
            for i = 1:numel(app.Samples)
                if isempty(app.Samples(i).name), continue; end
                e.name   = app.Samples(i).name;
                e.tStart = 0;
                e.tEnd   = round(length(app.Samples(i).data)/app.Samples(i).fs, 1);
                e.dB     = NaN;
                if isempty(app.AnalysisEntries) || ...
                   (numel(app.AnalysisEntries)==1 && isempty(app.AnalysisEntries(1).name))
                    app.AnalysisEntries = e;
                else
                    app.AnalysisEntries(end+1) = e;
                end
            end
            app.refreshEntriesListBox();
        end

        % Remove the currently selected entry from the queue
        function removeEntry(app)
            sel = app.EntriesListBox.Value;
            if isempty(sel) || isempty(app.AnalysisEntries), return; end
            % Value holds the index as ItemsData
            if iscell(sel), sel = sel{1}; end
            idx = sel;
            if idx >= 1 && idx <= numel(app.AnalysisEntries)
                app.AnalysisEntries(idx) = [];
            end
            app.refreshEntriesListBox();
        end

        % Remove all entries from the analysis queue
        function clearEntries(app)
            app.AnalysisEntries = struct('name',{},'tStart',{},'tEnd',{},'dB',{});
            app.refreshEntriesListBox();
        end

        % Rebuild the entries listbox display from the current queue
        function refreshEntriesListBox(app)
            if isempty(app.AnalysisEntries)
                app.EntriesListBox.Items = {'(empty - add entries above)'};
                app.EntriesListBox.ItemsData = {};
                return;
            end
            items = cell(1, numel(app.AnalysisEntries));
            idxs = cell(1, numel(app.AnalysisEntries));
            for i = 1:numel(app.AnalysisEntries)
                e = app.AnalysisEntries(i);
                if isnan(e.dB)
                    dbStr = '';
                else
                    dbStr = sprintf('  %.1f dB', e.dB);
                end
                items{i} = sprintf('%s  %.1f-%.1fs%s', e.name, e.tStart, e.tEnd, dbStr);
                idxs{i}  = i;
            end
            app.EntriesListBox.Items = items;
            app.EntriesListBox.ItemsData = [idxs{:}];
        end

        % Run FFT or Welch analysis on the entries in the queue and plot results.
        % Computes broadband dB for each entry and shows it in the legend.
        function analyzeButtonPushed(app)
            if isempty(app.AnalysisEntries)
                uialert(app.UIFigure, ...
                    'Add one or more entries using the panel on the left.', ...
                    'No Entries');
                return;
            end

            nfft    = str2double(app.FFTSizeDropdown.Value);
            winName = app.WindowDropdown.Value;
            applyCal  = app.ApplyCalGlobalCheckbox.Value && app.CalLoaded;
            doOverlay = app.OverlayCheckbox.Value;
            useLog    = strcmp(app.FreqScaleSwitch.Value, 'Log');
            method    = app.AveragingDropdown.Value;

            nEntries = numel(app.AnalysisEntries);
            cla(app.AnalysisAxes); hold(app.AnalysisAxes, 'on');
            colors = lines(nEntries); legs = {};

            for i = 1:nEntries
                e = app.AnalysisEntries(i);
                idx = find(strcmp({app.Samples.name}, e.name), 1);
                if isempty(idx), continue; end
                data = app.Samples(idx).data; fs = app.Samples(idx).fs;

                % Apply per-entry time trim
                totalDur = length(data) / fs;
                tStart = max(0, min(e.tStart, totalDur));
                tEnd   = min(e.tEnd, totalDur);
                if tEnd <= tStart, tEnd = totalDur; end
                sStart = round(tStart * fs) + 1;
                sEnd   = min(round(tEnd * fs), length(data));
                if sStart < sEnd
                    data = data(sStart:sEnd);
                end

                % Compute broadband RMS level of the trimmed segment
                rmsVal  = rms(data);
                levelDB = 20*log10(rmsVal + eps);
                if app.SPLCalibrated, levelDB = levelDB + app.SPLOffset; end

                % Store the computed dB back into the entry
                app.AnalysisEntries(i).dB = levelDB;

                if contains(method, 'Welch')
                    w = app.getWindow(nfft, winName);
                    [pxx, f] = pwelch(data, w, round(nfft*0.5), nfft, fs);
                    mag = 10*log10(pxx + eps);
                else
                    if length(data)<nfft, data=[data;zeros(nfft-length(data),1)]; end %#ok<AGROW>
                    w = app.getWindow(nfft, winName);
                    Y = fft(data(1:nfft).*w, nfft);
                    f = (0:nfft/2)' * fs/nfft;
                    mag = 20*log10(abs(Y(1:nfft/2+1))/(nfft/2) + eps);
                end

                if app.SPLCalibrated, mag = mag + app.SPLOffset; end
                if applyCal, mag = mag + app.getCalCorrection(f); end

                if ~doOverlay && i>1, cla(app.AnalysisAxes); hold(app.AnalysisAxes,'on'); end

                % Build legend: name [trim range] (dB level)
                if app.SPLCalibrated
                    unit = 'dB SPL';
                else
                    unit = 'dBFS';
                end
                legLabel = sprintf('%s [%.1f-%.1fs] (%.1f %s)', ...
                    e.name, tStart, tEnd, levelDB, unit);
                plot(app.AnalysisAxes, f, mag, 'Color', colors(i,:), 'LineWidth', 1.3);
                legs{end+1} = legLabel; %#ok<AGROW>
            end

            if useLog
                app.AnalysisAxes.XScale='log'; xlim(app.AnalysisAxes,[20 max(f)]);
            else
                app.AnalysisAxes.XScale='linear'; xlim(app.AnalysisAxes,[0 max(f)]);
            end
            xlabel(app.AnalysisAxes,'Frequency (Hz)');
            if app.SPLCalibrated
                ylabel(app.AnalysisAxes,'dB SPL');
            else
                ylabel(app.AnalysisAxes,'dBFS');
            end
            title(app.AnalysisAxes, 'Frequency Spectrum');
            legend(app.AnalysisAxes, legs, 'TextColor',[0.85 0.85 0.85], ...
                'Color',[0.2 0.2 0.22], 'Location','northeast', 'Interpreter', 'none');
            hold(app.AnalysisAxes,'off');

            % Refresh the entries list to show computed dB values
            app.refreshEntriesListBox();
        end

        % Generate a spectrogram, waterfall, or surface plot for the selected sample
        function waterfallPlot(app)
            selName = app.WFSampleDropdown.Value;
            if isempty(selName), return; end
            idx = find(strcmp({app.Samples.name}, selName), 1);
            if isempty(idx), return; end

            data = app.Samples(idx).data; fs = app.Samples(idx).fs;

            % Apply time trim from the waterfall trim spinners
            wfTrimStart = app.WFTrimStartSpinner.Value;
            wfTrimEnd   = app.WFTrimEndSpinner.Value;
            totalDur = length(data) / fs;
            timeOffset = 0;
            if wfTrimStart > 0 || (wfTrimEnd > 0 && wfTrimEnd < totalDur)
                tStart = max(0, min(wfTrimStart, totalDur));
                if wfTrimEnd <= tStart
                    tEnd = totalDur;
                else
                    tEnd = min(wfTrimEnd, totalDur);
                end
                sStart = round(tStart * fs) + 1;
                sEnd   = min(round(tEnd * fs), length(data));
                if sStart < sEnd
                    data = data(sStart:sEnd);
                    timeOffset = tStart;
                end
            end

            nfft = str2double(app.WFFFTSizeDropdown.Value);
            noverlap = round(nfft * app.WFOverlapSpinner.Value/100);
            maxFreq = app.WFMaxFreqSpinner.Value;
            applyCal = app.WFApplyCalCheckbox.Value && app.CalLoaded;
            dbRange = app.WFDbRangeSpinner.Value;
            style = app.WFStyleDropdown.Value;

            [S,F,T] = spectrogram(data, hann(nfft), noverlap, nfft, fs);
            T = T + timeOffset;  % preserve original recording timeline
            S_dB = 10*log10(abs(S).^2 + eps);

            if app.SPLCalibrated, S_dB = S_dB + app.SPLOffset; end
            if applyCal, S_dB = S_dB + app.getCalCorrection(F); end

            fIdx = F <= maxFreq; F=F(fIdx); S_dB=S_dB(fIdx,:);
            pk = max(S_dB(:)); clims = [pk-dbRange pk];

            cla(app.WFAxes);
            try colorbar(app.WFAxes, 'off'); catch, end

            switch style
                case 'Spectrogram (2D)'
                    imagesc(app.WFAxes, T, F, S_dB);
                    set(app.WFAxes, 'YDir', 'normal');
                    caxis(app.WFAxes, clims);
                    colormap(app.WFAxes, 'jet');
                    cb = colorbar(app.WFAxes);
                    cb.Label.String = 'dB'; cb.Color = [0.7 0.7 0.7];
                    xlabel(app.WFAxes, 'Time (s)');
                    ylabel(app.WFAxes, 'Frequency (Hz)');
                    title(app.WFAxes, sprintf('Spectrogram - %s', app.Samples(idx).name));
                    view(app.WFAxes, [0 90]);

                case 'Waterfall (3D)'
                    maxSlices = 150;
                    if size(S_dB,2) > maxSlices
                        step = ceil(size(S_dB,2)/maxSlices);
                        Sp = S_dB(:,1:step:end); Tp = T(1:step:end);
                    else
                        Sp = S_dB; Tp = T;
                    end
                    waterfall(app.WFAxes, F, Tp, Sp');
                    colormap(app.WFAxes, 'jet'); caxis(app.WFAxes, clims);
                    xlabel(app.WFAxes, 'Frequency (Hz)');
                    ylabel(app.WFAxes, 'Time (s)');
                    zlabel(app.WFAxes, 'dB');
                    title(app.WFAxes, sprintf('Waterfall - %s', app.Samples(idx).name));
                    view(app.WFAxes, [-35 40]);
                    zlim(app.WFAxes, clims);

                case 'Surface (3D)'
                    maxSlices = 150;
                    if size(S_dB,2) > maxSlices
                        step = ceil(size(S_dB,2)/maxSlices);
                        Sp = S_dB(:,1:step:end); Tp = T(1:step:end);
                    else
                        Sp = S_dB; Tp = T;
                    end
                    surf(app.WFAxes, F, Tp, Sp', 'EdgeColor', 'none');
                    colormap(app.WFAxes, 'jet'); caxis(app.WFAxes, clims);
                    cb = colorbar(app.WFAxes);
                    cb.Label.String = 'dB'; cb.Color = [0.7 0.7 0.7];
                    xlabel(app.WFAxes, 'Frequency (Hz)');
                    ylabel(app.WFAxes, 'Time (s)');
                    zlabel(app.WFAxes, 'dB');
                    title(app.WFAxes, sprintf('Surface - %s', app.Samples(idx).name));
                    view(app.WFAxes, [-35 40]);
                    zlim(app.WFAxes, clims);
            end
        end

        % Export the contents of any axes to a PNG or FIG file via save dialog
        function exportPlot(~, ax)
            [file, path] = uiputfile({'*.png','PNG';'*.fig','Figure'}, 'Export');
            if isequal(file,0), return; end
            exportgraphics(ax, fullfile(path,file), 'Resolution', 300);
        end
        
        % Save all session data (samples, calibration, SPL offset) to a MAT file
        function saveSession(app)
            % If we already have a session filename, overwrite it silently
            if strlength(app.SessionFile) > 0
                ses.Samples = app.Samples; ses.SampleCount = app.SampleCount;
                ses.CalFreq = app.CalFreq; ses.CalDB = app.CalDB;
                ses.CalPhase = app.CalPhase;
                ses.CalLoaded = app.CalLoaded; ses.CalFileName = app.CalFileName;
                ses.SPLOffset = app.SPLOffset; ses.SPLCalibrated = app.SPLCalibrated;
                try
                    save(app.SessionFile, '-struct', 'ses');
                    app.ProgressLabel.Text = sprintf('Saved session: %s', app.SessionFile);
                catch ME
                    uialert(app.UIFigure, ME.message, 'Save Error');
                end
                return;
            end
                    
            % Otherwise prompt for filename and store it for future saves
            [file,path] = uiputfile({'*.mat','Session'}, 'Save');
            if isequal(file,0), return; end
            app.SessionFile = fullfile(path,file);
        
            ses.Samples = app.Samples; ses.SampleCount = app.SampleCount;
            ses.CalFreq = app.CalFreq; ses.CalDB = app.CalDB;
            ses.CalPhase = app.CalPhase;
            ses.CalLoaded = app.CalLoaded; ses.CalFileName = app.CalFileName;
            ses.SPLOffset = app.SPLOffset; ses.SPLCalibrated = app.SPLCalibrated;
            try
                save(app.SessionFile, '-struct', 'ses');
                app.ProgressLabel.Text = sprintf('Saved session: %s', app.SessionFile);
            catch ME
                uialert(app.UIFigure, ME.message, 'Save Error');
            end
        end

        % Restore a previously saved session from a MAT file
        function loadSession(app)
            [file,path] = uigetfile({'*.mat','Session'}, 'Load');
            if isequal(file,0), return; end
            fullpath = fullfile(path,file);
            try
                ses = load(fullpath);
            catch ME
                uialert(app.UIFigure, ME.message, 'Load Error');
                return;
            end
            app.Samples = ses.Samples; 
            app.SampleCount = ses.SampleCount;
            if isfield(ses,'CalLoaded') && ses.CalLoaded
                app.CalFreq = ses.CalFreq; app.CalDB = ses.CalDB;
                app.CalLoaded = true; app.CalFileName = ses.CalFileName;
                app.CalFileLabel.Text = sprintf('Loaded: %s (%d pts)', app.CalFileName, numel(app.CalFreq));
                % Restore phase data if it was saved
                if isfield(ses, 'CalPhase')
                    app.CalPhase = ses.CalPhase;
                    if ~isempty(app.CalPhase)
                        app.CalFileLabel.Text = sprintf('Loaded: %s (%d pts, +phase)', ...
                            app.CalFileName, numel(app.CalFreq));
                    end
                else
                    app.CalPhase = [];
                end
            end
            if isfield(ses,'SPLCalibrated') && ses.SPLCalibrated
                app.SPLOffset = ses.SPLOffset; app.SPLCalibrated = true;
                app.SPLStatusLabel.Text = sprintf('Done: offset %+.1f dB', app.SPLOffset);
            end
        
            % Remember the file so future Save overwrites without prompting
            app.SessionFile = string(fullpath);   
            
            app.updateSampleLists();
            app.ProgressLabel.Text = sprintf('Loaded session: %s', fullpath);
        end

        function applyManualOffset(app)
            val = app.ManualOffsetSpinner.Value;
            app.SPLOffset = val;
            app.SPLCalibrated = true;
            app.SPLStatusLabel.Text = sprintf('Manual: %+.1f dB', app.SPLOffset);
        end

        % Clean up timers, stop recording, and close the figure on app exit
        function appCloseRequest(app)
            app.IsRecording = false; app.IsMonitoring = false;
            app.stopLiveTimer();
            try stop(app.Recorder); catch, end
            delete(app.UIFigure);
        end
    end

    methods (Access = public)
        function app = ExhaustAnalyzer()
            app.Samples = struct('name',{},'data',{},'fs',{},'timestamp',{});
            app.AnalysisEntries = struct('name',{},'tStart',{},'tEnd',{},'dB',{});
            createComponents(app);
            app.UIFigure.Visible = 'on';
        end

        function delete(app)
            app.IsRecording=false; app.IsMonitoring=false;
            app.stopLiveTimer();
            try stop(app.Recorder); catch, end
            delete(app.UIFigure);
        end
    end
end