classdef ExhaustAnalyzer < matlab.apps.AppBase
    % ExhaustAnalyzer - Acoustic measurement and spectral analysis tool
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

        SamplePanel             matlab.ui.container.Panel
        SampleListBox           matlab.ui.control.ListBox
        RenameSampleButton      matlab.ui.control.Button
        DeleteSampleButton      matlab.ui.control.Button
        ImportWavButton         matlab.ui.control.Button
        SaveSessionButton       matlab.ui.control.Button
        LoadSessionButton       matlab.ui.control.Button

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
        WFPlotButton            matlab.ui.control.Button
        WFExportButton          matlab.ui.control.Button
        WFAxes                  matlab.ui.control.UIAxes
    end

    properties (Access = private)
        Samples                 struct
        SampleCount             double = 0

        CalFreq                 double
        CalDB                   double
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

        % Persistent plot handles -- updated in-place, never cla+replot
        hWaveform                       % line handle for waveform
        hCursor                         % line handle for record cursor
        hFFTArea                        % area handle for live FFT
        hPeakLine                       % line handle for peak hold
        LastNFFT                double = 0  % track FFT size changes
    end

    methods (Access = private)

        function createComponents(app)

            app.UIFigure = uifigure('Name', 'Exhaust Analyzer', ...
                'Position', [50 50 1340 850], ...
                'Color', [0.15 0.15 0.17], ...
                'CloseRequestFcn', @(~,~) appCloseRequest(app));

            app.TabGroup = uitabgroup(app.UIFigure, 'Position', [10 10 1320 830]);

            %%   RECORD & MONITOR TAB
            app.MonitorTab = uitab(app.TabGroup, 'Title', '  Record & Monitor  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            panelW = 320;

            % --- Setup ---
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
                'Value', 15, 'Limits', [1 600], 'Step', 5, ...
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

            % Status
            app.RecordStatusLamp = uilamp(app.MonitorTab, ...
                'Position', [15 530 14 14], 'Color', [0.4 0.4 0.4]);
            app.RecordStatusLabel = uilabel(app.MonitorTab, 'Text', 'Idle', ...
                'Position', [34 528 60 20], 'FontColor', [0.7 0.7 0.7], 'FontSize', 11);
            app.ProgressLabel = uilabel(app.MonitorTab, 'Text', '', ...
                'Position', [100 528 235 20], 'FontColor', [0.9 0.85 0.6], ...
                'FontWeight', 'bold', 'FontSize', 11);

            % --- Mic Cal ---
            app.CalPanel = uipanel(app.MonitorTab, 'Title', 'Mic Calibration', ...
                'Position', [12 420 panelW 105], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.LoadCalButton = uibutton(app.CalPanel, 'push', ...
                'Text', 'Load .cal / .txt', 'Position', [10 55 120 24], ...
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

            % --- SPL Cal ---
            app.SPLCalPanel = uipanel(app.MonitorTab, 'Title', 'SPL Calibration', ...
                'Position', [12 325 panelW 90], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.SPLRefLabel = uilabel(app.SPLCalPanel, 'Text', 'Ref dB:', ...
                'Position', [10 38 45 22], 'FontColor', [0.85 0.85 0.85]);
            app.SPLRefSpinner = uispinner(app.SPLCalPanel, ...
                'Value', 94, 'Limits', [70 130], 'Step', 0.1, ...
                'Position', [58 38 70 22]);
            app.SPLCalibrateButton = uibutton(app.SPLCalPanel, 'push', ...
                'Text', 'Calibrate Now', 'Position', [138 36 115 26], ...
                'BackgroundColor', [0.5 0.35 0.15], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) runSPLCalibration(app));
            app.SPLStatusLabel = uilabel(app.SPLCalPanel, 'Text', 'Not calibrated (relative dBFS)', ...
                'Position', [10 10 295 20], 'FontColor', [0.62 0.62 0.62], 'FontSize', 11);

            % --- Live FFT Controls ---
            app.LiveFFTPanel = uipanel(app.MonitorTab, 'Title', 'Live FFT Controls', ...
                'Position', [12 145 panelW 175], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            yy = 125;
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

            % --- Sample Manager ---
            app.SamplePanel = uipanel(app.MonitorTab, 'Title', 'Samples', ...
                'Position', [12 5 panelW 135], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.SampleListBox = uilistbox(app.SamplePanel, ...
                'Items', {}, 'Position', [10 36 295 70], 'Multiselect', 'on');

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

            % --- Live Axes ---
            axL = 345; axW = 960;

            app.WaveformAxes = uiaxes(app.MonitorTab, ...
                'Position', [axL 440 axW 330]);
            title(app.WaveformAxes, 'Waveform');
            xlabel(app.WaveformAxes, 'Time (s)'); ylabel(app.WaveformAxes, 'Amplitude');
            app.styleAxesDark(app.WaveformAxes);

            app.LiveFFTAxes = uiaxes(app.MonitorTab, ...
                'Position', [axL 15 axW 405]);
            title(app.LiveFFTAxes, 'Live Spectrum');
            xlabel(app.LiveFFTAxes, 'Frequency (Hz)'); ylabel(app.LiveFFTAxes, 'dBFS');
            app.LiveFFTAxes.XScale = 'log';
            app.styleAxesDark(app.LiveFFTAxes);

            %%  ANALYSIS TAB
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
                'Position', [85 yy 45 20]);

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
                'Position', [300 20 1000 760]);
            title(app.AnalysisAxes, 'Frequency Spectrum');
            xlabel(app.AnalysisAxes, 'Frequency (Hz)'); ylabel(app.AnalysisAxes, 'Magnitude (dB)');
            app.AnalysisAxes.XScale = 'log';
            app.styleAxesDark(app.AnalysisAxes);

            %%  WATERFALL TAB
            app.WaterfallTab = uitab(app.TabGroup, 'Title', '  Waterfall / Spectrogram  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            app.WFPanel = uipanel(app.WaterfallTab, 'Title', 'Settings', ...
                'Position', [12 400 260 360], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            yy = 305;
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

            yy = yy - 28;
            app.WFApplyCalCheckbox = uicheckbox(app.WFPanel, ...
                'Text', 'Apply Calibration', 'Value', true, ...
                'Position', [10 yy 150 22], 'FontColor', [0.85 0.85 0.85]);

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

        function styleAxesDark(~, ax)
            ax.Color = [0.12 0.12 0.14];
            ax.XColor = [0.7 0.7 0.7];
            ax.YColor = [0.7 0.7 0.7];
            ax.ZColor = [0.7 0.7 0.7];
            ax.Title.Color = [0.85 0.85 0.85];
            ax.GridColor = [0.3 0.3 0.3];
            grid(ax, 'on');
        end

        %%  DEVICES
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

        %% INIT / LIVE PLOTS
        function initLivePlots(app)
            % Create persistent line handles once -- update data each tick
            cla(app.WaveformAxes);
            hold(app.WaveformAxes, 'on');
            app.hWaveform = plot(app.WaveformAxes, 0, 0, ...
                'Color', [0.3 0.7 1.0], 'LineWidth', 0.5);
            app.hCursor = plot(app.WaveformAxes, [0 0], [-1 1], '--', ...
                'Color', [1 0.35 0.15], 'LineWidth', 1.5, 'Visible', 'off');
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
        end

        %% RECORD + MONITOR
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

        function startLiveTimer(app)
            app.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.20, ...
                'BusyMode', 'drop', ...
                'TimerFcn', @(~,~) liveUpdate(app));
            start(app.LiveTimer);
        end

        function stopLiveTimer(app)
            if ~isempty(app.LiveTimer) && isvalid(app.LiveTimer)
                stop(app.LiveTimer); delete(app.LiveTimer);
            end
            app.LiveTimer = [];
        end

        function liveUpdate(app)
            % Early exit
            if ~app.IsRecording && ~app.IsMonitoring, return; end

            try
                data = getaudiodata(app.Recorder);
            catch
                return;
            end
            if isempty(data) || length(data) < 1024, return; end

            fs = app.Recorder.SampleRate;

            % --- Check recording duration ---
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

            % --- Update waveform by setting XData/YData ---
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

            % --- Live FFT ---
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

                % Trim DC bin
                f = f(2:end); mag = mag(2:end);

                % If FFT size changed, reset smoothing/peaks
                if nfft ~= app.LastNFFT
                    app.SmoothedFFT = mag;
                    app.PeakHoldData = mag;
                    app.LastNFFT = nfft;
                end

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

                % Update existing plot handles
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

        %% SPL CALIBRATION
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

        %% MIC CAL FILE
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

        %% SAMPLE MANAGEMENT
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

        %% WINDOWING
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

        %% FFT ANALYSIS
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

        %% WATERFALL / SPECTROGRAM
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
            style = app.WFStyleDropdown.Value;

            [S,F,T] = spectrogram(data, hann(nfft), noverlap, nfft, fs);
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

        function exportPlot(~, ax)
            [file, path] = uiputfile({'*.png','PNG';'*.fig','Figure'}, 'Export');
            if isequal(file,0), return; end
            exportgraphics(ax, fullfile(path,file), 'Resolution', 300);
        end

        %% SESSION
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
                app.SPLStatusLabel.Text = sprintf('Done: offset %+.1f dB', app.SPLOffset);
            end
            app.updateSampleLists();
        end

        %% CLEANUP
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