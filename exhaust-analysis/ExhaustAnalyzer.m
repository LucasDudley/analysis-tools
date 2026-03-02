classdef ExhaustAnalyzer < matlab.apps.AppBase

    % ExhaustAnalyzer - MATLAB App for acoustic measurement and spectral analysis
    %
    % Features:
    %   - Record multiple audio samples with selectable device/sample rate
    %   - Load calibration files (.cal, .txt) for mic correction
    %   - Real-time RTA (Real-Time Analyzer) with calibration applied
    %   - FFT analysis with overlay comparison of multiple samples
    %   - Waterfall / spectrogram plots vs time
    %   - Save / load measurement sessions (.mat)
    %   - Export plots and data

    properties (Access = public)
        UIFigure                matlab.ui.Figure

        % --- Tabs ---
        TabGroup                matlab.ui.container.TabGroup
        RecordTab               matlab.ui.container.Tab
        AnalysisTab             matlab.ui.container.Tab
        WaterfallTab            matlab.ui.container.Tab
        RTATab                  matlab.ui.container.Tab

        % --- Record Tab Components ---
        RecordPanel             matlab.ui.container.Panel
        SampleRateDropdown      matlab.ui.control.DropDown
        SampleRateLabel         matlab.ui.control.Label
        BitDepthDropdown        matlab.ui.control.DropDown
        BitDepthLabel           matlab.ui.control.Label
        DurationSpinner         matlab.ui.control.Spinner
        DurationLabel           matlab.ui.control.Label
        RecordButton            matlab.ui.control.Button
        StopButton              matlab.ui.control.Button
        RecordStatusLamp        matlab.ui.control.Lamp
        RecordStatusLabel       matlab.ui.control.Label
        RecordAxes              matlab.ui.control.UIAxes

        % --- Sample Manager Panel ---
        SamplePanel             matlab.ui.container.Panel
        SampleListBox           matlab.ui.control.ListBox
        SampleListLabel         matlab.ui.control.Label
        RenameSampleButton      matlab.ui.control.Button
        DeleteSampleButton      matlab.ui.control.Button
        ImportWavButton         matlab.ui.control.Button
        SaveSessionButton       matlab.ui.control.Button
        LoadSessionButton       matlab.ui.control.Button

        % --- Calibration Panel ---
        CalPanel                matlab.ui.container.Panel
        LoadCalButton           matlab.ui.control.Button
        ClearCalButton          matlab.ui.control.Button
        CalStatusLabel          matlab.ui.control.Label
        CalFileLabel            matlab.ui.control.Label
        CalAxes                 matlab.ui.control.UIAxes

        % --- Analysis Tab Components ---
        AnalysisPanel           matlab.ui.container.Panel
        AnalysisSampleListBox   matlab.ui.control.ListBox
        AnalysisSampleLabel     matlab.ui.control.Label
        FFTSizeDropdown         matlab.ui.control.DropDown
        FFTSizeLabel            matlab.ui.control.Label
        WindowDropdown          matlab.ui.control.DropDown
        WindowLabel             matlab.ui.control.Label
        AveragingDropdown       matlab.ui.control.DropDown
        AveragingLabel          matlab.ui.control.Label
        ApplyCalCheckbox        matlab.ui.control.CheckBox
        OverlayCheckbox         matlab.ui.control.CheckBox
        AnalyzeButton           matlab.ui.control.Button
        ExportPlotButton        matlab.ui.control.Button
        FreqScaleSwitch         matlab.ui.control.Switch
        FreqScaleLabel          matlab.ui.control.Label
        AnalysisAxes            matlab.ui.control.UIAxes

        % --- Waterfall Tab Components ---
        WaterfallPanel          matlab.ui.container.Panel
        WFSampleDropdown        matlab.ui.control.DropDown
        WFSampleLabel           matlab.ui.control.Label
        WFFFTSizeDropdown       matlab.ui.control.DropDown
        WFFFTSizeLabel          matlab.ui.control.Label
        WFOverlapSpinner        matlab.ui.control.Spinner
        WFOverlapLabel          matlab.ui.control.Label
        WFMaxFreqSpinner        matlab.ui.control.Spinner
        WFMaxFreqLabel          matlab.ui.control.Label
        WFApplyCalCheckbox      matlab.ui.control.CheckBox
        WFPlotButton            matlab.ui.control.Button
        WFStyleDropdown         matlab.ui.control.DropDown
        WFStyleLabel            matlab.ui.control.Label
        WFExportButton          matlab.ui.control.Button
        WaterfallAxes           matlab.ui.control.UIAxes

        % --- RTA Tab Components ---
        RTAPanel                matlab.ui.container.Panel
        RTAStartButton          matlab.ui.control.Button
        RTAStopButton           matlab.ui.control.Button
        RTAApplyCalCheckbox     matlab.ui.control.CheckBox
        RTABandsDropdown        matlab.ui.control.DropDown
        RTABandsLabel           matlab.ui.control.Label
        RTAPeakHoldCheckbox     matlab.ui.control.CheckBox
        RTAStatusLamp           matlab.ui.control.Lamp
        RTAStatusLabel          matlab.ui.control.Label
        RTAAxes                 matlab.ui.control.UIAxes
    end

    properties (Access = private)
        % --- Data Storage ---
        Samples                 struct      % Array of sample structs
        SampleCount             double = 0

        % --- Calibration ---
        CalFreq                 double      % Calibration frequencies
        CalDB                   double      % Calibration corrections (dB)
        CalLoaded               logical = false
        CalFileName             string = ""

        % --- Recording State ---
        Recorder                           % audiorecorder object
        IsRecording             logical = false

        % --- RTA State ---
        RTARunning              logical = false
        RTATimer                timer
        RTAPeakData             double
    end

    methods (Access = private)

        function createComponents(app)
            % --- Main Figure ---
            app.UIFigure = uifigure('Name', 'Exhaust Analyzer', ...
                'Position', [100 100 1200 780], ...
                'Color', [0.15 0.15 0.17], ...
                'CloseRequestFcn', @(~,~) appCloseRequest(app));

            % --- Tab Group ---
            app.TabGroup = uitabgroup(app.UIFigure, ...
                'Position', [10 10 1180 760]);

            %%  RECORD TAB 
            app.RecordTab = uitab(app.TabGroup, 'Title', '  Record  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            % Record Settings Panel
            app.RecordPanel = uipanel(app.RecordTab, 'Title', 'Recording Settings', ...
                'Position', [15 480 350 230], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.SampleRateLabel = uilabel(app.RecordPanel, 'Text', 'Sample Rate:', ...
                'Position', [15 170 90 22], 'FontColor', [0.85 0.85 0.85]);
            app.SampleRateDropdown = uidropdown(app.RecordPanel, ...
                'Items', {'44100','48000','96000'}, 'Value', '48000', ...
                'Position', [115 170 120 22]);

            app.BitDepthLabel = uilabel(app.RecordPanel, 'Text', 'Bit Depth:', ...
                'Position', [15 135 90 22], 'FontColor', [0.85 0.85 0.85]);
            app.BitDepthDropdown = uidropdown(app.RecordPanel, ...
                'Items', {'16','24'}, 'Value', '24', ...
                'Position', [115 135 120 22]);

            app.DurationLabel = uilabel(app.RecordPanel, 'Text', 'Duration (s):', ...
                'Position', [15 100 90 22], 'FontColor', [0.85 0.85 0.85]);
            app.DurationSpinner = uispinner(app.RecordPanel, ...
                'Value', 10, 'Limits', [1 300], 'Step', 1, ...
                'Position', [115 100 120 22]);

            app.RecordButton = uibutton(app.RecordPanel, 'push', ...
                'Text', '⏺  Record', ...
                'Position', [15 45 150 35], ...
                'BackgroundColor', [0.8 0.2 0.2], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'FontSize', 14, ...
                'ButtonPushedFcn', @(~,~) recordButtonPushed(app));

            app.StopButton = uibutton(app.RecordPanel, 'push', ...
                'Text', '⏹  Stop', ...
                'Position', [175 45 150 35], ...
                'BackgroundColor', [0.4 0.4 0.4], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'FontSize', 14, ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) stopButtonPushed(app));

            app.RecordStatusLabel = uilabel(app.RecordPanel, 'Text', 'Idle', ...
                'Position', [65 10 200 22], 'FontColor', [0.7 0.7 0.7]);
            app.RecordStatusLamp = uilamp(app.RecordPanel, ...
                'Position', [40 12 18 18], 'Color', [0.4 0.4 0.4]);

            % Sample Manager Panel
            app.SamplePanel = uipanel(app.RecordTab, 'Title', 'Sample Manager', ...
                'Position', [15 70 350 400], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.SampleListLabel = uilabel(app.SamplePanel, 'Text', 'Recorded Samples:', ...
                'Position', [15 345 200 22], 'FontColor', [0.85 0.85 0.85]);
            app.SampleListBox = uilistbox(app.SamplePanel, ...
                'Items', {}, 'Position', [15 140 320 205], ...
                'Multiselect', 'on');

            app.RenameSampleButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Rename', 'Position', [15 100 100 30], ...
                'ButtonPushedFcn', @(~,~) renameSample(app));
            app.DeleteSampleButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Delete', 'Position', [125 100 100 30], ...
                'ButtonPushedFcn', @(~,~) deleteSample(app));
            app.ImportWavButton = uibutton(app.SamplePanel, 'push', ...
                'Text', 'Import WAV', 'Position', [235 100 100 30], ...
                'ButtonPushedFcn', @(~,~) importWav(app));

            app.SaveSessionButton = uibutton(app.SamplePanel, 'push', ...
                'Text', '💾 Save Session', 'Position', [15 55 155 35], ...
                'BackgroundColor', [0.2 0.5 0.3], 'FontColor', 'w', ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) saveSession(app));
            app.LoadSessionButton = uibutton(app.SamplePanel, 'push', ...
                'Text', '📂 Load Session', 'Position', [180 55 155 35], ...
                'BackgroundColor', [0.3 0.3 0.5], 'FontColor', 'w', ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) loadSession(app));

            % Calibration Panel
            app.CalPanel = uipanel(app.RecordTab, 'Title', 'Calibration', ...
                'Position', [380 480 370 230], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.LoadCalButton = uibutton(app.CalPanel, 'push', ...
                'Text', 'Load Cal File', 'Position', [15 170 140 30], ...
                'BackgroundColor', [0.35 0.35 0.55], 'FontColor', 'w', ...
                'ButtonPushedFcn', @(~,~) loadCalFile(app));
            app.ClearCalButton = uibutton(app.CalPanel, 'push', ...
                'Text', 'Clear Cal', 'Position', [165 170 120 30], ...
                'ButtonPushedFcn', @(~,~) clearCal(app));
            app.CalFileLabel = uilabel(app.CalPanel, 'Text', 'No calibration loaded', ...
                'Position', [15 140 330 22], 'FontColor', [0.7 0.7 0.7]);

            app.CalAxes = uiaxes(app.CalPanel, 'Position', [15 10 335 130]);
            title(app.CalAxes, 'Mic Calibration Curve');
            xlabel(app.CalAxes, 'Frequency (Hz)');
            ylabel(app.CalAxes, 'Correction (dB)');
            app.CalAxes.XScale = 'log';
            app.CalAxes.Color = [0.12 0.12 0.14];
            app.CalAxes.XColor = [0.7 0.7 0.7];
            app.CalAxes.YColor = [0.7 0.7 0.7];
            app.CalAxes.Title.Color = [0.85 0.85 0.85];
            app.CalAxes.GridColor = [0.35 0.35 0.35];
            grid(app.CalAxes, 'on');

            % Record Waveform Preview
            app.RecordAxes = uiaxes(app.RecordTab, ...
                'Position', [380 70 780 400]);
            title(app.RecordAxes, 'Waveform Preview');
            xlabel(app.RecordAxes, 'Time (s)');
            ylabel(app.RecordAxes, 'Amplitude');
            app.RecordAxes.Color = [0.12 0.12 0.14];
            app.RecordAxes.XColor = [0.7 0.7 0.7];
            app.RecordAxes.YColor = [0.7 0.7 0.7];
            app.RecordAxes.Title.Color = [0.85 0.85 0.85];
            app.RecordAxes.GridColor = [0.3 0.3 0.3];
            grid(app.RecordAxes, 'on');

            %% ANALYSIS TAB 
            app.AnalysisTab = uitab(app.TabGroup, 'Title', '  FFT Analysis  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            app.AnalysisPanel = uipanel(app.AnalysisTab, 'Title', 'Analysis Settings', ...
                'Position', [15 440 280 270], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.AnalysisSampleLabel = uilabel(app.AnalysisPanel, 'Text', 'Select Samples:', ...
                'Position', [15 215 150 22], 'FontColor', [0.85 0.85 0.85]);
            app.AnalysisSampleListBox = uilistbox(app.AnalysisPanel, ...
                'Items', {}, 'Position', [15 115 250 100], ...
                'Multiselect', 'on');

            app.FFTSizeLabel = uilabel(app.AnalysisPanel, 'Text', 'FFT Size:', ...
                'Position', [15 85 70 22], 'FontColor', [0.85 0.85 0.85]);
            app.FFTSizeDropdown = uidropdown(app.AnalysisPanel, ...
                'Items', {'1024','2048','4096','8192','16384','32768','65536'}, ...
                'Value', '8192', 'Position', [90 85 100 22]);

            app.WindowLabel = uilabel(app.AnalysisPanel, 'Text', 'Window:', ...
                'Position', [15 55 70 22], 'FontColor', [0.85 0.85 0.85]);
            app.WindowDropdown = uidropdown(app.AnalysisPanel, ...
                'Items', {'Hanning','Hamming','Blackman-Harris','Flat Top','Rectangular'}, ...
                'Value', 'Hanning', 'Position', [90 55 150 22]);

            app.AveragingLabel = uilabel(app.AnalysisPanel, 'Text', 'Method:', ...
                'Position', [15 25 70 22], 'FontColor', [0.85 0.85 0.85]);
            app.AveragingDropdown = uidropdown(app.AnalysisPanel, ...
                'Items', {'Welch (Averaged)','Raw FFT'}, ...
                'Value', 'Welch (Averaged)', 'Position', [90 25 150 22]);

            % Options below panel
            app.ApplyCalCheckbox = uicheckbox(app.AnalysisTab, ...
                'Text', 'Apply Calibration', 'Value', true, ...
                'Position', [15 405 150 22], 'FontColor', [0.85 0.85 0.85]);
            app.OverlayCheckbox = uicheckbox(app.AnalysisTab, ...
                'Text', 'Overlay Mode (compare samples)', 'Value', true, ...
                'Position', [15 380 230 22], 'FontColor', [0.85 0.85 0.85]);

            app.FreqScaleLabel = uilabel(app.AnalysisTab, 'Text', 'Freq Scale:', ...
                'Position', [15 348 75 22], 'FontColor', [0.85 0.85 0.85]);
            app.FreqScaleSwitch = uiswitch(app.AnalysisTab, 'slider', ...
                'Items', {'Linear','Log'}, 'Value', 'Log', ...
                'Position', [100 352 45 20]);

            app.AnalyzeButton = uibutton(app.AnalysisTab, 'push', ...
                'Text', '📊 Analyze', 'Position', [15 300 135 35], ...
                'BackgroundColor', [0.2 0.45 0.7], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'FontSize', 13, ...
                'ButtonPushedFcn', @(~,~) analyzeButtonPushed(app));
            app.ExportPlotButton = uibutton(app.AnalysisTab, 'push', ...
                'Text', '📁 Export Plot', 'Position', [160 300 135 35], ...
                'ButtonPushedFcn', @(~,~) exportAnalysisPlot(app));

            % Analysis Axes
            app.AnalysisAxes = uiaxes(app.AnalysisTab, ...
                'Position', [310 30 845 680]);
            title(app.AnalysisAxes, 'Frequency Spectrum');
            xlabel(app.AnalysisAxes, 'Frequency (Hz)');
            ylabel(app.AnalysisAxes, 'Magnitude (dB)');
            app.AnalysisAxes.XScale = 'log';
            app.AnalysisAxes.Color = [0.12 0.12 0.14];
            app.AnalysisAxes.XColor = [0.7 0.7 0.7];
            app.AnalysisAxes.YColor = [0.7 0.7 0.7];
            app.AnalysisAxes.Title.Color = [0.85 0.85 0.85];
            app.AnalysisAxes.GridColor = [0.3 0.3 0.3];
            grid(app.AnalysisAxes, 'on');

            %% ==================== WATERFALL TAB ====================
            app.WaterfallTab = uitab(app.TabGroup, 'Title', '  Waterfall  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            app.WaterfallPanel = uipanel(app.WaterfallTab, 'Title', 'Waterfall Settings', ...
                'Position', [15 440 280 270], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.WFSampleLabel = uilabel(app.WaterfallPanel, 'Text', 'Sample:', ...
                'Position', [15 215 60 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFSampleDropdown = uidropdown(app.WaterfallPanel, ...
                'Items', {}, 'Position', [80 215 180 22]);

            app.WFFFTSizeLabel = uilabel(app.WaterfallPanel, 'Text', 'FFT Size:', ...
                'Position', [15 180 60 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFFFTSizeDropdown = uidropdown(app.WaterfallPanel, ...
                'Items', {'1024','2048','4096','8192','16384'}, ...
                'Value', '4096', 'Position', [80 180 120 22]);

            app.WFOverlapLabel = uilabel(app.WaterfallPanel, 'Text', 'Overlap %:', ...
                'Position', [15 145 65 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFOverlapSpinner = uispinner(app.WaterfallPanel, ...
                'Value', 75, 'Limits', [0 95], 'Step', 5, ...
                'Position', [80 145 100 22]);

            app.WFMaxFreqLabel = uilabel(app.WaterfallPanel, 'Text', 'Max Freq:', ...
                'Position', [15 110 65 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFMaxFreqSpinner = uispinner(app.WaterfallPanel, ...
                'Value', 5000, 'Limits', [100 20000], 'Step', 500, ...
                'Position', [80 110 100 22]);

            app.WFStyleLabel = uilabel(app.WaterfallPanel, 'Text', 'Style:', ...
                'Position', [15 75 60 22], 'FontColor', [0.85 0.85 0.85]);
            app.WFStyleDropdown = uidropdown(app.WaterfallPanel, ...
                'Items', {'Spectrogram (2D)','Waterfall (3D)','Surface (3D)'}, ...
                'Value', 'Spectrogram (2D)', 'Position', [80 75 180 22]);

            app.WFApplyCalCheckbox = uicheckbox(app.WaterfallPanel, ...
                'Text', 'Apply Calibration', 'Value', true, ...
                'Position', [15 42 150 22], 'FontColor', [0.85 0.85 0.85]);

            app.WFPlotButton = uibutton(app.WaterfallPanel, 'push', ...
                'Text', '📊 Plot Waterfall', 'Position', [15 5 150 30], ...
                'BackgroundColor', [0.2 0.45 0.7], 'FontColor', 'w', ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) waterfallPlot(app));
            app.WFExportButton = uibutton(app.WaterfallTab, 'push', ...
                'Text', '📁 Export', 'Position', [180 445 100 30], ...
                'ButtonPushedFcn', @(~,~) exportWaterfallPlot(app));

            % Waterfall Axes
            app.WaterfallAxes = uiaxes(app.WaterfallTab, ...
                'Position', [310 30 845 680]);
            title(app.WaterfallAxes, 'Spectrogram / Waterfall');
            app.WaterfallAxes.Color = [0.12 0.12 0.14];
            app.WaterfallAxes.XColor = [0.7 0.7 0.7];
            app.WaterfallAxes.YColor = [0.7 0.7 0.7];
            app.WaterfallAxes.ZColor = [0.7 0.7 0.7];
            app.WaterfallAxes.Title.Color = [0.85 0.85 0.85];
            app.WaterfallAxes.GridColor = [0.3 0.3 0.3];
            grid(app.WaterfallAxes, 'on');

            %% RTA TAB
            app.RTATab = uitab(app.TabGroup, 'Title', '  Real-Time RTA  ', ...
                'BackgroundColor', [0.18 0.18 0.20]);

            app.RTAPanel = uipanel(app.RTATab, 'Title', 'RTA Settings', ...
                'Position', [15 540 280 170], ...
                'BackgroundColor', [0.22 0.22 0.24], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');

            app.RTABandsLabel = uilabel(app.RTAPanel, 'Text', 'Resolution:', ...
                'Position', [15 115 75 22], 'FontColor', [0.85 0.85 0.85]);
            app.RTABandsDropdown = uidropdown(app.RTAPanel, ...
                'Items', {'1/3 Octave','1/6 Octave','1/12 Octave','Full FFT'}, ...
                'Value', '1/3 Octave', 'Position', [95 115 160 22]);

            app.RTAApplyCalCheckbox = uicheckbox(app.RTAPanel, ...
                'Text', 'Apply Calibration', 'Value', true, ...
                'Position', [15 85 150 22], 'FontColor', [0.85 0.85 0.85]);
            app.RTAPeakHoldCheckbox = uicheckbox(app.RTAPanel, ...
                'Text', 'Peak Hold', 'Value', false, ...
                'Position', [15 58 150 22], 'FontColor', [0.85 0.85 0.85]);

            app.RTAStartButton = uibutton(app.RTAPanel, 'push', ...
                'Text', '▶  Start RTA', 'Position', [15 12 120 35], ...
                'BackgroundColor', [0.1 0.6 0.2], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'FontSize', 13, ...
                'ButtonPushedFcn', @(~,~) rtaStart(app));
            app.RTAStopButton = uibutton(app.RTAPanel, 'push', ...
                'Text', '⏹  Stop', 'Position', [145 12 110 35], ...
                'BackgroundColor', [0.5 0.2 0.2], 'FontColor', 'w', ...
                'FontWeight', 'bold', 'FontSize', 13, ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) rtaStop(app));

            app.RTAStatusLabel = uilabel(app.RTATab, 'Text', 'Idle', ...
                'Position', [65 510 200 22], 'FontColor', [0.7 0.7 0.7]);
            app.RTAStatusLamp = uilamp(app.RTATab, ...
                'Position', [40 512 18 18], 'Color', [0.4 0.4 0.4]);

            % RTA Axes
            app.RTAAxes = uiaxes(app.RTATab, ...
                'Position', [310 30 845 680]);
            title(app.RTAAxes, 'Real-Time Analyzer');
            xlabel(app.RTAAxes, 'Frequency (Hz)');
            ylabel(app.RTAAxes, 'Level (dB)');
            app.RTAAxes.XScale = 'log';
            app.RTAAxes.Color = [0.12 0.12 0.14];
            app.RTAAxes.XColor = [0.7 0.7 0.7];
            app.RTAAxes.YColor = [0.7 0.7 0.7];
            app.RTAAxes.Title.Color = [0.85 0.85 0.85];
            app.RTAAxes.GridColor = [0.3 0.3 0.3];
            grid(app.RTAAxes, 'on');

        end % createComponents

        %% RECORDING
        function recordButtonPushed(app)
            if app.IsRecording
                return;
            end
            fs = str2double(app.SampleRateDropdown.Value);
            bits = str2double(app.BitDepthDropdown.Value);
            dur = app.DurationSpinner.Value;

            try
                app.Recorder = audiorecorder(fs, bits, 1);
            catch ME
                uialert(app.UIFigure, ['Audio device error: ' ME.message], 'Error');
                return;
            end

            app.IsRecording = true;
            app.RecordStatusLamp.Color = [0.9 0.1 0.1];
            app.RecordStatusLabel.Text = sprintf('Recording... (%ds)', dur);
            app.RecordButton.Enable = 'off';
            app.StopButton.Enable = 'on';

            recordblocking(app.Recorder, dur);

            if app.IsRecording
                app.finishRecording();
            end
        end

        function stopButtonPushed(app)
            if app.IsRecording && ~isempty(app.Recorder)
                stop(app.Recorder);
                app.finishRecording();
            end
        end

        function finishRecording(app)
            app.IsRecording = false;
            app.RecordStatusLamp.Color = [0.1 0.7 0.1];
            app.RecordStatusLabel.Text = 'Recording saved!';
            app.RecordButton.Enable = 'on';
            app.StopButton.Enable = 'off';

            data = getaudiodata(app.Recorder);
            fs = app.Recorder.SampleRate;

            app.SampleCount = app.SampleCount + 1;
            sName = sprintf('Sample_%d', app.SampleCount);

            newSample.name = sName;
            newSample.data = data;
            newSample.fs = fs;
            newSample.timestamp = datetime('now');

            if isempty(fieldnames(app.Samples)) && app.SampleCount == 1
                app.Samples = newSample;
            else
                app.Samples(end+1) = newSample;
            end

            app.updateSampleLists();
            app.plotWaveform(data, fs);
        end

        function plotWaveform(app, data, fs)
            t = (0:length(data)-1) / fs;
            cla(app.RecordAxes);
            plot(app.RecordAxes, t, data, 'Color', [0.3 0.7 1.0], 'LineWidth', 0.5);
            xlabel(app.RecordAxes, 'Time (s)');
            ylabel(app.RecordAxes, 'Amplitude');
            title(app.RecordAxes, 'Waveform Preview');
            xlim(app.RecordAxes, [0 t(end)]);
        end

        %% SAMPLE MANAGEMENT
        function updateSampleLists(app)
            if isempty(app.Samples) || (numel(app.Samples)==1 && isempty(app.Samples(1).name))
                names = {};
            else
                names = {app.Samples.name};
            end
            app.SampleListBox.Items = names;
            app.AnalysisSampleListBox.Items = names;
            app.WFSampleDropdown.Items = names;
        end

        function renameSample(app)
            sel = app.SampleListBox.Value;
            if isempty(sel), return; end
            if iscell(sel), sel = sel{1}; end
            idx = find(strcmp({app.Samples.name}, sel), 1);
            if isempty(idx), return; end

            newName = inputdlg('New name:', 'Rename Sample', [1 40], {sel});
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
                if ~isempty(idx)
                    app.Samples(idx) = [];
                end
            end
            app.updateSampleLists();
        end

        function importWav(app)
            [file, path] = uigetfile({'*.wav','WAV Files'}, 'Select WAV File', 'MultiSelect', 'on');
            if isequal(file, 0), return; end
            if ~iscell(file), file = {file}; end

            for i = 1:numel(file)
                [data, fs] = audioread(fullfile(path, file{i}));
                if size(data, 2) > 1
                    data = mean(data, 2); % Mix to mono
                end

                app.SampleCount = app.SampleCount + 1;
                [~, fname, ~] = fileparts(file{i});

                newSample.name = fname;
                newSample.data = data;
                newSample.fs = fs;
                newSample.timestamp = datetime('now');

                if isempty(fieldnames(app.Samples)) && app.SampleCount == 1
                    app.Samples = newSample;
                else
                    app.Samples(end+1) = newSample;
                end
            end
            app.updateSampleLists();
            app.plotWaveform(data, fs);
        end

        %% CALIBRATION
        function loadCalFile(app)
            [file, path] = uigetfile({'*.cal;*.txt','Calibration Files (*.cal, *.txt)'}, ...
                'Load Calibration File');
            if isequal(file, 0), return; end

            try
                fid = fopen(fullfile(path, file), 'r');
                rawText = fread(fid, '*char')';
                fclose(fid);

                % Remove comment lines (starting with * or ;)
                lines = strsplit(rawText, {'\n', '\r'});
                dataLines = {};
                for i = 1:numel(lines)
                    stripped = strtrim(lines{i});
                    if isempty(stripped), continue; end
                    if stripped(1) == '*' || stripped(1) == ';' || stripped(1) == '#'
                        continue;
                    end
                    % Check if line starts with a number
                    nums = sscanf(stripped, '%f %f');
                    if numel(nums) >= 2
                        dataLines{end+1} = stripped; %#ok<AGROW>
                    end
                end

                calData = zeros(numel(dataLines), 2);
                for i = 1:numel(dataLines)
                    nums = sscanf(dataLines{i}, '%f %f');
                    calData(i,:) = nums(1:2)';
                end

                app.CalFreq = calData(:,1);
                app.CalDB = calData(:,2);
                app.CalLoaded = true;
                app.CalFileName = file;
                app.CalFileLabel.Text = sprintf('✅ Loaded: %s (%d pts)', file, numel(app.CalFreq));

                % Plot calibration curve
                cla(app.CalAxes);
                semilogx(app.CalAxes, app.CalFreq, app.CalDB, ...
                    'Color', [1.0 0.6 0.1], 'LineWidth', 2);
                xlabel(app.CalAxes, 'Frequency (Hz)');
                ylabel(app.CalAxes, 'Correction (dB)');
                title(app.CalAxes, 'Mic Calibration Curve');
                xlim(app.CalAxes, [min(app.CalFreq) max(app.CalFreq)]);
                grid(app.CalAxes, 'on');

            catch ME
                uialert(app.UIFigure, ['Error reading cal file: ' ME.message], 'Error');
            end
        end

        function clearCal(app)
            app.CalFreq = [];
            app.CalDB = [];
            app.CalLoaded = false;
            app.CalFileName = "";
            app.CalFileLabel.Text = 'No calibration loaded';
            cla(app.CalAxes);
        end

        function correction = getCalCorrection(app, freqVec)
            % Interpolate calibration data to match the given frequency vector
            if app.CalLoaded
                correction = interp1(app.CalFreq, app.CalDB, freqVec, 'linear', 0);
            else
                correction = zeros(size(freqVec));
            end
        end

        %% WINDOWING
        function w = getWindow(app, N, windowName)
            switch windowName
                case 'Hanning'
                    w = hann(N);
                case 'Hamming'
                    w = hamming(N);
                case 'Blackman-Harris'
                    w = blackmanharris(N);
                case 'Flat Top'
                    w = flattopwin(N);
                case 'Rectangular'
                    w = ones(N, 1);
                otherwise
                    w = hann(N);
            end
        end

        %% ==================== FFT ANALYSIS ====================
        function analyzeButtonPushed(app)
            sel = app.AnalysisSampleListBox.Value;
            if isempty(sel), uialert(app.UIFigure, 'Select at least one sample.', 'Info'); return; end
            if ~iscell(sel), sel = {sel}; end

            nfft = str2double(app.FFTSizeDropdown.Value);
            winName = app.WindowDropdown.Value;
            applyCal = app.ApplyCalCheckbox.Value && app.CalLoaded;
            doOverlay = app.OverlayCheckbox.Value;
            useLog = strcmp(app.FreqScaleSwitch.Value, 'Log');
            method = app.AveragingDropdown.Value;

            cla(app.AnalysisAxes);
            hold(app.AnalysisAxes, 'on');

            colors = lines(numel(sel));
            legendEntries = {};

            for i = 1:numel(sel)
                idx = find(strcmp({app.Samples.name}, sel{i}), 1);
                if isempty(idx), continue; end

                data = app.Samples(idx).data;
                fs = app.Samples(idx).fs;

                if contains(method, 'Welch')
                    w = app.getWindow(nfft, winName);
                    overlap = round(nfft * 0.5);
                    [pxx, f] = pwelch(data, w, overlap, nfft, fs);
                    mag_dB = 10*log10(pxx + eps);
                else
                    % Raw FFT with window
                    if length(data) < nfft
                        data = [data; zeros(nfft - length(data), 1)];
                    end
                    w = app.getWindow(nfft, winName);
                    seg = data(1:nfft) .* w;
                    Y = fft(seg, nfft);
                    f = (0:nfft/2)' * fs / nfft;
                    mag_dB = 20*log10(abs(Y(1:nfft/2+1)) / (nfft/2) + eps);
                end

                % Apply calibration
                if applyCal
                    correction = app.getCalCorrection(f);
                    mag_dB = mag_dB + correction;
                end

                if ~doOverlay && i > 1
                    cla(app.AnalysisAxes);
                    hold(app.AnalysisAxes, 'on');
                end

                plot(app.AnalysisAxes, f, mag_dB, 'Color', colors(i,:), 'LineWidth', 1.2);
                legendEntries{end+1} = sel{i}; %#ok<AGROW>
            end

            if useLog
                app.AnalysisAxes.XScale = 'log';
                xlim(app.AnalysisAxes, [20 max(f)]);
            else
                app.AnalysisAxes.XScale = 'linear';
                xlim(app.AnalysisAxes, [0 max(f)]);
            end

            xlabel(app.AnalysisAxes, 'Frequency (Hz)');
            ylabel(app.AnalysisAxes, 'Magnitude (dB)');
            title(app.AnalysisAxes, 'Frequency Spectrum');
            legend(app.AnalysisAxes, legendEntries, 'TextColor', [0.85 0.85 0.85], ...
                'Color', [0.2 0.2 0.22], 'Location', 'northeast');
            hold(app.AnalysisAxes, 'off');
        end

        function exportAnalysisPlot(app)
            [file, path] = uiputfile({'*.png','PNG Image';'*.fig','MATLAB Figure'}, ...
                'Export Analysis Plot');
            if isequal(file, 0), return; end
            exportgraphics(app.AnalysisAxes, fullfile(path, file), 'Resolution', 300);
        end

        %% WATERFALL
        function waterfallPlot(app)
            selName = app.WFSampleDropdown.Value;
            if isempty(selName), uialert(app.UIFigure, 'Select a sample.', 'Info'); return; end

            idx = find(strcmp({app.Samples.name}, selName), 1);
            if isempty(idx), return; end

            data = app.Samples(idx).data;
            fs = app.Samples(idx).fs;
            nfft = str2double(app.WFFFTSizeDropdown.Value);
            overlapPct = app.WFOverlapSpinner.Value / 100;
            maxFreq = app.WFMaxFreqSpinner.Value;
            applyCal = app.WFApplyCalCheckbox.Value && app.CalLoaded;
            style = app.WFStyleDropdown.Value;

            w = hann(nfft);
            noverlap = round(nfft * overlapPct);

            [S, F, T] = spectrogram(data, w, noverlap, nfft, fs);
            S_dB = 10*log10(abs(S).^2 + eps);

            % Apply calibration
            if applyCal
                correction = app.getCalCorrection(F);
                S_dB = S_dB + correction;
            end

            % Limit frequency range
            fIdx = F <= maxFreq;
            F = F(fIdx);
            S_dB = S_dB(fIdx, :);

            cla(app.WaterfallAxes);

            switch style
                case 'Spectrogram (2D)'
                    imagesc(app.WaterfallAxes, T, F, S_dB);
                    set(app.WaterfallAxes, 'YDir', 'normal');
                    xlabel(app.WaterfallAxes, 'Time (s)');
                    ylabel(app.WaterfallAxes, 'Frequency (Hz)');
                    colormap(app.WaterfallAxes, 'jet');
                    cb = colorbar(app.WaterfallAxes);
                    cb.Label.String = 'dB';
                    cb.Color = [0.7 0.7 0.7];
                    title(app.WaterfallAxes, sprintf('Spectrogram - %s', selName));

                case 'Waterfall (3D)'
                    waterfall(app.WaterfallAxes, F, T, S_dB');
                    xlabel(app.WaterfallAxes, 'Frequency (Hz)');
                    ylabel(app.WaterfallAxes, 'Time (s)');
                    zlabel(app.WaterfallAxes, 'Magnitude (dB)');
                    colormap(app.WaterfallAxes, 'jet');
                    title(app.WaterfallAxes, sprintf('Waterfall - %s', selName));
                    view(app.WaterfallAxes, [-30 45]);

                case 'Surface (3D)'
                    surf(app.WaterfallAxes, F, T, S_dB', 'EdgeColor', 'none');
                    xlabel(app.WaterfallAxes, 'Frequency (Hz)');
                    ylabel(app.WaterfallAxes, 'Time (s)');
                    zlabel(app.WaterfallAxes, 'Magnitude (dB)');
                    colormap(app.WaterfallAxes, 'jet');
                    title(app.WaterfallAxes, sprintf('Surface - %s', selName));
                    view(app.WaterfallAxes, [-30 45]);
            end
        end

        function exportWaterfallPlot(app)
            [file, path] = uiputfile({'*.png','PNG Image';'*.fig','MATLAB Figure'}, ...
                'Export Waterfall Plot');
            if isequal(file, 0), return; end
            exportgraphics(app.WaterfallAxes, fullfile(path, file), 'Resolution', 300);
        end

        %% REAL-TIME RTA
        function rtaStart(app)
            if app.RTARunning, return; end

            fs = 48000;
            nfft = 4096;

            try
                app.Recorder = audiorecorder(fs, 16, 1);
            catch ME
                uialert(app.UIFigure, ['Audio error: ' ME.message], 'Error');
                return;
            end

            app.RTARunning = true;
            app.RTAStatusLamp.Color = [0.1 0.8 0.1];
            app.RTAStatusLabel.Text = 'RTA Running...';
            app.RTAStartButton.Enable = 'off';
            app.RTAStopButton.Enable = 'on';
            app.RTAPeakData = [];

            record(app.Recorder);

            % Create a timer for updating the RTA display
            app.RTATimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.15, ...
                'TimerFcn', @(~,~) rtaUpdate(app, fs, nfft));
            start(app.RTATimer);
        end

        function rtaStop(app)
            app.RTARunning = false;
            if ~isempty(app.RTATimer) && isvalid(app.RTATimer)
                stop(app.RTATimer);
                delete(app.RTATimer);
            end
            if ~isempty(app.Recorder)
                stop(app.Recorder);
            end
            app.RTAStatusLamp.Color = [0.4 0.4 0.4];
            app.RTAStatusLabel.Text = 'Idle';
            app.RTAStartButton.Enable = 'on';
            app.RTAStopButton.Enable = 'off';
        end

        function rtaUpdate(app, fs, nfft)
            if ~app.RTARunning, return; end

            try
                data = getaudiodata(app.Recorder);
                if length(data) < nfft, return; end

                % Use the latest segment
                segment = data(end-nfft+1:end);
                w = hann(nfft);
                segment = segment .* w;

                Y = fft(segment, nfft);
                f = (0:nfft/2)' * fs / nfft;
                mag_dB = 20*log10(abs(Y(1:nfft/2+1)) / (nfft/2) + eps);

                applyCal = app.RTAApplyCalCheckbox.Value && app.CalLoaded;
                if applyCal
                    correction = app.getCalCorrection(f);
                    mag_dB = mag_dB + correction;
                end

                % Octave band smoothing
                resolution = app.RTABandsDropdown.Value;
                if ~strcmp(resolution, 'Full FFT')
                    [f_bands, mag_bands] = app.octaveSmooth(f, mag_dB, resolution);
                else
                    f_bands = f(2:end); % Skip DC
                    mag_bands = mag_dB(2:end);
                end

                cla(app.RTAAxes);
                hold(app.RTAAxes, 'on');

                % Peak hold
                if app.RTAPeakHoldCheckbox.Value
                    if isempty(app.RTAPeakData) || length(app.RTAPeakData) ~= length(mag_bands)
                        app.RTAPeakData = mag_bands;
                    else
                        app.RTAPeakData = max(app.RTAPeakData, mag_bands);
                    end
                    plot(app.RTAAxes, f_bands, app.RTAPeakData, ...
                        'Color', [1.0 0.3 0.3 0.6], 'LineWidth', 1.5, ...
                        'DisplayName', 'Peak Hold');
                end

                % Current spectrum
                if strcmp(resolution, 'Full FFT')
                    plot(app.RTAAxes, f_bands, mag_bands, ...
                        'Color', [0.3 0.8 1.0], 'LineWidth', 1, ...
                        'DisplayName', 'Current');
                else
                    bar(app.RTAAxes, f_bands, mag_bands, 1, ...
                        'FaceColor', [0.3 0.8 1.0], 'EdgeColor', [0.15 0.4 0.5], ...
                        'FaceAlpha', 0.8, 'DisplayName', 'Current');
                    app.RTAAxes.XScale = 'log';
                end

                xlim(app.RTAAxes, [20 20000]);
                ylim(app.RTAAxes, [-100 0]);
                xlabel(app.RTAAxes, 'Frequency (Hz)');
                ylabel(app.RTAAxes, 'Level (dB)');
                title(app.RTAAxes, 'Real-Time Analyzer');
                hold(app.RTAAxes, 'off');

            catch
                % Silently handle transient errors during live update
            end
        end

        function [fc, mag_avg] = octaveSmooth(~, f, mag_dB, resolution)
            switch resolution
                case '1/3 Octave'
                    n = 3;
                case '1/6 Octave'
                    n = 6;
                case '1/12 Octave'
                    n = 12;
                otherwise
                    n = 3;
            end

            % ISO center frequencies for 1/3 octave, then interpolate
            fc_base = [20 25 31.5 40 50 63 80 100 125 160 200 250 315 400 ...
                       500 630 800 1000 1250 1600 2000 2500 3150 4000 5000 ...
                       6300 8000 10000 12500 16000 20000];

            if n ~= 3
                % Generate finer bands
                fc_base = [];
                fstart = 20;
                while fstart <= 20000
                    fc_base(end+1) = fstart; %#ok<AGROW>
                    fstart = fstart * 2^(1/n);
                end
            end

            fc = fc_base(:);
            mag_avg = zeros(size(fc));

            for i = 1:numel(fc)
                flo = fc(i) / 2^(1/(2*n));
                fhi = fc(i) * 2^(1/(2*n));
                idx = f >= flo & f <= fhi;
                if any(idx)
                    % Energy average
                    mag_avg(i) = 10*log10(mean(10.^(mag_dB(idx)/10)) + eps);
                else
                    mag_avg(i) = -120;
                end
            end
        end

        %% SESSION SAVE/LOAD
        function saveSession(app)
            [file, path] = uiputfile({'*.mat','MATLAB Session'}, 'Save Session');
            if isequal(file, 0), return; end

            session.Samples = app.Samples;
            session.SampleCount = app.SampleCount;
            session.CalFreq = app.CalFreq;
            session.CalDB = app.CalDB;
            session.CalLoaded = app.CalLoaded;
            session.CalFileName = app.CalFileName;

            save(fullfile(path, file), '-struct', 'session');
            uialert(app.UIFigure, 'Session saved successfully!', 'Success', 'Icon', 'success');
        end

        function loadSession(app)
            [file, path] = uigetfile({'*.mat','MATLAB Session'}, 'Load Session');
            if isequal(file, 0), return; end

            session = load(fullfile(path, file));
            app.Samples = session.Samples;
            app.SampleCount = session.SampleCount;

            if isfield(session, 'CalLoaded') && session.CalLoaded
                app.CalFreq = session.CalFreq;
                app.CalDB = session.CalDB;
                app.CalLoaded = true;
                app.CalFileName = session.CalFileName;
                app.CalFileLabel.Text = sprintf('✅ Loaded: %s (%d pts)', ...
                    app.CalFileName, numel(app.CalFreq));

                cla(app.CalAxes);
                semilogx(app.CalAxes, app.CalFreq, app.CalDB, ...
                    'Color', [1.0 0.6 0.1], 'LineWidth', 2);
                grid(app.CalAxes, 'on');
            end

            app.updateSampleLists();
            uialert(app.UIFigure, 'Session loaded successfully!', 'Success', 'Icon', 'success');
        end

        %% CLEANUP
        function appCloseRequest(app)
            if app.RTARunning
                app.rtaStop();
            end
            delete(app.UIFigure);
        end

    end % private methods

    methods (Access = public)
        function app = ExhaustAnalyzer()
            app.Samples = struct('name',{},'data',{},'fs',{},'timestamp',{});
            createComponents(app);
            app.UIFigure.Visible = 'on';
        end

        function delete(app)
            if app.RTARunning
                app.rtaStop();
            end
            delete(app.UIFigure);
        end
    end

end