classdef iDAQ < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        filepath
        analysisdate
        time             % Time, milliseconds, since DAQ was powered on
        gyro_x           % X gyro output, deg/sec, with 0.05 deg/sec resolution
        gyro_y           % Y gyro output, deg/sec, with 0.05 deg/sec resolution
        gyro_z           % Z gyro output, deg/sec, with 0.05 deg/sec resolution
        accel_x          % X accelerometer output, Gs, with 0.00333 G resolution
        accel_y          % Y accelerometer output, Gs, with 0.00333 G resolution
        accel_z          % Z accelerometer output, Gs, with 0.00333 G resolution
        link_1           % Raw strain link ADC data, must be converted to force
        link_2           % Raw strain link ADC data, must be converted to force
        link_3           % Raw strain link ADC data, must be converted to force
        link_4           % Raw strain link ADC data, must be converted to force
        link_5           % Raw strain link ADC data, must be converted to force
        adc_1            % Internal DAQ value, engineering use only
        adc_2            % On-board 5V supply monitor
        adc_3            % Internal DAQ value, engineering use only
        adc_4            % Internal DAQ value, engineering use only
        adc_5            % Approximate battery voltage
        adc_6            % On-board 3.3V supply monitor
        adc_7            % User input analog voltage #1, 0V to 4.0V
        adc_8            % User input analog voltage #2, 0V to 4.0V
        adc_temp         % Internal DAQ value, engineering use only
        din_1            % Digital input #1 - Lanyard switch status
        din_2            % General purpose digital input: 0-Low 1-High
        din_3            % General purpose digital input: 0-Low 1-High
        din_4            % General purpose digital input: 0-Low 1-High
        pwrsw            % Power switch status: 0-Pressed 1- Open
        pstemp           % Temperature reported by the pressure sensor, Celsius
        pressure         % Temperature reported by the pressure sensor, Pascals
        GPS_Msgs         % Number of NMEA GPS mesages received from the GPS module
        GPS_Valid        % GPS valid signal: V-Navigation warning A-Valid Data
        GPS_Mode         % GPS mode: M-Manual A-Automatic
        GPS_FixMode      % GPS fix mode; 1-Fix not available 2-2D fix 3-3D fix
        GPS_DateTime     % GPS date and time, YYYYMMDD-HHMMSS
        GPS_SatsInView   % Number of satellites in view
        GPS_SatsInUse    % Number of satellites in use
        GPS_Latitude     % GPS Latitude, decimal degrees
        GPS_Longitude    % GPS Longitude, decimal degrees
        GPS_Altitude     % GPS Altitude, meters
        GPS_GroundSpeed  % GPS Groundspeed, knots true
    end
    
    properties (Access = private)
        nlines
        nheaderlines = 1;
        ndatapoints
        chunksize = 5000;
    end
    
    methods
        function dataObj = iDAQ(filepath)
            if exist('filepath', 'var')
                filepath = fullfile(filepath);  % Ensure correct file separators
                dataObj.filepath = filepath;
            else
                uigetfile({'LOG.*', 'Raw Log File'; ...
                           '*.csv', 'Decoded Raw Log File'; ...
                           '*_proc.mat', 'Processed Log File'}, ...
                          'Select Wamore iDAQ data file' ...
                          );
                dataObj.filepath = [pathname file];
            end
            [~, ~, ext] = fileparts(dataObj.filepath);
            switch ext
                case '.csv'
                    % Parse decoded CSV & process
                    dataObj.analysisdate = iDAQ.getdate();
                    dataObj.nlines = iDAQ.countlines(filepath);
                case '.mat'
                    % No parsing needed, dump data straight in
                otherwise
                    % Need to figure out how to best catch LOG.*** files,
                    % catch them here for now
                    % Decode raw data (LOG.***) and process the resulting CSV
                    dataObj.analysisdate = iDAQ.getdate();
                    iDAQ.wamoredecoder(dataObj.filepath)
            end
        end
    end
    
    
    methods (Access = private)
        function initializedata(dataObj)
            dataObj.ndatapoints = dataObj.nlines - dataObj.nheaderlines;
            
            dataObj.time            = zeros(dataObj.ndatapoints, 1, 'uint32');  % Time, milliseconds, since DAQ was powered on
            dataObj.gyro_x          = zeros(dataObj.ndatapoints, 1);  % X gyro output, deg/sec, with 0.05 deg/sec resolution
            dataObj.gyro_y          = zeros(dataObj.ndatapoints, 1);  % Y gyro output, deg/sec, with 0.05 deg/sec resolution
            dataObj.gyro_z          = zeros(dataObj.ndatapoints, 1);  % Z gyro output, deg/sec, with 0.05 deg/sec resolution
            dataObj.accel_x         = zeros(dataObj.ndatapoints, 1);  % X accelerometer output, Gs, with 0.00333 G resolution
            dataObj.accel_y         = zeros(dataObj.ndatapoints, 1);  % Y accelerometer output, Gs, with 0.00333 G resolution
            dataObj.accel_z         = zeros(dataObj.ndatapoints, 1);  % Z accelerometer output, Gs, with 0.00333 G resolution
