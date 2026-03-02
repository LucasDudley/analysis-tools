classdef ExhaustAnalyzer < matlab.apps.AppBase
    % ExhaustAnalyzer - Acoustic measurement and spectral analysis tool
    %
    % Launch:  app = ExhaustAnalyzer;
    %
    % Workflow:
    %   1. Select input device, load calibration file
    %   2. Optionally run SPL calibration with a known-level calibrator
    %   3. Record + monitor live FFT with peak hold
    %   4. Analyze saved samples (overlay FFT, waterfall)
    %
    % Calibration file format (tab/space delimited, comments: * ; #):
    %   Freq(Hz)  Correction(dB)
    %   20        -1.2
    %   ...

    properties (Access = public)
        UIFigure                matlab.ui.Figure
        TabGroup                matlab.ui.container.TabGroup

        % === RECORD & MONITOR TAB ===
        MonitorTab              matlab.ui.container.Tab

        % Device / settings
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

        % Record controls
        RecordButton            matlab.ui.control.Button
        StopButton              matlab.ui.control.Button
        MonitorOnlyButton       matlab.ui.control.Button
        RecordStatusLamp        matlab.ui.control.Lamp
        RecordStatusLabel       matlab.ui.control.Label
        ProgressLabel           matlab.ui.control.Label
        ProgressBar             matlab.ui.control.Label  % visual bar via background color trick

        % Calibration panel
        CalPanel                matlab.ui.container.Panel
        LoadCalButton           matlab.ui.control.Button
        ClearCalButton          matlab.ui.control.Button
        CalFileLabel            matlab.ui.control.Label
        ApplyCalGlobalCheckbox  matlab.ui.control.CheckBox

        % SPL Calibration
        SPLCalPanel             matlab.ui.container.Panel
        SPLRefSpinner           matlab.ui.control.Spinner
        SPLRefLabel             matlab.ui.control.Label
        SPLCalibrateButton      matlab.ui.control.Button
        SPLStatusLabel          matlab.ui.control.Label

        % Live display axes
        WaveformAxes            matlab.ui.control.UIAxes
        LiveFFTAxes             matlab.ui.control.UIAxes

        % Live FFT controls
        LiveFFTPanel            matlab.ui.container.Panel
        LiveFFTSizeDropdown     matlab.ui.control.DropDown
        LiveFFTSizeLabel        matlab.ui.control.Label
        LivePeakHoldCheckbox    matlab.ui.control.CheckBox
        LiveDecayDropdown       matlab.ui.control.DropDown
        LiveDecayLabel          matlab.ui.control.Label
        ClearPeaksButton        matlab.ui.control.Button

        % Sample manager
        SamplePanel             matlab.ui.container.Panel
        SampleListBox           matlab.ui.control.ListBox
        RenameSampleButton      matlab.ui.control.Button
        DeleteSampleButton      matlab.ui.control.Button
        ImportWavButton         matlab.ui.control.Button
        SaveSessionButton       matlab.ui.control.Button
        LoadSessionButton       matlab.ui.control.Button

        % === ANALYSIS TAB ===
        AnalysisTab             matlab.ui.container.Tab
        AnalysisPanel           matlab.ui.container.Panel
        AnalysisSampleListBox   matlab.ui.control.ListBox
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

        % === WATERFALL TAB ===
        WaterfallTab            matlab.ui.container.Tab
        WFPanel                 matlab.ui.container.Panel
        WFSampleDropdown        matlab.ui.control.DropDown
        WFSampleLabel           matlab.ui.control.Label
        WFFFTSizeDropdown       matlab.ui.control.DropDown
        WFFFTSizeLabel          matlab.ui.control.Label
        WFOverlapSpinner        matlab.ui.control.Spinner
        WFOverlapLabel          matlab.ui.control.Label
        WFMaxFreqSpinner        matlab.ui.control.Spinner
        WFMaxFreqLabel          matlab.ui.control.Label
        WFDbRangeSpinner        matlab.ui.control.Spinner
        WFDbRangeLabel          matlab.ui.control.Label
        WFColorDropdown         matlab.ui.control.DropDown
        WFColorLabel            matlab.ui.control.Label
        WFApplyCalCheckbox      matlab.ui.control.CheckBox
        WFPlotButton            matlab.ui.control.Button
        WFExportButton          matlab.ui.control.Button
        SpectrogramAxes         matlab.ui.control.UIAxes
        Waterfall3DAxes         matlab.ui.control.UIAxes
    end

    properties (Access = private)
        % Data
        Samples                 struct
        SampleCount             double = 0

        % Calibration
        CalFreq                 double
        CalDB                   double
        CalLoaded               logical = false
        CalFileName             string = ""
        SPLOffset               double = 0      % dB offset from SPL cal
        SPLCalibrated           logical = false

        % Recording / monitoring
        Recorder
        IsRecording             logical = false
        IsMonitoring            logical = false
        LiveTimer               timer
        RecordStartTime         double
        RecordDuration          double

        % Live FFT state
        PeakHoldData            double
        SmoothedFFT             double
    end

    methods (Access = private)

        function createComponents(app)

            app.UIFigure = uifigure('Name', 'Exhaust Analyzer', ...
                'Position', [60 60 1320 830], ...
                'Color', [0.15 0.15 0.17], ...
                'CloseRequestFcn', @(~,~) appCloseRequest(app));

            app.TabGroup = uitabgroup(app.UIFigure, 'Position', [10 10 1300 810]);

            %%  ============ RECORD & MONITOR TAB ============
            app.MonitorTab = uitab(app.TabGroup, 'Title', '  Record & Monitor  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            % --- Device / Recording Setup ---
            app.SetupPanel = uipanel(app.MonitorTab, 'Title', 'Setup', ...
                'Position', [12 555 310 200], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            yy = 150;
            app.DeviceLabel = uilabel(app.SetupPanel, 'Text', 'Input:', ...
                'Position', [10 yy 40 22], 'FontColor', [0.85 0.85 0.85]);
            app.DeviceDropdown = uidropdown(app.SetupPanel, ...
                'Items', {'Default'}, 'Value', 'Default', ...
                'Position', [55 yy 185 22]);
            app.RefreshDevicesButton = uibutton(app.SetupPanel, 'push', ...
                'Text', 'Refresh', 'Position', [245 yy 50 22], 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) populateDevices(app));
            app.populateDevices();

            yy = yy - 30;
            app.SampleRateLabel = uilabel(app.SetupPanel, 'Text', 'Rate:', ...
                'Position', [10 yy 40 22], 'FontColor', [0.85 0.85 0.85]);
            app.SampleRateDropdown = uidropdown(app.SetupPanel, ...
                'Items', {'44100','48000','96000'}, 'Value', '48000', ...
                'Position', [55 yy 90 22]);
            app.BitDepthLabel = uilabel(app.SetupPanel, 'Text', 'Bits:', ...
                'Position', [155 yy 30 22], 'FontColor', [0.85 0.85 0.85]);
            app.BitDepthDropdown = uidropdown(app.SetupPanel, ...
                'Items', {'16','24'}, 'Value', '24', ...
                'Position', [190 yy 70 22]);

            yy = yy - 30;
            app.DurationLabel = uilabel(app.SetupPanel, 'Text', 'Duration (s):', ...
                'Position', [10 yy 80 22], 'FontColor', [0.85 0.85 0.85]);
            app.DurationSpinner = uispinner(app.SetupPanel, ...
                'Value', 15, 'Limits', [1 600], 'Step', 5, ...
                'Position', [95 yy 80 22]);

            yy = yy - 40;
            app.RecordButton = uibutton(app.SetupPanel, 'push', ...
                'Text', 'Record', 'Position', [10 yy 90 32], ...
                'BackgroundColor', [0.75 0.15 0.15], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'FontSize', 13, ...
                'ButtonPushedFcn', @(~,~) startRecording(app));
            app.StopButton = uibutton(app.SetupPanel, 'push', ...
                'Text', 'Stop', 'Position', [108 yy 70 32], ...
                'BackgroundColor', [0.4 0.4 0.4], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) stopAll(app));
            app.MonitorOnlyButton = uibutton(app.SetupPanel, 'push', ...
                'Text', 'Monitor Only', 'Position', [186 yy 108 32], ...
                'BackgroundColor', [0.2 0.45 0.2], 'FontColor', 'w', ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) startMonitorOnly(app));

            % Status row below setup panel
            app.RecordStatusLamp = uilamp(app.MonitorTab, ...
                'Position', [15 530 14 14], 'Color', [0.4 0.4 0.4]);
            app.RecordStatusLabel = uilabel(app.MonitorTab, 'Text', 'Idle', ...
                'Position', [34 528 70 20], 'FontColor', [0.7 0.7 0.7], 'FontSize', 11);
            app.ProgressLabel = uilabel(app.MonitorTab, 'Text', '', ...
                'Position', [110 528 220 20], 'FontColor', [0.9 0.85 0.6], ...
                'FontWeight', 'bold', 'FontSize', 11);

            % --- Calibration ---
            app.CalPanel = uipanel(app.MonitorTab, 'Title', 'Mic Calibration', ...
                'Position', [12 410 310 115], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.LoadCalButton = uibutton(app.CalPanel, 'push', ...
                'Text', 'Load .cal / .txt', 'Position', [10 62 120 26], ...
                'BackgroundColor', [0.3 0.3 0.5], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) loadCalFile(app));
            app.ClearCalButton = uibutton(app.CalPanel, 'push', ...
                'Text', 'Clear', 'Position', [138 62 60 26], ...
                'ButtonPushedFcn', @(~,~) clearCal(app));
            app.CalFileLabel = uilabel(app.CalPanel, 'Text', 'No file loaded', ...
                'Position', [10 38 280 22], 'FontColor', [0.65 0.65 0.65], 'FontSize', 11);
            app.ApplyCalGlobalCheckbox = uicheckbox(app.CalPanel, ...
                'Text', 'Apply to all displays', 'Value', true, ...
                'Position', [10 12 180 22], 'FontColor', [0.85 0.85 0.85]);

            % --- SPL Calibration ---
            app.SPLCalPanel = uipanel(app.MonitorTab, 'Title', 'SPL Calibration', ...
                'Position', [12 310 310 95], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.SPLRefLabel = uilabel(app.SPLCalPanel, 'Text', 'Ref dB SPL:', ...
                'Position', [10 42 75 22], 'FontColor', [0.85 0.85 0.85]);
            app.SPLRefSpinner = uispinner(app.SPLCalPanel, ...
                'Value', 94, 'Limits', [70 130], 'Step', 0.1, ...
                'Position', [88 42 75 22]);
            app.SPLCalibrateButton = uibutton(app.SPLCalPanel, 'push', ...
                'Text', 'Calibrate Now', 'Position', [175 40 120 26], ...
                'BackgroundColor', [0.5 0.35 0.15], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) runSPLCalibration(app));
            app.SPLStatusLabel = uilabel(app.SPLCalPanel, 'Text', 'Not calibrated (relative dBFS)', ...
                'Position', [10 12 285 22], 'FontColor', [0.65 0.65 0.65], 'FontSize', 11);

            % --- Live FFT Settings ---
            app.LiveFFTPanel = uipanel(app.MonitorTab, 'Title', 'Live FFT', ...
                'Position', [12 185 310 120], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            yy = 70;
            app.LiveFFTSizeLabel = uilabel(app.LiveFFTPanel, 'Text', 'FFT:', ...
                'Position', [10 yy 30 22], 'FontColor', [0.85 0.85 0.85]);
            app.LiveFFTSizeDropdown = uidropdown(app.LiveFFTPanel, ...
                'Items', {'2048','4096','8192','16384'}, 'Value', '8192', ...
                'Position', [42 yy 80 22]);
            app.LiveDecayLabel = uilabel(app.LiveFFTPanel, 'Text', 'Decay:', ...
                'Position', [135 yy 40 22], 'FontColor', [0.85 0.85 0.85]);
            app.LiveDecayDropdown = uidropdown(app.LiveFFTPanel, ...
                'Items', {'Fast','Medium','Slow','None'}, 'Value', 'Medium', ...
                'Position', [180 yy 100 22]);

            yy = yy - 30;
            app.LivePeakHoldCheckbox = uicheckbox(app.LiveFFTPanel, ...
                'Text', 'Peak Hold', 'Value', true, ...
                'Position', [10 yy 100 22], 'FontColor', [0.85 0.85 0.85]);
            app.ClearPeaksButton = uibutton(app.LiveFFTPanel, 'push', ...
                'Text', 'Clear Peaks', 'Position', [120 yy-2 90 24], ...
                'ButtonPushedFcn', @(~,~) clearPeaks(app));

            % --- Sample Manager ---
            app.SamplePanel = uipanel(app.MonitorTab, 'Title', 'Samples', ...
                'Position', [12 10 310 170], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.SampleListBox = uilistbox(app.SamplePanel, ...
                'Items', {}, 'Position', [10 55 290 85], 'Multiselect', 'on');

            bw = 56; bx = 10;
            app.RenameSampleButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Rename', 'Position', [bx 18 bw 28], 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) renameSample(app));
            app.DeleteSampleButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Delete', 'Position', [bx+bw+4 18 bw 28], 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) deleteSample(app));
            app.ImportWavButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Import', 'Position', [bx+2*(bw+4) 18 bw 28], 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) importWav(app));
            app.SaveSessionButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Save', 'Position', [bx+3*(bw+4) 18 bw 28], 'FontSize', 10, ...
                'BackgroundColor', [0.2 0.45 0.3], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) saveSession(app));
            app.LoadSessionButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Load', 'Position', [bx+4*(bw+4) 18 bw 28], 'FontSize', 10, ...
                'BackgroundColor', [0.3 0.3 0.5], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) loadSession(app));

            % --- Live Axes ---
            axLeft = 335;
            axW = 950;

            app.WaveformAxes = uiaxes(app.MonitorTab, ...
                'Position', [axLeft 430 axW 320]);
            title(app.WaveformAxes, 'Waveform');
            xlabel(app.WaveformAxes, 'Time (s)'); ylabel(app.WaveformAxes, 'Amplitude');
            app.styleAxesDark(app.WaveformAxes);

            app.LiveFFTAxes = uiaxes(app.MonitorTab, ...
                'Position', [axLeft 15 axW 395]);
            title(app.LiveFFTAxes, 'Live Spectrum');
            xlabel(app.LiveFFTAxes, 'Frequency (Hz)'); ylabel(app.LiveFFTAxes, 'dB');
            app.LiveFFTAxes.XScale = 'log';
            app.styleAxesDark(app.LiveFFTAxes);

            %%  ============ ANALYSIS TAB ============
            app.AnalysisTab = uitab(app.TabGroup, 'Title', '  FFT Analysis  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            app.AnalysisPanel = uipanel(app.AnalysisTab, 'Title', 'Settings', ...
                'Position', [12 350 275 400], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            uilabel(app.AnalysisPanel, 'Text', 'Samples (multi-select):', ...
                'Position', [10 345 200 22], 'FontColor', [0.85 0.85 0.85]);
            app.AnalysisSampleListBox = uilistbox(app.AnalysisPanel, ...
                'Items', {}, 'Position', [10 210 250 135], 'Multiselect', 'on');

            yy = 178;
            app.FFTSizeLabel = uilabel(app.AnalysisPanel, 'Text', 'FFT:', ...
                'Position', [10 yy 30 22], 'FontColor', [0.85 0.85 0.85]);
            app.FFTSizeDropdown = uidropdown(app.AnalysisPanel, ...
                'Items', {'1024','2048','4096','8192','16384','32768','65536'}, ...
                'Value', '8192', 'Position', [45 yy 90 22]);

            yy = yy - 28;
            app.WindowLabel = uilabel(app.AnalysisPanel, 'Text', 'Win:', ...
                'Position', [10 yy 30 22], 'FontColor', [0.85 0.85 0.85]);
            app.WindowDropdown = uidropdown(app.AnalysisPanel, ...
                'Items', {'Hanning','Hamming','Blackman-Harris','Flat Top','Rectangular'}, ...
                'Value', 'Hanning', 'Position', [45 yy 155 22]);

            yy = yy - 28;
            app.AveragingLabel = uilabel(app.AnalysisPanel, 'Text', 'Method:', ...
                'Position', [10 yy 45 22], 'FontColor', [0.85 0.85 0.85]);
            app.AveragingDropdown = uidropdown(app.AnalysisPanel, ...
                'Items', {'Welch (Averaged)','Raw FFT'}, ...
                'Value', 'Welch (Averaged)', 'Position', [60 yy 145 22]);

            yy = yy - 28;
            app.OverlayCheckbox = uicheckbox(app.AnalysisPanel, ...
                'Text', 'Overlay all selected', 'Value', true, ...
                'Position', [10 yy 170 22], 'FontColor', [0.85 0.85 0.85]);

            yy = yy - 28;
            app.FreqScaleLabel = uilabel(app.AnalysisPanel, 'Text', 'Scale:', ...
                'Position', [10 yy 38 22], 'FontColor', [0.85 0.85 0.85]);
            app.FreqScaleSwitch = uiswitch(app.AnalysisPanel, 'slider', ...
                'Items', {'Linear','Log'}, 'Value', 'Log', ...
                'Position', [55 yy+4 45 20]);

            yy = yy - 38;
            app.AnalyzeButton = uibutton(app.AnalysisPanel, 'push', ...
                'Text', 'Analyze', 'Position', [10 yy 110 32], ...
                'BackgroundColor', [0.2 0.45 0.7], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'FontSize', 13, ...
                'ButtonPushedFcn', @(~,~) analyzeButtonPushed(app));
            app.ExportAnalysisButton = uibutton(app.AnalysisPanel, 'push', ...
                'Text', 'Export', 'Position', [130 yy 100 32], ...
                'ButtonPushedFcn', @(~,~) exportPlot(app, app.AnalysisAxes));

            app.AnalysisAxes = uiaxes(app.AnalysisTab, ...
                'Position', [300 20 980 740]);
            title(app.AnalysisAxes, 'Frequency Spectrum');
            xlabel(app.AnalysisAxes, 'Frequency (Hz)'); ylabel(app.AnalysisAxes, 'Magnitude (dB)');
            app.AnalysisAxes.XScale = 'log';
            app.styleAxesDark(app.AnalysisAxes);

            %%  ============ WATERFALL TAB ============
            app.WaterfallTab = uitab(app.TabGroup, 'Title', '  Waterfall  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            app.WFPanel = uipanel(app.WaterfallTab, 'Title', 'Settings', ...
                'Position', [12 400 260 355], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            yy = 300;
            app.WFSampleLabel = uilabel(app.WFPanel, 'Text', 'Sample:', ...
                'Position', [10 yy 50 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFSampleDropdown = uidropdown(app.WFPanel, ...
                'Items', {}, 'Position', [65 yy 175 22]);

            yy = yy - 30;
            app.WFFFTSizeLabel = uilabel(app.WFPanel, 'Text', 'FFT:', ...
                'Position', [10 yy 30 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFFFTSizeDropdown = uidropdown(app.WFPanel, ...
                'Items', {'1024','2048','4096','8192','16384'}, ...
                'Value', '4096', 'Position', [65 yy 100 22]);

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
                'Value', 5000, 'Limits', [100 20000], 'Step', 500, ...
                'Position', [65 yy 95 22]);

            yy = yy - 30;
            app.WFDbRangeLabel = uilabel(app.WFPanel, 'Text', 'dB Range:', ...
                'Position', [10 yy 58 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFDbRangeSpinner = uispinner(app.WFPanel, ...
                'Value', 80, 'Limits', [20 120], 'Step', 10, ...
                'Position', [72 yy 80 22]);

            yy = yy - 30;
            app.WFColorLabel = uilabel(app.WFPanel, 'Text', 'Colormap:', ...
                'Position', [10 yy 58 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFColorDropdown = uidropdown(app.WFPanel, ...
                'Items', {'jet','parula','hot','turbo','gray'}, ...
                'Value', 'jet', 'Position', [72 yy 100 22]);

            yy = yy - 28;
            app.WFApplyCalCheckbox = uicheckbox(app.WFPanel, ...
                'Text', 'Apply Calibration', 'Value', true, ...
                'Position', [10 yy 150 22], 'FontColor', [0.85 0.85 0.85]);

            yy = yy - 35;
            app.WFPlotButton = uibutton(app.WFPanel, 'push', ...
                'Text', 'Plot', 'Position', [10 yy 100 30], ...
                'BackgroundColor', [0.2 0.45 0.7], 'FontColor', 'w', 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) waterfallPlot(app));
            app.WFExportButton = uibutton(app.WFPanel, 'push', ...
                'Text', 'Export', 'Position', [120 yy 100 30], ...
                'ButtonPushedFcn', @(~,~) exportWaterfallPlots(app));

            % Dual axes
            app.SpectrogramAxes = uiaxes(app.WaterfallTab, 'Position', [285 20 500 740]);
            title(app.SpectrogramAxes, 'Spectrogram');
            xlabel(app.SpectrogramAxes, 'Time (s)'); ylabel(app.SpectrogramAxes, 'Frequency (Hz)');
            app.styleAxesDark(app.SpectrogramAxes);

            app.Waterfall3DAxes = uiaxes(app.WaterfallTab, 'Position', [795 20 490 740]);
            title(app.Waterfall3DAxes, 'Waterfall');
            xlabel(app.Waterfall3DAxes, 'Hz'); ylabel(app.Waterfall3DAxes, 'Time (s)');
            zlabel(app.Waterfall3DAxes, 'dB');
            app.styleAxesDark(app.Waterfall3DAxes);
        end

        function styleAxesDark(~, ax)
            ax.Color = [0.12 0.12 0.14];
            ax.XColor = [0.7 0.7 0.7];
            ax.YColor = [0.7 0.7 0.7];
            ax.ZColor = [0.7 0.7 0.7];
            ax.Title.Color = [0.85 0.85 0.85];
            ax.GridColor = [0.3 0.3 0.3];
            grid(ax, 'on');
        end

        %% ===== DEVICES =====
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

        function id = getDeviceID(app)
            sel = app.DeviceDropdown.Value;
            if strcmp(sel, 'Default')
                id = -1;
            else
                tok = regexp(sel, '^\[(\d+)\]', 'tokens');
                if ~isempty(tok), id = str2double(tok{1}{1}); else, id = -1; end
            end
        end

        function rec = makeRecorder(app, fs, bits)
            devID = app.getDeviceID();
            if devID == -1
                rec = audiorecorder(fs, bits, 1);
            else
                rec = audiorecorder(fs, bits, 1, devID);
            end
        end

        %% ===== RECORD + MONITOR =====
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
            record(app.Recorder, dur);
            app.startLiveTimer();
        end

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
            record(app.Recorder);
            app.startLiveTimer();
        end

        function stopAll(app)
            wasRecording = app.IsRecording;
            app.IsRecording = false;
            app.IsMonitoring = false;
            app.stopLiveTimer();
            if ~isempty(app.Recorder)
                stop(app.Recorder);
                if wasRecording
                    app.saveSampleFromRecorder();
                end
            end
            app.setUIState('idle');
        end

        function setUIState(app, state)
            switch state
                case 'recording'
                    app.RecordStatusLamp.Color = [0.9 0.1 0.1];
                    app.RecordStatusLabel.Text = 'REC';
                    app.RecordButton.Enable = 'off';
                    app.MonitorOnlyButton.Enable = 'off';
                    app.StopButton.Enable = 'on';
                case 'monitoring'
                    app.RecordStatusLamp.Color = [0.1 0.7 0.2];
                    app.RecordStatusLabel.Text = 'MON';
                    app.ProgressLabel.Text = 'Monitoring (not recording)';
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

        function startLiveTimer(app)
            app.LiveTimer = timer('ExecutionMode', 'fixedRate', 'Period', 0.15, ...
                'TimerFcn', @(~,~) liveUpdate(app));
            start(app.LiveTimer);
        end

        function stopLiveTimer(app)
            if ~isempty(app.LiveTimer) && isvalid(app.LiveTimer)
                stop(app.LiveTimer); delete(app.LiveTimer);
            end
        end

        function liveUpdate(app)
            if ~app.IsRecording && ~app.IsMonitoring, return; end
            try
                data = getaudiodata(app.Recorder);
                if isempty(data), return; end
                fs = app.Recorder.SampleRate;

                % --- Progress (recording mode) ---
                if app.IsRecording
                    elapsed = toc(app.RecordStartTime);
                    remaining = max(0, app.RecordDuration - elapsed);
                    pct = min(100, elapsed/app.RecordDuration * 100);
                    app.ProgressLabel.Text = sprintf('%.1f / %.0f s   %.0f%% done   (%.0f s left)', ...
                        elapsed, app.RecordDuration, pct, remaining);
                    if elapsed >= app.RecordDuration
                        app.stopAll(); return;
                    end
                end

                % --- Waveform ---
                t = (0:length(data)-1) / fs;
                cla(app.WaveformAxes);
                plot(app.WaveformAxes, t, data, 'Color', [0.3 0.7 1.0], 'LineWidth', 0.4);
                if app.IsRecording
                    xlim(app.WaveformAxes, [0 app.RecordDuration]);
                    hold(app.WaveformAxes, 'on');
                    el = toc(app.RecordStartTime);
                    yl = ylim(app.WaveformAxes);
                    plot(app.WaveformAxes, [el el], yl, '--', 'Color', [1 0.35 0.15], 'LineWidth', 1.5);
                    hold(app.WaveformAxes, 'off');
                else
                    maxT = min(5, t(end));
                    xlim(app.WaveformAxes, [max(0,t(end)-maxT) t(end)]);
                end
                xlabel(app.WaveformAxes, 'Time (s)'); ylabel(app.WaveformAxes, 'Amplitude');
                title(app.WaveformAxes, 'Waveform');

                % --- Live FFT ---
                nfft = str2double(app.LiveFFTSizeDropdown.Value);
                if length(data) < nfft, return; end
                seg = data(end-nfft+1:end) .* hann(nfft);
                Y = fft(seg, nfft);
                f = (0:nfft/2)' * fs / nfft;
                mag = 20*log10(abs(Y(1:nfft/2+1))/(nfft/2) + eps);

                % Apply SPL offset
                if app.SPLCalibrated
                    mag = mag + app.SPLOffset;
                end

                % Apply mic cal
                if app.ApplyCalGlobalCheckbox.Value && app.CalLoaded
                    mag = mag + app.getCalCorrection(f);
                end

                % Trim DC
                f = f(2:end); mag = mag(2:end);

                % Decay smoothing
                alpha = app.getDecayAlpha();
                if isempty(app.SmoothedFFT) || length(app.SmoothedFFT) ~= length(mag)
                    app.SmoothedFFT = mag;
                else
                    app.SmoothedFFT = alpha * mag + (1-alpha) * app.SmoothedFFT;
                end

                % Peak hold
                if app.LivePeakHoldCheckbox.Value
                    if isempty(app.PeakHoldData) || length(app.PeakHoldData) ~= length(mag)
                        app.PeakHoldData = app.SmoothedFFT;
                    else
                        app.PeakHoldData = max(app.PeakHoldData, app.SmoothedFFT);
                    end
                end

                % Plot
                cla(app.LiveFFTAxes);
                hold(app.LiveFFTAxes, 'on');

                area(app.LiveFFTAxes, f, app.SmoothedFFT, ...
                    'FaceColor', [0.12 0.38 0.65], 'FaceAlpha', 0.55, ...
                    'EdgeColor', [0.25 0.6 0.95], 'LineWidth', 0.8);

                if app.LivePeakHoldCheckbox.Value && ~isempty(app.PeakHoldData)
                    plot(app.LiveFFTAxes, f, app.PeakHoldData, ...
                        'Color', [1.0 0.25 0.15], 'LineWidth', 1.3);
                end

                app.LiveFFTAxes.XScale = 'log';
                xlim(app.LiveFFTAxes, [20 fs/2]);
                if app.SPLCalibrated
                    ylabel(app.LiveFFTAxes, 'dB SPL');
                else
                    ylabel(app.LiveFFTAxes, 'dBFS');
                end
                xlabel(app.LiveFFTAxes, 'Frequency (Hz)');
                title(app.LiveFFTAxes, 'Live Spectrum');
                hold(app.LiveFFTAxes, 'off');

            catch
            end
        end

        function alpha = getDecayAlpha(app)
            switch app.LiveDecayDropdown.Value
                case 'Fast',   alpha = 0.55;
                case 'Medium', alpha = 0.28;
                case 'Slow',   alpha = 0.12;
                otherwise,     alpha = 1.0;
            end
        end

        function clearPeaks(app)
            app.PeakHoldData = [];
        end

        function saveSampleFromRecorder(app)
            data = getaudiodata(app.Recorder);
            fs = app.Recorder.SampleRate;
            if isempty(data), return; end

            app.SampleCount = app.SampleCount + 1;
            s.name = sprintf('Sample_%d', app.SampleCount);
            s.data = data;
            s.fs = fs;
            s.timestamp = datetime('now');

            if isempty(app.Samples) || (numel(app.Samples)==1 && isempty(app.Samples(1).name))
                app.Samples = s;
            else
                app.Samples(end+1) = s;
            end
            app.updateSampleLists();
            elapsed = length(data)/fs;
            app.ProgressLabel.Text = sprintf('Saved: %s (%.1f s)', s.name, elapsed);
        end

        %% ===== SPL CALIBRATION =====
        function runSPLCalibration(app)
            % Records 3 seconds, measures RMS, computes offset so dBFS -> dB SPL
            if app.IsRecording || app.IsMonitoring
                uialert(app.UIFigure, 'Stop recording/monitoring first.', 'Busy');
                return;
            end
            refSPL = app.SPLRefSpinner.Value;
            app.SPLStatusLabel.Text = 'Measuring... hold calibrator steady';
            drawnow;

            try
                rec = app.makeRecorder(48000, 24);
                recordblocking(rec, 3);
                data = getaudiodata(rec);
                rmsVal = rms(data);
                measuredDBFS = 20*log10(rmsVal + eps);
                app.SPLOffset = refSPL - measuredDBFS;
                app.SPLCalibrated = true;
                app.SPLStatusLabel.Text = sprintf('Calibrated: offset = %+.1f dB  (ref %.1f dB SPL)', ...
                    app.SPLOffset, refSPL);
            catch ME
                uialert(app.UIFigure, ME.message, 'SPL Cal Error');
                app.SPLStatusLabel.Text = 'Calibration failed';
            end
        end

        %% ===== CALIBRATION FILE =====
        function loadCalFile(app)
            [file, path] = uigetfile({'*.cal;*.txt','Cal Files'}, 'Load Calibration');
            if isequal(file, 0), return; end
            try
                raw = fileread(fullfile(path, file));
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
                app.CalLoaded = true; app.CalFileName = file;
                app.CalFileLabel.Text = sprintf('Loaded: %s (%d pts)', file, numel(freqs));
            catch ME
                uialert(app.UIFigure, ME.message, 'Cal File Error');
            end
        end

        function clearCal(app)
            app.CalFreq = []; app.CalDB = [];
            app.CalLoaded = false; app.CalFileName = "";
            app.CalFileLabel.Text = 'No file loaded';
        end

        function c = getCalCorrection(app, f)
            if app.CalLoaded
                c = interp1(app.CalFreq, app.CalDB, f, 'linear', 0);
            else
                c = zeros(size(f));
            end
        end

        %% ===== SAMPLE MANAGEMENT =====
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
            app.AnalysisSampleListBox.Items = names;
            app.AnalysisSampleListBox.ItemsData = raw;
            app.WFSampleDropdown.Items = names;
            app.WFSampleDropdown.ItemsData = raw;
        end

        function renameSample(app)
            sel = app.SampleListBox.Value;
            if isempty(sel), return; end
            if iscell(sel), sel = sel{1}; end
            idx = find(strcmp({app.Samples.name}, sel), 1);
            if isempty(idx), return; end
            newName = inputdlg('New name:', 'Rename', [1 40], {sel});
            if ~isempty(newName) && ~isempty(newName{1})
                app.Samples(idx).name = newName{1};
                app.updateSampleLists();
            end
        end

        function deleteSample(app)
            sel = app.SampleListBox.Value;
            if isempty(sel), return; end
            if ~iscell(sel), sel = {sel}; end
            for i = 1:numel(sel)
                idx = find(strcmp({app.Samples.name}, sel{i}), 1);
                if ~isempty(idx), app.Samples(idx) = []; end
            end
            app.updateSampleLists();
        end

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

        %% ===== WINDOWING =====
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

        %% ===== FFT ANALYSIS =====
        function analyzeButtonPushed(app)
            sel = app.AnalysisSampleListBox.Value;
            if isempty(sel), return; end
            if ~iscell(sel), sel = {sel}; end

            nfft = str2double(app.FFTSizeDropdown.Value);
            winName = app.WindowDropdown.Value;
            applyCal = app.ApplyCalGlobalCheckbox.Value && app.CalLoaded;
            doOverlay = app.OverlayCheckbox.Value;
            useLog = strcmp(app.FreqScaleSwitch.Value, 'Log');
            method = app.AveragingDropdown.Value;

            cla(app.AnalysisAxes); hold(app.AnalysisAxes, 'on');
            colors = lines(numel(sel)); legs = {};

            for i = 1:numel(sel)
                idx = find(strcmp({app.Samples.name}, sel{i}), 1);
                if isempty(idx), continue; end
                data = app.Samples(idx).data; fs = app.Samples(idx).fs;

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
                plot(app.AnalysisAxes, f, mag, 'Color', colors(i,:), 'LineWidth', 1.3);
                legs{end+1} = app.Samples(idx).name; %#ok<AGROW>
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
                'Color',[0.2 0.2 0.22], 'Location','northeast');
            hold(app.AnalysisAxes,'off');
        end

        %% ===== WATERFALL =====
        function waterfallPlot(app)
            selName = app.WFSampleDropdown.Value;
            if isempty(selName), return; end
            idx = find(strcmp({app.Samples.name}, selName), 1);
            if isempty(idx), return; end

            data = app.Samples(idx).data; fs = app.Samples(idx).fs;
            nfft = str2double(app.WFFFTSizeDropdown.Value);
            noverlap = round(nfft * app.WFOverlapSpinner.Value/100);
            maxFreq = app.WFMaxFreqSpinner.Value;
            applyCal = app.WFApplyCalCheckbox.Value && app.CalLoaded;
            dbRange = app.WFDbRangeSpinner.Value;
            cmap = app.WFColorDropdown.Value;

            [S,F,T] = spectrogram(data, hann(nfft), noverlap, nfft, fs);
            S_dB = 10*log10(abs(S).^2 + eps);

            if app.SPLCalibrated, S_dB = S_dB + app.SPLOffset; end
            if applyCal, S_dB = S_dB + app.getCalCorrection(F); end

            fIdx = F <= maxFreq; F=F(fIdx); S_dB=S_dB(fIdx,:);
            pk = max(S_dB(:)); clims = [pk-dbRange pk];

            % 2D
            cla(app.SpectrogramAxes);
            imagesc(app.SpectrogramAxes, T, F, S_dB);
            set(app.SpectrogramAxes,'YDir','normal');
            caxis(app.SpectrogramAxes, clims);
            colormap(app.SpectrogramAxes, cmap);
            cb = colorbar(app.SpectrogramAxes); cb.Label.String='dB'; cb.Color=[0.7 0.7 0.7];
            xlabel(app.SpectrogramAxes,'Time (s)'); ylabel(app.SpectrogramAxes,'Frequency (Hz)');
            title(app.SpectrogramAxes, sprintf('Spectrogram - %s', app.Samples(idx).name));

            % 3D
            cla(app.Waterfall3DAxes);
            maxSlices = 120;
            if size(S_dB,2)>maxSlices
                step=ceil(size(S_dB,2)/maxSlices);
                Sp=S_dB(:,1:step:end); Tp=T(1:step:end);
            else
                Sp=S_dB; Tp=T;
            end
            waterfall(app.Waterfall3DAxes, F, Tp, Sp');
            colormap(app.Waterfall3DAxes, cmap); caxis(app.Waterfall3DAxes, clims);
            xlabel(app.Waterfall3DAxes,'Hz'); ylabel(app.Waterfall3DAxes,'Time (s)');
            zlabel(app.Waterfall3DAxes,'dB');
            title(app.Waterfall3DAxes, sprintf('Waterfall - %s', app.Samples(idx).name));
            view(app.Waterfall3DAxes, [-35 40]); zlim(app.Waterfall3DAxes, clims);
        end

        function exportWaterfallPlots(app)
            folder = uigetdir('','Export Folder');
            if isequal(folder,0), return; end
            exportgraphics(app.SpectrogramAxes, fullfile(folder,'spectrogram.png'), 'Resolution',300);
            exportgraphics(app.Waterfall3DAxes, fullfile(folder,'waterfall3d.png'), 'Resolution',300);
        end

        function exportPlot(~, ax)
            [file,path] = uiputfile({'*.png','PNG';'*.fig','Figure'}, 'Export');
            if isequal(file,0), return; end
            exportgraphics(ax, fullfile(path,file), 'Resolution',300);
        end

        %% ===== SESSION =====
        function saveSession(app)
            [file,path] = uiputfile({'*.mat','Session'}, 'Save');
            if isequal(file,0), return; end
            ses.Samples=app.Samples; ses.SampleCount=app.SampleCount;
            ses.CalFreq=app.CalFreq; ses.CalDB=app.CalDB;
            ses.CalLoaded=app.CalLoaded; ses.CalFileName=app.CalFileName;
            ses.SPLOffset=app.SPLOffset; ses.SPLCalibrated=app.SPLCalibrated;
            save(fullfile(path,file), '-struct', 'ses');
        end

        function loadSession(app)
            [file,path] = uigetfile({'*.mat','Session'}, 'Load');
            if isequal(file,0), return; end
            ses = load(fullfile(path,file));
            app.Samples=ses.Samples; app.SampleCount=ses.SampleCount;
            if isfield(ses,'CalLoaded') && ses.CalLoaded
                app.CalFreq=ses.CalFreq; app.CalDB=ses.CalDB;
                app.CalLoaded=true; app.CalFileName=ses.CalFileName;
                app.CalFileLabel.Text = sprintf('Loaded: %s (%d pts)', app.CalFileName, numel(app.CalFreq));
            end
            if isfield(ses,'SPLCalibrated') && ses.SPLCalibrated
                app.SPLOffset=ses.SPLOffset; app.SPLCalibrated=true;
                app.SPLStatusLabel.Text = sprintf('Calibrated: offset = %+.1f dB', app.SPLOffset);
            end
            app.updateSampleLists();
        end

        %% ===== CLEANUP =====
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