%             dataObj.link_1          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
%             dataObj.link_2          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
%             dataObj.link_3          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
%             dataObj.link_4          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
%             dataObj.link_5          = zeros(dataObj.ndatapoints, 1);  % Raw strain link ADC data, must be converted to force
%             dataObj.adc_1           = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
%             dataObj.adc_2           = zeros(dataObj.ndatapoints, 1);  % On-board 5V supply monitor
%             dataObj.adc_3           = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
%             dataObj.adc_4           = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
%             dataObj.adc_5           = zeros(dataObj.ndatapoints, 1);  % Approximate battery voltage
%             dataObj.adc_6           = zeros(dataObj.ndatapoints, 1);  % On-board 3.3V supply monitor
%             dataObj.adc_7           = zeros(dataObj.ndatapoints, 1);  % User input analog voltage #1, 0V to 4.0V
%             dataObj.adc_8           = zeros(dataObj.ndatapoints, 1);  % User input analog voltage #2, 0V to 4.0V
%             dataObj.adc_temp        = zeros(dataObj.ndatapoints, 1);  % Internal DAQ value, engineering use only
%             dataObj.din_1           = false(dataObj.ndatapoints, 1);  % Digital input #1 - Lanyard switch status
%             dataObj.din_2           = false(dataObj.ndatapoints, 1);  % General purpose digital input: 0-Low 1-High
%             dataObj.din_3           = false(dataObj.ndatapoints, 1);  % General purpose digital input: 0-Low 1-High
%             dataObj.din_4           = false(dataObj.ndatapoints, 1);  % General purpose digital input: 0-Low 1-High
            dataObj.pwrsw           = false(dataObj.ndatapoints, 1);  % Power switch status: 0-Pressed 1- Open
            dataObj.pstemp          = zeros(dataObj.ndatapoints, 1);  % Temperature reported by the pressure sensor, Celsius
            dataObj.pressure        = zeros(dataObj.ndatapoints, 1);  % Temperature reported by the pressure sensor, Pascals
            dataObj.GPS_Msgs        = zeros(dataObj.ndatapoints, 1);  % Number of NMEA GPS mesages received from the GPS module
            dataObj.GPS_Valid       = cell(dataObj.ndatapoints, 1);   % GPS valid signal: V-Navigation warning A-Valid Data
            dataObj.GPS_Mode        = cell(dataObj.ndatapoints, 1);   % GPS mode: M-Manual A-Automatic
            dataObj.GPS_FixMode     = zeros(dataObj.ndatapoints, 1, 'uint8');  % GPS fix mode; 1-Fix not available 2-2D fix 3-3D fix
            dataObj.GPS_DateTime    = cell(dataObj.ndatapoints, 1);   % GPS date and time, YYYYMMDD-HHMMSS
            dataObj.GPS_SatsInView  = zeros(dataObj.ndatapoints, 1, 'uint8');  % Number of satellites in view
            dataObj.GPS_SatsInUse   = zeros(dataObj.ndatapoints, 1, 'uint8');  % Number of satellites in use
            dataObj.GPS_Latitude    = zeros(dataObj.ndatapoints, 1);  % GPS Latitude, decimal degrees
            dataObj.GPS_Longitude   = zeros(dataObj.ndatapoints, 1);  % GPS Longitude, decimal degrees
            dataObj.GPS_Altitude    = zeros(dataObj.ndatapoints, 1);  % GPS Altitude, meters
            dataObj.GPS_GroundSpeed = zeros(dataObj.ndatapoints, 1);  % GPS Groundspeed, knots true
        end
    end
    
        
    methods (Static)
        function date = getdate()
            if ~verLessThan('MATLAB', '8.4')  % datetime added in R2014b
                timenow = datetime('now', 'TimeZone', 'local');
                formatstr = sprintf('yyyy-mm-ddTHH:MM:SS%sZ', char(tzoffset(timenow)));
            else
                UTCoffset = -java.util.Date().getTimezoneOffset/60;  % See what Java thinks your TZ offset is
                timenow = clock;
                formatstr = sprintf('yyyy-mm-ddTHH:MM:SS%i:00Z', UTCoffset);
            end
            
            date = datestr(timenow, formatstr);  % ISO 8601 format
        end
        
        
        function nlines = countlines(filepath)
            % Count the number of lines present in the specified file.
            % filepath should be an absolute path
            
            filepath = fullfile(filepath);  % Make sure we're using the correct OS file separators
            
            % Attempt to use system specific calls, otherwise use MATLAB
            if ispc
                syscall = sprintf('find /v /c "" "%s"', filepath);
                [~, cmdout] = system(syscall);
                tmp = regexp(cmdout, '(?<=(:\s))(\d*)', 'match');
                nlines = str2double(tmp{1});
            elseif ismac || isunix
                syscall = sprintf('wc -l < "%s"', filepath);
                [~, cmdout] = system(syscall);
                nlines = str2double(cmdout);
            else
                % Can't determine OS, use MATLAB instead
                fID = fopen(filepath, 'rt');
                
                nlines = 0;
                while ~feof(fID)
                    nlines = nlines + sum(fread(fID, 16384, 'char') == char(10));
                end
                
                fclose(fID);
            end
        end
        
        
        function wamoredecoder(filepath)
            [pathname, filename, ext] = fileparts(filepath);
            startdir = cd(pathname);
            file = [filename, ext];
            if ~exist([file '.csv'], 'file')
                fprintf('Decoding Log %s ... ', regexprep(ext, '\.', ''))
                tic
                [~, cmdout] = dos(['logdecoder.exe ' file]);
                elapsedtime = toc;
                fprintf('logdecoder.exe exited, elapsed time %.3f seconds\n', elapsedtime)
                cd(startdir)
            else
                fprintf('Log %s already decoded, skipping decoder\n', regexprep(ext, '\.', ''))
                cd(startdir)
            end
        end
    end
    
end

